import 'dart:io';
import 'dart:async';
import 'dart:math';
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
import '../models/user_profile.dart';
import '../utils/ui_helpers.dart';
import '../utils/app_localizations.dart';
import '../utils/keyword_mapping_algorithm.dart';
import '../utils/risk_translator.dart';
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

  bool _settingHaptic = true;
  bool _settingAutoFlash = false;
  bool _settingAudioAlerts = true;
  bool _settingBatchScan = false;
  bool _settingStrictMode = false;

  final ImagePicker _picker = ImagePicker();
  File? _capturedImage;
  bool _isAnalyzing = false;

  bool _isRecalibrating = false;

  late TextRecognizer _textRecognizer;
  bool _isScanning = false;
  bool _isProcessingFrame = false;

  bool _isAutoMode = true;

  Timer? _frustrationTimer;
  DateTime? _scanStartTime;
  int _autoScanFailures = 0;

  String _diagnosticMessage = "init_scanner";
  List<TextBlock> _currentTextBlocks = [];
  Size? _imageSize;

  bool _isLocking = false;
  Timer? _lockTimer;
  String _bestExtractedText = "";

  String _rawText = "waiting_for_scan";
  String _productName = "unnamed";

  String _riskLevel = "GREEN";
  double _finalRiskScore = 0.0;
  bool _exceedsDailyCap = false;
  String _detectedTriggersText = "None";
  String _drinkCategory = "General Beverage";

  bool _isInvalidSachet = false;
  String _invalidSachetMessage = "";

  double _activeDailyCap = 15.0;

  double _currentZoomLevel = 1.0;
  double _minZoomLevel = 1.0;
  double _maxZoomLevel = 1.0;

  late AnimationController _laserController;
  late Animation<double> _laserAnimation;

  final TextEditingController _ocrTextController = TextEditingController();
  UserProfile? _userProfile;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);

    _laserController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1500));
    _laserAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(parent: _laserController, curve: Curves.easeInOutSine));

    _initCameraAndSettings();
  }

  Future<void> _initCameraAndSettings() async {
    final prefs = await SharedPreferences.getInstance();
    _settingHaptic = prefs.getBool('setting_haptic') ?? true;
    _settingAutoFlash = prefs.getBool('setting_flash') ?? false;
    _settingAudioAlerts = prefs.getBool('setting_audio') ?? true;
    _settingBatchScan = prefs.getBool('setting_batch') ?? false;
    _settingStrictMode = prefs.getBool('setting_strictness') ?? false;

    _userProfile = await widget.dbService.getUserProfile();
    _activeDailyCap = _userProfile?.dynamicDailyCap ?? 15.0;

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

        if (_isAutoMode) _startAutoScan();
      }
    } catch (e) {
      debugPrint("Camera Error: $e");
    }
  }

  // ==========================================
  // HARDWARE LIFECYCLE MANAGEMENT (FLASHLIGHT FIX)
  // ==========================================
  Future<void> _turnOffFlash() async {
    if (_controller != null && _controller!.value.isInitialized) {
      try {
        await _controller!.setFlashMode(FlashMode.off);
        if (mounted) setState(() => _isFlashOn = false);
      } catch (e) {
        debugPrint('Error turning off flash: \$e');
      }
    }
  }

  void _startAutoScan() {
    if (!_isAutoMode) return;

    setState(() {
      _diagnosticMessage = "analyzing_env";
      _isLocking = false;
      _bestExtractedText = "";
      _capturedImage = null;
      _scanStartTime = DateTime.now();
      _currentTextBlocks = [];
      _isScanning = true;
      _isInvalidSachet = false;
    });

    _laserController.repeat(reverse: true);
    _frustrationTimer?.cancel();
    _lockTimer?.cancel();

    _frustrationTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_isLocking || !_isAutoMode || _scanStartTime == null) return;

      int elapsed = DateTime.now().difference(_scanStartTime!).inSeconds;
      if (elapsed >= 15 || _autoScanFailures >= 3) {
        timer.cancel();
        setState(() {
          _isAutoMode = false;
          _isScanning = false;
        });
        _stopAutoScanEngine();
        _showFrustrationModal();
      }
    });

    if (_controller != null && !_controller!.value.isStreamingImages) {
      _controller!.startImageStream((CameraImage image) {
        if (_isProcessingFrame || !_isAutoMode) return;
        _isProcessingFrame = true;
        _processCameraFrame(image);
      });
    }
  }

  void _stopAutoScanEngine() async {
    _frustrationTimer?.cancel();
    _lockTimer?.cancel();
    _laserController.stop();
    if (_controller != null && _controller!.value.isStreamingImages) {
      await _controller!.stopImageStream();
    }
    // Explicitly turn off flash when engine stops
    await _turnOffFlash();
  }

  String _getVisuallySortedText(RecognizedText recognizedText) {
    List<TextBlock> blocks = List.from(recognizedText.blocks);
    blocks.sort((a, b) {
      final aTop = a.boundingBox.top;
      final bTop = b.boundingBox.top;
      final aLeft = a.boundingBox.left;
      final bLeft = b.boundingBox.left;

      if ((aTop - bTop).abs() < 20.0) return aLeft.compareTo(bLeft);
      return aTop.compareTo(bTop);
    });
    return blocks.map((b) => b.text).join('\n\n');
  }

  Future<void> _processCameraFrame(CameraImage image) async {
    if (!_isAutoMode) {
      _isProcessingFrame = false;
      return;
    }

    try {
      final WriteBuffer allBytes = WriteBuffer();
      for (final Plane plane in image.planes) {
        allBytes.putUint8List(plane.bytes);
      }
      final bytes = allBytes.done().buffer.asUint8List();

      final Size imgSize =
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
          size: imgSize,
          rotation: imageRotation,
          format: inputImageFormat,
          bytesPerRow: image.planes[0].bytesPerRow);

      final inputImage = InputImage.fromBytes(bytes: bytes, metadata: metadata);
      final RecognizedText recognizedText =
          await _textRecognizer.processImage(inputImage);

      if (!_isAutoMode) return;

      String sortedText = _getVisuallySortedText(recognizedText);

      int gibberishCount = sortedText
          .replaceAll(RegExp(r'[a-zA-Z0-9\s,\.\(\)\[\]\-%:\/]'), '')
          .length;
      int totalChars = sortedText.length > 0 ? sortedText.length : 1;
      double gibberishRatio = gibberishCount / totalChars;

      String nextDiagnostic = "";
      if (totalChars < 20) {
        nextDiagnostic = "move_closer";
      } else if (gibberishRatio > 0.25) {
        nextDiagnostic = "text_distorted";
      } else if (sortedText.length < 50 && recognizedText.blocks.length < 3) {
        nextDiagnostic = "glare_detected";
      } else {
        nextDiagnostic = "scanning_text";
      }

      if (mounted) {
        setState(() {
          _imageSize = imgSize;
          _currentTextBlocks = recognizedText.blocks;
          if (!_isLocking) _diagnosticMessage = nextDiagnostic;
        });
      }

      String? isolatedIngredientsText = _autoIsolateIngredients(sortedText) ??
          _autoIsolateIngredients(recognizedText.text);

      if (isolatedIngredientsText != null) {
        _bestExtractedText = isolatedIngredientsText;

        if (!_isLocking) {
          if (mounted) {
            setState(() {
              _isLocking = true;
              _diagnosticMessage = "ingredients_detected";
            });
          }
          if (_settingHaptic) HapticFeedback.lightImpact();

          _lockTimer = Timer(const Duration(milliseconds: 1500), () async {
            _frustrationTimer?.cancel();
            if (_controller != null && _controller!.value.isStreamingImages) {
              await _controller!.stopImageStream();
            }

            if (mounted) {
              try {
                final XFile file = await _controller!.takePicture();
                // FIX: Turn off flash right after taking the picture
                await _turnOffFlash();
                setState(() => _capturedImage = File(file.path));
              } catch (e) {
                debugPrint("Error taking auto-scan picture: \$e");
              }
            }

            if (_bestExtractedText.length > 20) {
              await _processExtractedText(
                  _bestExtractedText, "Auto-Scanned Sachet");
            } else {
              _autoScanFailures++;
              _startAutoScan();
            }
          });
        }
      }
    } catch (e) {
      debugPrint("Frame processing error: \$e");
    } finally {
      if (mounted) _isProcessingFrame = false;
    }
  }

  String? _autoIsolateIngredients(String rawText) {
    String lowerText = rawText.toLowerCase();

    int startIndex = -1;
    List<String> explicitKeywords = [
      'ingredients:',
      'ingredients',
      'mga sangkap:',
      'mga sangkap',
      'sangkap:',
      'contains:'
    ];
    for (String keyword in explicitKeywords) {
      startIndex = lowerText.indexOf(keyword);
      if (startIndex != -1) break;
    }

    if (startIndex == -1) {
      List<String> words = lowerText.split(RegExp(r'\s+'));
      int semanticScore = 0;
      for (int i = 0; i < words.length; i++) {
        if (KeywordMappingAlgorithm.semanticKeywords
            .any((k) => words[i].contains(k))) {
          semanticScore++;
          if (semanticScore >= 3) {
            startIndex = max(0, lowerText.indexOf(words[max(0, i - 8)]));
            break;
          }
        }
      }
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
      if (index > 15 && index < stopIndex) stopIndex = index;
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

  void _showFrustrationModal() {
    showModalBottomSheet(
        context: context,
        isDismissible: false,
        backgroundColor: Colors.transparent,
        builder: (context) {
          final colors = AppColors.of(context);
          final loc = AppLocalizations.of(context);

          return Container(
            padding: const EdgeInsets.all(25),
            decoration: BoxDecoration(
                color: colors.cardColor,
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(30))),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.support_agent, color: colors.primary, size: 50),
                const SizedBox(height: 15),
                Text(loc.loc('need_diff_approach'),
                    style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        color: colors.primaryDark)),
                const SizedBox(height: 10),
                Text(loc.loc('shiny_curved_desc'),
                    textAlign: TextAlign.center,
                    style: TextStyle(color: colors.textGrey, height: 1.4)),
                const SizedBox(height: 25),
                Container(
                  decoration: BoxDecoration(
                      color:
                          colors.isDark ? Colors.white10 : Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(15),
                      border: Border.all(
                          color: colors.isDark
                              ? Colors.white12
                              : Colors.grey.shade200)),
                  child: ListTile(
                    leading: Icon(Icons.camera_alt, color: colors.primaryDark),
                    title: Text(loc.loc('manual_shutter'),
                        style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: colors.textDark)),
                    subtitle: Text(loc.loc('take_photo_desc'),
                        style: TextStyle(fontSize: 11, color: colors.textGrey)),
                    onTap: () {
                      Navigator.pop(context);
                      _takePictureAndScan(colors);
                    },
                  ),
                ),
                const SizedBox(height: 10),
                Container(
                  decoration: BoxDecoration(
                      color:
                          colors.isDark ? Colors.white10 : Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(15),
                      border: Border.all(
                          color: colors.isDark
                              ? Colors.white12
                              : Colors.grey.shade200)),
                  child: ListTile(
                    leading: Icon(Icons.keyboard, color: colors.primaryDark),
                    title: Text(loc.loc('type_ingredients'),
                        style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: colors.textDark)),
                    subtitle: Text(loc.loc('type_ingredients_desc'),
                        style: TextStyle(fontSize: 11, color: colors.textGrey)),
                    onTap: () {
                      Navigator.pop(context);
                      _showManualEntryModal();
                    },
                  ),
                ),
                const SizedBox(height: 15),
                TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                    setState(() {
                      _isAutoMode = true;
                      _autoScanFailures = 0;
                    });
                    _startAutoScan();
                  },
                  child: Text(loc.loc('keep_trying_auto'),
                      style: TextStyle(
                          color: colors.textGrey, fontWeight: FontWeight.bold)),
                )
              ],
            ),
          );
        });
  }

  Future<void> _processExtractedText(String text, String sourceName) async {
    try {
      setState(() {
        _isInvalidSachet = false;
        _invalidSachetMessage = "";
      });

      final triggers = await widget.dbService.getAllTriggers();
      double currentDailyLoad = await _calculateDailyLoad();

      final allPantry = await widget.dbService.getPantryItems();
      final now = DateTime.now();
      final List<PantryItem> recentItems = allPantry.where((item) {
        return now.difference(item.dateScanned).inHours <= 6;
      }).toList();

      var result = KeywordMappingAlgorithm.analyze(
          text, triggers, _userProfile, currentDailyLoad, recentItems);

      if (_settingStrictMode && result.riskLevel == "YELLOW") {
        result = KeywordMappingAlgorithm.analyze(
            text, triggers, _userProfile, currentDailyLoad + 5.0, recentItems);
        result.riskLevel = "RED";
      }

      if (mounted) {
        setState(() {
          _isAnalyzing = false;
          _laserController.stop();
          _rawText = text.isEmpty ? "No text detected." : text;
          _ocrTextController.text = _rawText;
          _riskLevel = result.riskLevel;
          _finalRiskScore = result.finalRiskScore;
          _detectedTriggersText = result.triggersSummary;
          _exceedsDailyCap = result.exceedsDailyCap;
          _productName = sourceName;
          _drinkCategory = result.drinkCategory;
          _activeDailyCap = _userProfile?.dynamicDailyCap ?? 15.0;
        });

        if (_settingAudioAlerts || _settingHaptic) {
          if (_riskLevel == "RED" || _exceedsDailyCap) {
            HapticFeedback.heavyImpact();
            Future.delayed(const Duration(milliseconds: 150),
                () => HapticFeedback.heavyImpact());
          } else if (_riskLevel == "GREEN") {
            HapticFeedback.lightImpact();
          }
        }
      }
    } on InvalidSachetException catch (e) {
      if (mounted) {
        setState(() {
          _isAnalyzing = false;
          _laserController.stop();
          _isInvalidSachet = true;
          _invalidSachetMessage = e.message;
          _rawText = text.isEmpty ? "No text detected." : text;
          _ocrTextController.text = _rawText;
          _productName = "Invalid Item";
        });
        if (_settingHaptic) HapticFeedback.heavyImpact();
      }
    } catch (e) {
      debugPrint("Analysis Error: \$e");
      if (mounted) {
        setState(() {
          _isAnalyzing = false;
          _laserController.stop();
        });
      }
    }
  }

  void _showInfoModal(String title, String message, AppColors colors) {
    HapticFeedback.lightImpact();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.all(30),
        decoration: BoxDecoration(
            color: colors.cardColor,
            borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(30), topRight: Radius.circular(30)),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 20,
                  offset: const Offset(0, -5))
            ]),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
                child: Container(
                    width: 40,
                    height: 5,
                    decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(10)))),
            const SizedBox(height: 25),
            Row(
              children: [
                Icon(Icons.info_outline, color: colors.primary, size: 28),
                const SizedBox(width: 15),
                Expanded(
                  child: Text(title,
                      style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                          color: colors.primaryDark)),
                ),
              ],
            ),
            const SizedBox(height: 15),
            Text(message,
                style: TextStyle(
                    fontSize: 14,
                    height: 1.5,
                    color: colors.textDark,
                    fontWeight: FontWeight.w600)),
            const SizedBox(height: 30),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                    backgroundColor: colors.primary,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15))),
                onPressed: () => Navigator.pop(context),
                child: const Text('Got it',
                    style: TextStyle(
                        color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            )
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);

    // FIX: Force flash off before memory disposal
    _turnOffFlash();

    _frustrationTimer?.cancel();
    _lockTimer?.cancel();
    _laserController.dispose();
    _textRecognizer.close();
    _ocrTextController.dispose();

    if (_controller != null && _controller!.value.isInitialized) {
      if (_controller!.value.isStreamingImages) _controller!.stopImageStream();
      _controller!.dispose();
    }
    super.dispose();
  }

  void _onFocusTap(TapDownDetails details, BoxConstraints constraints) {
    if (_controller == null || !_controller!.value.isInitialized) return;
    final offset = Offset(details.localPosition.dx / constraints.maxWidth,
        details.localPosition.dy / constraints.maxHeight);
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
      debugPrint("Flash Error: \$e");
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_controller == null || !_controller!.value.isInitialized) return;
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused) {
      // FIX: Ensure hardware is released immediately upon backgrounding
      _turnOffFlash();
      if (_controller!.value.isStreamingImages) _controller!.stopImageStream();
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

  Future<File?> _cropImage(File imageFile, AppColors colors) async {
    final croppedFile = await ImageCropper().cropImage(
      sourcePath: imageFile.path,
      compressQuality: 100,
      uiSettings: [
        AndroidUiSettings(
            toolbarTitle: 'Crop Ingredients',
            toolbarColor: colors.primary,
            toolbarWidgetColor: Colors.white,
            initAspectRatio: CropAspectRatioPreset.original,
            lockAspectRatio: false,
            hideBottomControls: false),
        IOSUiSettings(title: 'Crop Ingredients'),
      ],
    );
    if (croppedFile != null) return File(croppedFile.path);
    return null;
  }

  Future<void> _pickFromGallery(AppColors colors) async {
    try {
      _stopAutoScanEngine();
      setState(() {
        _isScanning = false;
        _isProcessingFrame = true;
      });

      final pickedFile = await _picker.pickImage(source: ImageSource.gallery);
      if (pickedFile == null) {
        if (_isAutoMode) _startAutoScan();
        return;
      }

      File? cropped = await _cropImage(File(pickedFile.path), colors);
      if (cropped == null) {
        if (_isAutoMode) _startAutoScan();
        return;
      }

      setState(() {
        _capturedImage = cropped;
        _isAnalyzing = true;
      });

      _laserController.repeat(reverse: true);
      await _processImageForOCR(cropped.path, "Gallery Upload");
    } catch (e) {
      debugPrint("Gallery Error: \$e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Failed to load image. Please try again."),
            backgroundColor: Colors.redAccent,
          ),
        );
        setState(() {
          _capturedImage = null;
          _isAnalyzing = false;
        });
        if (_isAutoMode) _startAutoScan();
      }
    } finally {
      if (mounted) {
        setState(() => _isProcessingFrame = false);
      }
    }
  }

  Future<void> _takePictureAndScan(AppColors colors) async {
    if (_controller == null || !_controller!.value.isInitialized) return;
    try {
      _stopAutoScanEngine();
      setState(() {
        _isScanning = false;
        _isProcessingFrame = true;
      });

      final image = await _controller!.takePicture();
      // FIX: Ensure flash is off after manual shot
      await _turnOffFlash();

      File? cropped = await _cropImage(File(image.path), colors);
      if (cropped == null) {
        if (_isAutoMode) _startAutoScan();
        return;
      }

      setState(() {
        _capturedImage = cropped;
        _isAnalyzing = true;
      });

      _laserController.repeat(reverse: true);
      await _processImageForOCR(cropped.path, "Scanned Sachet");
    } catch (e) {
      debugPrint("Capture Error: \$e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
                "Failed to capture image. Please check camera permissions."),
            backgroundColor: Colors.redAccent,
          ),
        );
        setState(() {
          _capturedImage = null;
          _isAnalyzing = false;
        });
        if (_isAutoMode) _startAutoScan();
      }
    } finally {
      if (mounted) {
        setState(() => _isProcessingFrame = false);
      }
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
      debugPrint("Manual OCR Error: \$e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Could not analyze text. Please try again."),
            backgroundColor: Colors.redAccent,
          ),
        );
        setState(() {
          _isAnalyzing = false;
          _capturedImage = null;
        });
      }
    }
  }

  Future<void> _saveToDatabase(
      bool isConsumed, AppColors colors, AppLocalizations loc) async {
    try {
      Map<String, dynamic>? contextData;

      if (isConsumed) {
        contextData =
            await ConsumptionModal.show(context, _productName, _drinkCategory);
        if (contextData == null) return;
      }

      String? permanentImagePath;
      if (_capturedImage != null && _capturedImage!.path != 'manual_entry') {
        final directory = await getApplicationDocumentsDirectory();
        final String fileName =
            'sachet_\${DateTime.now().millisecondsSinceEpoch}.jpg';
        final String newPath = '\${directory.path}/\$fileName';
        final File savedImage = await _capturedImage!.copy(newPath);
        permanentImagePath = savedImage.path;
      }

      double finalStoredScore = _finalRiskScore;
      if (isConsumed && contextData != null) {
        finalStoredScore = RiskTranslator.calculateTrueAcidLoad(_finalRiskScore,
            contextData['portionCount'], contextData['portionMeasurement']);
      }

      final newItem = PantryItem()
        ..name = _productName
        ..dateScanned = DateTime.now()
        ..symptoms = ""
        ..riskLevel = _riskLevel
        ..isFavorite = false
        ..rawText = _rawText
        ..acidScore = finalStoredScore.round()
        ..imagePath = permanentImagePath
        ..isEmptyStomach = contextData?['isEmptyStomach'] ?? false
        ..isDiluted = contextData?['isDiluted'] ?? false
        ..isConsumed = isConsumed
        ..drinkCategory = _drinkCategory
        ..portionMeasurement = contextData?['portionMeasurement'] ?? "Sachet"
        ..portionCount = contextData?['portionCount'] ?? 1.0;

      await widget.dbService.savePantryItem(newItem);

      if (isConsumed) {
        final notifService = NotificationService();
        notifService.scheduleTargetedNotification(
            id: NotificationService.digestionTimerId,
            title: loc.loc('digestion_complete_title'),
            body: loc.loc('digestion_complete_body', {'name': newItem.name}),
            delay: const Duration(hours: 6));

        if (newItem.isEmptyStomach && !newItem.isDiluted) {
          notifService.scheduleTargetedNotification(
              id: NotificationService.hydrationChaserId,
              title: loc.loc('acid_buffer_reminder'),
              body: loc.loc('acid_buffer_body', {'name': newItem.name}),
              delay: const Duration(minutes: 15));
        }

        if (newItem.riskLevel == "RED" || newItem.riskLevel == "YELLOW") {
          notifService.scheduleTargetedNotification(
              id: NotificationService.symptomCheckinId,
              title: loc.loc('symptom_checkin_title'),
              body: loc.loc('symptom_checkin_body', {'name': newItem.name}),
              delay: const Duration(minutes: 45));
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(isConsumed
                ? loc.loc('item_consumed_logged', {'name': newItem.name})
                : loc.loc('saved_to_pantry')),
            backgroundColor: colors.successGreen,
            behavior: SnackBarBehavior.floating));

        if (_settingBatchScan) {
          if (_isAutoMode) _startAutoScan();
        } else {
          // Navigating away from scanner screen, hardware resources will be handled in dispose() automatically
          Navigator.pop(context);
        }
      }
    } catch (e) {
      debugPrint("Save To Database Error: \$e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Failed to save. Please check device storage."),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  void _showEditNameModal() {
    final TextEditingController nameController =
        TextEditingController(text: _productName);
    showDialog(
      context: context,
      builder: (context) {
        final colors = AppColors.of(context);
        final loc = AppLocalizations.of(context);
        return Dialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: Container(
            padding: const EdgeInsets.all(25),
            decoration: BoxDecoration(
                color: colors.cardColor,
                borderRadius: BorderRadius.circular(20)),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(loc.loc('name_this_drink'),
                    style: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 18,
                        color: colors.primaryDark)),
                const SizedBox(height: 20),
                TextField(
                    controller: nameController,
                    style: TextStyle(color: colors.textDark),
                    decoration: InputDecoration(
                        hintText: loc.loc('eg_nescafe'),
                        hintStyle: TextStyle(color: colors.textGrey),
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(15)),
                        focusedBorder: OutlineInputBorder(
                            borderSide: BorderSide(color: colors.primary)))),
                const SizedBox(height: 25),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                        backgroundColor: colors.primary,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(15))),
                    onPressed: () {
                      setState(() => _productName = nameController.text.isEmpty
                          ? loc.loc('unnamed')
                          : nameController.text);
                      Navigator.pop(context);
                    },
                    child: Text(loc.loc('save_name'),
                        style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 16)),
                  ),
                )
              ],
            ),
          ),
        );
      },
    );
  }

  void _showManualEntryModal() {
    final textController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) {
        final colors = AppColors.of(context);
        final loc = AppLocalizations.of(context);
        return Dialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
                color: colors.cardColor,
                borderRadius: BorderRadius.circular(20)),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    IconButton(
                        icon: Icon(Icons.close, color: colors.textDark),
                        onPressed: () => Navigator.pop(context)),
                    Expanded(
                      child: Text(loc.loc('manual_entry'),
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: colors.textDark)),
                    ),
                    const SizedBox(width: 48), // Balances the close icon
                  ],
                ),
                const SizedBox(height: 10),
                TextField(
                    controller: textController,
                    maxLines: 5,
                    style: TextStyle(color: colors.textDark),
                    decoration: InputDecoration(
                        hintText: loc.loc('type_ingredients_hint'),
                        hintStyle: TextStyle(color: colors.textGrey),
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(15)),
                        focusedBorder: OutlineInputBorder(
                            borderSide: BorderSide(color: colors.primary)))),
                const SizedBox(height: 20),
                GradientButton(
                  text: loc.loc('analyze'),
                  onPressed: () async {
                    final text = textController.text;
                    Navigator.pop(context);

                    _stopAutoScanEngine();
                    setState(() => _capturedImage = File('manual_entry'));

                    await _processExtractedText(
                        text.isEmpty ? loc.loc('no_text_provided') : text,
                        loc.loc('manual_entry'));
                  },
                )
              ],
            ),
          ),
        );
      },
    );
  }

  String _getRiskLevelText(AppLocalizations loc) {
    if (_riskLevel == "RED") return loc.loc('high_danger');
    if (_riskLevel == "YELLOW") return loc.loc('moderate_risk');
    return loc.loc('safe_to_consume');
  }

  Color _getRiskColor(AppColors colors) {
    if (_riskLevel == "RED") return colors.errorRed;
    if (_riskLevel == "YELLOW") return colors.accentOrange;
    return colors.successGreen;
  }

  Widget _buildScannerClinicalUI(String summary, AppColors colors) {
    if (summary.contains("No known stomach triggers") ||
        summary.contains("Great news")) {
      return Text(summary,
          style: const TextStyle(
              color: Colors.greenAccent, fontWeight: FontWeight.bold));
    }

    final List<String> parts = summary.split('\n\n');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: parts.map((part) {
        if (part.contains('⚠️ COMPOUND SYNERGY')) {
          return Container(
            margin: const EdgeInsets.only(top: 10, bottom: 10),
            padding: const EdgeInsets.all(15),
            decoration: BoxDecoration(
              color: Colors.redAccent.shade700,
              borderRadius: BorderRadius.circular(15),
              boxShadow: const [
                BoxShadow(color: Colors.black26, blurRadius: 5)
              ],
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.warning_rounded,
                    color: Colors.white, size: 24),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    part
                        .replaceAll(
                            '⚠️ COMPOUND SYNERGY: ', 'COMPOUND SYNERGY:\n')
                        .trim(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          );
        } else if (part.startsWith('Clinical Analysis:')) {
          return Text(
            part,
            style: const TextStyle(
              color: Colors.white,
              height: 1.5,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          );
        } else {
          return Container(
            margin: const EdgeInsets.only(top: 10),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              part,
              style: const TextStyle(
                color: Colors.white70,
                fontStyle: FontStyle.italic,
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
          );
        }
      }).toList(),
    );
  }

  Widget _buildResultBottomBar(AppColors colors, AppLocalizations loc) {
    return Container(
      padding: const EdgeInsets.only(left: 20, right: 20, top: 15, bottom: 30),
      decoration: BoxDecoration(color: colors.cardColor, boxShadow: [
        BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 20,
            offset: const Offset(0, -5))
      ]),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            InkWell(
                onTap: () {
                  setState(() {
                    _capturedImage = null;
                  });
                  if (_isAutoMode) _startAutoScan();
                },
                child: Container(
                    width: 75,
                    height: 60,
                    decoration: BoxDecoration(
                        color: colors.isDark
                            ? Colors.white12
                            : Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                            color: colors.isDark
                                ? Colors.white24
                                : Colors.grey.shade300)),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.refresh, color: colors.textDark, size: 24),
                        const SizedBox(height: 4),
                        Text(loc.loc('scan_again'),
                            style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                                color: colors.textDark))
                      ],
                    ))),
            const SizedBox(width: 10),
            Expanded(
              child: SizedBox(
                height: 60,
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                      padding: EdgeInsets.zero,
                      side: BorderSide(
                          color:
                              _isInvalidSachet ? Colors.grey : colors.primary,
                          width: 2),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20))),
                  onPressed: _isInvalidSachet
                      ? null
                      : () => _saveToDatabase(false, colors, loc),
                  child: Text(loc.loc('save_to_pantry_btn'),
                      style: TextStyle(
                          color:
                              _isInvalidSachet ? Colors.grey : colors.primary,
                          fontSize: 13,
                          fontWeight: FontWeight.w900)),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: SizedBox(
                height: 60,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                      backgroundColor:
                          _isInvalidSachet ? Colors.grey : colors.primary,
                      padding: EdgeInsets.zero,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20)),
                      elevation: 0),
                  onPressed: _isInvalidSachet
                      ? null
                      : () => _saveToDatabase(true, colors, loc),
                  child: Center(
                      child: Text(loc.loc('consume_now'),
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.w900))),
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
    final colors = AppColors.of(context);
    final loc = AppLocalizations.of(context);

    bool isResultView = _capturedImage != null;

    double impactPercentage = (_finalRiskScore / _activeDailyCap) * 100;
    if (impactPercentage > 100) impactPercentage = 100;
    if (impactPercentage.isNaN || impactPercentage.isInfinite) {
      impactPercentage = 0;
    }

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
            icon: Image.asset('assets/images/back_1.png',
                width: 24, color: colors.primaryDark),
            onPressed: () {
              if (isResultView) {
                setState(() => _capturedImage = null);
                if (_isAutoMode) _startAutoScan();
              } else {
                Navigator.pop(context);
              }
            }),
        title: Text(isResultView ? '' : 'TriggerLens',
            style: TextStyle(
                color: colors.primaryDark,
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
                  if (!isResultView)
                    Container(
                        margin: const EdgeInsets.only(bottom: 20),
                        padding: const EdgeInsets.all(5),
                        decoration: BoxDecoration(
                            color: colors.cardColor,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                                color: colors.isDark
                                    ? Colors.white12
                                    : Colors.grey.shade200)),
                        child: Row(
                          children: [
                            Expanded(
                                child: GestureDetector(
                                    onTap: () {
                                      if (!_isAutoMode) {
                                        setState(() => _isAutoMode = true);
                                        _startAutoScan();
                                      }
                                    },
                                    child: Container(
                                        padding: const EdgeInsets.symmetric(
                                            vertical: 12),
                                        decoration: BoxDecoration(
                                            color: _isAutoMode
                                                ? colors.primary
                                                : Colors.transparent,
                                            borderRadius:
                                                BorderRadius.circular(15)),
                                        child: Center(
                                            child: Text(
                                                loc.loc('auto_scan_mode'),
                                                style: TextStyle(
                                                    color: _isAutoMode
                                                        ? Colors.white
                                                        : colors.textGrey,
                                                    fontWeight:
                                                        FontWeight.bold)))))),
                            Expanded(
                                child: GestureDetector(
                                    onTap: () {
                                      if (_isAutoMode) {
                                        setState(() => _isAutoMode = false);
                                        _stopAutoScanEngine();
                                      }
                                    },
                                    child: Container(
                                        padding: const EdgeInsets.symmetric(
                                            vertical: 12),
                                        decoration: BoxDecoration(
                                            color: !_isAutoMode
                                                ? colors.primary
                                                : Colors.transparent,
                                            borderRadius:
                                                BorderRadius.circular(15)),
                                        child: Center(
                                            child: Text(
                                                loc.loc('manual_shutter'),
                                                style: TextStyle(
                                                    color: !_isAutoMode
                                                        ? Colors.white
                                                        : colors.textGrey,
                                                    fontWeight:
                                                        FontWeight.bold))))))
                          ],
                        )),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                        color: colors.cardColor,
                        borderRadius: BorderRadius.circular(30),
                        boxShadow: [
                          BoxShadow(
                              color: colors.primary.withOpacity(0.1),
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
                                        color: colors.background,
                                        child: Column(
                                            mainAxisAlignment:
                                                MainAxisAlignment.center,
                                            children: [
                                              Icon(Icons.check_circle_outline,
                                                  color: colors.primary,
                                                  size: 60),
                                              const SizedBox(height: 15),
                                              Text(
                                                  loc.loc(
                                                      'manual_entry_analysis'),
                                                  style: TextStyle(
                                                      color: colors.primaryDark,
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
                                                        decoration:
                                                            BoxDecoration(
                                                                color: colors
                                                                    .primary,
                                                                boxShadow: [
                                                              BoxShadow(
                                                                  color: colors
                                                                      .primaryLight,
                                                                  blurRadius:
                                                                      10,
                                                                  spreadRadius:
                                                                      3)
                                                            ])));
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
                                                        width: _controller!
                                                            .value
                                                            .previewSize!
                                                            .height,
                                                        height: _controller!
                                                            .value
                                                            .previewSize!
                                                            .width,
                                                        child: CameraPreview(
                                                            _controller!))),
                                              ),
                                              if (_imageSize != null &&
                                                  _isScanning &&
                                                  _isAutoMode)
                                                Positioned.fill(
                                                  child: CustomPaint(
                                                    painter:
                                                        _TextBoundingBoxPainter(
                                                      _currentTextBlocks,
                                                      _imageSize!,
                                                    ),
                                                  ),
                                                ),
                                              if (_isAutoMode)
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
                                                                      ? Colors
                                                                          .green
                                                                      : colors
                                                                          .primaryLight
                                                                          .withOpacity(
                                                                              0.8),
                                                                  width: 3),
                                                              borderRadius:
                                                                  BorderRadius
                                                                      .circular(
                                                                          20),
                                                              boxShadow: [
                                                                BoxShadow(
                                                                    color: _isLocking
                                                                        ? Colors
                                                                            .green
                                                                            .withOpacity(
                                                                                0.2)
                                                                        : colors
                                                                            .primary
                                                                            .withOpacity(
                                                                                0.2),
                                                                    blurRadius:
                                                                        15,
                                                                    spreadRadius:
                                                                        2)
                                                              ])),
                                                      const SizedBox(
                                                          height: 15),
                                                      Container(
                                                          padding: const EdgeInsets.symmetric(
                                                              horizontal: 15,
                                                              vertical: 8),
                                                          decoration: BoxDecoration(
                                                              color: _isLocking
                                                                  ? Colors.green
                                                                      .withOpacity(
                                                                          0.8)
                                                                  : Colors.black
                                                                      .withOpacity(
                                                                          0.7),
                                                              borderRadius:
                                                                  BorderRadius.circular(
                                                                      20)),
                                                          child: Text(loc.loc(_diagnosticMessage),
                                                              style: const TextStyle(
                                                                  color: Colors
                                                                      .white,
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .bold,
                                                                  fontSize:
                                                                      12))),
                                                    ],
                                                  ),
                                                ),
                                              if (_isAutoMode)
                                                AnimatedBuilder(
                                                  animation: _laserAnimation,
                                                  builder: (context, child) {
                                                    return Positioned(
                                                        top: _laserAnimation
                                                                .value *
                                                            constraints
                                                                .maxHeight,
                                                        left: 0,
                                                        right: 0,
                                                        child: Container(
                                                            height: 3,
                                                            decoration: BoxDecoration(
                                                                color: _isLocking
                                                                    ? Colors.green
                                                                    : colors.primary,
                                                                boxShadow: [
                                                                  BoxShadow(
                                                                      color: colors
                                                                          .primaryLight,
                                                                      blurRadius:
                                                                          10,
                                                                      spreadRadius:
                                                                          3)
                                                                ])));
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
                      Center(
                          child:
                              CircularProgressIndicator(color: colors.primary)),
                      const SizedBox(height: 20),
                      Center(
                          child: Text(loc.loc('extracting_text'),
                              style: TextStyle(
                                  color: colors.primaryDark,
                                  fontWeight: FontWeight.bold))),
                      const SizedBox(height: 100),
                    ] else ...[
                      if (_isInvalidSachet)
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(25),
                          decoration: BoxDecoration(
                              color: colors.isDark
                                  ? Colors.red.shade900.withOpacity(0.3)
                                  : Colors.red.shade50,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                  color: colors.isDark
                                      ? Colors.red.shade900
                                      : Colors.red.shade200)),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              const Icon(Icons.warning_amber_rounded,
                                  color: Colors.red, size: 50),
                              const SizedBox(height: 15),
                              Text("INVALID SACHET",
                                  style: TextStyle(
                                      fontSize: 22,
                                      fontWeight: FontWeight.w900,
                                      color: colors.isDark
                                          ? Colors.red.shade200
                                          : Colors.red.shade900)),
                              const SizedBox(height: 10),
                              Text(_invalidSachetMessage,
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                      color: colors.textDark,
                                      height: 1.4,
                                      fontWeight: FontWeight.bold)),
                            ],
                          ),
                        )
                      else ...[
                        GestureDetector(
                          onTap: _showEditNameModal,
                          child: Row(children: [
                            Expanded(
                                child: Text(
                                    _productName == 'unnamed'
                                        ? loc.loc('unnamed')
                                        : _productName,
                                    style: TextStyle(
                                        fontSize: 32,
                                        fontWeight: FontWeight.w900,
                                        color: colors.primaryDark,
                                        decoration: TextDecoration.underline,
                                        decorationColor: colors.primaryDark))),
                            Icon(Icons.edit_outlined,
                                color: colors.primaryDark, size: 22)
                          ]),
                        ),
                        const SizedBox(height: 5),
                        Text(
                            "${loc.loc('category_label')} ${loc.loc(_drinkCategory.toLowerCase().replaceAll(' ', '_'))}",
                            style: TextStyle(
                                color: colors.primary,
                                fontWeight: FontWeight.bold)),
                        const SizedBox(height: 10),
                        Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                                color: colors.cardColor,
                                borderRadius: BorderRadius.circular(20),
                                boxShadow: [
                                  BoxShadow(
                                      color: Colors.black.withOpacity(0.05),
                                      blurRadius: 10,
                                      offset: const Offset(0, 5))
                                ]),
                            child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Expanded(
                                          child: Row(
                                            children: [
                                              Flexible(
                                                child: Text(
                                                    loc.loc(
                                                        'acid_impact_verdict'),
                                                    style: TextStyle(
                                                        fontWeight:
                                                            FontWeight.w900,
                                                        fontSize: 16,
                                                        color: colors
                                                            .primaryDark)),
                                              ),
                                              const SizedBox(width: 8),
                                              GestureDetector(
                                                onTap: () => _showInfoModal(
                                                    loc.loc(
                                                        'acid_impact_verdict'),
                                                    "The overall calculated risk level based on your personal biology and the drink's acidic compounds.",
                                                    colors),
                                                child: Icon(Icons.info_outline,
                                                    color: colors.textGrey,
                                                    size: 16),
                                              ),
                                            ],
                                          ),
                                        ),
                                        Container(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 10, vertical: 5),
                                            decoration: BoxDecoration(
                                                color: _getRiskColor(colors)
                                                    .withOpacity(0.1),
                                                borderRadius:
                                                    BorderRadius.circular(10)),
                                            child: Text(_getRiskLevelText(loc),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: TextStyle(
                                                    color:
                                                        _getRiskColor(colors),
                                                    fontWeight: FontWeight.w900,
                                                    fontSize: 10)))
                                      ]),
                                  const SizedBox(height: 15),
                                  Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.end,
                                      children: [
                                        Text(_finalRiskScore.toStringAsFixed(1),
                                            style: TextStyle(
                                                fontSize: 42,
                                                fontWeight: FontWeight.w900,
                                                color: colors.textDark)),
                                        Padding(
                                          padding: const EdgeInsets.only(
                                              bottom: 8, left: 8),
                                          child: Text(loc.loc('acid_points'),
                                              style: TextStyle(
                                                  fontSize: 14,
                                                  fontWeight: FontWeight.w900,
                                                  color: colors.textGrey)),
                                        )
                                      ]),
                                  const SizedBox(height: 5),
                                  Text(
                                      RiskTranslator
                                          .getHumanizedScoreDescription(
                                              _finalRiskScore, loc),
                                      style: TextStyle(
                                          fontSize: 11,
                                          height: 1.4,
                                          color: colors.textGrey,
                                          fontStyle: FontStyle.italic)),
                                  Divider(
                                      height: 30,
                                      color: colors.isDark
                                          ? Colors.white12
                                          : Colors.grey.shade200),
                                  Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Expanded(
                                          child: Row(
                                            children: [
                                              Flexible(
                                                child: Text(
                                                    loc.loc('dashboard_impact'),
                                                    style: TextStyle(
                                                        fontWeight:
                                                            FontWeight.w900,
                                                        fontSize: 14,
                                                        color:
                                                            colors.textDark)),
                                              ),
                                              const SizedBox(width: 8),
                                              GestureDetector(
                                                onTap: () => _showInfoModal(
                                                    loc.loc('dashboard_impact'),
                                                    "How much of your daily safe acid limit this specific drink consumes.",
                                                    colors),
                                                child: Icon(Icons.info_outline,
                                                    color: colors.textGrey,
                                                    size: 16),
                                              ),
                                            ],
                                          ),
                                        ),
                                        Text(
                                            loc.loc('percent_daily_cap', {
                                              'percent': impactPercentage
                                                  .toStringAsFixed(0)
                                            }),
                                            style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 12,
                                                color: colors.primary))
                                      ]),
                                  const SizedBox(height: 10),
                                  ClipRRect(
                                      borderRadius: BorderRadius.circular(10),
                                      child: LinearProgressIndicator(
                                        value:
                                            _finalRiskScore / _activeDailyCap,
                                        minHeight: 8,
                                        backgroundColor: colors.isDark
                                            ? Colors.white12
                                            : Colors.grey.shade200,
                                        valueColor:
                                            AlwaysStoppedAnimation<Color>(
                                                _getRiskColor(colors)),
                                      )),
                                  const SizedBox(height: 10),
                                  Text(
                                      RiskTranslator.getDashboardImpactText(
                                          _finalRiskScore, _userProfile, loc),
                                      style: TextStyle(
                                          fontSize: 11,
                                          color: colors.textDark,
                                          fontWeight: FontWeight.w500)),
                                ])),
                        const SizedBox(height: 15),
                        if (impactPercentage > 60)
                          Container(
                              width: double.infinity,
                              margin: const EdgeInsets.only(bottom: 15),
                              padding: const EdgeInsets.all(15),
                              decoration: BoxDecoration(
                                  color: colors.isDark
                                      ? Colors.amber.shade900.withOpacity(0.3)
                                      : Colors.amber.shade50,
                                  borderRadius: BorderRadius.circular(15),
                                  border: Border.all(
                                      color: colors.isDark
                                          ? Colors.amber.shade900
                                          : Colors.amber.shade200)),
                              child: Row(
                                children: [
                                  Icon(Icons.medication_liquid,
                                      color: colors.isDark
                                          ? Colors.amber.shade200
                                          : Colors.orange),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                        RiskTranslator.getSmartRecommendation(
                                            _drinkCategory,
                                            _finalRiskScore,
                                            _activeDailyCap,
                                            loc),
                                        style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                            color: colors.isDark
                                                ? Colors.amber.shade100
                                                : Colors.orange.shade900)),
                                  )
                                ],
                              )),
                        Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                                color: colors.primary,
                                borderRadius: BorderRadius.circular(20),
                                boxShadow: [
                                  BoxShadow(
                                      color: colors.primary.withOpacity(0.3),
                                      blurRadius: 15,
                                      offset: const Offset(0, 5))
                                ]),
                            child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(children: [
                                    const Icon(Icons.biotech,
                                        color: Colors.white, size: 20),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                          loc.loc(
                                              'potential_clinical_irritants'),
                                          style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 16,
                                              fontWeight: FontWeight.w900)),
                                    ),
                                    GestureDetector(
                                      onTap: () => _showInfoModal(
                                          loc.loc(
                                              'potential_clinical_irritants'),
                                          "Chemical triggers isolated from the ingredients label that may cause reflux synergy.",
                                          colors),
                                      child: const Icon(Icons.info_outline,
                                          color: Colors.white70, size: 16),
                                    ),
                                  ]),
                                  const SizedBox(height: 15),
                                  _buildScannerClinicalUI(
                                      _detectedTriggersText, colors),
                                ])),
                      ],
                      const SizedBox(height: 15),
                      Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1E1E1E),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(children: [
                                  const Icon(Icons.terminal,
                                      color: Colors.greenAccent, size: 16),
                                  const SizedBox(width: 8),
                                  Text(loc.loc('raw_ocr_data'),
                                      style: const TextStyle(
                                          color: Colors.greenAccent,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w900)),
                                ]),
                                const SizedBox(height: 5),
                                Text(loc.loc('tap_to_edit_ocr'),
                                    style: const TextStyle(
                                        color: Colors.white54,
                                        fontSize: 9,
                                        fontStyle: FontStyle.italic)),
                                const SizedBox(height: 15),
                                TextField(
                                  controller: _ocrTextController,
                                  maxLines: null,
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 11,
                                      height: 1.5,
                                      fontFamily: 'monospace'),
                                  decoration: InputDecoration(
                                    filled: true,
                                    fillColor: Colors.black26,
                                    border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(10),
                                        borderSide: BorderSide.none),
                                    focusedBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(10),
                                        borderSide: const BorderSide(
                                            color: Colors.greenAccent)),
                                  ),
                                ),
                                const SizedBox(height: 15),
                                SizedBox(
                                  width: double.infinity,
                                  height: 45,
                                  child: ElevatedButton.icon(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor:
                                          Colors.greenAccent.shade700,
                                      foregroundColor: Colors.white,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                    ),
                                    icon: _isRecalibrating
                                        ? const SizedBox(
                                            width: 16,
                                            height: 16,
                                            child: CircularProgressIndicator(
                                                color: Colors.white,
                                                strokeWidth: 2))
                                        : const Icon(Icons.sync, size: 18),
                                    label: Text(
                                      _isRecalibrating
                                          ? loc.loc('recalibrating')
                                          : loc.loc('recalibrate_analysis'),
                                      style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13),
                                    ),
                                    onPressed: _isRecalibrating
                                        ? null
                                        : () async {
                                            setState(
                                                () => _isRecalibrating = true);
                                            FocusScope.of(context).unfocus();

                                            await Future.delayed(const Duration(
                                                milliseconds: 400));

                                            await _processExtractedText(
                                                _ocrTextController.text,
                                                _productName);

                                            setState(
                                                () => _isRecalibrating = false);

                                            if (mounted) {
                                              ScaffoldMessenger.of(context)
                                                  .showSnackBar(SnackBar(
                                                content: Text(
                                                    loc.loc(
                                                        'analysis_recalibrated'),
                                                    style: const TextStyle(
                                                        fontWeight:
                                                            FontWeight.bold)),
                                                backgroundColor: Colors.green,
                                                behavior:
                                                    SnackBarBehavior.floating,
                                                duration:
                                                    const Duration(seconds: 2),
                                              ));
                                            }
                                          },
                                  ),
                                ),
                              ])),
                      const SizedBox(height: 20),
                      SizedBox(
                        width: double.infinity,
                        height: 55,
                        child: OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                                foregroundColor: colors.primaryDark,
                                side: BorderSide(
                                    color: colors.primaryLight, width: 2),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(20))),
                            icon: const Icon(Icons.medical_services_outlined),
                            label: Text(loc.loc('first_aid_coach'),
                                style: const TextStyle(
                                    fontWeight: FontWeight.w900, fontSize: 16)),
                            onPressed: () {
                              Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                      builder: (context) => CoachScreen(
                                          dbService: widget.dbService,
                                          entryMode: 'scanner',
                                          scannedProduct: _productName,
                                          dynamicContextData:
                                              "User just scanned an item with risk level: \$_riskLevel.")));
                            }),
                      ),
                      const SizedBox(height: 150),
                    ]
                  ] else ...[
                    if (!_isAutoMode)
                      Column(
                        children: [
                          Container(
                            width: double.infinity,
                            height: 60,
                            decoration: BoxDecoration(
                                color: colors.cardColor,
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
                                        onTap: () =>
                                            _takePictureAndScan(colors),
                                        child: Container(
                                            decoration: BoxDecoration(
                                                color: colors.cardColor,
                                                borderRadius:
                                                    BorderRadius.circular(30),
                                                border: Border.all(
                                                    color: colors.isDark
                                                        ? Colors.white12
                                                        : Colors
                                                            .grey.shade200)),
                                            child: Row(
                                                mainAxisAlignment:
                                                    MainAxisAlignment.center,
                                                children: [
                                                  Icon(Icons.camera_alt,
                                                      color: colors.primary,
                                                      size: 20),
                                                  const SizedBox(width: 8),
                                                  Text(
                                                      loc.loc('manual_shutter'),
                                                      style: TextStyle(
                                                          color:
                                                              colors.textDark,
                                                          fontWeight:
                                                              FontWeight.bold))
                                                ])))),
                                Expanded(
                                    child: GestureDetector(
                                        onTap: () => _pickFromGallery(colors),
                                        child: Container(
                                            decoration: BoxDecoration(
                                                color: colors.primary,
                                                borderRadius:
                                                    const BorderRadius.only(
                                                        topRight:
                                                            Radius.circular(30),
                                                        bottomRight:
                                                            Radius.circular(
                                                                30))),
                                            child: Row(
                                                mainAxisAlignment:
                                                    MainAxisAlignment.center,
                                                children: [
                                                  const Icon(
                                                      Icons.image_outlined,
                                                      color: Colors.white,
                                                      size: 20),
                                                  const SizedBox(width: 8),
                                                  Text(loc.loc('gallery'),
                                                      style: const TextStyle(
                                                          color: Colors.white,
                                                          fontWeight:
                                                              FontWeight.bold))
                                                ])))),
                              ],
                            ),
                          ),
                          const SizedBox(height: 15),
                          SizedBox(
                              width: double.infinity,
                              height: 50,
                              child: ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                      backgroundColor: colors.cardColor,
                                      elevation: 0,
                                      shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(15))),
                                  onPressed: _showManualEntryModal,
                                  child: Text(
                                      loc.loc('type_ingredients_manually'),
                                      style: TextStyle(
                                          color: colors.textGrey,
                                          fontWeight: FontWeight.w900,
                                          fontSize: 16)))),
                          const SizedBox(height: 15),
                        ],
                      ),
                    Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                            color: colors.cardColor,
                            borderRadius: BorderRadius.circular(15),
                            boxShadow: [
                              BoxShadow(
                                  color: Colors.black.withOpacity(0.05),
                                  blurRadius: 10)
                            ]),
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(children: [
                                Icon(Icons.info_outline,
                                    color: colors.primaryDark),
                                const SizedBox(width: 8),
                                Text(loc.loc('how_it_works'),
                                    style: TextStyle(
                                        fontWeight: FontWeight.w900,
                                        color: colors.textDark))
                              ]),
                              const SizedBox(height: 10),
                              Text(loc.loc('how_it_works_desc'),
                                  style: TextStyle(
                                      fontSize: 11,
                                      color: colors.textGrey,
                                      height: 1.5))
                            ])),
                    const SizedBox(height: 100),
                  ]
                ],
              ),
            ),
          ),
          Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: isResultView
                  ? _buildResultBottomBar(colors, loc)
                  : Container(
                      height: 120,
                      color: Colors.transparent,
                      child:
                          Stack(alignment: Alignment.bottomCenter, children: [
                        Container(
                            margin: const EdgeInsets.only(
                                left: 20, right: 20, bottom: 20),
                            height: 65,
                            decoration: BoxDecoration(
                                color: colors.cardColor,
                                borderRadius: BorderRadius.circular(35),
                                boxShadow: [
                                  BoxShadow(
                                      color: Colors.black.withOpacity(0.05),
                                      blurRadius: 20,
                                      offset: const Offset(0, 5))
                                ]),
                            child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceAround,
                                children: [
                                  IconButton(
                                      icon: Image.asset(
                                          'assets/images/home.png',
                                          width: 24,
                                          color: colors.textDark),
                                      onPressed: () =>
                                          Navigator.pushAndRemoveUntil(
                                              context,
                                              MaterialPageRoute(
                                                  builder: (context) =>
                                                      MainLayoutScreen(
                                                          dbService:
                                                              widget.dbService,
                                                          initialIndex: 0)),
                                              (route) => false)),
                                  IconButton(
                                      icon: Image.asset(
                                          'assets/images/write.png',
                                          width: 24,
                                          color: colors.textDark),
                                      onPressed: () =>
                                          Navigator.pushAndRemoveUntil(
                                              context,
                                              MaterialPageRoute(
                                                  builder: (context) =>
                                                      MainLayoutScreen(
                                                          dbService:
                                                              widget.dbService,
                                                          initialIndex: 1)),
                                              (route) => false)),
                                  const SizedBox(width: 60),
                                  IconButton(
                                      icon: Image.asset(
                                          'assets/images/bar-graph.png',
                                          width: 24,
                                          color: colors.textDark),
                                      onPressed: () =>
                                          Navigator.pushAndRemoveUntil(
                                              context,
                                              MaterialPageRoute(
                                                  builder: (context) =>
                                                      MainLayoutScreen(
                                                          dbService:
                                                              widget.dbService,
                                                          initialIndex: 2)),
                                              (route) => false)),
                                  IconButton(
                                      icon: Image.asset(
                                          'assets/images/message.png',
                                          width: 24,
                                          color: colors.textDark),
                                      onPressed: () =>
                                          Navigator.pushAndRemoveUntil(
                                              context,
                                              MaterialPageRoute(
                                                  builder: (context) =>
                                                      MainLayoutScreen(
                                                          dbService:
                                                              widget.dbService,
                                                          initialIndex: 3)),
                                              (route) => false))
                                ])),
                        Positioned(
                            bottom: 35,
                            child: GestureDetector(
                                onTap: () {
                                  if (_isAutoMode) {
                                    setState(() => _isAutoMode = false);
                                    _stopAutoScanEngine();
                                  }
                                  _takePictureAndScan(colors);
                                },
                                child: Container(
                                    width: 70,
                                    height: 70,
                                    decoration: BoxDecoration(
                                        color: colors.primaryDark,
                                        shape: BoxShape.circle,
                                        boxShadow: [
                                          BoxShadow(
                                              color: colors.primary
                                                  .withOpacity(0.4),
                                              blurRadius: 20,
                                              offset: const Offset(0, 8))
                                        ]),
                                    child: Center(
                                        child: Image.asset(
                                            'assets/images/barcode-scanner.png',
                                            width: 32,
                                            color: Colors.white)))))
                      ])))
        ],
      ),
    );
  }
}

class _TextBoundingBoxPainter extends CustomPainter {
  final List<TextBlock> textBlocks;
  final Size imageSize;

  _TextBoundingBoxPainter(this.textBlocks, this.imageSize);

  @override
  void paint(Canvas canvas, Size size) {
    final double scaleX = size.width / imageSize.height;
    final double scaleY = size.height / imageSize.width;

    final Paint defaultPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..color = Colors.white.withOpacity(0.5);

    final Paint matchPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0
      ..color = Colors.greenAccent;

    for (var block in textBlocks) {
      final rect = Rect.fromLTRB(
        block.boundingBox.left * scaleX,
        block.boundingBox.top * scaleY,
        block.boundingBox.right * scaleX,
        block.boundingBox.bottom * scaleY,
      );

      bool isSemanticTarget = KeywordMappingAlgorithm.semanticKeywords
          .any((kw) => block.text.toLowerCase().contains(kw));

      canvas.drawRect(rect, isSemanticTarget ? matchPaint : defaultPaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
