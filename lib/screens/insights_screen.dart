import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import '../services/database_service.dart';
import '../models/pantry_item.dart';
import '../utils/ui_helpers.dart';

class InsightsScreen extends StatefulWidget {
  final DatabaseService dbService;
  const InsightsScreen({super.key, required this.dbService});

  @override
  State<InsightsScreen> createState() => _InsightsScreenState();
}

class _InsightsScreenState extends State<InsightsScreen> {
  bool _isLoading = true;

  // Graph Data (Last 5 Days of Acid Scores)
  List<double> _dailyScores = List.filled(5, 0.0);

  // Correlation Data
  int _totalSymptomLogs = 0;
  List<MapEntry<String, int>> _topTriggers = [];

  // Session Timer Data
  Timer? _timer;
  Duration _timeRemaining = Duration.zero;

  @override
  void initState() {
    super.initState();
    _loadInsightsData();

    // Sync timer every second
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_timeRemaining.inSeconds > 0) {
        setState(() {
          _timeRemaining = _timeRemaining - const Duration(seconds: 1);
        });
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _loadInsightsData() async {
    final allItems = await widget.dbService.getPantryItems();
    final now = DateTime.now();

    // 1. CALCULATE GRAPH DATA (Last 5 Days)
    List<double> tempScores = List.filled(5, 0.0);
    DateTime today = DateTime(now.year, now.month, now.day);

    // 2. CORRELATION DATA MINING
    int symptomCount = 0;
    Map<String, int> triggerCounts = {
      'Dairy / Milk': 0,
      'Coffee / Caffeine': 0,
      'Citric Acid / Vit C': 0,
      'Palm Oil / Fats': 0,
      'Chocolate / Cocoa': 0,
    };

    // 3. SESSION TIMER TRACKING
    DateTime? latestScanTime;

    for (var item in allItems) {
      // --- Timer Logic ---
      if (latestScanTime == null || item.dateScanned.isAfter(latestScanTime)) {
        latestScanTime = item.dateScanned;
      }

      // --- Graph Logic ---
      DateTime scanDate = DateTime(
          item.dateScanned.year, item.dateScanned.month, item.dateScanned.day);
      int daysAgo = today.difference(scanDate).inDays;
      if (daysAgo >= 0 && daysAgo < 5) {
        // Index 4 is Today, Index 0 is 4 days ago
        tempScores[4 - daysAgo] += item.acidScore.toDouble();
      }

      // --- Correlation Logic ---
      if (item.symptoms.isNotEmpty && item.symptoms != "None") {
        symptomCount++;
        String text = item.rawText.toLowerCase();

        if (text.contains('milk') ||
            text.contains('dairy') ||
            text.contains('whey')) {
          triggerCounts['Dairy / Milk'] = triggerCounts['Dairy / Milk']! + 1;
        }
        if (text.contains('coffee') || text.contains('caffeine')) {
          triggerCounts['Coffee / Caffeine'] =
              triggerCounts['Coffee / Caffeine']! + 1;
        }
        if (text.contains('citric') ||
            text.contains('vitamin c') ||
            text.contains('ascorbic')) {
          triggerCounts['Citric Acid / Vit C'] =
              triggerCounts['Citric Acid / Vit C']! + 1;
        }
        if (text.contains('palm oil') || text.contains('creamer')) {
          triggerCounts['Palm Oil / Fats'] =
              triggerCounts['Palm Oil / Fats']! + 1;
        }
        if (text.contains('chocolate') ||
            text.contains('cocoa') ||
            text.contains('cacao')) {
          triggerCounts['Chocolate / Cocoa'] =
              triggerCounts['Chocolate / Cocoa']! + 1;
        }
      }
    }

    // Set Timer
    if (latestScanTime != null) {
      final expireTime = latestScanTime.add(const Duration(hours: 6));
      _timeRemaining = expireTime.difference(now);
      if (_timeRemaining.isNegative) _timeRemaining = Duration.zero;
    }

    // Sort Triggers by frequency
    var sortedTriggers = triggerCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value)); // Highest first

