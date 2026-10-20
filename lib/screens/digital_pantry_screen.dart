import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import '../services/database_service.dart';
import '../services/notification_service.dart';
import '../models/pantry_item.dart';
import '../utils/ui_helpers.dart';
import '../utils/risk_calculator.dart'; // NEW: Imported Risk Calculator
import '../widgets/consumption_modal.dart';

class DigitalPantryScreen extends StatefulWidget {
  final DatabaseService dbService;
  const DigitalPantryScreen({super.key, required this.dbService});

  @override
  State<DigitalPantryScreen> createState() => _DigitalPantryScreenState();
}

class _DigitalPantryScreenState extends State<DigitalPantryScreen> {
  // NEW STATE VARIABLES FOR INVENTORY UPGRADE
  List<PantryItem> _allGroupedItems = [];
  List<PantryItem> _displayedItems = [];
  bool _isLoading = true;

  String _searchQuery = "";
  String _selectedFilter = "All"; // Options: All, Favorites, Safe, Med, High
  final TextEditingController _searchController = TextEditingController();

  final ImagePicker _picker = ImagePicker();

  // MOCK STOMACH LOAD: Hook this up to your actual RiskCalculator or State Management
  final double _currentStomachLoad = 12.0;
  final double _dailyMaxLoad = 15.0;

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

  // ==========================================
  // SURGICALLY UPDATED: Grouping & Symptom Memory
  // ==========================================
  Future<void> _loadPantryItems() async {
    setState(() => _isLoading = true);
    var allLogs = await widget.dbService.getPantryItems();

    // 1. Sort newest first
    allLogs.sort((a, b) => b.dateScanned.compareTo(a.dateScanned));

    Map<String, PantryItem> uniqueItemsMap = {};
    Map<String, String> symptomMemory = {};

    for (var item in allLogs) {
      String normalizedName = item.name.trim().toLowerCase();

      // 2. Track Symptom Memory: If this item EVER caused a symptom, remember it
      if (item.symptoms.isNotEmpty && item.symptoms != "None") {
        if (!symptomMemory.containsKey(normalizedName)) {
          symptomMemory[normalizedName] = item.symptoms;
        }
      }

      // 3. Keep only the most recent version of the item for the inventory
      if (!uniqueItemsMap.containsKey(normalizedName)) {
        uniqueItemsMap[normalizedName] = item;
      }
    }

    List<PantryItem> groupedItems = uniqueItemsMap.values.toList();

    // 4. Inject Symptom Memory back into the displayed items
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

  // ==========================================
  // NEW: Real-Time Search & Smart Chips
  // ==========================================
  void _applyFilters() {
    List<PantryItem> filtered = _allGroupedItems;

    // Apply Search
    if (_searchQuery.isNotEmpty) {
      filtered = filtered
          .where((item) =>
              item.name.toLowerCase().contains(_searchQuery.toLowerCase()))
          .toList();
    }

    // Apply Smart Chips
    if (_selectedFilter == "Favorites") {
      filtered = filtered.where((item) => item.isFavorite).toList();
    } else if (_selectedFilter == "Safe") {
      filtered = filtered
          .where((item) =>
              item.riskLevel.toUpperCase().contains("GREEN") ||
              item.riskLevel.toUpperCase().contains("SAFE"))
          .toList();
    } else if (_selectedFilter == "Med") {
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

    if (mounted) {
      setState(() {
        _displayedItems = filtered;
        _isLoading = false;
      });
    }
  }

  Future<void> _deleteItem(int id) async {
    await widget.dbService.deletePantryItem(id);
    _loadPantryItems();
  }

  Future<void> _toggleFavorite(int id, bool currentStatus) async {
    await widget.dbService.toggleFavorite(id, !currentStatus);
    _loadPantryItems();
  }

  // ==========================================
  // SURGICALLY UPDATED: Consume & Schedule Alerts
  // ==========================================
  Future<void> _consumeAgain(PantryItem originalItem) async {
    final contextData = await ConsumptionModal.show(context, originalItem.name);

    if (contextData == null) return;

    final newItem = PantryItem()
      ..name = originalItem.name
      ..dateScanned = DateTime.now()
      ..symptoms = ""
      ..riskLevel = originalItem.riskLevel
      ..isFavorite = originalItem.isFavorite
      ..rawText = originalItem.rawText
      ..acidScore = originalItem.acidScore
      ..imagePath = originalItem.imagePath
      ..isEmptyStomach = contextData['isEmptyStomach'] ?? false
      ..isDiluted = contextData['isDiluted'] ?? false;

    await widget.dbService.savePantryItem(newItem);

    // --- NEW: NOTIFICATION TRIGGER LOGIC ---
    final notifService = NotificationService();

    // 1. Always schedule the 4-Hour Digestion Complete timer
    notifService.scheduleTargetedNotification(
      id: NotificationService.digestionTimerId,
      title: 'Digestion Complete',
      body:
          'It has been 4 hours since you consumed ${newItem.name}. Your stomach load has reset.',
      delay: const Duration(hours: 4),
    );

    // 2. The 15-Minute Hydration Chaser (Empty Stomach without Dilution)
    if (newItem.isEmptyStomach && !newItem.isDiluted) {
      notifService.scheduleTargetedNotification(
        id: NotificationService.hydrationChaserId,
        title: 'Acid Buffer Reminder',
        body:
            'Since you had ${newItem.name} on an empty stomach, slowly sip some water now to coat your stomach lining.',
        delay: const Duration(minutes: 15),
      );
    }

    // 3. The 45-Minute Symptom Check-in
    if (newItem.riskLevel == "RED" || newItem.riskLevel == "YELLOW") {
      notifService.scheduleTargetedNotification(
        id: NotificationService.symptomCheckinId,
        title: 'Symptom Check-In',
        body:
            'How is your stomach feeling after drinking ${newItem.name}? Tap to log any discomfort.',
        delay: const Duration(minutes: 45),
      );
    }
    // ----------------------------------------

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Logged: Consumed ${newItem.name}!'),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        ),
      );
    }

    _loadPantryItems();
  }

