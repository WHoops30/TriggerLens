import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/database_service.dart';
import '../services/notification_service.dart';
import '../models/pantry_item.dart';
import '../models/user_profile.dart';
import '../models/daily_log.dart';
import '../utils/ui_helpers.dart';
import '../utils/risk_calculator.dart';
import 'profile_screen.dart';
import 'scanner_screen.dart';
import 'digital_pantry_screen.dart';
import 'coach_screen.dart';

class DashboardScreen extends StatefulWidget {
  final DatabaseService dbService;
  const DashboardScreen({super.key, required this.dbService});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  bool _showNotifications = false;
  bool _hasUnreadNotifications = false;

  final Set<String> _dismissedNotifIds = {};

  Timer? _timer;
  Duration _timeRemaining = Duration.zero;
  int _cumulativeScore = 0;
  double _riskPercentage = 0.0;
  List<PantryItem> _recentScans = [];
  int _totalScans = 0;
  int _symptomCount = 0;

  User? _currentUser;
  UserProfile? _userProfile;

  double _activeDailyCap = 15.0;
  String _currentMentalState = "Relaxed";

  List<Map<String, dynamic>> _generatedNotifications = [];

  final List<String> _gerdFacts = [
    "Sleeping on your left side helps keep stomach acid away from your esophagus.",
    "Chewing sugar-free gum increases saliva, which naturally neutralizes acid.",
    "Eating smaller, more frequent meals reduces pressure on your stomach valve.",
    "Avoid lying down for at least 3 hours after eating or drinking.",
    "Tight clothing around your waist can push stomach acid upward.",
    "Drinking water slowly is better than chugging, which can overfill the stomach.",
    "Elevating the head of your bed by 6-8 inches can prevent nighttime reflux.",
    "Stress can increase your stomach's sensitivity to small amounts of acid.",
    "Wait 30 minutes after a meal before exercising to avoid acid splash.",
    "Bananas and melons are naturally low-acid fruits that can soothe the stomach.",
    "Oatmeal is excellent for absorbing excess stomach acid.",
    "Smoking weakens the valve that keeps stomach acid out of the esophagus.",
    "Carbonated beverages increase stomach pressure and trigger burping.",
    "Aloe vera juice (unsweetened) can help coat and soothe the esophageal lining.",
    "Ginger tea is a natural anti-inflammatory that aids digestion.",
    "Late-night snacking is a major trigger for morning acid reflux.",
    "Excess weight puts extra pressure on your abdomen, pushing acid up.",
    "Peppermint can actually relax the stomach valve and worsen reflux. Use caution!",
    "Drinking a glass of lukewarm water in the morning helps flush the digestive system.",
    "Acid reflux isn't always heartburn—chronic coughing or a sore throat can be symptoms."
  ];

