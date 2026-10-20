import 'dart:async';
import 'dart:math';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';

// PDF & Printing Packages
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../services/database_service.dart';
import '../models/pantry_item.dart';
import '../models/user_profile.dart';
import '../utils/ui_helpers.dart';
import '../utils/keyword_mapping_algorithm.dart';

// ENUM for distinct export actions
enum ExportAction { download, print, share }

class InsightsScreen extends StatefulWidget {
  final DatabaseService dbService;
  const InsightsScreen({super.key, required this.dbService});

  @override
  State<InsightsScreen> createState() => _InsightsScreenState();
}

class _InsightsScreenState extends State<InsightsScreen> {
  bool _isLoading = true;

  // Data Models
  UserProfile? _userProfile;
  List<PantryItem> _allHistoryLogs = [];

  // Dynamic Graph State
  int _selectedGraphDays = 15; // Options: 15, 30, 90
  List<double> _dailyScores = [];
  double _dailyCap = 15.0;

  // History Log State
  int _selectedHistoryDays = 7; // Options: 1, 3, 7, 30
  List<PantryItem> _filteredHistoryLogs = [];
  int _visibleHistoryCount = 5; // Start by showing only 5 items

  // Plain-English Analytics
  int _totalSymptomLogs = 0;
  List<MapEntry<String, int>> _topTriggers = [];
  String _worstTimeOfDay = "Not enough data";
  int _emptyStomachFlareUps = 0;

  // Session Tracker
  Timer? _timer;
  Duration _timeRemaining = Duration.zero;

