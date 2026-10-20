import 'dart:io';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:camera/camera.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/database_service.dart';
import '../services/notification_service.dart';
import '../models/pantry_item.dart';
import '../utils/ui_helpers.dart';
import '../utils/keyword_mapping_algorithm.dart';
import '../widgets/consumption_modal.dart';
import 'coach_screen.dart';
import '../main.dart';

class ScannerScreen extends StatefulWidget {
  final DatabaseService dbService;
  const ScannerScreen({super.key, required this.dbService});

  @override
  State<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends State<ScannerScreen>
    with WidgetsBindingObserver, TickerProviderStateMixin {
  CameraController? _controller;
  bool _isInitialized = false;
  bool _isFlashOn = false;

  // DYNAMIC SETTINGS STATES
  bool _settingHaptic = true;
  bool _settingAutoFlash = false;
  bool _settingBatchScan = false;
  bool _settingStrictMode = false;

  final ImagePicker _picker = ImagePicker();
  File? _capturedImage;
  bool _isAnalyzing = false;

  late TextRecognizer _textRecognizer;
  bool _isScanning = false;
  bool _isProcessingFrame = false;
  Timer? _snarkTimer;
  String _snarkyMessage = "";

  bool _isLocking = false;
  Timer? _lockTimer;
  String _bestExtractedText = "";

  // EXPANDED: 12 Unique Snarky Messages
  final List<String> _snarkyMessages = [
    "Unless this sachet is written in invisible ink, there are zero ingredients here.",
    "I'm an OCR scanner, not a mind reader. Point me at a nutrition label!",
    "Are you scanning an egg? Bring me a beverage sachet.",
    "No ingredients detected. Either this is pure air, or you need to get closer.",
    "I see a lot of things, but 'Ingredients' isn't one of them. Try rotating the sachet.",
    "Are we scanning a blank wall today? Get me closer to the text!",
    "My AI brain is powerful, but it can't invent ingredients that aren't in the camera frame.",
    "Hold still! Or at least point me at the back of the packet.",
    "Did you drink it already? Because I'm not seeing any nutritional info.",
    "I'm looking for words like 'sugar' or 'citric acid', not your thumb.",
    "Still waiting... Did you forget to flip the sachet over?",
    "If this is a staring contest, you're winning. Now show me the ingredients."
  ];

  String _rawText = "Waiting for scan...";
  String _productName = "Unnamed";

  String _riskLevel = "GREEN";
  double _finalRiskScore = 0.0;
  bool _exceedsDailyCap = false;
  String _detectedTriggersText = "None";

  String _symptoms = "None";
  int _symptomSeverity = 0;

  double _currentZoomLevel = 1.0;
  double _minZoomLevel = 1.0;
  double _maxZoomLevel = 1.0;

  late AnimationController _laserController;
  late Animation<double> _laserAnimation;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);

