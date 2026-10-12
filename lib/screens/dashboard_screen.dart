import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/database_service.dart';
import '../models/pantry_item.dart';
import '../models/user_profile.dart';
import '../utils/ui_helpers.dart';
import 'profile_screen.dart';
import 'scanner_screen.dart';

class DashboardScreen extends StatefulWidget {
  final DatabaseService dbService;
  const DashboardScreen({super.key, required this.dbService});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  bool _showNotifications = false;

  Timer? _timer;
  Duration _timeRemaining = Duration.zero;
  int _cumulativeScore = 0;
  double _riskPercentage = 0.0;
  List<PantryItem> _recentScans = [];
  int _totalScans = 0;
  int _symptomCount = 0;

  User? _currentUser;
  UserProfile? _userProfile;

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

  Future<void> _loadDashboardData() async {
    final allItems = await widget.dbService.getPantryItems();
    final profile = await widget.dbService.getUserProfile();
    final now = DateTime.now();

    int tempScore = 0;
    DateTime? latestScanTime;
    int symptomLogs = 0;

    for (var item in allItems) {
      if (item.symptoms.isNotEmpty && item.symptoms != "None") {
        symptomLogs++;
      }

      final difference = now.difference(item.dateScanned);
      if (difference.inHours < 6) {
        tempScore += item.acidScore;

        if (latestScanTime == null ||
            item.dateScanned.isAfter(latestScanTime)) {
          latestScanTime = item.dateScanned;
        }
      }
    }

    if (latestScanTime != null) {
      final expireTime = latestScanTime.add(const Duration(hours: 6));
      _timeRemaining = expireTime.difference(now);
      if (_timeRemaining.isNegative) _timeRemaining = Duration.zero;
    } else {
      _timeRemaining = Duration.zero;
    }

    int dailyCap = profile?.dailyCap ?? 15;
    double tempPercent = (tempScore / dailyCap) * 100;
    if (tempPercent > 100) tempPercent = 100;

    if (mounted) {
      setState(() {
        _userProfile = profile;
        _totalScans = allItems.length;
        _symptomCount = symptomLogs;
        _recentScans = allItems.take(3).toList();
        _cumulativeScore = tempScore;
        _riskPercentage = tempPercent;
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
                  // Top Row: Logo & Avatar
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
                                      errorBuilder: (_, __, ___) => Image.asset(
                                          'assets/images/man.png',
                                          fit: BoxFit.cover))
                                  : Image.asset('assets/images/man.png',
                                      fit: BoxFit.cover)),
                        ),
                      )
                    ],
                  ),
                  const SizedBox(height: 10),

                  Text('Hi ${_getFirstName()}!',
                      style: const TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.w900,
                          color: AppColors.textDark)),

                  const SizedBox(height: 20),

                  Stack(
                    clipBehavior: Clip.none,
                    children: [
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
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
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
                            Text('${_riskPercentage.toInt()}%',
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 36,
                                    fontWeight: FontWeight.w900)),
                            const SizedBox(height: 15),
                            Stack(
                              alignment: Alignment.centerLeft,
                              children: [
                                Container(
                                    width: double.infinity,
                                    height: 12,
                                    decoration: BoxDecoration(
                                        color: Colors.white.withOpacity(0.2),
                                        borderRadius:
                                            BorderRadius.circular(10))),
                                Container(
                                    width: MediaQuery.of(context).size.width *
                                        0.8 *
                                        (_riskPercentage / 100),
                                    height: 12,
                                    decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius:
                                            BorderRadius.circular(10))),
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
                      Positioned(
                        top: -15,
                        right: -10,
                        child: GestureDetector(
                          onTap: () =>
                              setState(() => _showNotifications = true),
                          child: Image.asset('assets/images/active.png',
                              width: 45),
                        ),
                      )
                    ],
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
                          onPressed: () {},
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
        color: Colors.white.withOpacity(0.8),
        child: Center(
          child: Container(
            width: MediaQuery.of(context).size.width * 0.9,
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
              mainAxisSize: MainAxisSize.min,
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
                    Image.asset('assets/images/active.png', width: 35),
                  ],
                ),
                const SizedBox(height: 10),
                const Text('Notifications',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 32,
                        fontWeight: FontWeight.w900)),
                const SizedBox(height: 25),
                _buildNotificationItem(
                    'System Update', 'Database Synced', true),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNotificationItem(String title, String date, bool isChecked) {
    return Container(
      margin: const EdgeInsets.only(bottom: 15),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.15),
        borderRadius: BorderRadius.circular(25),
      ),
      child: Row(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
                color: Colors.white, borderRadius: BorderRadius.circular(15)),
            child: Center(
                child: Image.asset('assets/images/triggerlens_icon.png',
                    width: 35)),
          ),
          const SizedBox(width: 15),
          Expanded(
            // FIXED: Added Expanded to prevent column overflow
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      // FIXED: Added Expanded to prevent title overflow
                      child: Text(title,
                          style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w900,
                              fontSize: 18),
                          overflow: TextOverflow.ellipsis),
                    ),
                    const SizedBox(width: 10),
                    Text(date,
                        style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 11,
                            fontWeight: FontWeight.bold)),
                  ],
                ),
                const SizedBox(height: 8),
                const Text('Active',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w900)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
