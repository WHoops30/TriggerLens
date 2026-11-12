import 'dart:async';
import 'dart:math';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
import '../utils/app_localizations.dart';
import '../utils/keyword_mapping_algorithm.dart';
import '../utils/risk_translator.dart';
import '../main.dart';

enum ExportAction { download, print, share }

class DailyGraphData {
  final DateTime date;
  double score;
  bool hasSymptom;
  List<String> symptoms;
  List<PantryItem> items;

  DailyGraphData({
    required this.date,
    this.score = 0.0,
    this.hasSymptom = false,
    required this.symptoms,
    required this.items,
  });
}

class InsightsScreen extends StatefulWidget {
  final DatabaseService dbService;
  const InsightsScreen({super.key, required this.dbService});

  @override
  State<InsightsScreen> createState() => _InsightsScreenState();
}

class _InsightsScreenState extends State<InsightsScreen> {
  bool _isLoading = true;

  UserProfile? _userProfile;
  List<PantryItem> _allHistoryLogs = [];

  List<DailyGraphData> _weeklyData = [];
  int _selectedGraphIndex = 6;
  double _dailyCap = 15.0;

  int _selectedHistoryDays = 7;
  String _currentSort = "Newest";
  List<PantryItem> _filteredHistoryLogs = [];
  int _visibleHistoryCount = 5;

  int _totalSymptomLogs = 0;
  List<MapEntry<String, int>> _topTriggers = [];
  String _worstTimeOfDay = "not_enough_data";
  int _emptyStomachFlareUps = 0;
  String _topSymptomName = "no_recent_symptoms";
  int _topSymptomCount = 0;

  Timer? _clockTimer;
  Timer? _carouselTimer;
  Timer? _pauseTimer;

  final PageController _pageController = PageController();
  List<PantryItem> _activeQueue = [];
  int _currentCarouselPage = 0;
  bool _isCarouselPaused = false;