    _laserController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    _laserAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _laserController, curve: Curves.easeInOutSine),
    );

    _initCameraAndSettings();
  }

  Future<void> _initCameraAndSettings() async {
    final prefs = await SharedPreferences.getInstance();
    _settingHaptic = prefs.getBool('setting_haptic') ?? true;
    _settingAutoFlash = prefs.getBool('setting_flash') ?? false;
    _settingBatchScan = prefs.getBool('setting_batch') ?? false;
    _settingStrictMode = prefs.getBool('setting_strictness') ?? false;

    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) return;

      _controller = CameraController(
        cameras[0],
        ResolutionPreset.high,
        enableAudio: false,
        imageFormatGroup: Platform.isAndroid
            ? ImageFormatGroup.nv21
            : ImageFormatGroup.bgra8888,
      );
      await _controller!.initialize();

      _minZoomLevel = await _controller!.getMinZoomLevel();
      _maxZoomLevel = await _controller!.getMaxZoomLevel();

      if (mounted) {
        setState(() {
          _isInitialized = true;
          _isFlashOn = _settingAutoFlash;
        });

        if (_settingAutoFlash) {
          await _controller!.setFlashMode(FlashMode.torch);
        } else {
          await _controller!.setFlashMode(FlashMode.off);
        }

        _startAutoScan();
      }
    } catch (e) {
      debugPrint("Camera Error: $e");
    }
  }

  void _startAutoScan() {
    setState(() {
      _snarkyMessage = "";
      _isScanning = true;
      _isLocking = false;
      _bestExtractedText = "";
      _capturedImage = null;
    });

    _laserController.repeat(reverse: true);

    _snarkTimer?.cancel();
    _lockTimer?.cancel();

    _snarkTimer = Timer(const Duration(seconds: 10), () async {
      if (_isLocking) return;

      if (_controller != null && _controller!.value.isStreamingImages) {
        await _controller!.stopImageStream();
      }
      if (mounted) {
        setState(() {
          _isScanning = false;
          _snarkyMessage = (_snarkyMessages.toList()..shuffle()).first;
        });
        if (_settingHaptic) HapticFeedback.mediumImpact();
      }
    });

    _controller!.startImageStream((CameraImage image) {
      if (_isProcessingFrame) return;
      _isProcessingFrame = true;
      _processCameraFrame(image);
    });
  }

  String _getVisuallySortedText(RecognizedText recognizedText) {
    List<TextBlock> blocks = List.from(recognizedText.blocks);

    blocks.sort((a, b) {
      final aTop = a.boundingBox.top;
      final bTop = b.boundingBox.top;
      final aLeft = a.boundingBox.left;
      final bLeft = b.boundingBox.left;

      if ((aTop - bTop).abs() < 20.0) {
        return aLeft.compareTo(bLeft);
      }
      return aTop.compareTo(bTop);
    });

    return blocks.map((b) => b.text).join('\n\n');
  }

  Future<void> _processCameraFrame(CameraImage image) async {
    try {
      final WriteBuffer allBytes = WriteBuffer();
      for (final Plane plane in image.planes) {
        allBytes.putUint8List(plane.bytes);
      }
      final bytes = allBytes.done().buffer.asUint8List();

      final Size imageSize =
          Size(image.width.toDouble(), image.height.toDouble());
      final camera = _controller!.description;
      final imageRotation =
          InputImageRotationValue.fromRawValue(camera.sensorOrientation) ??
              InputImageRotation.rotation0deg;

      final inputImageFormat =
          InputImageFormatValue.fromRawValue(image.format.raw) ??
              (Platform.isAndroid
                  ? InputImageFormat.nv21
                  : InputImageFormat.bgra8888);

      final metadata = InputImageMetadata(
        size: imageSize,
        rotation: imageRotation,
        format: inputImageFormat,
        bytesPerRow: image.planes[0].bytesPerRow,
      );

      final inputImage = InputImage.fromBytes(bytes: bytes, metadata: metadata);
      final RecognizedText recognizedText =
          await _textRecognizer.processImage(inputImage);

      String sortedText = _getVisuallySortedText(recognizedText);

      String? isolatedIngredientsText = _autoIsolateIngredients(sortedText) ??
          _autoIsolateIngredients(recognizedText.text);

      if (isolatedIngredientsText != null) {
        _bestExtractedText = isolatedIngredientsText;

        if (!_isLocking) {
          if (mounted) {
            setState(() {
              _isLocking = true;
            });
          }
          if (_settingHaptic) HapticFeedback.lightImpact();

          _lockTimer = Timer(const Duration(milliseconds: 1800), () async {
            _snarkTimer?.cancel();
            if (_controller != null && _controller!.value.isStreamingImages) {
              await _controller!.stopImageStream();
            }

            if (mounted) {
              try {
                final XFile file = await _controller!.takePicture();
                setState(() {
                  _capturedImage = File(file.path);
                });
              } catch (e) {
                debugPrint("Error taking auto-scan picture: $e");
              }
            }

            await _processExtractedText(
                _bestExtractedText, "Auto-Scanned Sachet");
          });
        }
      }
    } catch (e) {
      debugPrint("Frame processing error: $e");
    } finally {
      if (mounted) _isProcessingFrame = false;
    }
  }

  String? _autoIsolateIngredients(String rawText) {
    String lowerText = rawText.toLowerCase();

    List<String> startKeywords = [
      'ingredients:',
      'ingredients',
      'mga sangkap:',
      'mga sangkap',
      'sangkap:',
      'contains:'
    ];

    int startIndex = -1;
    for (String keyword in startKeywords) {
      startIndex = lowerText.indexOf(keyword);
      if (startIndex != -1) break;
    }

    if (startIndex == -1) return null;

    String isolatedBlock = rawText.substring(startIndex);
    String lowerIsolated = isolatedBlock.toLowerCase();

    List<String> stopKeywords = [
      'allergen',
      'manufactured',
      'distributed',
      'store in',
      'store out',
      'net weight',
      'net wt',
      'best before',
      'expiry',
      'nutrition',
      'produced by',
      'imported by',
      'warning',
      'caution',
      'directions',
      'preparation',
      'how to prepare',
      'how to use',
      'fda reg',
      'lot no',
      'serving size',
      'serving suggestion',
      'keep in a cool',
      'to prepare',
      'pour contents',
      'empty sachet'
    ];

    int stopIndex = isolatedBlock.length;

    for (String stopWord in stopKeywords) {
      int index = lowerIsolated.indexOf(stopWord);
      if (index > 15 && index < stopIndex) {
        stopIndex = index;
      }
    }

    int doubleNewlineIndex = isolatedBlock.indexOf('\n\n', 20);
    if (doubleNewlineIndex != -1 && doubleNewlineIndex < stopIndex) {
      stopIndex = doubleNewlineIndex;
    }

    String cleanIngredients = isolatedBlock.substring(0, stopIndex).trim();
    cleanIngredients =
        cleanIngredients.replaceAll(RegExp(r'\s*\n\s*'), ' ').trim();

    if (cleanIngredients.length > 400) {
      cleanIngredients = cleanIngredients.substring(0, 400) + "... (Truncated)";
    }

    return cleanIngredients;
  }

  Future<void> _processExtractedText(String text, String sourceName) async {
    try {
      final triggers = await widget.dbService.getAllTriggers();
      final userProfile = await widget.dbService.getUserProfile();
      double currentDailyLoad = await _calculateDailyLoad();

      var result = KeywordMappingAlgorithm.analyze(
          text, triggers, userProfile, currentDailyLoad);

      if (_settingStrictMode && result.riskLevel == "YELLOW") {
        result = KeywordMappingAlgorithm.analyze(
            text, triggers, userProfile, currentDailyLoad + 5.0);
        result.riskLevel = "RED";
      }

      if (mounted) {
        setState(() {
          _isAnalyzing = false;
          _laserController.stop();
          _rawText = text.isEmpty ? "No text detected." : text;
          _riskLevel = result.riskLevel;
          _finalRiskScore = result.finalRiskScore;
          _detectedTriggersText = result.triggersSummary;
          _exceedsDailyCap = result.exceedsDailyCap;
          _productName = sourceName;
        });

        if (_settingHaptic) {
          if (_riskLevel == "RED" || _exceedsDailyCap) {
            HapticFeedback.heavyImpact();
            Future.delayed(const Duration(milliseconds: 150),
                () => HapticFeedback.heavyImpact());
          } else if (_riskLevel == "GREEN") {
            HapticFeedback.lightImpact();
          }
        }
      }
    } catch (e) {
      debugPrint("Analysis Error: $e");
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _snarkTimer?.cancel();
    _lockTimer?.cancel();
    _laserController.dispose();
    _textRecognizer.close();

    if (_controller != null && _controller!.value.isInitialized) {
      if (_controller!.value.isStreamingImages) {
        _controller!.stopImageStream();
      }
      _controller!.setFlashMode(FlashMode.off);
      _controller!.dispose();
    }
    super.dispose();
  }

  void _onFocusTap(TapDownDetails details, BoxConstraints constraints) {
    if (_controller == null || !_controller!.value.isInitialized) return;
    final offset = Offset(
      details.localPosition.dx / constraints.maxWidth,
      details.localPosition.dy / constraints.maxHeight,
    );
    _controller!.setFocusPoint(offset);
    _controller!.setExposurePoint(offset);
  }

  void _onScaleUpdate(ScaleUpdateDetails details) async {
    if (_controller == null || !_controller!.value.isInitialized) return;
    double newZoom = _currentZoomLevel * details.scale;
    if (newZoom < _minZoomLevel) newZoom = _minZoomLevel;
    if (newZoom > _maxZoomLevel) newZoom = _maxZoomLevel;
    await _controller!.setZoomLevel(newZoom);
    _currentZoomLevel = newZoom;
  }

  Future<void> _toggleFlash() async {
    if (_controller == null || !_controller!.value.isInitialized) return;
    try {
      setState(() => _isFlashOn = !_isFlashOn);
      await _controller!
          .setFlashMode(_isFlashOn ? FlashMode.torch : FlashMode.off);
    } catch (e) {
      debugPrint("Flash Error: $e");
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_controller == null || !_controller!.value.isInitialized) return;
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused) {
      if (_controller!.value.isStreamingImages) {
        _controller!.stopImageStream();
      }
      _controller!.dispose();
      if (mounted) setState(() => _isInitialized = false);
    } else if (state == AppLifecycleState.resumed) {
      _initCameraAndSettings();
    }
  }

  Future<double> _calculateDailyLoad() async {
    final allItems = await widget.dbService.getPantryItems();
    final now = DateTime.now();
    double load = 0.0;
    for (var item in allItems) {
      if (item.dateScanned.year == now.year &&
          item.dateScanned.month == now.month &&
          item.dateScanned.day == now.day) {
        load += item.acidScore.toDouble();
      }
    }
    return load;
  }

  Future<File?> _cropImage(File imageFile) async {
    final croppedFile = await ImageCropper().cropImage(
      sourcePath: imageFile.path,
      compressQuality: 100,
      uiSettings: [
        AndroidUiSettings(
            toolbarTitle: 'Crop Ingredients',
            toolbarColor: AppColors.primary,
            toolbarWidgetColor: Colors.white,
            initAspectRatio: CropAspectRatioPreset.original,
            lockAspectRatio: false,
            hideBottomControls: false),
        IOSUiSettings(title: 'Crop Ingredients'),
      ],
    );
    if (croppedFile != null) {
      return File(croppedFile.path);
    }
    return null;
  }

  Future<void> _pickFromGallery() async {
    try {
      if (_controller != null && _controller!.value.isStreamingImages) {
        await _controller!.stopImageStream();
      }
      _snarkTimer?.cancel();
      _lockTimer?.cancel();

      final pickedFile = await _picker.pickImage(source: ImageSource.gallery);
      if (pickedFile == null) {
        _startAutoScan();
        return;
      }

      File? cropped = await _cropImage(File(pickedFile.path));
      if (cropped == null) {
        _startAutoScan();
        return;
      }

      setState(() {
        _capturedImage = cropped;
        _isAnalyzing = true;
      });

      _laserController.repeat(reverse: true);
      await _processImageForOCR(cropped.path, "Gallery Upload");
    } catch (e) {
      debugPrint("Gallery Error: $e");
    }
  }

  Future<void> _takePictureAndScan() async {
    if (_controller == null || !_controller!.value.isInitialized) return;

    try {
      if (_controller!.value.isStreamingImages) {
        await _controller!.stopImageStream();
      }
      _snarkTimer?.cancel();
      _lockTimer?.cancel();

      final image = await _controller!.takePicture();

      if (_isFlashOn) {
        await _controller!.setFlashMode(FlashMode.off);
        _isFlashOn = false;
      }

      File? cropped = await _cropImage(File(image.path));
      if (cropped == null) {
        _startAutoScan();
        return;
      }

      setState(() {
        _capturedImage = cropped;
        _isAnalyzing = true;
      });

      _laserController.repeat(reverse: true);
      await _processImageForOCR(cropped.path, "Scanned Sachet");
    } catch (e) {
      debugPrint("Capture Error: $e");
    }
  }

  Future<void> _processImageForOCR(String imagePath, String defaultName) async {
    try {
      final inputImage = InputImage.fromFilePath(imagePath);
      final RecognizedText recognizedText =
          await _textRecognizer.processImage(inputImage);

      String sortedText = _getVisuallySortedText(recognizedText);

      String isolatedIngredientsText = _autoIsolateIngredients(sortedText) ??
          _autoIsolateIngredients(recognizedText.text) ??
          sortedText;

      await _processExtractedText(isolatedIngredientsText, defaultName);
    } catch (e) {
      debugPrint("Manual OCR Error: $e");
    }
  }

  Future<void> _saveToDatabase() async {
    final contextData = await ConsumptionModal.show(context, _productName);

    if (contextData == null) return;

    String? permanentImagePath;

    if (_capturedImage != null && _capturedImage!.path != 'manual_entry') {
      try {
        final directory = await getApplicationDocumentsDirectory();
        final String fileName =
            'sachet_${DateTime.now().millisecondsSinceEpoch}.jpg';
        final String newPath = '${directory.path}/$fileName';
        final File savedImage = await _capturedImage!.copy(newPath);
        permanentImagePath = savedImage.path;
      } catch (e) {
        debugPrint("Error saving permanent image: $e");
      }
    }

    final newItem = PantryItem()
      ..name = _productName
      ..dateScanned = DateTime.now()
      ..symptoms = _symptoms == "None" ? "" : _symptoms
      ..riskLevel = _riskLevel
      ..isFavorite = false
      ..rawText = _rawText
      ..acidScore = _finalRiskScore.round()
      ..imagePath = permanentImagePath
      ..isEmptyStomach = contextData['isEmptyStomach'] ?? false
      ..isDiluted = contextData['isDiluted'] ?? false;

    await widget.dbService.savePantryItem(newItem);

    final notifService = NotificationService();

    notifService.scheduleTargetedNotification(
      id: NotificationService.digestionTimerId,
      title: 'Digestion Complete',
      body:
          'It has been 4 hours since your last drink. Your stomach load has reset.',
      delay: const Duration(hours: 4),
    );

    if (newItem.isEmptyStomach && !newItem.isDiluted) {
      notifService.scheduleTargetedNotification(
        id: NotificationService.hydrationChaserId,
        title: 'Acid Buffer Reminder',
        body:
            'Since you had ${newItem.name} on an empty stomach, slowly sip some water now to coat your stomach lining.',
        delay: const Duration(minutes: 15),
      );
    }

    if ((newItem.riskLevel == "RED" || newItem.riskLevel == "YELLOW") &&
        (newItem.symptoms.isEmpty || newItem.symptoms == "None")) {
      notifService.scheduleTargetedNotification(
        id: NotificationService.symptomCheckinId,
        title: 'Symptom Check-In',
        body:
            'How is your stomach feeling after drinking ${newItem.name}? Tap to log any discomfort.',
        delay: const Duration(minutes: 45),
      );
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Item Consumed & Saved!'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating),
      );

      if (_settingBatchScan) {
        _startAutoScan();
      } else {
        Navigator.pop(context);
      }
    }
  }

  void _showEditNameModal() {
    final TextEditingController nameController =
        TextEditingController(text: _productName);
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Container(
          padding: const EdgeInsets.all(25),
          decoration: BoxDecoration(
              color: Colors.white, borderRadius: BorderRadius.circular(20)),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Name This Drink',
                  style: TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 18,
                      color: AppColors.primaryDark)),
              const SizedBox(height: 20),
              TextField(
                controller: nameController,
                decoration: InputDecoration(
                  hintText: 'e.g., Nescafe 3-in-1',
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(15)),
                  focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(15),
                      borderSide: const BorderSide(color: AppColors.primary)),
                ),
              ),
              const SizedBox(height: 25),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(15))),
                  onPressed: () {
                    setState(() {
                      _productName = nameController.text.isEmpty
                          ? "Unnamed"
                          : nameController.text;
                    });
                    Navigator.pop(context);
                  },
                  child: const Text('Save Name',
                      style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16)),
                ),
              )
            ],
          ),
        ),
      ),
    );
  }

  void _showManualEntryModal() {
    final textController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
              color: Colors.white, borderRadius: BorderRadius.circular(20)),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context)),
                  const Text('Manual Entry',
                      style:
                          TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(width: 48),
                ],
              ),
              const SizedBox(height: 10),
              TextField(
                controller: textController,
                maxLines: 5,
                decoration: InputDecoration(
                  hintText: 'Type ingredients separated by commas...',
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(15)),
                  focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(15),
                      borderSide: const BorderSide(color: AppColors.primary)),
                ),
              ),
              const SizedBox(height: 20),
              GradientButton(
                text: 'Analyze',
                onPressed: () async {
                  final text = textController.text;
                  Navigator.pop(context);

                  if (_controller != null &&
                      _controller!.value.isStreamingImages) {
                    await _controller!.stopImageStream();
                  }
                  _snarkTimer?.cancel();
                  _lockTimer?.cancel();

                  setState(() {
                    _capturedImage = File('manual_entry');
                  });

                  await _processExtractedText(
                      text.isEmpty ? "No text provided." : text,
                      "Manual Entry");
                },
              )
            ],
          ),
        ),
      ),
    );
  }

  void _showDeleteModal() {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
        child: Container(
          padding: const EdgeInsets.all(30),
          decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(30)),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Align(
                  alignment: Alignment.centerLeft,
                  child: IconButton(
                      icon: Image.asset('assets/images/back_1.png',
                          width: 24, color: Colors.white),
                      onPressed: () => Navigator.pop(context),
                      padding: EdgeInsets.zero)),
              const SizedBox(height: 10),
              const Text('Discard Scan?',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 32,
                      fontWeight: FontWeight.w900)),
              const SizedBox(height: 20),
              const Text(
                  'Are you sure you want to discard this scanned product? It will not be saved to your pantry.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      color: Colors.white, fontSize: 16, height: 1.5)),
              const SizedBox(height: 30),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white.withOpacity(0.2),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20)),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 25, vertical: 12)),
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel',
                        style: TextStyle(
                            color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20)),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 25, vertical: 12)),
                    onPressed: () {
                      Navigator.pop(context);
                      setState(() => _capturedImage = null);
                      _startAutoScan();
                    },
                    child: const Text('Discard',
                        style: TextStyle(
                            color: AppColors.primaryDark,
                            fontWeight: FontWeight.bold)),
                  ),
                ],
              )
            ],
          ),
        ),
      ),
    );
  }

  void _showSymptomsModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(builder: (context, setModalState) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.65,
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.only(
                topLeft: Radius.circular(30), topRight: Radius.circular(30)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(30.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                    child: Container(
                        width: 40,
                        height: 5,
                        decoration: BoxDecoration(
                            color: Colors.grey.shade300,
                            borderRadius: BorderRadius.circular(10)))),
                const SizedBox(height: 20),
                const Row(
                  children: [
                    Icon(Icons.local_fire_department,
                        color: Colors.orange, size: 36),
                    SizedBox(width: 15),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Log a Symptom',
                              style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w900,
                                  color: AppColors.textDark)),
                          Text('Track how you feel after this product',
                              style: TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textGrey,
                                  fontWeight: FontWeight.w500)),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: Colors.grey.shade200),
                              boxShadow: [
                                BoxShadow(
                                    color: Colors.black.withOpacity(0.05),
                                    blurRadius: 10,
                                    offset: const Offset(0, 5))
                              ]),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                  'What symptoms are you currently experiencing?',
                                  style: TextStyle(
                                      fontWeight: FontWeight.w900,
                                      color: AppColors.textDark)),
                              const SizedBox(height: 10),
                              _buildSymptomRadio('Burning pain', setModalState),
                              _buildSymptomRadio('Nausea', setModalState),
                              _buildSymptomRadio(
                                  'Excessive burping', setModalState),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: Colors.grey.shade200),
                              boxShadow: [
                                BoxShadow(
                                    color: Colors.black.withOpacity(0.05),
                                    blurRadius: 10,
                                    offset: const Offset(0, 5))
                              ]),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                  'On a scale of 1 to 10, how severe is your discomfort right now?',
                                  style: TextStyle(
                                      fontWeight: FontWeight.w900,
                                      color: AppColors.textDark)),
                              Row(
                                children: [
                                  Expanded(
                                      child: Slider(
                                          value: _symptomSeverity.toDouble(),
                                          min: 0,
                                          max: 10,
                                          divisions: 10,
                                          activeColor: AppColors.primary,
                                          onChanged: (val) => setModalState(
                                              () => _symptomSeverity =
                                                  val.toInt()))),
                                  Text('$_symptomSeverity',
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w900,
                                          fontSize: 18,
                                          color: AppColors.primary)),
                                ],
                              )
                            ],
                          ),
                        ),
                        const SizedBox(height: 30),
                      ],
                    ),
                  ),
                ),
                SizedBox(
                  width: double.infinity,
                  height: 55,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30))),
                    onPressed: () {
                      setState(() {});
                      Navigator.pop(context);
                    },
                    child: const Text('Save Log',
                        style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 16)),
                  ),
                )
              ],
            ),
          ),
        );
      }),
    );
  }

  Widget _buildSymptomRadio(String title, Function setModalState) {
    return InkWell(
      onTap: () => setModalState(() => _symptoms = title),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Row(
          children: [
            Icon(
                _symptoms == title
                    ? Icons.radio_button_checked
                    : Icons.radio_button_unchecked,
                color: _symptoms == title ? AppColors.primary : Colors.grey,
                size: 18),
            const SizedBox(width: 10),
            Text(title,
                style: const TextStyle(
                    fontSize: 14,
                    color: AppColors.textDark,
                    fontWeight: FontWeight.w500)),
          ],
        ),
      ),
    );
  }

  String _getRiskLevelText() {
    if (_riskLevel == "RED") return "High Danger";
    if (_riskLevel == "YELLOW") return "Moderate Risk";
    return "Safe to Consume";
  }

  Color _getRiskColor() {
    if (_riskLevel == "RED") return AppColors.errorRed;
    if (_riskLevel == "YELLOW") return AppColors.accentOrange;
    return Colors.green;
  }

  Widget _buildResultBottomBar() {
    return Container(
      padding: const EdgeInsets.only(left: 20, right: 20, top: 15, bottom: 30),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 20,
              offset: const Offset(0, -5))
        ],
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            InkWell(
              onTap: _showDeleteModal,
              child: Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Icon(Icons.delete_outline,
                    color: Colors.red, size: 28),
              ),
            ),
            const SizedBox(width: 15),
            Expanded(
              child: SizedBox(
                height: 60,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    padding: EdgeInsets.zero,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20)),
                    elevation: 0,
                  ),
                  onPressed: _saveToDatabase,
                  child: Ink(
                    decoration: BoxDecoration(
                      gradient: AppColors.primaryGradient,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Center(
                      child: Text('Consumed',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w900)),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    bool isResultView = _capturedImage != null;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
            icon: Image.asset('assets/images/back_1.png',
                width: 24, color: AppColors.primaryDark),
            onPressed: () {
              if (isResultView) {
                setState(() => _capturedImage = null);
                _startAutoScan();
              } else {
                Navigator.pop(context);
              }
            }),
        title: Text(isResultView ? '' : 'Auto-Scan Mode',
            style: const TextStyle(
                color: AppColors.primaryDark,
                fontWeight: FontWeight.w900,
                fontSize: 24)),
        centerTitle: true,
      ),
      body: Stack(
        children: [
          SafeArea(
            child: SingleChildScrollView(
              padding:
                  const EdgeInsets.symmetric(horizontal: 25.0, vertical: 10),
              child: Column(
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(30),
                        boxShadow: [
                          BoxShadow(
                              color: AppColors.primary.withOpacity(0.1),
                              blurRadius: 20,
                              offset: const Offset(0, 10))
                        ]),
                    child: Stack(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(20),
                          child: AspectRatio(
                            aspectRatio: 1,
                            child: isResultView
                                ? (_capturedImage!.path == 'manual_entry'
                                    ? Container(
                                        color: AppColors.background,
                                        child: Column(
                                            mainAxisAlignment:
                                                MainAxisAlignment.center,
                                            children: const [
                                              Icon(Icons.check_circle_outline,
                                                  color: AppColors.primary,
                                                  size: 60),
                                              SizedBox(height: 15),
                                              Text('Manual Entry Analysis',
                                                  style: TextStyle(
                                                      color:
                                                          AppColors.primaryDark,
                                                      fontWeight:
                                                          FontWeight.bold))
                                            ]))
                                    : Stack(
                                        fit: StackFit.expand,
                                        children: [
                                          Image.file(_capturedImage!,
                                              fit: BoxFit.cover),
                                          if (_isAnalyzing)
                                            AnimatedBuilder(
                                              animation: _laserAnimation,
                                              builder: (context, child) {
                                                return Positioned(
                                                  top: _laserAnimation.value *
                                                      (MediaQuery.of(context)
                                                              .size
                                                              .width -
                                                          50),
                                                  left: 0,
                                                  right: 0,
                                                  child: Container(
                                                    height: 3,
                                                    decoration: BoxDecoration(
                                                      color: AppColors.primary,
                                                      boxShadow: [
                                                        BoxShadow(
                                                            color: AppColors
                                                                .primaryLight,
                                                            blurRadius: 10,
                                                            spreadRadius: 3)
                                                      ],
                                                    ),
                                                  ),
                                                );
                                              },
                                            ),
                                        ],
                                      ))
                                : (_isInitialized
                                    ? LayoutBuilder(
                                        builder: (context, constraints) {
                                          return Stack(
                                            fit: StackFit.expand,
                                            children: [
                                              GestureDetector(
                                                onTapDown: (details) =>
                                                    _onFocusTap(
                                                        details, constraints),
                                                onScaleUpdate: _onScaleUpdate,
                                                child: FittedBox(
                                                  fit: BoxFit.cover,
                                                  child: SizedBox(
                                                    width: _controller!.value
                                                        .previewSize!.height,
                                                    height: _controller!.value
                                                        .previewSize!.width,
                                                    child: CameraPreview(
                                                        _controller!),
                                                  ),
                                                ),
                                              ),
                                              Center(
                                                child: Column(
                                                  mainAxisSize:
                                                      MainAxisSize.min,
                                                  children: [
                                                    Container(
                                                      width: 260,
                                                      height: 160,
                                                      decoration: BoxDecoration(
                                                          border: Border.all(
                                                              color: _isLocking
                                                                  ? Colors.green
                                                                  : AppColors
                                                                      .primaryLight
                                                                      .withOpacity(
                                                                          0.8),
                                                              width: 3),
                                                          borderRadius:
                                                              BorderRadius
                                                                  .circular(20),
                                                          boxShadow: [
                                                            BoxShadow(
                                                                color: _isLocking
                                                                    ? Colors
                                                                        .green
                                                                        .withOpacity(
                                                                            0.2)
                                                                    : AppColors
                                                                        .primary
                                                                        .withOpacity(
                                                                            0.2),
                                                                blurRadius: 15,
                                                                spreadRadius: 2)
                                                          ]),
                                                    ),
                                                    const SizedBox(height: 15),
                                                    Container(
                                                      padding: const EdgeInsets
                                                          .symmetric(
                                                          horizontal: 15,
                                                          vertical: 8),
                                                      decoration: BoxDecoration(
                                                        color: _isLocking
                                                            ? Colors.green
                                                                .withOpacity(
                                                                    0.8)
                                                            : Colors.black
                                                                .withOpacity(
                                                                    0.6),
                                                        borderRadius:
                                                            BorderRadius
                                                                .circular(20),
                                                      ),
                                                      child: Text(
                                                        _isLocking
                                                            ? 'Ingredients found! Hold still...'
                                                            : 'Auto-scanning for "Ingredients"...',
                                                        style: const TextStyle(
                                                            color: Colors.white,
                                                            fontWeight:
                                                                FontWeight.bold,
                                                            fontSize: 12),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              AnimatedBuilder(
                                                animation: _laserAnimation,
                                                builder: (context, child) {
                                                  return Positioned(
                                                    top: _laserAnimation.value *
                                                        constraints.maxHeight,
                                                    left: 0,
                                                    right: 0,
                                                    child: Container(
                                                      height: 3,
                                                      decoration: BoxDecoration(
                                                        color: _isLocking
                                                            ? Colors.green
                                                            : AppColors.primary,
                                                        boxShadow: [
                                                          BoxShadow(
                                                              color: _isLocking
                                                                  ? Colors
                                                                      .greenAccent
                                                                  : AppColors
                                                                      .primaryLight,
                                                              blurRadius: 10,
                                                              spreadRadius: 3)
                                                        ],
                                                      ),
                                                    ),
                                                  );
                                                },
                                              ),
                                            ],
                                          );
                                        },
                                      )
                                    : Container(
                                        color: Colors.black,
                                        child: const Center(
                                            child: CircularProgressIndicator(
                                                color: Colors.white)))),
                          ),
                        ),
                        if (!isResultView)
                          Positioned(
                            top: 15,
                            right: 15,
                            child: GestureDetector(
                              onTap: _toggleFlash,
                              child: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                    color: Colors.black45,
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                        color: Colors.white, width: 1.5)),
                                child: Icon(
                                    _isFlashOn
                                        ? Icons.flash_on
                                        : Icons.flash_off,
                                    color: Colors.white,
                                    size: 20),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  if (isResultView) ...[
                    if (_isAnalyzing) ...[
                      const SizedBox(height: 60),
                      const Center(
                          child: CircularProgressIndicator(
                              color: AppColors.primary)),
                      const SizedBox(height: 20),
                      const Center(
                          child: Text('Extracting text via Google ML Kit...',
                              style: TextStyle(
                                  color: AppColors.primaryDark,
                                  fontWeight: FontWeight.bold))),
                      const SizedBox(height: 100),
                    ] else ...[
                      GestureDetector(
                        onTap: _showEditNameModal,
                        child: Row(
                          children: [
                            Expanded(
                                child: Text(_productName,
                                    style: const TextStyle(
                                        fontSize: 32,
                                        fontWeight: FontWeight.w900,
                                        color: AppColors.primaryDark,
                                        decoration: TextDecoration.underline,
                                        decorationColor:
                                            AppColors.primaryDark))),
                            const Icon(Icons.edit_outlined,
                                color: AppColors.primaryDark, size: 22),
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),
                      if (_exceedsDailyCap)
                        Container(
                            width: double.infinity,
                            margin: const EdgeInsets.only(bottom: 15),
                            padding: const EdgeInsets.all(15),
                            decoration: BoxDecoration(
                                color: Colors.red.withOpacity(0.1),
                                border: Border.all(
                                    color: Colors.red.shade200, width: 2),
                                borderRadius: BorderRadius.circular(15)),
                            child: const Row(
                              children: [
                                Icon(Icons.warning_amber_rounded,
                                    color: Colors.red, size: 28),
                                SizedBox(width: 10),
                                Expanded(
                                    child: Text(
                                  "DAILY LIMIT EXCEEDED. Consuming this item breaches your safe acid threshold.",
                                  style: TextStyle(
                                      color: Colors.red,
                                      fontWeight: FontWeight.bold,
                                      height: 1.4),
                                ))
                              ],
                            )),
                      if (_symptoms != "None") ...[
                        Container(
                          padding: const EdgeInsets.all(15),
                          decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(25),
                              boxShadow: [
                                BoxShadow(
                                    color: Colors.black.withOpacity(0.05),
                                    blurRadius: 10)
                              ]),
                          child: Row(
                            children: [
                              const Icon(Icons.local_fire_department,
                                  color: Colors.orange, size: 36),
                              const SizedBox(width: 15),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('Logged Symptom',
                                        style: TextStyle(
                                            fontWeight: FontWeight.w900,
                                            fontSize: 14,
                                            color: AppColors.textDark)),
                                    Text(_symptoms,
                                        style: const TextStyle(
                                            fontSize: 12,
                                            color: AppColors.textGrey)),
                                  ],
                                ),
                              ),
                              Text('Severity: $_symptomSeverity',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w900,
                                      color: AppColors.textDark,
                                      fontSize: 14)),
                            ],
                          ),
                        ),
                        const SizedBox(height: 15),
                      ] else ...[
                        Align(
                            alignment: Alignment.centerLeft,
                            child: Text(_getRiskLevelText(),
                                style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w900,
                                    color: _getRiskColor()))),
                        Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                                'Score: ${_finalRiskScore.toStringAsFixed(1)}',
                                style: const TextStyle(
                                    fontSize: 36,
                                    fontWeight: FontWeight.w900,
                                    color: AppColors.textDark))),
                        const Text(
                            'Calculated based on your current personal sensitivity phase and the product\'s base acid load.',
                            style: TextStyle(
                                fontSize: 11,
                                color: AppColors.textGrey,
                                height: 1.5)),
                        const SizedBox(height: 20),
                      ],
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                            gradient: AppColors.primaryGradient,
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                  color: AppColors.primary.withOpacity(0.3),
                                  blurRadius: 15,
                                  offset: const Offset(0, 5))
                            ]),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('Detected Risk',
                                    style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 18,
                                        fontWeight: FontWeight.w900)),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 15, vertical: 5),
                                  decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(10)),
                                  child: const Column(
                                    children: [
                                      Text('1',
                                          style: TextStyle(
                                              color: AppColors.primaryDark,
                                              fontSize: 16,
                                              fontWeight: FontWeight.w900)),
                                      Text('Consumed',
                                          style: TextStyle(
                                              color: AppColors.textDark,
                                              fontSize: 8,
                                              fontWeight: FontWeight.bold)),
                                    ],
                                  ),
                                )
                              ],
                            ),
                            const SizedBox(height: 10),
                            Text(_detectedTriggersText,
                                style: const TextStyle(
                                    color: Colors.white70,
                                    fontSize: 11,
                                    height: 1.4)),
                            const SizedBox(height: 10),
                            const Text('Extracted OCR Text',
                                style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold)),
                            Text(_rawText,
                                style: const TextStyle(
                                    color: Colors.white70,
                                    fontSize: 11,
                                    height: 1.4)),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      Row(
                        children: [
                          if (_symptoms == "None") ...[
                            Expanded(
                              child: InkWell(
                                onTap: _showSymptomsModal,
                                child: Container(
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 15),
                                  decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(15),
                                      boxShadow: [
                                        BoxShadow(
                                            color:
                                                Colors.black.withOpacity(0.05),
                                            blurRadius: 10,
                                            offset: const Offset(0, 5))
                                      ]),
                                  child: const Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.local_fire_department,
                                          color: Colors.orange, size: 18),
                                      SizedBox(width: 8),
                                      Text('Log Symptom',
                                          style: TextStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w900,
                                              color: AppColors.textDark)),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 15),
                          ],
                          Expanded(
                            child: InkWell(
                              onTap: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                      builder: (context) => CoachScreen(
                                            dbService: widget.dbService,
                                            entryMode: 'scanner',
                                            activeSymptom: _symptoms != "None"
                                                ? _symptoms
                                                : null,
                                            symptomSeverity: _symptomSeverity,
                                            scannedProduct: _productName,
                                            dynamicContextData:
                                                _detectedTriggersText,
                                          ))),
                              child: Container(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 15),
                                decoration: BoxDecoration(
                                    color: AppColors.primaryLight
                                        .withOpacity(0.15),
                                    borderRadius: BorderRadius.circular(15),
                                    border: Border.all(
                                        color: AppColors.primaryLight)),
                                child: const Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.medical_services_outlined,
                                        color: AppColors.primaryDark, size: 18),
                                    SizedBox(width: 8),
                                    Text('First Aid Coach',
                                        style: TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w900,
                                            color: AppColors.primaryDark)),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 150),
                    ]
                  ] else ...[
                    Container(
                      width: double.infinity,
                      height: 60,
                      decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(30),
                          boxShadow: [
                            BoxShadow(
                                color: Colors.black.withOpacity(0.05),
                                blurRadius: 10,
                                offset: const Offset(0, 5))
                          ]),
                      child: Row(
                        children: [
                          Expanded(
                            child: GestureDetector(
                              onTap: _takePictureAndScan,
                              child: Container(
                                decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(30),
                                    border: Border.all(
                                        color: Colors.grey.shade200)),
                                child: const Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.camera_alt_outlined,
                                        color: AppColors.textDark, size: 20),
                                    SizedBox(width: 8),
                                    Text('Manual Shutter',
                                        style: TextStyle(
                                            color: AppColors.textDark,
                                            fontWeight: FontWeight.bold)),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          Expanded(
                            child: GestureDetector(
                              onTap: _pickFromGallery,
                              child: Container(
                                decoration: BoxDecoration(
                                    gradient: LinearGradient(colors: [
                                      AppColors.primaryLight.withOpacity(0.6),
                                      AppColors.primary
                                    ]),
                                    borderRadius: const BorderRadius.only(
                                        topRight: Radius.circular(30),
                                        bottomRight: Radius.circular(30))),
                                child: const Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.image_outlined,
                                        color: AppColors.textDark, size: 20),
                                    SizedBox(width: 8),
                                    Text('Gallery',
                                        style: TextStyle(
                                            color: AppColors.textDark,
                                            fontWeight: FontWeight.bold)),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 15),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(15))),
                        onPressed: _showManualEntryModal,
                        child: const Text('Type Ingredients Manually',
                            style: TextStyle(
                                color: Colors.grey,
                                fontWeight: FontWeight.w900,
                                fontSize: 16)),
                      ),
                    ),
                    const SizedBox(height: 15),
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(15),
                          boxShadow: [
                            BoxShadow(
                                color: Colors.black.withOpacity(0.05),
                                blurRadius: 10)
                          ]),
                      child: const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.info_outline,
                                  color: AppColors.textDark),
                              SizedBox(width: 8),
                              Text('How it works',
                                  style: TextStyle(
                                      fontWeight: FontWeight.w900,
                                      color: AppColors.textDark)),
                            ],
                          ),
                          SizedBox(height: 10),
                          Text(
                              "Point the camera at a powdered drink sachet. The scanner will automatically detect the ingredients and isolate them for PRAL analysis. No need to press a button unless the scanner fails.",
                              style: TextStyle(
                                  fontSize: 10,
                                  color: AppColors.textGrey,
                                  height: 1.5)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 100),
                  ]
                ],
              ),
            ),
          ),
          if (!isResultView && _snarkyMessage.isNotEmpty)
            Positioned.fill(
              child: Container(
                color: Colors.black.withOpacity(0.85),
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 40.0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Image.asset('assets/images/triggerlens_icon.png',
                            width: 60, color: Colors.grey),
                        const SizedBox(height: 30),
                        Text(
                          _snarkyMessage,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                            height: 1.4,
                          ),
                        ),
                        const SizedBox(height: 40),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 40, vertical: 15),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(30)),
                          ),
                          onPressed: _startAutoScan,
                          child: const Text('Scan Again',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold)),
                        )
                      ],
                    ),
                  ),
                ),
              ),
            ),
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: isResultView
                ? _buildResultBottomBar()
                : Container(
                    height: 120,
                    color: Colors.transparent,
                    child: Stack(
                      alignment: Alignment.bottomCenter,
                      children: [
                        Container(
                          margin: const EdgeInsets.only(
                              left: 20, right: 20, bottom: 20),
                          height: 65,
                          decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(35),
                              boxShadow: [
                                BoxShadow(
                                    color: Colors.black.withOpacity(0.05),
                                    blurRadius: 20,
                                    offset: const Offset(0, 5))
                              ]),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: [
                              IconButton(
                                icon: Image.asset(
                                  'assets/images/home.png',
                                  width: 24,
                                  color: AppColors.textDark,
                                ),
                                onPressed: () => Navigator.pushAndRemoveUntil(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => MainLayoutScreen(
                                      dbService: widget.dbService,
                                      initialIndex: 0,
                                    ),
                                  ),
                                  (route) => false,
                                ),
                              ),
                              IconButton(
                                icon: Image.asset(
                                  'assets/images/write.png',
                                  width: 24,
                                  color: AppColors.textDark,
                                ),
                                onPressed: () => Navigator.pushAndRemoveUntil(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => MainLayoutScreen(
                                      dbService: widget.dbService,
                                      initialIndex: 1,
                                    ),
                                  ),
                                  (route) => false,
                                ),
                              ),
                              const SizedBox(width: 60),
                              IconButton(
                                icon: Image.asset(
                                  'assets/images/bar-graph.png',
                                  width: 24,
                                  color: AppColors.textDark,
                                ),
                                onPressed: () => Navigator.pushAndRemoveUntil(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => MainLayoutScreen(
                                      dbService: widget.dbService,
                                      initialIndex: 2,
                                    ),
                                  ),
                                  (route) => false,
                                ),
                              ),
                              IconButton(
                                icon: Image.asset(
                                  'assets/images/message.png',
                                  width: 24,
                                  color: AppColors.textDark,
                                ),
                                onPressed: () => Navigator.pushAndRemoveUntil(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => MainLayoutScreen(
                                      dbService: widget.dbService,
                                      initialIndex: 3,
                                    ),
                                  ),
                                  (route) => false,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Positioned(
                          bottom: 35,
                          child: GestureDetector(
                            onTap: _takePictureAndScan,
                            child: Container(
                              width: 75,
                              height: 75,
                              decoration: BoxDecoration(
                                  gradient: AppColors.primaryGradient,
                                  borderRadius: BorderRadius.circular(25),
                                  boxShadow: [
                                    BoxShadow(
                                        color:
                                            AppColors.primary.withOpacity(0.4),
                                        blurRadius: 20,
                                        offset: const Offset(0, 8))
                                  ]),
                              child: Center(
                                child: Image.asset(
                                    'assets/images/barcode-scanner.png',
                                    width: 40,
                                    color: Colors.white),
                              ),
                            ),
                          ),
                        )
                      ],
                    ),
                  ),
          )
        ],
      ),
    );
  }
}
