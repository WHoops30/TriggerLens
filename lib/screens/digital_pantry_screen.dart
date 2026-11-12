import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import '../services/database_service.dart';
import '../services/notification_service.dart';
import '../models/pantry_item.dart';
import '../models/user_profile.dart';
import '../utils/ui_helpers.dart';
import '../utils/app_localizations.dart';
import '../utils/risk_translator.dart';
import '../widgets/consumption_modal.dart';
import '../utils/keyword_mapping_algorithm.dart';
import '../main.dart';
import 'coach_screen.dart';

class DigitalPantryScreen extends StatefulWidget {
  final DatabaseService dbService;
  const DigitalPantryScreen({super.key, required this.dbService});

  @override
  State<DigitalPantryScreen> createState() => _DigitalPantryScreenState();
}

class _DigitalPantryScreenState extends State<DigitalPantryScreen> {
  List<PantryItem> _allGroupedItems = [];
  List<PantryItem> _displayedItems = [];
  bool _isLoading = true;

  String _searchQuery = "";
  String _selectedFilter = "All";
  String _currentSort = "Newest";

  final TextEditingController _searchController = TextEditingController();
  final ImagePicker _picker = ImagePicker();

  UserProfile? _userProfile;
  final double _currentStomachLoad = 12.0;
  double _dailyMaxLoad = 15.0;