  // ==========================================
  // EDIT LOGIC: Name and Image
  // ==========================================
  Future<void> _editName(PantryItem item, StateSetter setModalState) async {
    final TextEditingController nameController =
        TextEditingController(text: item.name);

    await showDialog(
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
              const Text('Rename Item',
                  style: TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 18,
                      color: AppColors.primaryDark)),
              const SizedBox(height: 20),
              TextField(
                controller: nameController,
                decoration: InputDecoration(
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
                  onPressed: () async {
                    item.name = nameController.text.isEmpty
                        ? "Unnamed"
                        : nameController.text;
                    await widget.dbService.savePantryItem(item);
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

  // ==========================================
  // EDIT LOGIC: Symptoms & Cancellation
  // ==========================================
  void _showEditSymptomModal(PantryItem item, StateSetter setParentModalState) {
    String tempSymptom = item.symptoms.isEmpty || item.symptoms == "None"
        ? "None"
        : item.symptoms;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(builder: (context, setInnerState) {
        Widget buildRadio(String title) {
          return InkWell(
            onTap: () => setInnerState(() => tempSymptom = title),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Row(
                children: [
                  Icon(
                      tempSymptom == title
                          ? Icons.radio_button_checked
                          : Icons.radio_button_unchecked,
                      color: tempSymptom == title
                          ? AppColors.primary
                          : Colors.grey,
                      size: 20),
                  const SizedBox(width: 12),
                  Text(title,
                      style: const TextStyle(
                          fontSize: 16,
                          color: AppColors.textDark,
                          fontWeight: FontWeight.w600)),
                ],
              ),
            ),
          );
        }

        return Container(
          padding: const EdgeInsets.all(30),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.only(
                topLeft: Radius.circular(30), topRight: Radius.circular(30)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Update Symptom',
                  style: TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 20,
                      color: AppColors.textDark)),
              const Text('Did this drink cause any discomfort?',
                  style: TextStyle(fontSize: 12, color: AppColors.textGrey)),
              const SizedBox(height: 20),
              buildRadio('None'),
              buildRadio('Burning pain'),
              buildRadio('Nausea'),
              buildRadio('Excessive burping'),
              const SizedBox(height: 30),
              SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(15))),
                  onPressed: () async {
                    item.symptoms = tempSymptom == "None" ? "" : tempSymptom;
                    await widget.dbService.savePantryItem(item);

                    if (item.symptoms.isNotEmpty) {
                      NotificationService().cancelNotification(
                          NotificationService.symptomCheckinId);
                    }

                    setParentModalState(() {});
                    _loadPantryItems();
                    Navigator.pop(context);
                  },
                  child: const Text('Save Update',
                      style: TextStyle(
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

  Color _getRiskColor(String riskLevel) {
    if (riskLevel.toUpperCase().contains('RED') ||
        riskLevel.toUpperCase().contains('HIGH')) return AppColors.errorRed;
    if (riskLevel.toUpperCase().contains('YELLOW') ||
        riskLevel.toUpperCase().contains('MODERATE'))
      return AppColors.accentOrange;
    return Colors.green;
  }

  // ==========================================
  // DETAILED VIEW MODAL (FULLY RESTORED)
  // ==========================================
  void _showItemDetails(PantryItem item) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(builder: (context, setModalState) {
        bool hasSymptom = item.symptoms.isNotEmpty && item.symptoms != "None";

        return Container(
          height: MediaQuery.of(context).size.height * 0.90,
          decoration: const BoxDecoration(
            color: AppColors.background,
            borderRadius: BorderRadius.only(
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
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(20),
                                  border:
                                      Border.all(color: Colors.grey.shade300),
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
                                            color: Colors.grey.shade300))
                                    : null,
                              ),
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                    color: AppColors.primary,
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

                      // NAME & RISK SECTION
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: GestureDetector(
                              onTap: () => _editName(item, setModalState),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      item.name,
                                      style: const TextStyle(
                                          fontSize: 28,
                                          fontWeight: FontWeight.w900,
                                          color: AppColors.primaryDark),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  const Icon(Icons.edit,
                                      color: AppColors.primaryDark, size: 20),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 5),
                      Text(
                          'Scanned on ${DateFormat('MMMM dd, yyyy - h:mm a').format(item.dateScanned)}',
                          style: const TextStyle(
                              color: AppColors.textGrey,
                              fontSize: 12,
                              fontWeight: FontWeight.bold)),
                      const SizedBox(height: 20),

                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 15, vertical: 8),
                        decoration: BoxDecoration(
                            color:
                                _getRiskColor(item.riskLevel).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(10)),
                        child: Text(
                          "RISK: ${item.riskLevel.toUpperCase()}",
                          style: TextStyle(
                              color: _getRiskColor(item.riskLevel),
                              fontWeight: FontWeight.w900,
                              fontSize: 12),
                        ),
                      ),
                      const SizedBox(height: 25),

                      // OCR TEXT SECTION
                      const Text('Extracted Ingredients',
                          style: TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 16,
                              color: AppColors.textDark)),
                      const SizedBox(height: 10),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: Colors.grey.shade200)),
                        child: Text(
                          item.rawText.isEmpty
                              ? "No text available."
                              : item.rawText,
                          style: const TextStyle(
                              color: AppColors.textGrey,
                              height: 1.5,
                              fontSize: 12),
                        ),
                      ),

                      // SYMPTOMS SECTION
                      const SizedBox(height: 25),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Logged Symptoms',
                              style: TextStyle(
                                  fontWeight: FontWeight.w900,
                                  fontSize: 16,
                                  color: AppColors.textDark)),
                          GestureDetector(
                            onTap: () =>
                                _showEditSymptomModal(item, setModalState),
                            child: const Icon(Icons.edit,
                                color: AppColors.primaryDark, size: 20),
                          )
                        ],
                      ),
                      const SizedBox(height: 10),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(15),
                        decoration: BoxDecoration(
                            color: hasSymptom
                                ? Colors.orange.shade50
                                : Colors.green.shade50,
                            borderRadius: BorderRadius.circular(20)),
                        child: Row(
                          children: [
                            Icon(
                                hasSymptom
                                    ? Icons.local_fire_department
                                    : Icons.check_circle_outline,
                                color:
                                    hasSymptom ? Colors.orange : Colors.green),
                            const SizedBox(width: 15),
                            Text(
                                hasSymptom
                                    ? item.symptoms
                                    : "No symptoms logged",
                                style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: hasSymptom
                                        ? Colors.deepOrange
                                        : Colors.green.shade700)),
                          ],
                        ),
                      ),

                      const SizedBox(height: 40),

                      // CONSUME & DELETE BUTTONS
                      Row(
                        children: [
                          Expanded(
                            child: SizedBox(
                              height: 55,
                              child: OutlinedButton.icon(
                                  style: OutlinedButton.styleFrom(
                                      foregroundColor: Colors.red,
                                      side: const BorderSide(
                                          color: Colors.red, width: 2),
                                      shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(20))),
                                  icon: const Icon(Icons.delete_outline),
                                  label: const Text('Delete',
                                      style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16)),
                                  onPressed: () {
                                    _deleteItem(item.id);
                                    Navigator.pop(context);
                                  }),
                            ),
                          ),
                          const SizedBox(width: 15),
                          Expanded(
                            child: SizedBox(
                              height: 55,
                              child: ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(
                                      backgroundColor: AppColors.primary,
                                      shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(20))),
                                  icon: const Icon(Icons.add_task,
                                      color: Colors.white),
                                  label: const Text('Consume',
                                      style: TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16)),
                                  onPressed: () {
                                    Navigator.pop(context);
                                    _consumeAgain(item);
                                  }),
                            ),
                          ),
                        ],
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

  // ==========================================
  // FILTER CHIP WIDGET BUILDER
  // ==========================================
  Widget _buildFilterChip(String label, String value,
      [IconData? icon, Color? iconColor]) {
    bool isSelected = _selectedFilter == value;
    return GestureDetector(
      onTap: () {
        setState(() => _selectedFilter = value);
        _applyFilters();
      },
      child: Container(
        margin: const EdgeInsets.only(right: 10),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color: isSelected ? AppColors.primary : Colors.grey.shade300),
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
                    color: isSelected ? Colors.white : AppColors.textDark)),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
            icon: Image.asset('assets/images/back_1.png',
                width: 24, color: AppColors.primaryDark),
            onPressed: () => Navigator.pop(context)),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 25.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Digital Pantry',
                  style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.w900,
                      color: AppColors.primaryDark)),
              const SizedBox(height: 15),

              // 1. LIVE SEARCH BAR
              TextField(
                controller: _searchController,
                onChanged: (value) {
                  _searchQuery = value;
                  _applyFilters();
                },
                decoration: InputDecoration(
                  hintText: "Search your inventory...",
                  prefixIcon:
                      const Icon(Icons.search, color: AppColors.textGrey),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear,
                              color: AppColors.textGrey),
                          onPressed: () {
                            _searchController.clear();
                            _searchQuery = "";
                            _applyFilters();
                          })
                      : null,
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding: const EdgeInsets.symmetric(vertical: 0),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(20),
                      borderSide: BorderSide.none),
                ),
              ),
              const SizedBox(height: 15),

              // 2. SMART FILTER CHIPS
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _buildFilterChip("All", "All"),
                    _buildFilterChip("Favorites", "Favorites", Icons.favorite,
                        Colors.redAccent),
                    _buildFilterChip(
                        "Safe", "Safe", Icons.circle, Colors.green),
                    _buildFilterChip(
                        "Med", "Med", Icons.circle, AppColors.accentOrange),
                    _buildFilterChip(
                        "High", "High", Icons.circle, AppColors.errorRed),
                  ],
                ),
              ),
              const SizedBox(height: 25),

              // 3. INVENTORY LIST
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                      color: AppColors.primaryLight.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(30)),
                  child: _isLoading
                      ? const Center(
                          child: CircularProgressIndicator(
                              color: AppColors.primary))
                      : _displayedItems.isEmpty
                          ? Center(
                              child: Text(
                                  'No items found matching your filters.',
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                      color: AppColors.textGrey)))
                          : ListView.builder(
                              itemCount: _displayedItems.length,
                              itemBuilder: (context, index) {
                                final item = _displayedItems[index];

                                // CAPACITY WARNING LOGIC (Hook _currentStomachLoad to RiskCalculator)
                                bool exceedsCapacity =
                                    (_currentStomachLoad + item.acidScore) >
                                        _dailyMaxLoad;
                                bool hasSymptomMemory =
                                    item.symptoms != "None" &&
                                        item.symptoms.isNotEmpty;

                                Color riskColor = _getRiskColor(item.riskLevel);

                                return GestureDetector(
                                  onTap: () => _showItemDetails(item),
                                  child: Container(
                                    margin: const EdgeInsets.only(bottom: 15),
                                    padding: const EdgeInsets.all(15),
                                    decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(20),
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
                                            // Product Image
                                            Container(
                                              width: 70,
                                              height: 70,
                                              decoration: BoxDecoration(
                                                  color: Colors.white,
                                                  borderRadius:
                                                      BorderRadius.circular(15),
                                                  border: Border.all(
                                                      color: Colors
                                                          .grey.shade200)),
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
                                                            color: Colors.grey
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
                                                          child: Text(item.name,
                                                              overflow:
                                                                  TextOverflow
                                                                      .ellipsis,
                                                              style: const TextStyle(
                                                                  fontSize: 18,
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .w900,
                                                                  color: AppColors
                                                                      .primaryDark))),
                                                      GestureDetector(
                                                        onTap: () =>
                                                            _toggleFavorite(
                                                                item.id,
                                                                item.isFavorite),
                                                        child: Icon(
                                                            item.isFavorite
                                                                ? Icons.favorite
                                                                : Icons
                                                                    .favorite_border,
                                                            color: item
                                                                    .isFavorite
                                                                ? Colors.red
                                                                : AppColors
                                                                    .primaryDark,
                                                            size: 24),
                                                      ),
                                                    ],
                                                  ),

                                                  // SYMPTOM MEMORY BADGE
                                                  if (hasSymptomMemory) ...[
                                                    const SizedBox(height: 5),
                                                    Container(
                                                      padding: const EdgeInsets
                                                          .symmetric(
                                                          horizontal: 8,
                                                          vertical: 3),
                                                      decoration: BoxDecoration(
                                                          color: Colors
                                                              .red.shade50,
                                                          borderRadius:
                                                              BorderRadius
                                                                  .circular(8),
                                                          border: Border.all(
                                                              color: Colors.red
                                                                  .shade100)),
                                                      child: Text(
                                                          '🔥 ${item.symptoms} Trigger',
                                                          style: TextStyle(
                                                              fontSize: 10,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .bold,
                                                              color: Colors.red
                                                                  .shade700)),
                                                    ),
                                                  ],
                                                  const SizedBox(height: 12),

                                                  Row(
                                                    mainAxisAlignment:
                                                        MainAxisAlignment
                                                            .spaceBetween,
                                                    children: [
                                                      Container(
                                                        padding:
                                                            const EdgeInsets
                                                                .symmetric(
                                                                horizontal: 10,
                                                                vertical: 4),
                                                        decoration: BoxDecoration(
                                                            color: Colors.white,
                                                            borderRadius:
                                                                BorderRadius
                                                                    .circular(
                                                                        20),
                                                            border: Border.all(
                                                                color: Colors
                                                                    .grey
                                                                    .shade200)),
                                                        child: Text(
                                                            item.riskLevel
                                                                    .toUpperCase()
                                                                    .contains(
                                                                        'RED')
                                                                ? 'HIGH'
                                                                : (item.riskLevel
                                                                        .toUpperCase()
                                                                        .contains(
                                                                            'YELLOW')
                                                                    ? 'MED'
                                                                    : 'SAFE'),
                                                            style: TextStyle(
                                                                fontSize: 10,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .w900,
                                                                color:
                                                                    riskColor)),
                                                      ),
                                                      GestureDetector(
                                                        onTap: () =>
                                                            _consumeAgain(item),
                                                        child: Container(
                                                          padding:
                                                              const EdgeInsets
                                                                  .symmetric(
                                                                  horizontal:
                                                                      12,
                                                                  vertical: 6),
                                                          decoration: BoxDecoration(
                                                              color: AppColors
                                                                  .primaryLight
                                                                  .withOpacity(
                                                                      0.1),
                                                              borderRadius:
                                                                  BorderRadius
                                                                      .circular(
                                                                          15)),
                                                          child: const Row(
                                                            children: [
                                                              Icon(Icons.add,
                                                                  size: 14,
                                                                  color: AppColors
                                                                      .primaryDark),
                                                              SizedBox(
                                                                  width: 4),
                                                              Text('Consume',
                                                                  style: TextStyle(
                                                                      fontSize:
                                                                          11,
                                                                      fontWeight:
                                                                          FontWeight
                                                                              .bold,
                                                                      color: AppColors
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

                                        // CAPACITY EXCEEDED WARNING
                                        if (exceedsCapacity) ...[
                                          const SizedBox(height: 12),
                                          Container(
                                            width: double.infinity,
                                            padding: const EdgeInsets.symmetric(
                                                vertical: 8, horizontal: 12),
                                            decoration: BoxDecoration(
                                                color: Colors.amber.shade100,
                                                borderRadius:
                                                    BorderRadius.circular(10)),
                                            child: Row(
                                              children: [
                                                Icon(
                                                    Icons.warning_amber_rounded,
                                                    color:
                                                        Colors.amber.shade900,
                                                    size: 16),
                                                const SizedBox(width: 8),
                                                Text(
                                                    '⚠️ Exceeds Daily Acid Cap',
                                                    style: TextStyle(
                                                        fontSize: 11,
                                                        fontWeight:
                                                            FontWeight.bold,
                                                        color: Colors
                                                            .amber.shade900)),
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
    );
  }
}