  @override
  void initState() {
    super.initState();
    _fetchBaseData();

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_timeRemaining.inSeconds > 0) {
        setState(() => _timeRemaining -= const Duration(seconds: 1));
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  // 1. Initial Database Fetch
  Future<void> _fetchBaseData() async {
    final allItems = await widget.dbService.getPantryItems();
    final profile = await widget.dbService.getUserProfile();

    // Sort all items chronologically (Newest first)
    allItems.sort((a, b) => b.dateScanned.compareTo(a.dateScanned));

    setState(() {
      _userProfile = profile;
      _dailyCap = profile?.dynamicDailyCap ?? 15.0;
      _allHistoryLogs = allItems;
    });

    await _processDynamicInsights();
    _filterHistoryLogs();
  }

  // 2. The Dynamic Calculator (Recalculates Graph/Triggers when Timeframe changes)
  Future<void> _processDynamicInsights() async {
    setState(() => _isLoading = true);

    DateTime now = DateTime.now();
    DateTime today = DateTime(now.year, now.month, now.day);
    DateTime cutoffDate = today.subtract(Duration(days: _selectedGraphDays));

    List<double> tempScores = List.filled(_selectedGraphDays, 0.0);

    final customTriggers = await widget.dbService.getAllTriggers();
    List<String> allTrackedIngredients = [
      'citric acid',
      'vitamin c',
      'caffeine',
      'coffee',
      'palm oil',
      'creamer',
      'milk',
      'skimmed milk',
      'chocolate',
      'sugar',
      'salt'
    ];
    for (var ct in customTriggers) {
      allTrackedIngredients.add(ct.name.toLowerCase());
    }

    Map<String, int> dynamicTriggerCounts = {};
    for (var ingredient in allTrackedIngredients) {
      dynamicTriggerCounts[ingredient] = 0;
    }

    int symptomCount = 0;
    int emptyStomachCount = 0;
    Map<String, int> timeOfDayCounts = {
      'Morning (6am-12pm)': 0,
      'Afternoon (12pm-5pm)': 0,
      'Evening (5pm-9pm)': 0,
      'Late Night (9pm+)': 0,
    };
    DateTime? latestScanTime;

    // Process only logs within the selected graph timeframe
    for (var item in _allHistoryLogs) {
      if (item.dateScanned.isAfter(cutoffDate)) {
        // --- Session Timer ---
        if (latestScanTime == null ||
            item.dateScanned.isAfter(latestScanTime)) {
          latestScanTime = item.dateScanned;
        }

        // --- Graph Data ---
        DateTime scanDate = DateTime(item.dateScanned.year,
            item.dateScanned.month, item.dateScanned.day);
        int daysAgo = today.difference(scanDate).inDays;
        if (daysAgo >= 0 && daysAgo < _selectedGraphDays) {
          tempScores[(_selectedGraphDays - 1) - daysAgo] +=
              item.acidScore.toDouble();
        }

        // --- Symptom Deep Dive ---
        if (item.symptoms.isNotEmpty && item.symptoms != "None") {
          symptomCount++;
          if (item.isEmptyStomach) emptyStomachCount++;

          int hour = item.dateScanned.hour;
          if (hour >= 6 && hour < 12)
            timeOfDayCounts['Morning (6am-12pm)'] =
                timeOfDayCounts['Morning (6am-12pm)']! + 1;
          else if (hour >= 12 && hour < 17)
            timeOfDayCounts['Afternoon (12pm-5pm)'] =
                timeOfDayCounts['Afternoon (12pm-5pm)']! + 1;
          else if (hour >= 17 && hour < 21)
            timeOfDayCounts['Evening (5pm-9pm)'] =
                timeOfDayCounts['Evening (5pm-9pm)']! + 1;
          else
            timeOfDayCounts['Late Night (9pm+)'] =
                timeOfDayCounts['Late Night (9pm+)']! + 1;

          String cleanedText =
              KeywordMappingAlgorithm.cleanRawText(item.rawText);
          for (var trackedIngredient in allTrackedIngredients) {
            if (KeywordMappingAlgorithm.fuzzyContains(
                cleanedText, trackedIngredient)) {
              dynamicTriggerCounts[trackedIngredient] =
                  dynamicTriggerCounts[trackedIngredient]! + 1;
            }
          }
        }
      }
    }

    if (latestScanTime != null) {
      final expireTime = latestScanTime.add(const Duration(hours: 6));
      _timeRemaining = expireTime.difference(now);
      if (_timeRemaining.isNegative) _timeRemaining = Duration.zero;
    }

    var sortedTriggers = dynamicTriggerCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    var sortedTimes = timeOfDayCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    if (mounted) {
      setState(() {
        _dailyScores = tempScores;
        _totalSymptomLogs = symptomCount;
        _topTriggers =
            sortedTriggers.where((e) => e.value > 0).take(3).toList();
        _emptyStomachFlareUps = emptyStomachCount;
        _worstTimeOfDay =
            symptomCount > 0 ? sortedTimes.first.key : "No recent data";
        _isLoading = false;
      });
    }
  }

  // 3. Independent filter for the History Log List
  void _filterHistoryLogs() {
    DateTime today = DateTime.now();
    DateTime cutoffDate = today.subtract(Duration(days: _selectedHistoryDays));

    setState(() {
      _filteredHistoryLogs = _allHistoryLogs
          .where((item) => item.dateScanned.isAfter(cutoffDate))
          .toList();
      _visibleHistoryCount = 5; // Reset to 5 when filter changes
    });
  }

  // ==========================================
  // REAL PDF GENERATION & EXPORT LOGIC
  // ==========================================
  void _showExportOptions() {
    showModalBottomSheet(
        context: context,
        shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
        builder: (context) => SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text("Export Clinical Report",
                        style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primaryDark)),
                    const SizedBox(height: 10),

                    // 1. Download Button
                    ListTile(
                      leading: const Icon(Icons.file_download,
                          color: AppColors.primary),
                      title: const Text("Download PDF"),
                      subtitle:
                          const Text("Save a copy directly to your device"),
                      onTap: () {
                        Navigator.pop(context);
                        _generateRealPDFReport(action: ExportAction.download);
                      },
                    ),

                    // 2. Print Button
                    ListTile(
                      leading:
                          const Icon(Icons.print, color: AppColors.primary),
                      title: const Text("Print PDF"),
                      subtitle:
                          const Text("Send directly to a wireless printer"),
                      onTap: () {
                        Navigator.pop(context);
                        _generateRealPDFReport(action: ExportAction.print);
                      },
                    ),

                    // 3. Share Button
                    ListTile(
                      leading:
                          const Icon(Icons.share, color: AppColors.primary),
                      title: const Text("Share PDF"),
                      subtitle:
                          const Text("Send via Email, Viber, or Messenger"),
                      onTap: () {
                        Navigator.pop(context);
                        _generateRealPDFReport(action: ExportAction.share);
                      },
                    ),
                  ],
                ),
              ),
            ));
  }

  Future<void> _generateRealPDFReport({required ExportAction action}) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (pw.Context context) {
          return [
            pw.Header(level: 0, text: 'TriggerLens Clinical Summary'),
            pw.Text(
                'Generated: ${DateFormat('MMMM dd, yyyy').format(DateTime.now())}'),
            pw.Text('Analytics Timeframe: Last $_selectedGraphDays Days'),
            pw.SizedBox(height: 20),
            pw.Text('Identified Diet Triggers',
                style:
                    pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
            pw.Divider(),
            if (_topTriggers.isEmpty)
              pw.Text('No significant triggers identified in this period.')
            else
              ..._topTriggers.map((t) => pw.Bullet(
                  text:
                      '${t.key.toUpperCase()} - Associated with ${t.value} symptom occurrences.')),
            pw.SizedBox(height: 20),
            pw.Text(
                'Detailed Consumption Log (Last $_selectedHistoryDays Days)',
                style:
                    pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 10),
            pw.TableHelper.fromTextArray(
              context: context,
              headers: <String>[
                'Date & Time',
                'Item Scanned',
                'Risk Level',
                'Reported Symptom'
              ],
              data: <List<String>>[
                ..._filteredHistoryLogs.map((item) => [
                      DateFormat('MM/dd/yy h:mm a').format(item.dateScanned),
                      item.name,
                      item.riskLevel.replaceAll(" Risk", ""),
                      item.symptoms.isEmpty ? "None" : item.symptoms,
                    ])
              ],
            ),
          ];
        },
      ),
    );

    final bytes = await pdf.save();
    final fileName =
        'TriggerLens_Report_${DateTime.now().millisecondsSinceEpoch}.pdf';

    if (action == ExportAction.print) {
      await Printing.layoutPdf(
          onLayout: (format) async => bytes, name: fileName);
    } else if (action == ExportAction.share) {
      await Printing.sharePdf(bytes: bytes, filename: fileName);
    } else if (action == ExportAction.download) {
      try {
        final dir = await getApplicationDocumentsDirectory();
        final file = File('${dir.path}/$fileName');
        await file.writeAsBytes(bytes);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Downloaded to Documents: $fileName'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ));
        }
      } catch (e) {
        // Fallback to share sheet if direct save fails due to permissions
        await Printing.sharePdf(bytes: bytes, filename: fileName);
      }
    }
  }

  Color _getRiskColor(String riskLevel) {
    if (riskLevel.toUpperCase().contains('RED') ||
        riskLevel.toUpperCase().contains('HIGH')) return AppColors.errorRed;
    if (riskLevel.toUpperCase().contains('YELLOW') ||
        riskLevel.toUpperCase().contains('MODERATE'))
      return AppColors.accentOrange;
    return Colors.green;
  }

  // Tappable Chips for Graph
  Widget _buildGraphChip(String label, int days) {
    bool isSelected = _selectedGraphDays == days;
    return GestureDetector(
      onTap: () {
        setState(() => _selectedGraphDays = days);
        _processDynamicInsights();
      },
      child: Container(
        margin: const EdgeInsets.only(right: 10),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color: isSelected ? AppColors.primary : Colors.grey.shade300),
        ),
        child: Text(label,
            style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 12,
                color: isSelected ? Colors.white : AppColors.textDark)),
      ),
    );
  }

  // Tappable Chips for History Log
  Widget _buildHistoryChip(String label, int days) {
    bool isSelected = _selectedHistoryDays == days;
    return GestureDetector(
      onTap: () {
        setState(() => _selectedHistoryDays = days);
        _filterHistoryLogs();
      },
      child: Container(
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primaryDark : Colors.grey.shade200,
          borderRadius: BorderRadius.circular(15),
        ),
        child: Text(label,
            style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 11,
                color: isSelected ? Colors.white : AppColors.textDark)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
          backgroundColor: AppColors.background,
          body: Center(
              child: CircularProgressIndicator(color: AppColors.primary)));
    }

    String hr = _timeRemaining.inHours.toString().padLeft(2, '0');
    String mn = (_timeRemaining.inMinutes % 60).toString().padLeft(2, '0');
    String sc = (_timeRemaining.inSeconds % 60).toString().padLeft(2, '0');
    double timerProgress =
        _timeRemaining.inSeconds > 0 ? _timeRemaining.inSeconds / 21600 : 0.0;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Image.asset('assets/images/back_1.png',
              width: 24, color: AppColors.primaryDark),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon:
                const Icon(Icons.picture_as_pdf, color: AppColors.primaryDark),
            tooltip: "Export PDF",
            onPressed: _showExportOptions,
          )
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 25.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Insights',
                  style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.w900,
                      color: AppColors.primaryDark)),
              const SizedBox(height: 5),
              Text('Your Phase: ${_userProfile?.phase ?? "Maintenance"}',
                  style: const TextStyle(
                      fontSize: 14,
                      color: AppColors.primary,
                      fontWeight: FontWeight.bold)),
              const SizedBox(height: 20),

              // ANALYTICS TIMEFRAME
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _buildGraphChip("15 Days", 15),
                    _buildGraphChip("30 Days", 30),
                    _buildGraphChip("3 Months", 90),
                  ],
                ),
              ),
              const SizedBox(height: 25),

              // 1. THE DYNAMIC LIMIT GRAPH
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Acid Load History',
                      style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          color: AppColors.textDark)),
                  Text('Limit: ${_dailyCap.toStringAsFixed(1)}',
                      style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey)),
                ],
              ),
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                height: 200,
                padding: const EdgeInsets.all(15),
                decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 10,
                          offset: const Offset(0, 5))
                    ]),
                child: CustomPaint(
                    painter: _LimitGraphPainter(
                        data: _dailyScores, capLimit: _dailyCap)),
              ),
              const SizedBox(height: 30),

              // 2. THE LIFESTYLE TRENDS
              const Text('Lifestyle Trends',
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      color: AppColors.textDark)),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(15),
                      decoration: BoxDecoration(
                          color: Colors.orange.shade50,
                          borderRadius: BorderRadius.circular(15)),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.access_time_filled,
                              color: Colors.orange.shade400, size: 24),
                          const SizedBox(height: 10),
                          const Text('Most Vulnerable',
                              style: TextStyle(
                                  fontSize: 10,
                                  color: Colors.black54,
                                  fontWeight: FontWeight.bold)),
                          Text(_worstTimeOfDay,
                              style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w900,
                                  color: Colors.orange.shade900)),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 15),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(15),
                      decoration: BoxDecoration(
                          color: Colors.blue.shade50,
                          borderRadius: BorderRadius.circular(15)),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.no_meals,
                              color: Colors.blue.shade400, size: 24),
                          const SizedBox(height: 10),
                          const Text('Empty Stomach',
                              style: TextStyle(
                                  fontSize: 10,
                                  color: Colors.black54,
                                  fontWeight: FontWeight.bold)),
                          Text('$_emptyStomachFlareUps Flare-ups',
                              style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w900,
                                  color: Colors.blue.shade900)),
                        ],
                      ),
                    ),
                  )
                ],
              ),
              const SizedBox(height: 30),

              // 3. THE DYNAMIC TRIGGERS
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.primaryLight.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Your Specific Triggers',
                        style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                            color: AppColors.primaryDark)),
                    const SizedBox(height: 15),
                    if (_totalSymptomLogs == 0 || _topTriggers.isEmpty) ...[
                      const Text(
                          'Not enough data in this timeframe to find patterns.',
                          style: TextStyle(
                              fontSize: 12, color: AppColors.textDark)),
                    ] else ...[
                      const Text(
                          'In this period, these ingredients were consumed right before a symptom was logged:',
                          style: TextStyle(
                              fontSize: 12,
                              color: AppColors.textDark,
                              height: 1.4)),
                      const SizedBox(height: 15),
                      ..._topTriggers.map((trigger) {
                        return Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12)),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(trigger.key.toUpperCase(),
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.textDark)),
                              Text('${trigger.value} Incidents',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.errorRed)),
                            ],
                          ),
                        );
                      }),
                    ]
                  ],
                ),
              ),
              const SizedBox(height: 30),

              // 4. LIVE SESSION TRACKER
              const Align(
                alignment: Alignment.centerLeft,
                child: Text('Session Tracker',
                    style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        color: AppColors.primaryDark)),
              ),
              const SizedBox(height: 20),
              Center(
                child: SizedBox(
                  width: 120,
                  height: 120,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      SizedBox(
                        width: 120,
                        height: 120,
                        child: CircularProgressIndicator(
                          value: timerProgress,
                          strokeWidth: 8,
                          backgroundColor:
                              AppColors.primaryLight.withOpacity(0.3),
                          color: AppColors.primary,
                          strokeCap: StrokeCap.round,
                        ),
                      ),
                      Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Image.asset('assets/images/clock.png',
                              width: 24, color: AppColors.primaryDark),
                        ],
                      )
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 15),
              Center(
                child: Column(
                  children: [
                    Text('$hr : $mn : $sc',
                        style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                            color: AppColors.primaryDark)),
                    const Text('HR   MN   SEC',
                        style: TextStyle(
                            fontSize: 8,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primaryDark)),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              const Center(
                child: Text('Remaining in 6-hour window',
                    style: TextStyle(
                        fontSize: 11,
                        color: AppColors.primary,
                        fontWeight: FontWeight.w600)),
              ),
              const SizedBox(height: 40),

              // 5. CONSUMPTION HISTORY LOG
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const Text('History Log',
                      style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          color: AppColors.primaryDark)),
                  Text('${_filteredHistoryLogs.length} entries',
                      style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey)),
                ],
              ),
              const SizedBox(height: 10),

              // HISTORY TIMEFRAME CHIPS
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _buildHistoryChip("1 Day", 1),
                    _buildHistoryChip("3 Days", 3),
                    _buildHistoryChip("7 Days", 7),
                    _buildHistoryChip("30 Days", 30),
                  ],
                ),
              ),
              const SizedBox(height: 15),

              _filteredHistoryLogs.isEmpty
                  ? const Center(
                      child: Padding(
                      padding: EdgeInsets.all(20.0),
                      child: Text('No drinks logged in this timeframe.',
                          style: TextStyle(color: AppColors.textGrey)),
                    ))
                  : ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: min(
                          _filteredHistoryLogs.length, _visibleHistoryCount),
                      itemBuilder: (context, index) {
                        final item = _filteredHistoryLogs[index];
                        final formattedTime =
                            DateFormat('MMM dd, yyyy • h:mm a')
                                .format(item.dateScanned);
                        bool hasSymptom =
                            item.symptoms.isNotEmpty && item.symptoms != "None";
                        Color riskColor = _getRiskColor(item.riskLevel);

                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(15),
                          decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(15),
                              border: Border.all(color: Colors.grey.shade100),
                              boxShadow: [
                                BoxShadow(
                                    color: Colors.black.withOpacity(0.02),
                                    blurRadius: 5,
                                    offset: const Offset(0, 2))
                              ]),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                margin:
                                    const EdgeInsets.only(top: 5, right: 15),
                                width: 12,
                                height: 12,
                                decoration: BoxDecoration(
                                    color: riskColor, shape: BoxShape.circle),
                              ),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(item.name,
                                        style: const TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w900,
                                            color: AppColors.primaryDark),
                                        overflow: TextOverflow.ellipsis),
                                    const SizedBox(height: 4),
                                    Text(formattedTime,
                                        style: const TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.grey)),
                                    if (hasSymptom) ...[
                                      const SizedBox(height: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                            color: Colors.red.shade50,
                                            borderRadius:
                                                BorderRadius.circular(8)),
                                        child: Text('🔥 ${item.symptoms}',
                                            style: TextStyle(
                                                fontSize: 10,
                                                fontWeight: FontWeight.bold,
                                                color: Colors.red.shade700)),
                                      ),
                                    ]
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),

              // SEE MORE BUTTON
              if (_filteredHistoryLogs.length > _visibleHistoryCount)
                Center(
                  child: TextButton.icon(
                    onPressed: () {
                      setState(() {
                        _visibleHistoryCount += 5; // Expand list by 5 items
                      });
                    },
                    icon: const Icon(Icons.keyboard_arrow_down,
                        color: AppColors.primaryDark),
                    label: const Text("See More",
                        style: TextStyle(
                            color: AppColors.primaryDark,
                            fontWeight: FontWeight.bold)),
                  ),
                ),

              const SizedBox(height: 100),
            ],
          ),
        ),
      ),
    );
  }
}