  @override
  void initState() {
    super.initState();
    _loadPantryItems();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadPantryItems() async {
    setState(() => _isLoading = true);

    _userProfile = await widget.dbService.getUserProfile();
    if (_userProfile != null) {
      _dailyMaxLoad = _userProfile!.dynamicDailyCap;
    }

    var allLogs = await widget.dbService.getAllSavedAndConsumedItems();

    allLogs.sort((a, b) => b.dateScanned.compareTo(a.dateScanned));

    Map<String, PantryItem> uniqueItemsMap = {};
    Map<String, String> symptomMemory = {};

    for (var item in allLogs) {
      String normalizedName = item.name.trim().toLowerCase();

      if (item.symptoms.isNotEmpty && item.symptoms != "None") {
        if (!symptomMemory.containsKey(normalizedName)) {
          symptomMemory[normalizedName] = item.symptoms;
        }
      }

      if (!uniqueItemsMap.containsKey(normalizedName)) {
        uniqueItemsMap[normalizedName] = item;
      }
    }

    List<PantryItem> groupedItems = uniqueItemsMap.values.toList();

    for (var item in groupedItems) {
      String normalizedName = item.name.trim().toLowerCase();
      if (symptomMemory.containsKey(normalizedName)) {
        item.symptoms = symptomMemory[normalizedName]!;
      } else {
        item.symptoms = "None";
      }
    }

    _allGroupedItems = groupedItems;
    _applyFilters();
  }

  void _applyFilters() {
    List<PantryItem> filtered = List.from(_allGroupedItems);

    if (_searchQuery.isNotEmpty) {
      filtered = filtered
          .where((item) =>
              item.name.toLowerCase().contains(_searchQuery.toLowerCase()))
          .toList();
    }

    if (_selectedFilter == "Favorites") {
      filtered = filtered.where((item) => item.isFavorite).toList();
    } else if (_selectedFilter == "Safe") {
      filtered = filtered
          .where((item) =>
              item.riskLevel.toUpperCase().contains("GREEN") ||
              item.riskLevel.toUpperCase().contains("SAFE"))
          .toList();
    } else if (_selectedFilter == "Moderate") {
      filtered = filtered
          .where((item) =>
              item.riskLevel.toUpperCase().contains("YELLOW") ||
              item.riskLevel.toUpperCase().contains("MEDIUM") ||
              item.riskLevel.toUpperCase().contains("MODERATE"))
          .toList();
    } else if (_selectedFilter == "High") {
      filtered = filtered
          .where((item) =>
              item.riskLevel.toUpperCase().contains("RED") ||
              item.riskLevel.toUpperCase().contains("HIGH"))
          .toList();
    }

    if (_currentSort == "Newest") {
      filtered.sort((a, b) => b.dateScanned.compareTo(a.dateScanned));
    } else if (_currentSort == "Oldest") {
      filtered.sort((a, b) => a.dateScanned.compareTo(b.dateScanned));
    } else if (_currentSort == "Highest Risk") {
      filtered.sort((a, b) => b.acidScore.compareTo(a.acidScore));
    } else if (_currentSort == "Lowest Risk") {
      filtered.sort((a, b) => a.acidScore.compareTo(b.acidScore));
    } else if (_currentSort == "A-Z") {
      filtered
          .sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    }

    if (mounted) {
      setState(() {
        _displayedItems = filtered;
        _isLoading = false;
      });
    }
  }

  void _confirmDelete(int id, AppColors colors, AppLocalizations loc) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: colors.cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
            loc.loc('delete_message_q') != 'delete_message_q'
                ? loc.loc('delete_message_q')
                : 'Delete Item?',
            style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: colors.errorRed)),
        content: Text(
            'Are you sure you want to permanently delete this item from your pantry?',
            style: TextStyle(color: colors.textDark)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(loc.loc('cancel'),
                style: const TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: colors.errorRed,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10))),
            onPressed: () async {
              Navigator.pop(context);
              await _deleteItem(id);
              if (mounted) Navigator.pop(this.context);
            },
            child: Text(loc.loc('delete'),
                style: const TextStyle(
                    color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteItem(int id) async {
    await widget.dbService.deletePantryItem(id);
    _loadPantryItems();
  }

  Future<void> _toggleFavorite(int id, bool currentStatus) async {
    await widget.dbService.toggleFavorite(id, !currentStatus);
    _loadPantryItems();
  }

  Future<void> _consumeAgain(
      PantryItem originalItem, AppColors colors, AppLocalizations loc) async {
    final contextData = await ConsumptionModal.show(
        context, originalItem.name, originalItem.drinkCategory);

    if (contextData == null) return;

    double newTrueScore = RiskTranslator.calculateTrueAcidLoad(
        originalItem.acidScore.toDouble(),
        contextData['portionCount'],
        contextData['portionMeasurement']);

    // Generate a BRAND NEW entry in the DB so Insights can chart this specific consumption instance
    final newItem = PantryItem()
      ..name = originalItem.name
      ..dateScanned = DateTime.now()
      ..symptoms = ""
      ..riskLevel = originalItem.riskLevel
      ..isFavorite = originalItem.isFavorite
      ..rawText = originalItem.rawText
      ..acidScore = newTrueScore.round()
      ..imagePath = originalItem.imagePath
      ..isEmptyStomach = contextData['isEmptyStomach'] ?? false
      ..isDiluted = contextData['isDiluted'] ?? false
      ..isConsumed = true
      ..drinkCategory = originalItem.drinkCategory
      ..portionMeasurement = contextData['portionMeasurement']
      ..portionCount = contextData['portionCount'];

    await widget.dbService.savePantryItem(newItem);

    final notifService = NotificationService();

    notifService.scheduleTargetedNotification(
      id: NotificationService.digestionTimerId,
      title: loc.loc('digestion_complete_title'),
      body: loc.loc('digestion_complete_body', {'name': newItem.name}),
      delay: const Duration(hours: 6),
    );

    if (newItem.isEmptyStomach && !newItem.isDiluted) {
      notifService.scheduleTargetedNotification(
        id: NotificationService.hydrationChaserId,
        title: loc.loc('acid_buffer_reminder'),
        body: loc.loc('acid_buffer_body', {'name': newItem.name}),
        delay: const Duration(minutes: 15),
      );
    }

    if (newItem.riskLevel == "RED" || newItem.riskLevel == "YELLOW") {
      notifService.scheduleTargetedNotification(
        id: NotificationService.symptomCheckinId,
        title: loc.loc('symptom_checkin_title'),
        body: loc.loc('symptom_checkin_body', {'name': newItem.name}),
        delay: const Duration(minutes: 45),
      );
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content:
              Text(loc.loc('item_consumed_logged', {'name': newItem.name})),
          backgroundColor: colors.successGreen,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        ),
      );
    }

    _loadPantryItems();
  }

  Future<void> _editName(PantryItem item, StateSetter setModalState,
      AppColors colors, AppLocalizations loc) async {
    final TextEditingController nameController =
        TextEditingController(text: item.name);

    await showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Container(
          padding: const EdgeInsets.all(25),
          decoration: BoxDecoration(
              color: colors.cardColor, borderRadius: BorderRadius.circular(20)),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(loc.loc('rename_item'),
                  style: TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 18,
                      color: colors.primaryDark)),
              const SizedBox(height: 20),
              TextField(
                controller: nameController,
                style: TextStyle(color: colors.textDark),
                decoration: InputDecoration(
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(15)),
                  focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(15),
                      borderSide: BorderSide(color: colors.primary)),
                ),
              ),
              const SizedBox(height: 25),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                      backgroundColor: colors.primary,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(15))),
                  onPressed: () async {
                    item.name = nameController.text.isEmpty
                        ? loc.loc('unnamed')
                        : nameController.text;
                    await widget.dbService.savePantryItem(item);
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
      ),
    );

    setModalState(() {});
    _loadPantryItems();
  }

  Future<void> _updateImage(PantryItem item, StateSetter setModalState) async {
    try {
      final pickedFile = await _picker.pickImage(source: ImageSource.gallery);
      if (pickedFile == null) return;

      final directory = await getApplicationDocumentsDirectory();
      final String fileName =
          'sachet_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final String newPath = '${directory.path}/$fileName';

      final File savedImage = await File(pickedFile.path).copy(newPath);

      item.imagePath = savedImage.path;
      await widget.dbService.savePantryItem(item);

      setModalState(() {});
      _loadPantryItems();
    } catch (e) {
      debugPrint("Error updating image: $e");
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

  void _showEditSymptomModal(PantryItem item, StateSetter setParentModalState,
      AppColors colors, AppLocalizations loc) {
    String tempSymptom = item.symptoms.isEmpty ? "None" : item.symptoms;
    int tempSeverity = 0;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(builder: (context, setInnerState) {
        List<Map<String, dynamic>> symptomMatrix = [
          {"name": "Heartburn", "title": loc.loc('symp_heartburn')},
          {
            "name": "Acid Regurgitation",
            "title": loc.loc('symp_acid_regurgitation')
          },
          {"name": "Dyspepsia", "title": loc.loc('symp_dyspepsia')},
          {
            "name": "Globus Sensation",
            "title": loc.loc('symp_globus_sensation')
          },
          {"name": "Nausea", "title": loc.loc('symp_nausea')},
          {
            "name": "Excessive Burping",
            "title": loc.loc('symp_excessive_burping')
          },
          {"name": "Bloating", "title": loc.loc('symp_bloating')},
          {"name": "Cramps", "title": loc.loc('symp_cramps')},
          {"name": "Chest Pain", "title": loc.loc('symp_chest_pain')},
          {"name": "Acidic Taste", "title": loc.loc('symp_acidic_taste')},
          {"name": "Sore Throat", "title": loc.loc('symp_sore_throat')},
          {"name": "Dry Cough", "title": loc.loc('symp_dry_cough')},
          {"name": "None", "title": loc.loc('symp_none')},
        ];

        return Container(
          height: MediaQuery.of(context).size.height * 0.85,
          padding: const EdgeInsets.all(25),
          decoration: BoxDecoration(
            color: colors.background,
            borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(30), topRight: Radius.circular(30)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                  child: Container(
                      width: 50,
                      height: 5,
                      decoration: BoxDecoration(
                          color: Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(10)))),
              const SizedBox(height: 25),
              Text(loc.loc('log_clinical_symptom'),
                  style: TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 24,
                      color: colors.primaryDark)),
              const SizedBox(height: 5),
              Text(loc.loc('log_symptom_desc'),
                  style: TextStyle(
                      fontSize: 12, color: colors.textGrey, height: 1.4)),
              const SizedBox(height: 20),
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: symptomMatrix.map((symp) {
                          bool isSelected = tempSymptom == symp['name'];
                          return ChoiceChip(
                            label: Text(symp['title']),
                            selected: isSelected,
                            selectedColor: colors.primary,
                            backgroundColor: colors.cardColor,
                            labelStyle: TextStyle(
                              color:
                                  isSelected ? Colors.white : colors.textDark,
                              fontWeight: isSelected
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                            ),
                            onSelected: (selected) {
                              HapticFeedback.lightImpact();
                              setInnerState(() => tempSymptom = symp['name']);
                            },
                          );
                        }).toList(),
                      ),
                      if (tempSymptom != "None" && tempSymptom.isNotEmpty) ...[
                        const SizedBox(height: 30),
                        Text(loc.loc('severity_scale_q'),
                            style: TextStyle(
                                fontWeight: FontWeight.w900,
                                color: colors.textDark)),
                        Row(children: [
                          Expanded(
                              child: Slider(
                                  value: tempSeverity.toDouble(),
                                  min: 0,
                                  max: 10,
                                  divisions: 10,
                                  activeColor: colors.primary,
                                  onChanged: (val) => setInnerState(
                                      () => tempSeverity = val.toInt()))),
                          Text('$tempSeverity',
                              style: TextStyle(
                                  fontWeight: FontWeight.w900,
                                  fontSize: 18,
                                  color: colors.primary))
                        ])
                      ]
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 15),
              SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                      backgroundColor: colors.primary,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20))),
                  onPressed: () async {
                    item.symptoms = tempSymptom;
                    await widget.dbService.savePantryItem(item);

                    if (item.symptoms.isNotEmpty && item.symptoms != "None") {
                      NotificationService().cancelNotification(
                          NotificationService.symptomCheckinId);
                    }

                    setParentModalState(() {});
                    _loadPantryItems();
                    Navigator.pop(context);

                    if (tempSeverity >= 8) {
                      Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (context) => CoachScreen(
                                  dbService: widget.dbService,
                                  entryMode: 'scanner',
                                  activeSymptom: item.symptoms,
                                  symptomSeverity: tempSeverity,
                                  scannedProduct: item.name,
                                  dynamicContextData:
                                      "Pantry Item. Risk: ${item.riskLevel}",
                                  drinkCategory: item.drinkCategory,
                                  portionMeasurement: item.portionMeasurement,
                                  portionCount: item.portionCount)));
                    }
                  },
                  child: Text(loc.loc('save_biological_log'),
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16)),
                ),
              )
            ],
          ),
        );
      }),
    );
  }

  Color _getRiskColor(String riskLevel, AppColors colors) {
    if (riskLevel.toUpperCase().contains('RED') ||
        riskLevel.toUpperCase().contains('HIGH')) return colors.errorRed;
    if (riskLevel.toUpperCase().contains('YELLOW') ||
        riskLevel.toUpperCase().contains('MODERATE') ||
        riskLevel.toUpperCase().contains('MEDIUM')) {
      return colors.accentOrange;
    }
    return colors.successGreen;
  }

  Future<ScanResult> _getHistoricalAnalysis(String rawText) async {
    final triggers = await widget.dbService.getAllTriggers();
    final profile = await widget.dbService.getUserProfile();
    return KeywordMappingAlgorithm.analyze(rawText, triggers, profile, 0.0, []);
  }

  Widget _buildPantryClinicalUI(String summary) {
    if (summary.contains("No known stomach triggers") ||
        summary.contains("Great news")) {
      return Text(summary,
          style: const TextStyle(
              color: Colors.greenAccent,
              fontSize: 12,
              fontWeight: FontWeight.bold));
    }

    List<String> parts = summary.split('\n\n');

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
              child:
                  Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
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
                            height: 1.4))),
              ]));
        } else if (part.startsWith('Clinical Analysis:')) {
          return Text(part,
              style: const TextStyle(
                  color: Colors.white,
                  height: 1.5,
                  fontSize: 12,
                  fontWeight: FontWeight.w800));
        } else {
          return Container(
              margin: const EdgeInsets.only(top: 10),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10)),
              child: Text(part,
                  style: const TextStyle(
                      color: Colors.white70,
                      fontStyle: FontStyle.italic,
                      fontSize: 11,
                      fontWeight: FontWeight.bold)));
        }
      }).toList(),
    );
  }

  void _showItemDetails(
      PantryItem item, AppColors colors, AppLocalizations loc) {
    final TextEditingController ocrController =
        TextEditingController(text: item.rawText);
    bool isRecalibrating = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(builder: (context, setModalState) {
        bool hasSymptom = item.symptoms.isNotEmpty && item.symptoms != "None";

        double impactPercentage = (item.acidScore / _dailyMaxLoad) * 100;
        if (impactPercentage > 100) impactPercentage = 100;
        if (impactPercentage.isNaN || impactPercentage.isInfinite) {
          impactPercentage = 0;
        }

        return Container(
          height: MediaQuery.of(context).size.height * 0.90,
          decoration: BoxDecoration(
            color: colors.background,
            borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(30), topRight: Radius.circular(30)),
          ),
          child: Column(
            children: [
              const SizedBox(height: 15),
              Container(
                  width: 50,
                  height: 5,
                  decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(10))),
              const SizedBox(height: 20),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 25),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // IMAGE SECTION
                      Center(
                        child: GestureDetector(
                          onTap: () => _updateImage(item, setModalState),
                          child: Stack(
                            alignment: Alignment.bottomRight,
                            children: [
                              Container(
                                width: 150,
                                height: 150,
                                decoration: BoxDecoration(
                                  color: colors.cardColor,
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                      color: colors.isDark
                                          ? Colors.white12
                                          : Colors.grey.shade300),
                                  image: item.imagePath != null
                                      ? DecorationImage(
                                          image:
                                              FileImage(File(item.imagePath!)),
                                          fit: BoxFit.cover)
                                      : null,
                                ),
                                child: item.imagePath == null
                                    ? Center(
                                        child: Image.asset(
                                            'assets/images/triggerlens_icon.png',
                                            width: 60,
                                            color: colors.isDark
                                                ? Colors.white24
                                                : Colors.grey.shade300))
                                    : null,
                              ),
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                    color: colors.primary,
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                        color: Colors.white, width: 3)),
                                child: const Icon(Icons.camera_alt,
                                    color: Colors.white, size: 20),
                              )
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 25),

                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: GestureDetector(
                              onTap: () =>
                                  _editName(item, setModalState, colors, loc),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      item.name,
                                      style: TextStyle(
                                          fontSize: 28,
                                          fontWeight: FontWeight.w900,
                                          color: colors.primaryDark),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Icon(Icons.edit,
                                      color: colors.primaryDark, size: 20),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 5),
                      Text(
                          '${loc.loc('category_label')} ${loc.loc(item.drinkCategory.toLowerCase().replaceAll(' ', '_'))}',
                          style: TextStyle(
                              color: colors.primary,
                              fontWeight: FontWeight.bold)),
                      const SizedBox(height: 5),
                      Text(
                          loc.loc('logged_on', {
                            'date': DateFormat('MMMM dd, yyyy - h:mm a')
                                .format(item.dateScanned)
                          }),
                          style: TextStyle(
                              color: colors.textGrey,
                              fontSize: 12,
                              fontWeight: FontWeight.bold)),
                      const SizedBox(height: 20),

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
                                                      color:
                                                          colors.primaryDark)),
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
                                              color: _getRiskColor(
                                                      item.riskLevel, colors)
                                                  .withOpacity(0.1),
                                              borderRadius:
                                                  BorderRadius.circular(10)),
                                          child: Text(
                                              item.riskLevel
                                                      .toUpperCase()
                                                      .contains('YELLOW')
                                                  ? 'MODERATE'
                                                  : item.riskLevel
                                                      .toUpperCase(),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: TextStyle(
                                                  color: _getRiskColor(
                                                      item.riskLevel, colors),
                                                  fontWeight: FontWeight.w900,
                                                  fontSize: 10)))
                                    ]),
                                const SizedBox(height: 15),
                                Row(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text(item.acidScore.toStringAsFixed(1),
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
                                    RiskTranslator.getHumanizedScoreDescription(
                                        item.acidScore.toDouble(), loc),
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
                                Row(children: [
                                  Icon(Icons.scale,
                                      color: Colors.grey.shade400, size: 16),
                                  const SizedBox(width: 8),
                                  Text(
                                      loc.loc('portion_label', {
                                        'count': item.portionCount.toString(),
                                        'measure': item.portionMeasurement
                                      }),
                                      style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12,
                                          color: colors.textDark)),
                                ]),
                                const SizedBox(height: 8),
                                Row(children: [
                                  Icon(
                                      item.isEmptyStomach
                                          ? Icons.warning_amber_rounded
                                          : Icons.restaurant,
                                      color: Colors.grey.shade400,
                                      size: 16),
                                  const SizedBox(width: 8),
                                  Text(
                                      item.isEmptyStomach
                                          ? loc.loc('consumed_empty_stomach')
                                          : loc.loc('consumed_with_food'),
                                      style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12,
                                          color: colors.textDark)),
                                ]),
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
                                                      color: colors.textDark)),
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
                                      value: item.acidScore / _dailyMaxLoad,
                                      minHeight: 8,
                                      backgroundColor: colors.isDark
                                          ? Colors.white12
                                          : Colors.grey.shade200,
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                          _getRiskColor(
                                              item.riskLevel, colors)),
                                    )),
                                const SizedBox(height: 10),
                                Text(
                                    RiskTranslator.getDashboardImpactText(
                                        item.acidScore.toDouble(),
                                        _userProfile,
                                        loc),
                                    style: TextStyle(
                                        fontSize: 11,
                                        color: colors.textDark,
                                        fontWeight: FontWeight.w500)),
                              ])),
                      const SizedBox(height: 25),

                      if (item.isConsumed) ...[
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(loc.loc('clinical_symptoms'),
                                style: TextStyle(
                                    fontWeight: FontWeight.w900,
                                    fontSize: 16,
                                    color: colors.textDark)),
                            if (!hasSymptom)
                              GestureDetector(
                                onTap: () => _showEditSymptomModal(
                                    item, setModalState, colors, loc),
                                child: Icon(Icons.edit,
                                    color: colors.primaryDark, size: 20),
                              )
                          ],
                        ),
                        const SizedBox(height: 10),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(15),
                          decoration: BoxDecoration(
                              color: hasSymptom
                                  ? (colors.isDark
                                      ? Colors.orange.shade900.withOpacity(0.3)
                                      : Colors.orange.shade50)
                                  : (colors.isDark
                                      ? Colors.green.shade900.withOpacity(0.3)
                                      : Colors.green.shade50),
                              borderRadius: BorderRadius.circular(20)),
                          child: Row(
                            children: [
                              Icon(
                                  hasSymptom
                                      ? Icons.local_fire_department
                                      : Icons.check_circle_outline,
                                  color: hasSymptom
                                      ? Colors.orange
                                      : Colors.green),
                              const SizedBox(width: 15),
                              Expanded(
                                child: Text(
                                    hasSymptom
                                        ? loc.loc(
                                            'symp_${item.symptoms.toLowerCase().replaceAll(' ', '_')}')
                                        : loc.loc('no_symptoms_logged'),
                                    style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: hasSymptom
                                            ? (colors.isDark
                                                ? Colors.orange.shade200
                                                : Colors.deepOrange)
                                            : (colors.isDark
                                                ? Colors.green.shade300
                                                : Colors.green.shade700))),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 35),
                      ] else ...[
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                              color: colors.isDark
                                  ? Colors.blue.shade900.withOpacity(0.3)
                                  : Colors.blue.shade50,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                  color: colors.isDark
                                      ? Colors.blue.shade900
                                      : Colors.blue.shade100)),
                          child: Row(
                            children: [
                              Icon(Icons.info_outline,
                                  color: colors.isDark
                                      ? Colors.blue.shade200
                                      : Colors.blue),
                              const SizedBox(width: 15),
                              Expanded(
                                child: Text(
                                  loc.loc('pantry_saved_info'),
                                  style: TextStyle(
                                      color: colors.isDark
                                          ? Colors.blue.shade100
                                          : Colors.blue.shade900,
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      height: 1.4),
                                ),
                              )
                            ],
                          ),
                        ),
                        const SizedBox(height: 35),
                      ],

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
                                        loc.loc('potential_clinical_irritants'),
                                        style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 16,
                                            fontWeight: FontWeight.w900)),
                                  ),
                                  GestureDetector(
                                    onTap: () => _showInfoModal(
                                        loc.loc('potential_clinical_irritants'),
                                        "Chemical triggers isolated from the ingredients label that may cause reflux synergy.",
                                        colors),
                                    child: const Icon(Icons.info_outline,
                                        color: Colors.white70, size: 16),
                                  ),
                                ]),
                                const SizedBox(height: 15),
                                FutureBuilder<ScanResult>(
                                  future: _getHistoricalAnalysis(item.rawText),
                                  builder: (context, snapshot) {
                                    if (snapshot.connectionState ==
                                        ConnectionState.waiting) {
                                      return const Center(
                                          child: Padding(
                                              padding: EdgeInsets.all(20),
                                              child: CircularProgressIndicator(
                                                  color: Colors.white)));
                                    }
                                    if (!snapshot.hasData) {
                                      return const SizedBox();
                                    }
                                    return _buildPantryClinicalUI(
                                        snapshot.data!.triggersSummary);
                                  },
                                ),
                              ])),
                      const SizedBox(height: 25),

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
                                  controller: ocrController,
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
                                    icon: isRecalibrating
                                        ? const SizedBox(
                                            width: 16,
                                            height: 16,
                                            child: CircularProgressIndicator(
                                                color: Colors.white,
                                                strokeWidth: 2))
                                        : const Icon(Icons.sync, size: 18),
                                    label: Text(
                                      isRecalibrating
                                          ? loc.loc('recalibrating')
                                          : loc.loc('recalibrate_analysis'),
                                      style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13),
                                    ),
                                    onPressed: isRecalibrating
                                        ? null
                                        : () async {
                                            setModalState(
                                                () => isRecalibrating = true);
                                            FocusScope.of(context).unfocus();

                                            await Future.delayed(const Duration(
                                                milliseconds: 400));

                                            String newText = ocrController
                                                    .text.isEmpty
                                                ? loc.loc('no_text_provided')
                                                : ocrController.text;

                                            final triggers = await widget
                                                .dbService
                                                .getAllTriggers();
                                            final userProfile = await widget
                                                .dbService
                                                .getUserProfile();

                                            var result =
                                                KeywordMappingAlgorithm.analyze(
                                                    newText,
                                                    triggers,
                                                    userProfile,
                                                    0.0, []);

                                            double finalStoredScore =
                                                result.finalRiskScore;
                                            if (item.isConsumed) {
                                              finalStoredScore = RiskTranslator
                                                  .calculateTrueAcidLoad(
                                                      result.finalRiskScore,
                                                      item.portionCount,
                                                      item.portionMeasurement);
                                            }

                                            item.rawText = newText;
                                            item.riskLevel = result.riskLevel;
                                            item.acidScore =
                                                finalStoredScore.round();
                                            item.drinkCategory =
                                                result.drinkCategory;

                                            await widget.dbService
                                                .savePantryItem(item);

                                            setModalState(
                                                () => isRecalibrating = false);
                                            _loadPantryItems();

                                            if (mounted) {
                                              ScaffoldMessenger.of(context)
                                                  .showSnackBar(SnackBar(
                                                content: Text(
                                                    loc.loc(
                                                        'pantry_item_recalibrated'),
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
                      Row(
                        children: [
                          Expanded(
                            child: SizedBox(
                              height: 55,
                              child: OutlinedButton.icon(
                                  style: OutlinedButton.styleFrom(
                                      foregroundColor: colors.errorRed,
                                      side: BorderSide(
                                          color: colors.errorRed, width: 2),
                                      shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(20))),
                                  icon: const Icon(Icons.delete_outline),
                                  label: Text(loc.loc('delete'),
                                      style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16)),
                                  onPressed: () {
                                    _confirmDelete(item.id, colors, loc);
                                  }),
                            ),
                          ),
                          const SizedBox(width: 15),
                          if (!item.isConsumed)
                            Expanded(
                              child: SizedBox(
                                height: 55,
                                child: ElevatedButton.icon(
                                    style: ElevatedButton.styleFrom(
                                        backgroundColor: colors.primary,
                                        shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(20))),
                                    icon: const Icon(Icons.add_task,
                                        color: Colors.white),
                                    label: Text(loc.loc('consume_btn'),
                                        style: const TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 16)),
                                    onPressed: () {
                                      Navigator.pop(context);
                                      _consumeAgain(item, colors, loc);
                                    }),
                              ),
                            )
                          else
                            Expanded(
                              child: SizedBox(
                                height: 55,
                                child: ElevatedButton.icon(
                                    style: ElevatedButton.styleFrom(
                                        backgroundColor: colors.primary,
                                        shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(20))),
                                    icon: const Icon(Icons.refresh,
                                        color: Colors.white),
                                    label: Text(loc.loc('drink_again'),
                                        style: const TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 16)),
                                    onPressed: () {
                                      Navigator.pop(context);
                                      _consumeAgain(item, colors, loc);
                                    }),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 15),
                      if (item.isConsumed)
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
                              label: Text(loc.loc('tummy_buddy'),
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w900,
                                      fontSize: 16)),
                              onPressed: () {
                                Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                        builder: (context) => CoachScreen(
                                            dbService: widget.dbService,
                                            entryMode: 'scanner',
                                            activeSymptom: hasSymptom
                                                ? item.symptoms
                                                : null,
                                            symptomSeverity: 5,
                                            scannedProduct: item.name,
                                            dynamicContextData:
                                                "Pantry Item. Risk: ${item.riskLevel}",
                                            drinkCategory: item.drinkCategory,
                                            portionMeasurement:
                                                item.portionMeasurement,
                                            portionCount: item.portionCount)));
                              }),
                        ),
                      const SizedBox(height: 40),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      }),
    );
  }

  Widget _buildFilterChip(
      String label, String value, AppColors colors, AppLocalizations loc,
      [IconData? icon, Color? iconColor]) {
    bool isSelected = _selectedFilter == value;
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        setState(() => _selectedFilter = value);
        _applyFilters();
      },
      child: Container(
        margin: const EdgeInsets.only(right: 10),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? colors.primaryDark : colors.cardColor,
          border: Border.all(
              color: isSelected
                  ? colors.primaryDark
                  : (colors.isDark ? Colors.white24 : Colors.grey.shade300)),
          borderRadius: BorderRadius.circular(15),
        ),
        child: Row(
          children: [
            if (icon != null) ...[
              Icon(icon,
                  size: 16, color: isSelected ? Colors.white : iconColor),
              const SizedBox(width: 6)
            ],
            Text(label,
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 11,
                    color: isSelected ? Colors.white : colors.textDark)),
          ],
        ),
      ),
    );
  }

  // FIXED: Sorter Dropdown mapping logic
  String _getDropdownKey(String value) {
    if (value == "Newest") return 'sort_newest';
    if (value == "Oldest") return 'sort_oldest';
    if (value == "Highest Risk") return 'sort_highest_risk';
    if (value == "Lowest Risk") return 'sort_lowest_risk';
    if (value == "A-Z") return 'sort_a_z';
    return value;
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final loc = AppLocalizations.of(context);

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Image.asset('assets/images/back_1.png',
              width: 24, color: colors.primaryDark),
          onPressed: () {
            if (Navigator.canPop(context)) {
              Navigator.pop(context);
            } else {
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(
                  builder: (context) => MainLayoutScreen(
                    dbService: widget.dbService,
                    initialIndex: 0,
                  ),
                ),
                (route) => false,
              );
            }
          },
        ),
      ),
      body: SafeArea(
        child: RefreshIndicator(
          color: colors.primary,
          backgroundColor: colors.cardColor,
          onRefresh: _loadPantryItems,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 25.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(loc.loc('digital_pantry'),
                    style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.w900,
                        color: colors.primaryDark)),
                const SizedBox(height: 15),
                TextField(
                  controller: _searchController,
                  style: TextStyle(color: colors.textDark),
                  onChanged: (value) {
                    _searchQuery = value;
                    _applyFilters();
                  },
                  decoration: InputDecoration(
                    hintText: loc.loc('search_inventory'),
                    hintStyle: TextStyle(color: colors.textGrey),
                    prefixIcon: Icon(Icons.search, color: colors.textGrey),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: Icon(Icons.clear, color: colors.textGrey),
                            onPressed: () {
                              _searchController.clear();
                              _searchQuery = "";
                              _applyFilters();
                            })
                        : null,
                    filled: true,
                    fillColor: colors.cardColor,
                    contentPadding: const EdgeInsets.symmetric(vertical: 0),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(20),
                        borderSide: BorderSide.none),
                  ),
                ),
                const SizedBox(height: 15),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(loc.loc('filters'), // FIXED: Localized Label
                        style: TextStyle(
                            fontWeight: FontWeight.w900,
                            color: colors.textDark)),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 2),
                      decoration: BoxDecoration(
                          color: colors.cardColor,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                              color: colors.isDark
                                  ? Colors.white12
                                  : Colors.grey.shade200)),
                      child: Row(
                        children: [
                          Icon(Icons.sort, color: colors.primaryDark, size: 16),
                          const SizedBox(width: 5),
                          DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              value: _currentSort,
                              dropdownColor: colors.cardColor,
                              style: TextStyle(
                                  color: colors.textDark,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 11),
                              icon: const Icon(Icons.arrow_drop_down,
                                  color: Colors.grey),
                              items: [
                                "Newest",
                                "Oldest",
                                "Highest Risk",
                                "Lowest Risk",
                                "A-Z"
                              ].map((String value) {
                                return DropdownMenuItem<String>(
                                  value: value,
                                  child: Text(loc.loc(_getDropdownKey(
                                      value))), // FIXED: Localized Dropdown Elements
                                );
                              }).toList(),
                              onChanged: (newValue) {
                                if (newValue != null) {
                                  HapticFeedback.lightImpact();
                                  setState(() => _currentSort = newValue);
                                  _applyFilters();
                                }
                              },
                            ),
                          ),
                        ],
                      ),
                    )
                  ],
                ),
                const SizedBox(height: 10),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      // FIXED: Passing translated labels but keeping internal logic intact
                      _buildFilterChip(loc.loc('all'), "All", colors, loc),
                      _buildFilterChip(loc.loc('favorites'), "Favorites",
                          colors, loc, Icons.favorite, Colors.redAccent),
                      _buildFilterChip(loc.loc('safe'), "Safe", colors, loc,
                          Icons.circle, Colors.green),
                      _buildFilterChip(loc.loc('med'), "Moderate", colors, loc,
                          Icons.circle, colors.accentOrange),
                      _buildFilterChip(loc.loc('high'), "High", colors, loc,
                          Icons.circle, colors.errorRed),
                    ],
                  ),
                ),
                const SizedBox(height: 25),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                        color: colors.primaryLight.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(30)),
                    child: _isLoading
                        ? Center(
                            child: CircularProgressIndicator(
                                color: colors.primary))
                        : _displayedItems.isEmpty
                            // FIXED: Added SingleChildScrollView to gracefully squish when search keyboard pops up
                            ? Center(
                                child: SingleChildScrollView(
                                  physics: const BouncingScrollPhysics(),
                                  child: Padding(
                                    padding: const EdgeInsets.all(20.0),
                                    child: Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.all(20),
                                          decoration: BoxDecoration(
                                              color: colors.cardColor,
                                              shape: BoxShape.circle,
                                              boxShadow: [
                                                BoxShadow(
                                                    color: Colors.black
                                                        .withOpacity(0.05),
                                                    blurRadius: 10)
                                              ]),
                                          child: Icon(Icons.kitchen_outlined,
                                              size: 60,
                                              color: colors.primaryLight),
                                        ),
                                        const SizedBox(height: 20),
                                        Text(loc.loc('pantry_empty_title'),
                                            textAlign: TextAlign.center,
                                            style: TextStyle(
                                                fontSize: 20,
                                                fontWeight: FontWeight.bold,
                                                color: colors.primaryDark)),
                                        const SizedBox(height: 10),
                                        Text(loc.loc('pantry_empty_desc'),
                                            textAlign: TextAlign.center,
                                            style: TextStyle(
                                                color: colors.textGrey,
                                                height: 1.5)),
                                      ],
                                    ),
                                  ),
                                ),
                              )
                            : ListView.builder(
                                physics: const AlwaysScrollableScrollPhysics(
                                    parent: BouncingScrollPhysics()),
                                itemCount: _displayedItems.length,
                                itemBuilder: (context, index) {
                                  final item = _displayedItems[index];

                                  bool exceedsCapacity =
                                      (_currentStomachLoad + item.acidScore) >
                                          _dailyMaxLoad;
                                  bool hasSymptomMemory =
                                      item.symptoms != "None" &&
                                          item.symptoms.isNotEmpty;

                                  Color riskColor =
                                      _getRiskColor(item.riskLevel, colors);

                                  return GestureDetector(
                                    onTap: () =>
                                        _showItemDetails(item, colors, loc),
                                    child: Container(
                                      margin: const EdgeInsets.only(bottom: 15),
                                      padding: const EdgeInsets.all(15),
                                      decoration: BoxDecoration(
                                          color: colors.cardColor,
                                          borderRadius:
                                              BorderRadius.circular(20),
                                          boxShadow: [
                                            BoxShadow(
                                                color: Colors.black
                                                    .withOpacity(0.05),
                                                blurRadius: 10,
                                                offset: const Offset(0, 5))
                                          ]),
                                      child: Column(
                                        children: [
                                          Row(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Container(
                                                width: 70,
                                                height: 70,
                                                decoration: BoxDecoration(
                                                    color: colors.cardColor,
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            15),
                                                    border: Border.all(
                                                        color: colors.isDark
                                                            ? Colors.white12
                                                            : Colors.grey
                                                                .shade200)),
                                                child: ClipRRect(
                                                  borderRadius:
                                                      BorderRadius.circular(15),
                                                  child: item.imagePath != null
                                                      ? Image.file(
                                                          File(item.imagePath!),
                                                          fit: BoxFit.cover)
                                                      : Padding(
                                                          padding:
                                                              const EdgeInsets
                                                                  .all(15.0),
                                                          child: Image.asset(
                                                              'assets/images/triggerlens_icon.png',
                                                              color: colors.isDark
                                                                  ? Colors
                                                                      .white24
                                                                  : Colors.grey
                                                                      .shade300)),
                                                ),
                                              ),
                                              const SizedBox(width: 15),
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    Row(
                                                      mainAxisAlignment:
                                                          MainAxisAlignment
                                                              .spaceBetween,
                                                      children: [
                                                        Expanded(
                                                            child: Text(
                                                                item.name,
                                                                overflow:
                                                                    TextOverflow
                                                                        .ellipsis,
                                                                style: TextStyle(
                                                                    fontSize:
                                                                        18,
                                                                    fontWeight:
                                                                        FontWeight
                                                                            .w900,
                                                                    color: colors
                                                                        .primaryDark))),
                                                        GestureDetector(
                                                          onTap: () {
                                                            HapticFeedback
                                                                .lightImpact();
                                                            _toggleFavorite(
                                                                item.id,
                                                                item.isFavorite);
                                                          },
                                                          child: Icon(
                                                              item.isFavorite
                                                                  ? Icons
                                                                      .favorite
                                                                  : Icons
                                                                      .favorite_border,
                                                              color: item
                                                                      .isFavorite
                                                                  ? Colors.red
                                                                  : colors
                                                                      .primaryDark,
                                                              size: 24),
                                                        ),
                                                      ],
                                                    ),
                                                    if (hasSymptomMemory) ...[
                                                      const SizedBox(height: 5),
                                                      Container(
                                                        padding:
                                                            const EdgeInsets
                                                                .symmetric(
                                                                horizontal: 8,
                                                                vertical: 3),
                                                        decoration: BoxDecoration(
                                                            color: colors.isDark
                                                                ? Colors.red
                                                                    .shade900
                                                                    .withOpacity(
                                                                        0.3)
                                                                : Colors.red
                                                                    .shade50,
                                                            borderRadius:
                                                                BorderRadius
                                                                    .circular(
                                                                        8),
                                                            border: Border.all(
                                                                color: colors
                                                                        .isDark
                                                                    ? Colors.red
                                                                        .shade900
                                                                    : Colors.red
                                                                        .shade100)),
                                                        child: Text(
                                                            '🔥 ${loc.loc('symp_${item.symptoms.toLowerCase().replaceAll(' ', '_')}')}',
                                                            style: TextStyle(
                                                                fontSize: 10,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .bold,
                                                                color: colors.isDark
                                                                    ? Colors.red
                                                                        .shade200
                                                                    : Colors.red
                                                                        .shade700)),
                                                      ),
                                                    ],
                                                    const SizedBox(height: 12),
                                                    Row(
                                                      crossAxisAlignment:
                                                          CrossAxisAlignment
                                                              .center,
                                                      children: [
                                                        Expanded(
                                                          child: Wrap(
                                                            spacing: 6,
                                                            runSpacing: 6,
                                                            children: [
                                                              Container(
                                                                padding: const EdgeInsets
                                                                    .symmetric(
                                                                    horizontal:
                                                                        10,
                                                                    vertical:
                                                                        4),
                                                                decoration: BoxDecoration(
                                                                    color: colors
                                                                        .cardColor,
                                                                    borderRadius:
                                                                        BorderRadius.circular(
                                                                            20),
                                                                    border: Border.all(
                                                                        color: colors.isDark
                                                                            ? Colors.white12
                                                                            : Colors.grey.shade200)),
                                                                child: Text(
                                                                    item.riskLevel.toUpperCase().contains(
                                                                            'RED')
                                                                        ? 'HIGH'
                                                                        : (item.riskLevel.toUpperCase().contains('YELLOW')
                                                                            ? 'MODERATE'
                                                                            : 'SAFE'),
                                                                    style: TextStyle(
                                                                        fontSize:
                                                                            10,
                                                                        fontWeight:
                                                                            FontWeight
                                                                                .w900,
                                                                        color:
                                                                            riskColor)),
                                                              ),
                                                              if (!item
                                                                  .isConsumed)
                                                                Container(
                                                                  padding: const EdgeInsets
                                                                      .symmetric(
                                                                      horizontal:
                                                                          10,
                                                                      vertical:
                                                                          4),
                                                                  decoration: BoxDecoration(
                                                                      color: colors
                                                                              .isDark
                                                                          ? Colors
                                                                              .blue
                                                                              .shade900
                                                                              .withOpacity(
                                                                                  0.3)
                                                                          : Colors
                                                                              .blue
                                                                              .shade50,
                                                                      borderRadius:
                                                                          BorderRadius.circular(
                                                                              20),
                                                                      border: Border.all(
                                                                          color: colors.isDark
                                                                              ? Colors.blue.shade900
                                                                              : Colors.blue.shade200)),
                                                                  child: Text(
                                                                      loc.loc(
                                                                          'saved_only'),
                                                                      style: TextStyle(
                                                                          fontSize:
                                                                              9,
                                                                          fontWeight: FontWeight
                                                                              .bold,
                                                                          color: colors.isDark
                                                                              ? Colors.blue.shade100
                                                                              : Colors.blue.shade900)),
                                                                )
                                                            ],
                                                          ),
                                                        ),
                                                        const SizedBox(
                                                            width: 10),
                                                        GestureDetector(
                                                          onTap: () {
                                                            HapticFeedback
                                                                .selectionClick();
                                                            _consumeAgain(item,
                                                                colors, loc);
                                                          },
                                                          child: Container(
                                                            padding:
                                                                const EdgeInsets
                                                                    .symmetric(
                                                                    horizontal:
                                                                        12,
                                                                    vertical:
                                                                        6),
                                                            decoration: BoxDecoration(
                                                                color: colors
                                                                    .primaryLight
                                                                    .withOpacity(
                                                                        0.1),
                                                                borderRadius:
                                                                    BorderRadius
                                                                        .circular(
                                                                            15)),
                                                            child: Row(
                                                              children: [
                                                                Icon(Icons.add,
                                                                    size: 14,
                                                                    color: colors
                                                                        .primaryDark),
                                                                const SizedBox(
                                                                    width: 4),
                                                                Text(
                                                                    loc.loc(
                                                                        'consume_btn'),
                                                                    style: TextStyle(
                                                                        fontSize:
                                                                            11,
                                                                        fontWeight:
                                                                            FontWeight
                                                                                .bold,
                                                                        color: colors
                                                                            .primaryDark)),
                                                              ],
                                                            ),
                                                          ),
                                                        )
                                                      ],
                                                    )
                                                  ],
                                                ),
                                              ),
                                            ],
                                          ),
                                          if (exceedsCapacity) ...[
                                            const SizedBox(height: 12),
                                            Container(
                                              width: double.infinity,
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      vertical: 8,
                                                      horizontal: 12),
                                              decoration: BoxDecoration(
                                                  color: colors.isDark
                                                      ? Colors.amber.shade900
                                                          .withOpacity(0.3)
                                                      : Colors.amber.shade100,
                                                  borderRadius:
                                                      BorderRadius.circular(
                                                          10)),
                                              child: Row(
                                                children: [
                                                  Icon(
                                                      Icons
                                                          .warning_amber_rounded,
                                                      color: colors.isDark
                                                          ? Colors
                                                              .amber.shade200
                                                          : Colors
                                                              .amber.shade900,
                                                      size: 16),
                                                  const SizedBox(width: 8),
                                                  Expanded(
                                                    child: Text(
                                                        loc.loc(
                                                            'exceeds_daily_cap'),
                                                        style: TextStyle(
                                                            fontSize: 11,
                                                            fontWeight:
                                                                FontWeight.bold,
                                                            color: colors.isDark
                                                                ? Colors.amber
                                                                    .shade200
                                                                : Colors.amber
                                                                    .shade900)),
                                                  ),
                                                ],
                                              ),
                                            )
                                          ],
                                        ],
                                      ),
                                    ),
                                  );
                                }),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