  @override
  void initState() {
    super.initState();
    _currentUser = FirebaseAuth.instance.currentUser;
    _loadDashboardData();

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_timeRemaining.inSeconds > 0) {
        setState(() {
          _timeRemaining = _timeRemaining - const Duration(seconds: 1);
        });
      } else if (_timeRemaining.inSeconds <= 0 && _cumulativeScore > 0) {
        _loadDashboardData();
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String _getFirstName() {
    if (_currentUser?.displayName != null &&
        _currentUser!.displayName!.trim().isNotEmpty) {
      return _currentUser!.displayName!.split(' ').first;
    }
    if (_currentUser?.email != null && _currentUser!.email!.isNotEmpty) {
      return _currentUser!.email!.split('@').first;
    }
    return "There";
  }

  void _addNotificationIfNew(Map<String, dynamic> notif) {
    if (!_dismissedNotifIds.contains(notif['id'])) {
      _generatedNotifications.add(notif);
    }
  }

  void _generateNotifications() {
    int previousCount = _generatedNotifications.length;
    _generatedNotifications.clear();

    if (_currentMentalState != "Relaxed") {
      _addNotificationIfNew({
        'id': 'stress_penalty',
        'title': 'Stress Penalty Active',
        'subtitle':
            'Your acid tolerance is temporarily reduced by 15% to protect your sensitive stomach.',
        'icon': Icons.psychology_alt,
        'color': Colors.deepOrange,
        'action': null,
      });
    }

    if (_riskPercentage >= 80) {
      _addNotificationIfNew({
        'id': 'threshold_warning',
        'title': 'Threshold Warning',
        'subtitle':
            'You are at ${_riskPercentage.toInt()}% of your daily limit. Switch to water for your next drink!',
        'icon': Icons.warning_amber_rounded,
        'color': Colors.red,
        'action': 'coach',
      });
    }

    if (_timeRemaining.inSeconds == 0 && _recentScans.isNotEmpty) {
      _addNotificationIfNew({
        'id': 'digestion_complete',
        'title': 'Digestion Complete',
        'subtitle':
            'It has been 4 hours since your last drink. Your active stomach load has reset.',
        'icon': Icons.check_circle_outline,
        'color': Colors.green,
        'action': null,
      });
    } else if (_timeRemaining.inHours > 0 && _timeRemaining.inHours < 2) {
      _addNotificationIfNew({
        'id': 'digestion_progress',
        'title': 'Digestion in Progress',
        'subtitle':
            'Less than 2 hours remaining until your last drink is fully digested.',
        'icon': Icons.hourglass_bottom,
        'color': AppColors.accentOrange,
        'action': null,
      });
    }

    if (_recentScans.isNotEmpty) {
      final lastDrink = _recentScans.first;
      if ((lastDrink.riskLevel == "RED" || lastDrink.riskLevel == "YELLOW") &&
          (lastDrink.symptoms.isEmpty || lastDrink.symptoms == "None")) {
        _addNotificationIfNew({
          'id': 'symptom_check_${lastDrink.id}',
          'title': 'Symptom Check-In',
          'subtitle':
              'How are you feeling after drinking ${lastDrink.name}? Log any discomfort to recalibrate your safe limit.',
          'icon': Icons.local_fire_department,
          'color': Colors.orange,
          'action': 'pantry',
        });
      }
    }

    _addNotificationIfNew({
      'id': 'scan_prompt',
      'title': 'Ready for a drink?',
      'subtitle': 'Scan a new sachet to check its acid load before consuming.',
      'icon': Icons.qr_code_scanner,
      'color': AppColors.primary,
      'action': 'scan',
    });

    _addNotificationIfNew({
      'id': 'health_tip',
      'title': 'Quick Health Tip',
      'subtitle': _gerdFacts[DateTime.now().day % _gerdFacts.length],
      'icon': Icons.lightbulb_outline,
      'color': Colors.blueAccent,
      'action': null,
    });

    if (_generatedNotifications.length > previousCount && !_showNotifications) {
      _hasUnreadNotifications = true;
    }
  }

  Future<void> _loadDashboardData() async {
    final allItems = await widget.dbService.getPantryItems();
    final profile = await widget.dbService.getUserProfile();
    final logs = await widget.dbService.getDailyLogs();
    final now = DateTime.now();

    DailyLog? todayLog;
    for (var log in logs) {
      if (log.date.year == now.year &&
          log.date.month == now.month &&
          log.date.day == now.day) {
        todayLog = log;
      }
    }
    String mentalState = todayLog?.mentalState ?? "Relaxed";

    double baseCap = profile?.baseDailyCap ?? 15.0;
    if (baseCap.isNaN || baseCap.isInfinite || baseCap <= 0) {
      baseCap = 15.0;
    }

    double activeCap = baseCap;
    if (mentalState == "Stressed" ||
        mentalState == "Anxious" ||
        mentalState == "Exhausted") {
      activeCap = baseCap * 0.85;
    }

    int symptomLogs = 0;
    DateTime? latestScanTime;

    for (var item in allItems) {
      if (item.symptoms.isNotEmpty && item.symptoms != "None") {
        symptomLogs++;
      }

      final difference = now.difference(item.dateScanned);
      if (difference.inHours < 4) {
        if (latestScanTime == null ||
            item.dateScanned.isAfter(latestScanTime)) {
          latestScanTime = item.dateScanned;
        }
      }
    }

    if (latestScanTime != null) {
      final expireTime = latestScanTime.add(const Duration(hours: 4));
      _timeRemaining = expireTime.difference(now);
      if (_timeRemaining.isNegative) _timeRemaining = Duration.zero;
    } else {
      _timeRemaining = Duration.zero;
    }

    double tempScore = RiskCalculator.calculateActiveLoad(allItems);
    if (tempScore.isNaN || tempScore.isInfinite) tempScore = 0.0;

    double tempPercent = 0.0;
    if (activeCap <= 0.0) {
      tempPercent = tempScore > 0 ? 100.0 : 0.0;
    } else {
      tempPercent = (tempScore / activeCap) * 100;
    }

    if (tempPercent.isNaN || tempPercent.isInfinite) tempPercent = 0.0;
    if (tempPercent > 100) tempPercent = 100;

    if (mounted) {
      setState(() {
        _userProfile = profile;
        _totalScans = allItems.length;
        _symptomCount = symptomLogs;
        _recentScans = allItems.take(3).toList();
        _cumulativeScore = tempScore.round();
        _riskPercentage = tempPercent;
        _currentMentalState = mentalState;
        _activeDailyCap = activeCap;

        _generateNotifications();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    String hr = _timeRemaining.inHours.toString().padLeft(2, '0');
    String mn = (_timeRemaining.inMinutes % 60).toString().padLeft(2, '0');
    String sc = (_timeRemaining.inSeconds % 60).toString().padLeft(2, '0');

    Color riskGradientStart = AppColors.primaryLight;
    Color riskGradientEnd = AppColors.primaryDark;

    if (_riskPercentage >= 80) {
      riskGradientStart = Colors.redAccent;
      riskGradientEnd = AppColors.errorRed;
    } else if (_riskPercentage >= 40) {
      riskGradientStart = Colors.orangeAccent;
      riskGradientEnd = AppColors.accentOrange;
    }

    String targetLabel = _activeDailyCap <= 0.0
        ? "TARGET: STRICT (<= 0.0)"
        : "CAP: ${_activeDailyCap.toStringAsFixed(1)} PRAL";

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Stack(
          children: [
            SingleChildScrollView(
              padding:
                  const EdgeInsets.symmetric(horizontal: 25.0, vertical: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Text('Trigger',
                              style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w900,
                                  color: AppColors.primaryDark)),
                          const Text('Lens',
                              style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w400,
                                  color: AppColors.primaryDark)),
                          const SizedBox(width: 5),
                          Image.asset('assets/images/triggerlens_icon.png',
                              width: 30),
                        ],
                      ),
                      Row(
                        children: [
                          GestureDetector(
                            onTap: () {
                              setState(() {
                                _showNotifications = true;
                                _hasUnreadNotifications = false;
                              });
                            },
                            child: Stack(
                              clipBehavior: Clip.none,
                              children: [
                                Image.asset('assets/images/active.png',
                                    width: 35),
                                if (_hasUnreadNotifications &&
                                    _generatedNotifications.isNotEmpty)
                                  Positioned(
                                    right: 2,
                                    top: 0,
                                    child: Container(
                                      padding: const EdgeInsets.all(4),
                                      decoration: const BoxDecoration(
                                        color: Colors.red,
                                        shape: BoxShape.circle,
                                      ),
                                      child: Text(
                                        '${_generatedNotifications.length}',
                                        style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 9,
                                            fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                  )
                              ],
                            ),
                          ),
                          const SizedBox(width: 15),
                          GestureDetector(
                            onTap: () async {
                              await Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                      builder: (context) => ProfileScreen(
                                          dbService: widget.dbService)));
                              _loadDashboardData();
                            },
                            child: Container(
                              width: 55,
                              height: 55,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: AppColors.primaryLight.withOpacity(0.3),
                              ),
                              child: ClipOval(
                                  child: _currentUser?.photoURL != null
                                      ? Image.network(_currentUser!.photoURL!,
                                          fit: BoxFit.cover,
                                          errorBuilder: (_, __, ___) =>
                                              Image.asset(
                                                  'assets/images/man.png',
                                                  fit: BoxFit.cover))
                                      : Image.asset('assets/images/man.png',
                                          fit: BoxFit.cover)),
                            ),
                          ),
                        ],
                      )
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text('Hi ${_getFirstName()}!',
                      style: const TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.w900,
                          color: AppColors.textDark)),
                  if (_currentMentalState != "Relaxed") ...[
                    const SizedBox(height: 5),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                          color: Colors.orange.shade50,
                          borderRadius: BorderRadius.circular(15),
                          border: Border.all(color: Colors.orange.shade200)),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.warning_amber_rounded,
                              size: 14, color: Colors.deepOrange),
                          const SizedBox(width: 6),
                          Text('Stress Penalty: Acid tolerance reduced by 15%',
                              style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.orange.shade900)),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 20),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(25),
                    decoration: BoxDecoration(
                        gradient: LinearGradient(
                            colors: [riskGradientStart, riskGradientEnd]),
                        borderRadius: BorderRadius.circular(25),
                        boxShadow: [
                          BoxShadow(
                              color: riskGradientEnd.withOpacity(0.3),
                              blurRadius: 15,
                              offset: const Offset(0, 8))
                        ]),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Expanded(
                              child: Text('CUMULATIVE RISK',
                                  style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w900)),
                            ),
                            Row(
                              children: [
                                Text('$hr : $mn : $sc',
                                    style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 16,
                                        fontWeight: FontWeight.w900)),
                                const SizedBox(width: 8),
                                const Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('HR   MN   SEC',
                                        style: TextStyle(
                                            color: Colors.white70,
                                            fontSize: 7,
                                            fontWeight: FontWeight.bold)),
                                  ],
                                )
                              ],
                            )
                          ],
                        ),
                        const SizedBox(height: 5),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Text('${_riskPercentage.toInt()}%',
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 36,
                                    fontWeight: FontWeight.w900)),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                    color: Colors.black.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(8)),
                                child: Text(
                                  targetLabel,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 15),
                        Stack(
                          alignment: Alignment.centerLeft,
                          children: [
                            Container(
                                width: double.infinity,
                                height: 12,
                                decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(10))),
                            Container(
                                width: MediaQuery.of(context).size.width *
                                    0.8 *
                                    (_riskPercentage / 100),
                                height: 12,
                                decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(10))),
                            if (_riskPercentage > 0)
                              Positioned(
                                left: (MediaQuery.of(context).size.width *
                                        0.8 *
                                        (_riskPercentage / 100)) -
                                    10,
                                child: Container(
                                    width: 20,
                                    height: 20,
                                    decoration: const BoxDecoration(
                                        color: Colors.white,
                                        shape: BoxShape.circle,
                                        boxShadow: [
                                          BoxShadow(
                                              color: Colors.black26,
                                              blurRadius: 4)
                                        ])),
                              )
                          ],
                        )
                      ],
                    ),
                  ),
                  const SizedBox(height: 30),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildStatPill(
                          _totalScans.toString(),
                          'Scans',
                          AppColors.primary,
                          AppColors.primaryLight.withOpacity(0.1)),
                      _buildStatPill(_totalScans.toString(), 'Consumed',
                          AppColors.successGreen, Colors.green.shade50),
                      _buildStatPill(_symptomCount.toString(), 'Symptoms',
                          AppColors.accentOrange, Colors.orange.shade50),
                    ],
                  ),
                  const SizedBox(height: 30),
                  Container(
                    width: double.infinity,
                    height: 60,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(colors: [
                        AppColors.primaryLight.withOpacity(0.8),
                        AppColors.primary.withOpacity(0.8)
                      ]),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          shadowColor: Colors.transparent,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20))),
                      onPressed: () async {
                        await Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (context) => ScannerScreen(
                                    dbService: widget.dbService)));
                        _loadDashboardData();
                      },
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Image.asset('assets/images/barcode-scanner.png',
                              width: 30, color: Colors.white),
                          const SizedBox(width: 15),
                          const Text('Scan a sachet',
                              style: TextStyle(
                                  fontSize: 18,
                                  color: Colors.white,
                                  fontWeight: FontWeight.w900)),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 30),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Recent Scans',
                          style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                              color: AppColors.textDark)),
                      TextButton(
                          onPressed: () async {
                            await Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (context) => DigitalPantryScreen(
                                        dbService: widget.dbService)));
                            _loadDashboardData();
                          },
                          child: const Text('View all',
                              style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w900,
                                  color: AppColors.primaryDark)))
                    ],
                  ),
                  const SizedBox(height: 10),
                  if (_recentScans.isEmpty)
                    const Center(
                        child: Text("No recent scans found.",
                            style: TextStyle(
                                color: AppColors.textGrey,
                                fontStyle: FontStyle.italic)))
                  else
                    ..._recentScans.asMap().entries.map((entry) {
                      int index = entry.key;
                      PantryItem item = entry.value;

                      Color riskColor = AppColors.successGreen;
                      if (item.riskLevel.toUpperCase().contains('HIGH')) {
                        riskColor = AppColors.errorRed;
                      } else if (item.riskLevel
                          .toUpperCase()
                          .contains('MEDIUM')) {
                        riskColor = AppColors.accentOrange;
                      }

                      String formattedDate =
                          DateFormat('MM/dd/yyyy').format(item.dateScanned);

                      return _buildRecentScanCard(
                          item.name,
                          'Consumed - $formattedDate',
                          item.riskLevel.toUpperCase(),
                          riskColor,
                          index == 0);
                    }),
                  const SizedBox(height: 100),
                ],
              ),
            ),
            if (_showNotifications) _buildNotificationOverlay(),
          ],
        ),
      ),
    );
  }

  Widget _buildStatPill(
      String number, String label, Color numColor, Color bgColor) {
    return Container(
      width: 105,
      padding: const EdgeInsets.symmetric(vertical: 15),
      decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white, width: 2),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, 5))
          ]),
      child: Column(
        children: [
          Text(number,
              style: TextStyle(
                  fontSize: 22, fontWeight: FontWeight.w900, color: numColor)),
          const SizedBox(height: 4),
          Text(label,
              style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textDark)),
        ],
      ),
    );
  }

  Widget _buildRecentScanCard(String title, String subtitle, String riskLabel,
      Color riskColor, bool isGradient) {
    return Container(
      margin: const EdgeInsets.only(bottom: 15),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
          gradient: isGradient
              ? LinearGradient(colors: [
                  AppColors.primaryLight.withOpacity(0.3),
                  AppColors.primary.withOpacity(0.1)
                ])
              : null,
          color: isGradient ? null : Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, 4))
          ]),
      child: Row(
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(15),
                border: Border.all(color: Colors.grey.shade200)),
            child: Center(
                child: Image.asset('assets/images/triggerlens_icon.png',
                    width: 40)),
          ),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        color: isGradient
                            ? AppColors.primaryDark
                            : AppColors.textDark)),
                const SizedBox(height: 4),
                Text(subtitle,
                    style: TextStyle(
                        fontSize: 12,
                        color: isGradient ? Colors.white : AppColors.textGrey,
                        fontWeight: FontWeight.w600)),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (isGradient) Image.asset('assets/images/clock.png', width: 16),
              const SizedBox(height: 15),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.grey.shade200)),
                child: Text(riskLabel,
                    style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        color: riskColor)),
              ),
            ],
          )
        ],
      ),
    );
  }

  Widget _buildNotificationOverlay() {
    return Positioned.fill(
      child: Container(
        color: Colors.white.withOpacity(0.9),
        child: Center(
          child: Container(
            width: MediaQuery.of(context).size.width * 0.9,
            height: MediaQuery.of(context).size.height * 0.75,
            padding: const EdgeInsets.all(25),
            decoration: BoxDecoration(
                color: AppColors.primaryDark,
                borderRadius: BorderRadius.circular(35),
                boxShadow: [
                  BoxShadow(
                      color: AppColors.primaryDark.withOpacity(0.4),
                      blurRadius: 30,
                      offset: const Offset(0, 15))
                ]),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                      icon: Image.asset('assets/images/back_1.png',
                          width: 28, color: Colors.white),
                      onPressed: () =>
                          setState(() => _showNotifications = false),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                    GestureDetector(
                      onTap: () {
                        NotificationService().sendTestNotification();
                        ScaffoldMessenger.of(context)
                            .showSnackBar(const SnackBar(
                          content: Text(
                              'Test OS Notification fired! Check your phone lock screen.'),
                          backgroundColor: AppColors.successGreen,
                        ));
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(15),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.vibration,
                                color: Colors.white, size: 14),
                            SizedBox(width: 6),
                            Text('Test OS Push',
                                style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                const Text('Updates & Tips',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 32,
                        fontWeight: FontWeight.w900)),
                const SizedBox(height: 25),
                Expanded(
                  child: ListView.builder(
                    itemCount: _generatedNotifications.length,
                    itemBuilder: (context, index) {
                      final notif = _generatedNotifications[index];
                      return Dismissible(
                          key: Key(notif['id']),
                          direction: DismissDirection.horizontal,
                          onDismissed: (direction) {
                            setState(() {
                              _dismissedNotifIds.add(notif['id']);
                              _generatedNotifications.removeAt(index);
                            });
                          },
                          background: Container(
                            margin: const EdgeInsets.only(bottom: 15),
                            decoration: BoxDecoration(
                                color: Colors.red.withOpacity(0.5),
                                borderRadius: BorderRadius.circular(25)),
                            alignment: Alignment.centerLeft,
                            padding: const EdgeInsets.only(left: 20),
                            child:
                                const Icon(Icons.delete, color: Colors.white),
                          ),
                          secondaryBackground: Container(
                            margin: const EdgeInsets.only(bottom: 15),
                            decoration: BoxDecoration(
                                color: Colors.red.withOpacity(0.5),
                                borderRadius: BorderRadius.circular(25)),
                            alignment: Alignment.centerRight,
                            padding: const EdgeInsets.only(right: 20),
                            child:
                                const Icon(Icons.delete, color: Colors.white),
                          ),
                          child: _buildNotificationItem(notif));
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNotificationItem(Map<String, dynamic> notif) {
    return GestureDetector(
      onTap: () async {
        setState(() => _showNotifications = false);

        if (notif['action'] == 'scan') {
          await Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (context) =>
                      ScannerScreen(dbService: widget.dbService)));
        } else if (notif['action'] == 'coach') {
          await Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (context) => CoachScreen(
                      dbService: widget.dbService,
                      entryMode: 'insights',
                      activeSymptom: 'Acid Overload',
                      symptomSeverity: 8,
                      scannedProduct: 'Cumulative Limit Breached',
                      dynamicContextData: 'High PRAL Warning')));
        } else if (notif['action'] == 'pantry') {
          await Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (context) =>
                      DigitalPantryScreen(dbService: widget.dbService)));
        }
        _loadDashboardData();
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 15),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.15),
          borderRadius: BorderRadius.circular(25),
          border: notif['action'] != null
              ? Border.all(color: Colors.white30, width: 2)
              : null,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 45,
              height: 45,
              decoration: BoxDecoration(
                  color: Colors.white, borderRadius: BorderRadius.circular(15)),
              child: Center(
                  child: Icon(notif['icon'], color: notif['color'], size: 28)),
            ),
            const SizedBox(width: 15),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(notif['title'],
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                          fontSize: 16)),
                  const SizedBox(height: 6),
                  Text(notif['subtitle'],
                      style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                          height: 1.4,
                          fontWeight: FontWeight.w600)),
                  if (notif['action'] != null) ...[
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Text(
                            notif['action'] == 'scan'
                                ? 'Tap to open scanner'
                                : (notif['action'] == 'coach'
                                    ? 'Tap for First Aid tips'
                                    : 'Tap to log symptom in Pantry'),
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold)),
                        const SizedBox(width: 5),
                        const Icon(Icons.arrow_forward_ios,
                            color: Colors.white, size: 10)
                      ],
                    )
                  ]
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