// SCALABLE BAR CHART PAINTER
class _LimitGraphPainter extends CustomPainter {
  final List<double> data;
  final double capLimit;
  _LimitGraphPainter({required this.data, required this.capLimit});

  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty) return;

    double maxData = data.reduce(max);
    if (capLimit > maxData) maxData = capLimit;
    maxData += 5;

    // Threshold Line
    double capY = size.height - ((capLimit / maxData) * size.height);
    final limitPaint = Paint()
      ..color = Colors.red.withOpacity(0.5)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    double dashWidth = 5, dashSpace = 5, startX = 0;
    while (startX < size.width) {
      canvas.drawLine(
          Offset(startX, capY), Offset(startX + dashWidth, capY), limitPaint);
      startX += dashWidth + dashSpace;
    }

    // Dynamic Bars
    int count = data.length;
    double barSpace = size.width / count;
    double barWidth = barSpace * 0.6;

    for (int i = 0; i < count; i++) {
      double x = (barSpace * i) + (barSpace * 0.2);
      double barHeight = (data[i] / maxData) * size.height;
      double y = size.height - barHeight;

      Color barColor =
          data[i] > capLimit ? AppColors.accentOrange : AppColors.primary;
      final barPaint = Paint()
        ..color = barColor
        ..style = PaintingStyle.fill;

      canvas.drawRRect(
          RRect.fromRectAndRadius(Rect.fromLTWH(x, y, barWidth, barHeight),
              const Radius.circular(3)),
          barPaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
