import 'dart:io';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_cropper/image_cropper.dart';
import '../services/database_service.dart';
import '../models/pantry_item.dart';
import '../utils/ui_helpers.dart';
import '../utils/keyword_mapping_algorithm.dart';
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

  final ImagePicker _picker = ImagePicker();

  File? _capturedImage;
  bool _isAnalyzing = false;

  String _rawText = "Waiting for scan...";
  String _productName = "Unnamed";

  String _riskLevel = "GREEN";
  double _finalRiskScore = 0.0;
  bool _exceedsDailyCap = false;
  String _detectedTriggersText = "None";

  String _symptoms = "None";
  int _symptomSeverity = 0;

  // Zoom Variables
  double _currentZoomLevel = 1.0;
  double _minZoomLevel = 1.0;
  double _maxZoomLevel = 1.0;

  // Laser Animation Variables
  late AnimationController _laserController;
  late Animation<double> _laserAnimation;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _laserController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    _laserAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _laserController, curve: Curves.easeInOutSine),
    );

    _initCamera();
  }

  Future<void> _initCamera() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) return;

      _controller = CameraController(cameras[0], ResolutionPreset.high,
          enableAudio: false);
      await _controller!.initialize();

      _minZoomLevel = await _controller!.getMinZoomLevel();
      _maxZoomLevel = await _controller!.getMaxZoomLevel();

      if (mounted) {
        setState(() {
          _isInitialized = true;
          _controller!.setFlashMode(FlashMode.off);
        });
      }
    } catch (e) {
      debugPrint("Camera Error: $e");
    }
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
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _laserController.dispose();
    if (_controller != null && _controller!.value.isInitialized) {
      _controller!.setFlashMode(FlashMode.off);
    }
    _controller?.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_controller == null || !_controller!.value.isInitialized) return;
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused) {
      _controller!.dispose();
      if (mounted) setState(() => _isInitialized = false);
    } else if (state == AppLifecycleState.resumed) {
      _initCamera();
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

  String _autoIsolateIngredients(String rawText) {
    String lowerText = rawText.toLowerCase();

    List<String> keywords = [
      'ingredients:',
      'ingredients',
      'mga sangkap:',
      'mga sangkap',
      'sangkap:',
      'contains:'
    ];

    int startIndex = -1;
    for (String keyword in keywords) {
      startIndex = lowerText.indexOf(keyword);
      if (startIndex != -1) break;
    }

    if (startIndex != -1) {
      debugPrint("Auto-detected ingredients block at index $startIndex");
      return rawText.substring(startIndex);
    }

    return rawText;
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
      final pickedFile = await _picker.pickImage(source: ImageSource.gallery);
      if (pickedFile == null) return;

      File? cropped = await _cropImage(File(pickedFile.path));
      if (cropped == null) return;

      setState(() {
        _capturedImage = cropped;
        _isAnalyzing = true;
      });

      _laserController.repeat(reverse: true);
      await _processImageForOCR(cropped.path, "Gallery Upload");
    } catch (e) {
      debugPrint("Gallery Error: $e");
      if (mounted) {
        setState(() {
          _isAnalyzing = false;
          _rawText = "Failed to load image from gallery.";
        });
      }
    }
  }

  Future<void> _takePictureAndScan() async {
    if (_controller == null || !_controller!.value.isInitialized) return;

    try {
      final image = await _controller!.takePicture();

      if (_isFlashOn) {
        await _controller!.setFlashMode(FlashMode.off);
        _isFlashOn = false;
      }

      File? cropped = await _cropImage(File(image.path));
      if (cropped == null) {
        _initCamera();
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
      if (mounted) {
        setState(() {
          _isAnalyzing = false;
          _rawText = "Failed to process camera image.";
        });
      }
    }
  }

  Future<void> _processImageForOCR(String imagePath, String defaultName) async {
    try {
      final inputImage = InputImage.fromFilePath(imagePath);
      final textRecognizer =
          TextRecognizer(script: TextRecognitionScript.latin);

      final RecognizedText recognizedText =
          await textRecognizer.processImage(inputImage);
      String extractedText = recognizedText.text;

      await textRecognizer.close();

      String isolatedIngredientsText = _autoIsolateIngredients(extractedText);

      final triggers = await widget.dbService.getAllTriggers();
      final userProfile = await widget.dbService.getUserProfile();
      double currentDailyLoad = await _calculateDailyLoad();

      final result = KeywordMappingAlgorithm.analyze(
          isolatedIngredientsText, triggers, userProfile, currentDailyLoad);

      if (mounted) {
        setState(() {
          _isAnalyzing = false;
          _laserController.stop();
          _rawText = isolatedIngredientsText.isEmpty
              ? "No text detected."
              : isolatedIngredientsText;
          _riskLevel = result.riskLevel;
          _finalRiskScore = result.finalRiskScore;
          _detectedTriggersText = result.triggersSummary;
          _exceedsDailyCap = result.exceedsDailyCap;
          _productName = defaultName;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isAnalyzing = false;
          _laserController.stop();
          _rawText = "OCR Processing Failed: $e";
        });
      }
    }
  }

  Future<void> _saveToDatabase() async {
    final newItem = PantryItem()
      ..name = _productName
      ..dateScanned = DateTime.now()
      ..symptoms = _symptoms == "None" ? "" : _symptoms
      ..riskLevel = _riskLevel
      ..isFavorite = false
      ..rawText = _rawText
      ..acidScore = _finalRiskScore.round();

    await widget.dbService.savePantryItem(newItem);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Item Consumed & Saved to Digital Pantry!'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating),
      );
      Navigator.pop(context);
    }
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

                  setState(() {
                    _capturedImage = File('manual_entry');
                    _isAnalyzing = true;
                  });

                  final triggers = await widget.dbService.getAllTriggers();
                  final userProfile = await widget.dbService.getUserProfile();
                  double currentDailyLoad = await _calculateDailyLoad();

                  final result = KeywordMappingAlgorithm.analyze(
                      text, triggers, userProfile, currentDailyLoad);

                  setState(() {
                    _isAnalyzing = false;
                    _rawText = text.isEmpty ? "No text provided." : text;
                    _riskLevel = result.riskLevel;
                    _finalRiskScore = result.finalRiskScore;
                    _detectedTriggersText = result.triggersSummary;
                    _exceedsDailyCap = result.exceedsDailyCap;
                    _productName = "Manual Entry";
                  });
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
          height: MediaQuery.of(context).size.height * 0.55,
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
                const SizedBox(height: 30),
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
                      _buildSymptomRadio('Excessive burping', setModalState),
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
                                      () => _symptomSeverity = val.toInt()))),
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
                const Spacer(),
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
            onPressed: () => isResultView
                ? setState(() => _capturedImage = null)
                : Navigator.pop(context)),
        title: Text(isResultView ? '' : 'Scan Ingredients',
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
                                        color: Colors.grey.shade200,
                                        child: const Center(
                                            child: Text('Manual Entry')))
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
                                                              color: AppColors
                                                                  .primaryLight
                                                                  .withOpacity(
                                                                      0.8),
                                                              width: 3),
                                                          borderRadius:
                                                              BorderRadius
                                                                  .circular(20),
                                                          boxShadow: [
                                                            BoxShadow(
                                                                color: AppColors
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
                                                        color: Colors.black
                                                            .withOpacity(0.6),
                                                        borderRadius:
                                                            BorderRadius
                                                                .circular(20),
                                                      ),
                                                      child: const Text(
                                                        'Align ingredients list inside the box',
                                                        style: TextStyle(
                                                            color: Colors.white,
                                                            fontWeight:
                                                                FontWeight.bold,
                                                            fontSize: 12),
                                                      ),
                                                    ),
                                                  ],
                                                ),
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
                      Row(
                        children: [
                          Expanded(
                              child: Text(_productName,
                                  style: const TextStyle(
                                      fontSize: 32,
                                      fontWeight: FontWeight.w900,
                                      color: AppColors.primaryDark,
                                      decoration: TextDecoration.underline,
                                      decorationColor: AppColors.primaryDark))),
                          const Icon(Icons.edit_outlined,
                              color: AppColors.primaryDark, size: 22),
                        ],
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
                            const Text('Raw OCR Text',
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
                                          dbService: widget.dbService))),
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
                                    Text('Camera',
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
                              Icon(Icons.arrow_drop_down,
                                  color: AppColors.textDark),
                              Text('Raw OCR Text',
                                  style: TextStyle(
                                      fontWeight: FontWeight.w900,
                                      color: AppColors.textDark)),
                            ],
                          ),
                          SizedBox(height: 10),
                          Text(
                              "Point the camera at a powdered drink sachet and tap the purple button to scan its ingredients.",
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
                                  icon: Image.asset('assets/images/home.png',
                                      width: 24, color: AppColors.textDark),
                                  onPressed: () => Navigator.pushAndRemoveUntil(
                                      context,
                                      MaterialPageRoute(
                                          builder: (context) =>
                                              MainLayoutScreen(
                                                  dbService: widget.dbService,
                                                  initialIndex: 0)),
                                      (route) => false)),
                              IconButton(
                                  icon: Image.asset('assets/images/write.png',
                                      width: 24, color: AppColors.textDark),
                                  onPressed: () => Navigator.pushAndRemoveUntil(
                                      context,
                                      MaterialPageRoute(
                                          builder: (context) =>
                                              MainLayoutScreen(
                                                  dbService: widget.dbService,
                                                  initialIndex: 1)),
                                      (route) => false)),
                              const SizedBox(width: 60),
                              IconButton(
                                  icon: Image.asset(
                                      'assets/images/bar-graph.png',
                                      width: 24,
                                      color: AppColors.textDark),
                                  onPressed: () => Navigator.pushAndRemoveUntil(
                                      context,
                                      MaterialPageRoute(
                                          builder: (context) =>
                                              MainLayoutScreen(
                                                  dbService: widget.dbService,
                                                  initialIndex: 2)),
                                      (route) => false)),
                              IconButton(
                                  icon: Image.asset('assets/images/message.png',
                                      width: 24, color: AppColors.textDark),
                                  onPressed: () => Navigator.pushAndRemoveUntil(
                                      context,
                                      MaterialPageRoute(
                                          builder: (context) =>
                                              MainLayoutScreen(
                                                  dbService: widget.dbService,
                                                  initialIndex: 3)),
                                      (route) => false)),
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
