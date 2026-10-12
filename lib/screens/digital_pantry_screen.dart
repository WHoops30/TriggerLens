import 'package:flutter/material.dart';
import 'package:intl/intl.dart'; // Used for formatting dates
import '../services/database_service.dart';
import '../models/pantry_item.dart';
import '../utils/ui_helpers.dart';

class DigitalPantryScreen extends StatefulWidget {
  final DatabaseService dbService;
  const DigitalPantryScreen({super.key, required this.dbService});

  @override
  State<DigitalPantryScreen> createState() => _DigitalPantryScreenState();
}

class _DigitalPantryScreenState extends State<DigitalPantryScreen> {
  List<PantryItem> _pantryItems = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadPantryItems();
  }

  // Fetch items from the Isar Database
  Future<void> _loadPantryItems() async {
    final items = await widget.dbService.getPantryItems();
    setState(() {
      _pantryItems = items;
      _isLoading = false;
    });
  }

  // Delete an item and refresh the list
  Future<void> _deleteItem(int id) async {
    await widget.dbService.deletePantryItem(id);
    _loadPantryItems();
  }

  // Toggle favorite and refresh
  Future<void> _toggleFavorite(int id, bool currentStatus) async {
    await widget.dbService.toggleFavorite(id, !currentStatus);
    _loadPantryItems();
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
              const Text('Everyday Drink',
                  style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey,
                      fontWeight: FontWeight.w600)),
              const SizedBox(height: 25),

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
                      : _pantryItems.isEmpty
                          ? const Center(
                              child: Text(
                                  'Your pantry is empty.\nScan a drink to get started!',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(color: AppColors.textGrey)))
                          : ListView.builder(
                              itemCount: _pantryItems.length,
                              itemBuilder: (context, index) {
                                final item = _pantryItems[index];

                                // Visuals based on the most recent item (index 0 gets the purple gradient)
                                final isGradient = index == 0;
                                final bgGradient = isGradient
                                    ? AppColors.primaryGradient
                                    : null;
                                final bgColor =
                                    isGradient ? null : Colors.white;
                                final textColor = isGradient
                                    ? Colors.white
                                    : AppColors.primaryDark;
                                final subTextColor = isGradient
                                    ? Colors.white
                                    : AppColors.textDark;

                                // Format the database date to match your UI (e.g. 07/19/2026)
                                final formattedDate = DateFormat('MM/dd/yyyy')
                                    .format(item.dateScanned);

                                // Determine Risk Color
                                Color riskColor = AppColors.successGreen;
                                if (item.riskLevel
                                    .toUpperCase()
                                    .contains('HIGH'))
                                  riskColor = AppColors.errorRed;
                                if (item.riskLevel
                                    .toUpperCase()
                                    .contains('MEDIUM'))
                                  riskColor = AppColors.accentOrange;

                                return Container(
                                  margin: const EdgeInsets.only(bottom: 15),
                                  padding: const EdgeInsets.all(15),
                                  decoration: BoxDecoration(
                                      gradient: bgGradient,
                                      color: bgColor,
                                      borderRadius: BorderRadius.circular(20),
                                      boxShadow: [
                                        BoxShadow(
                                            color:
                                                Colors.black.withOpacity(0.05),
                                            blurRadius: 10,
                                            offset: const Offset(0, 5))
                                      ]),
                                  child: Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      // Product Image Placeholder
                                      Container(
                                        width: 70,
                                        height: 70,
                                        decoration: BoxDecoration(
                                            color: Colors.white,
                                            borderRadius:
                                                BorderRadius.circular(15),
                                            border: Border.all(
                                                color: Colors.grey.shade200)),
                                        child: ClipRRect(
                                          borderRadius:
                                              BorderRadius.circular(15),
                                          child: Image.asset(
                                              'assets/images/triggerlens_icon.png',
                                              fit: BoxFit.cover),
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
                                                Text(item.name,
                                                    style: TextStyle(
                                                        fontSize: 22,
                                                        fontWeight:
                                                            FontWeight.w900,
                                                        color: textColor)),
                                                GestureDetector(
                                                  onTap: () => _toggleFavorite(
                                                      item.id, item.isFavorite),
                                                  child: Icon(
                                                      item.isFavorite
                                                          ? Icons.favorite
                                                          : Icons
                                                              .favorite_border,
                                                      color: isGradient
                                                          ? Colors.white
                                                          : AppColors
                                                              .primaryDark,
                                                      size: 24),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 5),
                                            Text('Consumed - $formattedDate',
                                                style: TextStyle(
                                                    fontSize: 10,
                                                    color: subTextColor,
                                                    fontWeight:
                                                        FontWeight.bold)),
                                            Text(
                                                'Symptoms: ${item.symptoms.isEmpty ? "None" : item.symptoms}',
                                                style: TextStyle(
                                                    fontSize: 10,
                                                    color: subTextColor)),
                                            const SizedBox(height: 15),

                                            // Risk Pill and Icons Row
                                            Row(
                                              mainAxisAlignment:
                                                  MainAxisAlignment.end,
                                              children: [
                                                Container(
                                                  padding: const EdgeInsets
                                                      .symmetric(
                                                      horizontal: 10,
                                                      vertical: 4),
                                                  decoration: BoxDecoration(
                                                      color: Colors.white,
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                              20),
                                                      border: Border.all(
                                                          color: Colors
                                                              .grey.shade200)),
                                                  child: Text(
                                                      item.riskLevel
                                                          .toUpperCase(),
                                                      style: TextStyle(
                                                          fontSize: 10,
                                                          fontWeight:
                                                              FontWeight.w900,
                                                          color: riskColor)),
                                                ),
                                                if (isGradient) ...[
                                                  const SizedBox(width: 8),
                                                  Image.asset(
                                                      'assets/images/clock.png',
                                                      width: 16),
                                                ],
                                                const SizedBox(width: 15),
                                                GestureDetector(
                                                  onTap: () =>
                                                      _deleteItem(item.id),
                                                  child: Icon(
                                                      Icons.delete_outline,
                                                      color: isGradient
                                                          ? Colors.white
                                                          : Colors.black87,
                                                      size: 22),
                                                ),
                                              ],
                                            )
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }),
                ),
              ),
              const SizedBox(height: 100), // Space for floating bottom nav
            ],
          ),
        ),
      ),
    );
  }
}