    if (mounted) {
      setState(() {
        _dailyScores = tempScores;
        _totalSymptomLogs = symptomCount;
        _topTriggers = sortedTriggers
            .where((e) => e.value > 0)
            .take(2)
            .toList(); // Only show top 2
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: AppColors.background,
        body:
            Center(child: CircularProgressIndicator(color: AppColors.primary)),
      );
    }

    String hr = _timeRemaining.inHours.toString().padLeft(2, '0');
    String mn = (_timeRemaining.inMinutes % 60).toString().padLeft(2, '0');
    String sc = (_timeRemaining.inSeconds % 60).toString().padLeft(2, '0');

    // Calculate 6-hour progress (21600 total seconds)
    double timerProgress = 0.0;
    if (_timeRemaining.inSeconds > 0) {
      timerProgress = _timeRemaining.inSeconds / 21600;
    }

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
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 30.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Insights',
                  style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                      color: AppColors.primaryDark)),
              const SizedBox(height: 5),
              const Text('Your acid load patterns over the last 5 days',
                  style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textDark,
                      fontWeight: FontWeight.w500)),
              const SizedBox(height: 30),

              // DYNAMIC GRAPH
              Container(
                width: double.infinity,
                height: 180,
                decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                        color: Colors.black12, width: 1.5), // Softer border
                    boxShadow: [
                      BoxShadow(
                          color: Colors.grey.withOpacity(0.05), blurRadius: 10)
                    ]),
                child: CustomPaint(painter: _GraphPainter(data: _dailyScores)),
              ),

              const SizedBox(height: 25),

              // DYNAMIC CORRELATION CARD
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.white,
                        AppColors.primaryLight
                            .withOpacity(0.4) // Softer pastel transition
                      ],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                    borderRadius: BorderRadius.circular(15),
                    boxShadow: [
                      BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 10,
                          offset: const Offset(0, 5))
                    ]),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Ingredient ↔ Symptom Correlation',
                        style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w900,
                            color: AppColors.primaryDark)),
                    const SizedBox(height: 15),
                    if (_totalSymptomLogs == 0 || _topTriggers.isEmpty) ...[
                      const Text('Not enough data yet.',
                          style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textDark)),
                      const SizedBox(height: 5),
                      const Text(
                        'Keep scanning sachets and logging your symptoms to generate your personalized trigger insights!',
                        style: TextStyle(
                            fontSize: 11,
                            color: AppColors.textDark,
                            height: 1.4),
                      ),
                    ] else ...[
                      const Text('Correlation Detected:',
                          style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w900,
                              color: AppColors.textDark)),
                      const SizedBox(height: 5),
                      Text(
                        'Based on your $_totalSymptomLogs recent symptom logs, our algorithm has identified highly probable links between specific ingredients and your acid rebound responses.',
                        style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.textDark,
                            height: 1.4),
                      ),
                      const SizedBox(height: 15),
                      const Text('Your Specific Triggers:',
                          style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w900,
                              color: AppColors.textDark)),
                      const SizedBox(height: 10),

                      // Dynamically render the top 2 offending triggers
                      ..._topTriggers.map((trigger) {
                        int percent =
                            ((trigger.value / _totalSymptomLogs) * 100).round();
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildBullet(trigger.key),
                            _buildBullet(
                                '$percent% Flare-up association rate. Found in ${trigger.value} of your problematic scans.'),
                            const SizedBox(height: 10),
                          ],
                        );
                      }),
                    ]
                  ],
                ),
              ),
              const SizedBox(height: 30),

              // LIVE SESSION TRACKER
              const Align(
                alignment: Alignment.centerLeft,
                child: Text('Session Tracker',
                    style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        color: AppColors.primaryDark)), // Replaced accentCyan
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
              const SizedBox(height: 100),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBullet(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 2, left: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('• ',
              style: TextStyle(
                  fontSize: 12,
                  color: AppColors.textDark,
                  fontWeight: FontWeight.bold)),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                  fontSize: 11, color: AppColors.textDark, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }
}

// THE DYNAMIC GRAPH PAINTER
class _GraphPainter extends CustomPainter {
  final List<double> data; // List of exactly 5 data points
  _GraphPainter({required this.data});

  @override
  void paint(Canvas canvas, Size size) {
    final gridPaint = Paint()
      ..color = Colors.black12
      ..strokeWidth = 1;

    final linePaint = Paint()
      ..color = AppColors.primaryDark
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke;

    final dotPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;

    final dotBorderPaint = Paint()
      ..color = AppColors.primaryDark
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke;

    // Draw Background Grid
    for (int i = 1; i < 5; i++) {
      double x = (size.width / 4) * i;
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
    }
    for (int i = 1; i < 4; i++) {
      double y = (size.height / 4) * i;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    // Determine the highest value in our dataset to scale the Y axis dynamically
    double maxData = data.reduce(max);
    if (maxData < 10) maxData = 10; // Give it a baseline if scores are low

    // Calculate dynamic coordinates
    List<Offset> points = [];
    for (int i = 0; i < 5; i++) {
      double x = (size.width / 4) * i; // Distribute evenly across X axis

      // Calculate Y: Invert it because 0 is at the top of the canvas.
      // Leave a 20% margin at the top so the line doesn't hit the ceiling.
      double y = size.height - ((data[i] / maxData) * (size.height * 0.8));

      // Ensure it doesn't dip below the floor
      if (y > size.height - 10) y = size.height - 10;

      points.add(Offset(x, y));
    }

    // Draw the continuous connecting Line
    final path = Path();
    path.moveTo(points[0].dx, points[0].dy);
    for (int i = 1; i < points.length; i++) {
      path.lineTo(points[i].dx, points[i].dy);
    }
    canvas.drawPath(path, linePaint);

    // Draw the specific data Dots on top of the line
    for (var point in points) {
      canvas.drawCircle(point, 6, dotPaint);
      canvas.drawCircle(point, 6, dotBorderPaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) =>
      true; // Always repaint when data changes
}