  @override
  void initState() {
    super.initState();
    _fetchBaseData();

    _clockTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        _updateDigestionQueue();
      }
    });

    _startCarouselTimer();
  }

  @override
  void dispose() {
    _clockTimer?.cancel();
    _carouselTimer?.cancel();
    _pauseTimer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  void _startCarouselTimer() {
    _carouselTimer?.cancel();
    _carouselTimer = Timer.periodic(const Duration(seconds: 4), (timer) {
      if (!_isCarouselPaused &&
          _activeQueue.length > 1 &&
          _pageController.hasClients) {
        int nextPage = _currentCarouselPage + 1;
        if (nextPage >= _activeQueue.length) nextPage = 0;

        _pageController.animateToPage(
          nextPage,
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeInOut,
        );
      }
    });
  }

  void _pauseCarouselBriefly() {
    setState(() => _isCarouselPaused = true);
    _pauseTimer?.cancel();
    _pauseTimer = Timer(const Duration(seconds: 8), () {
      if (mounted) setState(() => _isCarouselPaused = false);
    });
  }

  Future<void> _fetchBaseData() async {
    final allItems = await widget.dbService.getPantryItems();
    final profile = await widget.dbService.getUserProfile();

    final consumedItems = allItems.where((item) => item.isConsumed).toList();
    consumedItems.sort((a, b) => b.dateScanned.compareTo(a.dateScanned));

    setState(() {
      _userProfile = profile;
      _dailyCap = profile?.dynamicDailyCap ?? 15.0;
      _allHistoryLogs = consumedItems;
    });

    await _processInteractiveChartData();
    _filterHistoryLogs();
    _updateDigestionQueue();
  }

  void _updateDigestionQueue() {
    final now = DateTime.now();

    List<PantryItem> active = _allHistoryLogs.where((item) {
      final expireTime = item.dateScanned.add(const Duration(hours: 6));
      return expireTime.isAfter(now);
    }).toList();

    active.sort((a, b) => a.dateScanned.compareTo(b.dateScanned));

    if (mounted) {
      setState(() {
        _activeQueue = active;
        if (_activeQueue.isNotEmpty &&
            _currentCarouselPage >= _activeQueue.length) {
          _currentCarouselPage = _activeQueue.length - 1;
        }
      });
    }
  }

  Future<void> _processInteractiveChartData() async {
    DateTime now = DateTime.now();
    DateTime today = DateTime(now.year, now.month, now.day);

    List<DailyGraphData> tempData = [];
    for (int i = 6; i >= 0; i--) {
      tempData.add(DailyGraphData(
          date: today.subtract(Duration(days: i)),
          score: 0.0,
          hasSymptom: false,
          symptoms: [],
          items: []));
    }

    final customTriggers = await widget.dbService.getAllTriggers();
    Map<String, int> dynamicTriggerCounts = {};
    for (var ct in customTriggers) {
      dynamicTriggerCounts[ct.name.toLowerCase()] = 0;
    }

    int symptomCount = 0;
    int emptyStomachCount = 0;
    Map<String, int> timeOfDayCounts = {
      'morning_time': 0,
      'afternoon_time': 0,
      'evening_time': 0,
      'late_night_time': 0,
    };
    Map<String, int> symptomTypeCounts = {};

    for (var item in _allHistoryLogs) {
      DateTime scanDate = DateTime(
          item.dateScanned.year, item.dateScanned.month, item.dateScanned.day);
      int daysAgo = today.difference(scanDate).inDays;

      double trueScore = RiskTranslator.calculateTrueAcidLoad(
          item.acidScore.toDouble(),
          item.portionCount,
          item.portionMeasurement);

      if (daysAgo >= 0 && daysAgo < 7) {
        int index = 6 - daysAgo;
        tempData[index].score += trueScore;
        tempData[index].items.add(item);

        if (item.symptoms.isNotEmpty && item.symptoms != "None") {
          tempData[index].hasSymptom = true;
          if (!tempData[index].symptoms.contains(item.symptoms)) {
            tempData[index].symptoms.add(item.symptoms);
          }
        }
      }

      if (item.symptoms.isNotEmpty && item.symptoms != "None") {
        symptomCount++;
        if (item.isEmptyStomach) emptyStomachCount++;
        symptomTypeCounts[item.symptoms] =
            (symptomTypeCounts[item.symptoms] ?? 0) + 1;

        int hour = item.dateScanned.hour;
        if (hour >= 6 && hour < 12) {
          timeOfDayCounts['morning_time'] =
              timeOfDayCounts['morning_time']! + 1;
        } else if (hour >= 12 && hour < 17) {
          timeOfDayCounts['afternoon_time'] =
              timeOfDayCounts['afternoon_time']! + 1;
        } else if (hour >= 17 && hour < 21) {
          timeOfDayCounts['evening_time'] =
              timeOfDayCounts['evening_time']! + 1;
        } else {
          timeOfDayCounts['late_night_time'] =
              timeOfDayCounts['late_night_time']! + 1;
        }

        String cleanedText = KeywordMappingAlgorithm.cleanRawText(item.rawText);
        for (var trigger in customTriggers) {
          if (KeywordMappingAlgorithm.findFuzzyMatch(
                  cleanedText, trigger.name.toLowerCase())
              .found) {
            dynamicTriggerCounts[trigger.name.toLowerCase()] =
                dynamicTriggerCounts[trigger.name.toLowerCase()]! + 1;
          }
        }
      }
    }

    var sortedTriggers = dynamicTriggerCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    var sortedTimes = timeOfDayCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    String topSymptom = "no_recent_symptoms";
    int topSymptomOccurrences = 0;
    if (symptomTypeCounts.isNotEmpty) {
      var sortedSymp = symptomTypeCounts.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));
      topSymptom = sortedSymp.first.key;
      topSymptomOccurrences = sortedSymp.first.value;
    }

    if (mounted) {
      setState(() {
        _weeklyData = tempData;
        _totalSymptomLogs = symptomCount;
        _topTriggers =
            sortedTriggers.where((e) => e.value > 0).take(3).toList();
        _emptyStomachFlareUps = emptyStomachCount;
        _worstTimeOfDay =
            symptomCount > 0 ? sortedTimes.first.key : "not_enough_data";
        _topSymptomName = topSymptom;
        _topSymptomCount = topSymptomOccurrences;
        _isLoading = false;
      });
    }
  }

  void _filterHistoryLogs() {
    DateTime today = DateTime.now();
    DateTime cutoffDate = today.subtract(Duration(days: _selectedHistoryDays));

    List<PantryItem> filtered = _allHistoryLogs
        .where((item) => item.dateScanned.isAfter(cutoffDate))
        .toList();

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

    setState(() {
      _filteredHistoryLogs = filtered;
      _visibleHistoryCount = 5;
    });
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

  void _showExportOptions(AppColors colors, AppLocalizations loc) {
    showModalBottomSheet(
        context: context,
        backgroundColor: colors.cardColor,
        shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
        builder: (context) => SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(loc.loc('export_clinical_report'),
                        style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: colors.primaryDark)),
                    const SizedBox(height: 10),
                    ListTile(
                      leading: Icon(Icons.file_download, color: colors.primary),
                      title: Text(loc.loc('download_pdf'),
                          style: TextStyle(
                              color: colors.textDark,
                              fontWeight: FontWeight.bold)),
                      subtitle: Text(loc.loc('save_copy_device'),
                          style: TextStyle(color: colors.textGrey)),
                      onTap: () {
                        Navigator.pop(context);
                        _generateRealPDFReport(
                            action: ExportAction.download, loc: loc);
                      },
                    ),
                    ListTile(
                      leading: Icon(Icons.print, color: colors.primary),
                      title: Text(loc.loc('print_pdf'),
                          style: TextStyle(
                              color: colors.textDark,
                              fontWeight: FontWeight.bold)),
                      subtitle: Text(loc.loc('send_wireless_printer'),
                          style: TextStyle(color: colors.textGrey)),
                      onTap: () {
                        Navigator.pop(context);
                        _generateRealPDFReport(
                            action: ExportAction.print, loc: loc);
                      },
                    ),
                    ListTile(
                      leading: Icon(Icons.share, color: colors.primary),
                      title: Text(loc.loc('share_pdf'),
                          style: TextStyle(
                              color: colors.textDark,
                              fontWeight: FontWeight.bold)),
                      subtitle: Text(loc.loc('send_via_social'),
                          style: TextStyle(color: colors.textGrey)),
                      onTap: () {
                        Navigator.pop(context);
                        _generateRealPDFReport(
                            action: ExportAction.share, loc: loc);
                      },
                    ),
                  ],
                ),
              ),
            ));
  }

  Future<void> _generateRealPDFReport(
      {required ExportAction action, required AppLocalizations loc}) async {
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
            pw.Text(
                'Analytics Timeframe: Last $_selectedHistoryDays Days (Sorted by: $_currentSort)'),
            pw.SizedBox(height: 10),
            pw.Text(
                'Patient Profile: ${_userProfile?.clinicalStatus ?? "Preventative"} (${_userProfile?.ageGroup ?? "Unknown Age"})',
                style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
            pw.Text(
                'Primary Goal: ${_userProfile?.primaryGoal ?? "Tracking Limits"}'),
            pw.SizedBox(height: 20),
            pw.Text('Identified Diet Triggers (14-Day Cycle)',
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
            pw.Text('Detailed Consumption Log',
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

    // FIXED: Production-grade readable filename instead of raw epoch timestamp
    final String cleanTimestamp =
        DateFormat('MMM_dd_yyyy').format(DateTime.now());
    final fileName = 'TriggerLens_Report_$cleanTimestamp.pdf';

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
            content: Text(
                loc.loc('downloaded_to_documents', {'file': fileName}),
                style: const TextStyle(
                    fontWeight: FontWeight.bold, color: Colors.white)),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ));
        }
      } catch (e) {
        await Printing.sharePdf(bytes: bytes, filename: fileName);
      }
    }
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

  Widget _buildHistoryChip(
      String fallbackLabel, int days, AppColors colors, AppLocalizations loc) {
    bool isSelected = _selectedHistoryDays == days;

    String displayLabel = fallbackLabel;
    if (days == 14) {
      displayLabel = loc.loc('14_days');
    } else {
      displayLabel = loc.loc(fallbackLabel);
    }

    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        setState(() => _selectedHistoryDays = days);
        _filterHistoryLogs();
      },
      child: Container(
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? colors.primaryDark : colors.cardColor,
          border: Border.all(
              color: isSelected
                  ? colors.primaryDark
                  : (colors.isDark ? Colors.white24 : Colors.grey.shade300)),
          borderRadius: BorderRadius.circular(15),
        ),
        child: Text(displayLabel,
            style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 11,
                color: isSelected ? Colors.white : colors.textDark)),
      ),
    );
  }

  Widget _buildEmptyState(AppColors colors, AppLocalizations loc) {
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.7,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(25),
                  decoration: BoxDecoration(
                    color: colors.primaryLight.withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.auto_graph_rounded,
                      size: 70, color: colors.primary),
                ),
                const SizedBox(height: 30),
                Text(loc.loc('no_insights_yet'),
                    style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                        color: colors.primaryDark)),
                const SizedBox(height: 15),
                Text(loc.loc('no_insights_desc'),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        color: colors.textGrey, height: 1.5, fontSize: 13)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInteractiveChart(AppColors colors, AppLocalizations loc) {
    double maxScore = 0.0;
    if (_weeklyData.isNotEmpty) {
      maxScore = _weeklyData.map((e) => e.score).reduce(max);
    }

    if (maxScore.isNaN || maxScore.isInfinite) maxScore = 15.0;

    double safeCap = _dailyCap;
    if (safeCap.isNaN || safeCap.isInfinite || safeCap <= 0) safeCap = 15.0;

    double yCeiling = max(maxScore, safeCap) * 1.3;
    if (yCeiling <= 0 || yCeiling.isNaN || yCeiling.isInfinite) yCeiling = 15.0;

    double limitBottomOffset = (safeCap / yCeiling) * 160 + 20;
    if (limitBottomOffset.isNaN ||
        limitBottomOffset.isInfinite ||
        limitBottomOffset < 0) {
      limitBottomOffset = 20;
    }

    return Column(
      children: [
        Container(
          height: 220,
          width: double.infinity,
          padding: const EdgeInsets.only(top: 20, right: 10, left: 10),
          decoration: BoxDecoration(
              color: colors.cardColor,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                  color: colors.isDark ? Colors.white12 : Colors.grey.shade200),
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withOpacity(0.02),
                    blurRadius: 10,
                    offset: const Offset(0, 5))
              ]),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Column(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: List.generate(
                    4,
                    (index) => Divider(
                        color: colors.isDark
                            ? Colors.white12
                            : Colors.grey.shade100,
                        thickness: 2)),
              ),
              Positioned(
                bottom: limitBottomOffset,
                left: 0,
                right: 0,
                child: Row(
                  children: [
                    Text(loc.loc('cap_label'),
                        style: TextStyle(
                            fontSize: 8,
                            fontWeight: FontWeight.bold,
                            color: Colors.red.shade300)),
                    const SizedBox(width: 5),
                    Expanded(
                        child: LayoutBuilder(builder: (context, constraints) {
                      int dashCount = constraints.maxWidth.isFinite
                          ? (constraints.maxWidth / 8).floor()
                          : 0;
                      if (dashCount < 0) dashCount = 0;

                      return Flex(
                        direction: Axis.horizontal,
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: List.generate(
                            dashCount,
                            (index) => SizedBox(
                                width: 4,
                                height: 1.5,
                                child: DecoratedBox(
                                    decoration: BoxDecoration(
                                        color: Colors.red.shade300)))),
                      );
                    })),
                  ],
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: _weeklyData.asMap().entries.map((entry) {
                  int idx = entry.key;
                  DailyGraphData data = entry.value;
                  bool isSelected = _selectedGraphIndex == idx;

                  double barHeight = 0;
                  if (!data.score.isNaN && !data.score.isInfinite) {
                    barHeight = (data.score / yCeiling) * 160;
                  }
                  if (barHeight < 0) barHeight = 0;
                  if (barHeight < 4 && data.score > 0) barHeight = 4;
                  if (barHeight > 180) barHeight = 180;

                  return GestureDetector(
                    onTap: () {
                      HapticFeedback.selectionClick();
                      setState(() => _selectedGraphIndex = idx);
                    },
                    child: Container(
                      color: Colors.transparent,
                      width: 40,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          if (data.hasSymptom)
                            const Padding(
                              padding: EdgeInsets.only(bottom: 4),
                              child: Icon(Icons.local_fire_department,
                                  color: Colors.orange, size: 16),
                            ),
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeOut,
                            height: barHeight,
                            width: isSelected ? 24 : 14,
                            decoration: BoxDecoration(
                                color: data.score > safeCap
                                    ? colors.errorRed
                                    : (isSelected
                                        ? colors.primaryDark
                                        : colors.primary),
                                borderRadius: BorderRadius.circular(4),
                                boxShadow: isSelected
                                    ? [
                                        BoxShadow(
                                            color:
                                                colors.primary.withOpacity(0.4),
                                            blurRadius: 8,
                                            offset: const Offset(0, 4))
                                      ]
                                    : []),
                          ),
                          const SizedBox(height: 8),
                          Text(
                              idx == 6
                                  ? loc.loc('today')
                                  : DateFormat('E').format(data.date),
                              style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: isSelected
                                      ? FontWeight.w900
                                      : FontWeight.bold,
                                  color: isSelected
                                      ? colors.primaryDark
                                      : colors.textGrey)),
                          const SizedBox(height: 10),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
        ),
        const SizedBox(height: 15),
        if (_weeklyData.isNotEmpty && _selectedGraphIndex < _weeklyData.length)
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
                color: _weeklyData[_selectedGraphIndex].score > safeCap
                    ? (colors.isDark
                        ? Colors.red.shade900.withOpacity(0.3)
                        : Colors.red.shade50)
                    : colors.primaryLight.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                    color: _weeklyData[_selectedGraphIndex].score > safeCap
                        ? (colors.isDark
                            ? Colors.red.shade900
                            : Colors.red.shade100)
                        : colors.primaryLight.withOpacity(0.3))),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                        _selectedGraphIndex == 6
                            ? loc.loc('todays_breakdown')
                            : DateFormat('EEEE, MMM d')
                                .format(_weeklyData[_selectedGraphIndex].date),
                        style: TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 16,
                            color: colors.textDark)),
                    Text(
                        '${_weeklyData[_selectedGraphIndex].score.toStringAsFixed(1)} Points',
                        style: TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 16,
                            color:
                                _weeklyData[_selectedGraphIndex].score > safeCap
                                    ? colors.errorRed
                                    : colors.primaryDark)),
                  ],
                ),
                const SizedBox(height: 15),
                if (_weeklyData[_selectedGraphIndex].items.isEmpty)
                  Text(loc.loc('no_drinks_this_day'),
                      style: TextStyle(
                          color: colors.textGrey,
                          fontStyle: FontStyle.italic,
                          fontSize: 12))
                else ...[
                  ..._weeklyData[_selectedGraphIndex]
                      .items
                      .map((item) => Padding(
                            padding: const EdgeInsets.only(bottom: 6),
                            child: Row(
                              children: [
                                Icon(Icons.coffee,
                                    size: 12, color: colors.textGrey),
                                const SizedBox(width: 8),
                                Expanded(
                                    child: Text(
                                        "${item.portionCount} ${item.portionMeasurement} ${item.name}",
                                        style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                            color: colors.textDark),
                                        overflow: TextOverflow.ellipsis)),
                              ],
                            ),
                          )),
                  if (_weeklyData[_selectedGraphIndex].hasSymptom) ...[
                    const Divider(height: 20, color: Colors.black12),
                    Row(
                      children: [
                        const Icon(Icons.local_fire_department,
                            size: 14, color: Colors.orange),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                              loc.loc('logged_symptom_list', {
                                'symptoms': _weeklyData[_selectedGraphIndex]
                                    .symptoms
                                    .map((s) => loc.loc(
                                        'symp_${s.toLowerCase().replaceAll(' ', '_')}'))
                                    .join(', ')
                              }),
                              style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: colors.isDark
                                      ? Colors.red.shade200
                                      : Colors.red.shade700)),
                        ),
                      ],
                    )
                  ]
                ]
              ],
            ),
          )
      ],
    );
  }

  // FIXED: Applied dynamic translations to the Insights dropdown as well
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

    if (_isLoading) {
      return Scaffold(
          backgroundColor: colors.background,
          body:
              Center(child: CircularProgressIndicator(color: colors.primary)));
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
            if (Navigator.canPop(context)) {
              Navigator.pop(context);
            } else {
              Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(
                      builder: (context) => MainLayoutScreen(
                          dbService: widget.dbService, initialIndex: 0)),
                  (route) => false);
            }
          },
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.picture_as_pdf, color: colors.primaryDark),
            tooltip: "Export PDF",
            onPressed: () => _showExportOptions(colors, loc),
          )
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          color: colors.primary,
          backgroundColor: colors.cardColor,
          onRefresh: _fetchBaseData,
          child: _allHistoryLogs.isEmpty
              ? _buildEmptyState(colors, loc)
              : SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(
                      parent: BouncingScrollPhysics()),
                  padding: const EdgeInsets.symmetric(horizontal: 25.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(loc.loc('insights'),
                          style: TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.w900,
                              color: colors.primaryDark)),
                      const SizedBox(height: 5),
                      Text(
                          '${loc.loc('profile_label')} ${_userProfile?.clinicalStatus ?? loc.loc('preventative')}',
                          style: TextStyle(
                              fontSize: 14,
                              color: colors.primary,
                              fontWeight: FontWeight.bold)),
                      const SizedBox(height: 30),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(loc.loc('7_day_clinical_trends'),
                                style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w900,
                                    color: colors.textDark)),
                          ),
                          GestureDetector(
                            onTap: () => _showInfoModal(
                                loc.loc('7_day_clinical_trends'),
                                "This chart visualizes your actual acid consumption versus your safe daily limit over the past week.",
                                colors),
                            child: Icon(Icons.info_outline,
                                color: colors.textGrey, size: 18),
                          )
                        ],
                      ),
                      const SizedBox(height: 15),
                      _buildInteractiveChart(colors, loc),
                      const SizedBox(height: 35),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(loc.loc('all_time_lifestyle_patterns'),
                                style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w900,
                                    color: colors.textDark)),
                          ),
                          GestureDetector(
                            onTap: () => _showInfoModal(
                                loc.loc('all_time_lifestyle_patterns'),
                                "The algorithm analyzes all your historical scans to identify specific times, behaviors, and chemical ingredients that consistently trigger flare-ups for you.",
                                colors),
                            child: Icon(Icons.info_outline,
                                color: colors.textGrey, size: 18),
                          )
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.all(15),
                              decoration: BoxDecoration(
                                  color: colors.isDark
                                      ? Colors.orange.shade900.withOpacity(0.3)
                                      : Colors.orange.shade50,
                                  borderRadius: BorderRadius.circular(15)),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Icon(Icons.access_time_filled,
                                      color: colors.isDark
                                          ? Colors.orange.shade200
                                          : Colors.orange.shade400,
                                      size: 24),
                                  const SizedBox(height: 10),
                                  Text(loc.loc('most_vulnerable'),
                                      style: TextStyle(
                                          fontSize: 10,
                                          color: colors.isDark
                                              ? Colors.orange.shade100
                                              : Colors.black54,
                                          fontWeight: FontWeight.bold)),
                                  Text(loc.loc(_worstTimeOfDay),
                                      style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w900,
                                          color: colors.isDark
                                              ? Colors.orange.shade200
                                              : Colors.orange.shade900)),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 15),
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.all(15),
                              decoration: BoxDecoration(
                                  color: colors.isDark
                                      ? Colors.blue.shade900.withOpacity(0.3)
                                      : Colors.blue.shade50,
                                  borderRadius: BorderRadius.circular(15)),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Icon(Icons.no_meals,
                                      color: colors.isDark
                                          ? Colors.blue.shade200
                                          : Colors.blue.shade400,
                                      size: 24),
                                  const SizedBox(height: 10),
                                  Text(loc.loc('empty_stomach_label'),
                                      style: TextStyle(
                                          fontSize: 10,
                                          color: colors.isDark
                                              ? Colors.blue.shade100
                                              : Colors.black54,
                                          fontWeight: FontWeight.bold)),
                                  Text(
                                      loc.loc('flare_ups_count', {
                                        'count':
                                            _emptyStomachFlareUps.toString()
                                      }),
                                      style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w900,
                                          color: colors.isDark
                                              ? Colors.blue.shade200
                                              : Colors.blue.shade900)),
                                ],
                              ),
                            ),
                          )
                        ],
                      ),
                      Container(
                          width: double.infinity,
                          margin: const EdgeInsets.only(top: 15),
                          padding: const EdgeInsets.all(15),
                          decoration: BoxDecoration(
                              color: colors.isDark
                                  ? Colors.red.shade900.withOpacity(0.3)
                                  : Colors.red.shade50,
                              borderRadius: BorderRadius.circular(15)),
                          child: Row(children: [
                            Icon(Icons.medical_information,
                                color: colors.isDark
                                    ? Colors.red.shade200
                                    : Colors.red.shade400,
                                size: 24),
                            const SizedBox(width: 15),
                            Expanded(
                              child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(loc.loc('primary_clinical_symptom'),
                                        style: TextStyle(
                                            fontSize: 10,
                                            color: colors.isDark
                                                ? Colors.red.shade100
                                                : Colors.black54,
                                            fontWeight: FontWeight.bold)),
                                    Text(
                                        _topSymptomName == "no_recent_symptoms"
                                            ? loc.loc('no_recent_symptoms')
                                            : loc.loc('symptom_logs_count', {
                                                'name': loc.loc(
                                                    'symp_${_topSymptomName.toLowerCase().replaceAll(' ', '_')}'),
                                                'count':
                                                    _topSymptomCount.toString()
                                              }),
                                        style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w900,
                                            color: colors.isDark
                                                ? Colors.red.shade200
                                                : Colors.red.shade900)),
                                  ]),
                            )
                          ])),
                      const SizedBox(height: 30),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: colors.primaryLight.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(loc.loc('your_specific_triggers'),
                                style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w900,
                                    color: colors.primaryDark)),
                            const SizedBox(height: 15),
                            if (_totalSymptomLogs == 0 ||
                                _topTriggers.isEmpty) ...[
                              Text(loc.loc('not_enough_data_triggers'),
                                  style: TextStyle(
                                      fontSize: 12,
                                      color: colors.textDark,
                                      fontStyle: FontStyle.italic)),
                            ] else ...[
                              Text(loc.loc('ingredients_repeatedly_appear'),
                                  style: TextStyle(
                                      fontSize: 12,
                                      color: colors.textDark,
                                      height: 1.4)),
                              const SizedBox(height: 15),
                              ..._topTriggers.map((trigger) {
                                return Container(
                                  margin: const EdgeInsets.only(bottom: 10),
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                      color: colors.cardColor,
                                      borderRadius: BorderRadius.circular(12)),
                                  child: Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Expanded(
                                        child: Text(trigger.key.toUpperCase(),
                                            style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                                color: colors.textDark)),
                                      ),
                                      Text(
                                          loc.loc('incidents_count', {
                                            'count': trigger.value.toString()
                                          }),
                                          style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              color: colors.errorRed)),
                                    ],
                                  ),
                                );
                              }),
                            ]
                          ],
                        ),
                      ),
                      const SizedBox(height: 30),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(loc.loc('session_tracker'),
                                style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w900,
                                    color: colors.primaryDark)),
                          ),
                          GestureDetector(
                            onTap: () => _showInfoModal(
                                loc.loc('session_tracker'),
                                "Your stomach takes approximately 6 hours to fully digest and neutralize the acid impact of a beverage. This tracks the active timeline.",
                                colors),
                            child: Icon(Icons.info_outline,
                                color: colors.textGrey, size: 18),
                          )
                        ],
                      ),
                      const SizedBox(height: 20),
                      if (_activeQueue.isEmpty)
                        Column(
                          children: [
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
                                        value: 0.0,
                                        strokeWidth: 8,
                                        backgroundColor: colors.primaryLight
                                            .withOpacity(0.3),
                                        color: colors.primary,
                                        strokeCap: StrokeCap.round,
                                      ),
                                    ),
                                    Image.asset('assets/images/clock.png',
                                        width: 24, color: colors.primaryDark)
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 15),
                            Text('00 : 00 : 00',
                                style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w900,
                                    color: colors.primaryDark)),
                            Text(loc.loc('hr_mn_sec'),
                                style: TextStyle(
                                    fontSize: 8,
                                    fontWeight: FontWeight.bold,
                                    color: colors.primaryDark)),
                            const SizedBox(height: 12),
                            Text(loc.loc('stomach_empty'),
                                style: const TextStyle(
                                    fontSize: 13,
                                    color: Colors.green,
                                    fontWeight: FontWeight.w900)),
                          ],
                        )
                      else
                        SizedBox(
                          height: 260,
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              PageView.builder(
                                  controller: _pageController,
                                  onPageChanged: (idx) {
                                    setState(() => _currentCarouselPage = idx);
                                    _pauseCarouselBriefly();
                                  },
                                  itemCount: _activeQueue.length,
                                  itemBuilder: (context, index) {
                                    final item = _activeQueue[index];
                                    final expireTime = item.dateScanned
                                        .add(const Duration(hours: 6));
                                    Duration remaining =
                                        expireTime.difference(DateTime.now());
                                    if (remaining.isNegative) {
                                      remaining = Duration.zero;
                                    }

                                    String hr = remaining.inHours
                                        .toString()
                                        .padLeft(2, '0');
                                    String mn = (remaining.inMinutes % 60)
                                        .toString()
                                        .padLeft(2, '0');
                                    String sc = (remaining.inSeconds % 60)
                                        .toString()
                                        .padLeft(2, '0');
                                    double timerProgress =
                                        remaining.inSeconds > 0
                                            ? remaining.inSeconds / 21600
                                            : 0.0;

                                    return Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        SizedBox(
                                          width: 120,
                                          height: 120,
                                          child: Stack(
                                            alignment: Alignment.center,
                                            children: [
                                              SizedBox(
                                                width: 120,
                                                height: 120,
                                                child:
                                                    CircularProgressIndicator(
                                                  value: timerProgress,
                                                  strokeWidth: 8,
                                                  backgroundColor: colors
                                                      .primaryLight
                                                      .withOpacity(0.3),
                                                  color: colors.primary,
                                                  strokeCap: StrokeCap.round,
                                                ),
                                              ),
                                              Image.asset(
                                                  'assets/images/clock.png',
                                                  width: 24,
                                                  color: colors.primaryDark)
                                            ],
                                          ),
                                        ),
                                        const SizedBox(height: 15),
                                        Text('$hr : $mn : $sc',
                                            style: TextStyle(
                                                fontSize: 16,
                                                fontWeight: FontWeight.w900,
                                                color: colors.primaryDark)),
                                        Text(loc.loc('hr_mn_sec'),
                                            style: TextStyle(
                                                fontSize: 8,
                                                fontWeight: FontWeight.bold,
                                                color: colors.primaryDark)),
                                        const SizedBox(height: 12),
                                        Padding(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 40.0),
                                          child: Text(
                                              loc.loc('currently_digesting',
                                                  {'drink': item.name}),
                                              textAlign: TextAlign.center,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: TextStyle(
                                                  fontSize: 13,
                                                  color: colors.primaryDark,
                                                  fontWeight: FontWeight.w900)),
                                        ),
                                        Padding(
                                          padding:
                                              const EdgeInsets.only(top: 4.0),
                                          child: Text(
                                              loc.loc('queue_position', {
                                                'current':
                                                    (index + 1).toString(),
                                                'total': _activeQueue.length
                                                    .toString()
                                              }),
                                              style: TextStyle(
                                                  fontSize: 11,
                                                  color: colors.textGrey,
                                                  fontWeight: FontWeight.bold)),
                                        ),
                                      ],
                                    );
                                  }),
                              if (_activeQueue.length > 1)
                                Positioned(
                                  left: 0,
                                  child: IconButton(
                                    icon: Icon(Icons.chevron_left,
                                        size: 36, color: colors.primary),
                                    onPressed: () {
                                      _pauseCarouselBriefly();
                                      _pageController.previousPage(
                                          duration:
                                              const Duration(milliseconds: 300),
                                          curve: Curves.easeInOut);
                                    },
                                  ),
                                ),
                              if (_activeQueue.length > 1)
                                Positioned(
                                  right: 0,
                                  child: IconButton(
                                    icon: Icon(Icons.chevron_right,
                                        size: 36, color: colors.primary),
                                    onPressed: () {
                                      _pauseCarouselBriefly();
                                      _pageController.nextPage(
                                          duration:
                                              const Duration(milliseconds: 300),
                                          curve: Curves.easeInOut);
                                    },
                                  ),
                                ),
                            ],
                          ),
                        ),
                      const SizedBox(height: 40),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(loc.loc('history_log'),
                              style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w900,
                                  color: colors.primaryDark)),
                          Text(
                              loc.loc('entries_count', {
                                'count': _filteredHistoryLogs.length.toString()
                              }),
                              style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.grey)),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
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
                                Icon(Icons.sort,
                                    color: colors.primaryDark, size: 16),
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
                                        child: Text(
                                            loc.loc(_getDropdownKey(value))),
                                      );
                                    }).toList(),
                                    onChanged: (newValue) {
                                      if (newValue != null) {
                                        HapticFeedback.lightImpact();
                                        setState(() => _currentSort = newValue);
                                        _filterHistoryLogs();
                                      }
                                    },
                                  ),
                                ),
                              ],
                            ),
                          )
                        ],
                      ),
                      const SizedBox(height: 15),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            _buildHistoryChip('1_day', 1, colors, loc),
                            _buildHistoryChip('3_days', 3, colors, loc),
                            _buildHistoryChip('7_days', 7, colors, loc),
                            _buildHistoryChip('14_days', 14, colors, loc),
                          ],
                        ),
                      ),
                      const SizedBox(height: 15),
                      Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                              color: colors.isDark
                                  ? Colors.grey[900]
                                  : Colors.grey[100],
                              borderRadius: BorderRadius.circular(10)),
                          child: Row(children: [
                            Icon(Icons.auto_delete_outlined,
                                size: 16, color: colors.textGrey),
                            const SizedBox(width: 8),
                            Expanded(
                                child: Text(
                                    "Heuristic logs are automatically purged after 14 days for optimal performance and privacy.",
                                    style: TextStyle(
                                        fontSize: 10,
                                        color: colors.textGrey,
                                        fontStyle: FontStyle.italic))),
                          ])),
                      const SizedBox(height: 15),
                      _filteredHistoryLogs.isEmpty
                          ? Center(
                              child: Padding(
                              padding: const EdgeInsets.all(20.0),
                              child: Text(loc.loc('no_drinks_logged'),
                                  style: TextStyle(color: colors.textGrey)),
                            ))
                          : ListView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: min(_filteredHistoryLogs.length,
                                  _visibleHistoryCount),
                              itemBuilder: (context, index) {
                                final item = _filteredHistoryLogs[index];
                                final formattedTime =
                                    DateFormat('MMM dd, yyyy • h:mm a')
                                        .format(item.dateScanned);
                                bool hasSymptom = item.symptoms.isNotEmpty &&
                                    item.symptoms != "None";
                                Color riskColor =
                                    _getRiskColor(item.riskLevel, colors);

                                return Container(
                                  margin: const EdgeInsets.only(bottom: 12),
                                  padding: const EdgeInsets.all(15),
                                  decoration: BoxDecoration(
                                      color: colors.cardColor,
                                      borderRadius: BorderRadius.circular(15),
                                      border: Border.all(
                                          color: colors.isDark
                                              ? Colors.white12
                                              : Colors.grey.shade100),
                                      boxShadow: [
                                        BoxShadow(
                                            color:
                                                Colors.black.withOpacity(0.02),
                                            blurRadius: 5,
                                            offset: const Offset(0, 2))
                                      ]),
                                  child: Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Container(
                                        margin: const EdgeInsets.only(
                                            top: 5, right: 15),
                                        width: 12,
                                        height: 12,
                                        decoration: BoxDecoration(
                                            color: riskColor,
                                            shape: BoxShape.circle),
                                      ),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(item.name,
                                                style: TextStyle(
                                                    fontSize: 16,
                                                    fontWeight: FontWeight.w900,
                                                    color: colors.primaryDark),
                                                overflow:
                                                    TextOverflow.ellipsis),
                                            const SizedBox(height: 4),
                                            Text(formattedTime,
                                                style: const TextStyle(
                                                    fontSize: 11,
                                                    fontWeight: FontWeight.bold,
                                                    color: Colors.grey)),
                                            if (hasSymptom) ...[
                                              const SizedBox(height: 8),
                                              Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                        horizontal: 8,
                                                        vertical: 4),
                                                decoration: BoxDecoration(
                                                    color: colors.isDark
                                                        ? Colors.red.shade900
                                                            .withOpacity(0.3)
                                                        : Colors.red.shade50,
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            8)),
                                                child: Text(
                                                    '🔥 ${loc.loc('symp_${item.symptoms.toLowerCase().replaceAll(' ', '_')}')}',
                                                    style: TextStyle(
                                                        fontSize: 10,
                                                        fontWeight:
                                                            FontWeight.bold,
                                                        color: colors.isDark
                                                            ? Colors
                                                                .red.shade200
                                                            : Colors
                                                                .red.shade700)),
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
                      if (_filteredHistoryLogs.length > _visibleHistoryCount)
                        Center(
                          child: TextButton.icon(
                            onPressed: () {
                              setState(() {
                                _visibleHistoryCount += 5;
                              });
                            },
                            icon: Icon(Icons.keyboard_arrow_down,
                                color: colors.primaryDark),
                            label: Text(loc.loc('see_more'),
                                style: TextStyle(
                                    color: colors.primaryDark,
                                    fontWeight: FontWeight.bold)),
                          ),
                        ),
                      const SizedBox(height: 100),
                    ],
                  ),
                ),
        ),
      ),
    );
  }
}
