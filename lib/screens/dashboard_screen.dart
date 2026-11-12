import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';

import '../services/database_service.dart';
import '../services/notification_service.dart';
import '../models/pantry_item.dart';
import '../models/user_profile.dart';
import '../models/daily_log.dart';
import '../utils/ui_helpers.dart';
import '../utils/app_localizations.dart';
import '../utils/risk_translator.dart';
import 'profile_screen.dart';
import 'scanner_screen.dart';
import 'digital_pantry_screen.dart';
import 'coach_screen.dart';
import '../main.dart';

class DashboardScreen extends StatefulWidget {
  final DatabaseService dbService;
  const DashboardScreen({super.key, required this.dbService});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen>
    with SingleTickerProviderStateMixin {
  bool _showNotifications = false;

  final Set<String> _dismissedNotifIds = {};

  int _cumulativeScore = 0;
  double _riskPercentage = 0.0;
  List<PantryItem> _recentScans = [];
  int _totalScans = 0;
  int _symptomCount = 0;

  User? _currentUser;

  double _activeDailyCap = 15.0;
  String _currentMentalState = "Relaxed";

  // In-Memory Cache to prevent O(N) DB calls every second
  List<PantryItem> _allItemsInMemory = [];

  List<Map<String, dynamic>> _generatedNotifications = [];

  Timer? _clockTimer;
  Timer? _carouselTimer;
  Timer? _pauseTimer;

  final PageController _pageController = PageController();
  List<PantryItem> _activeQueue = [];
  int _currentCarouselPage = 0;
  bool _isCarouselPaused = false;

  late AnimationController _bellController;
  late Animation<double> _bellAnimation;

  @override
  void initState() {
    super.initState();
    _currentUser = FirebaseAuth.instance.currentUser;

    _bellController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    // Softened the pulse animation to look more premium
    _bellAnimation = Tween<double>(begin: 1.0, end: 1.15).animate(
      CurvedAnimation(parent: _bellController, curve: Curves.elasticOut),
    );

    _loadDashboardData();

    _clockTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) _updateDigestionTimer();
    });

    _startCarouselTimer();
  }

  @override
  void dispose() {
    _clockTimer?.cancel();
    _carouselTimer?.cancel();
    _pauseTimer?.cancel();
    _pageController.dispose();
    _bellController.dispose();
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

  String _getFirstName() {
    String rawName = "There";
    if (_currentUser?.displayName != null &&
        _currentUser!.displayName!.trim().isNotEmpty) {
      rawName = _currentUser!.displayName!.split(' ').first;
    } else if (_currentUser?.email != null && _currentUser!.email!.isNotEmpty) {
      rawName = _currentUser!.email!.split('@').first;
    }
    return rawName.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '');
  }

  void _addNotificationIfNew(Map<String, dynamic> notif) {
    if (!_dismissedNotifIds.contains(notif['id'])) {
      bool exists = _generatedNotifications.any((n) => n['id'] == notif['id']);
      if (!exists) {
        _generatedNotifications.add(notif);
        _triggerBellWarp();
      }
    }
  }

  void _triggerBellWarp() {
    if (mounted) {
      HapticFeedback.lightImpact();
      _bellController.forward(from: 0.0).then((_) {
        _bellController.reverse();
      });
    }
  }

  void _generateNotifications() {
    final loc = AppLocalizations.of(context);

    if (_currentMentalState != "Relaxed") {
      _addNotificationIfNew({
        'id': 'stress_penalty_${DateTime.now().day}',
        'title': loc.loc('stress_penalty_active'),
        'subtitle': loc.loc('stress_penalty_desc'),
        'icon': Icons.psychology_alt,
        'color': Colors.deepOrange,
        'action': null,
      });
    }

    if (_riskPercentage >= 80) {
      _addNotificationIfNew({
        'id': 'threshold_warning_${DateTime.now().day}',
        'title': loc.loc('threshold_warning'),
        'subtitle': loc.loc('threshold_warning_desc',
            {'percent': _riskPercentage.toInt().toString()}),
        'icon': Icons.warning_amber_rounded,
        'color': Colors.red,
        'action': 'coach',
      });
    }

    if (_activeQueue.isEmpty && _recentScans.isNotEmpty) {
      _addNotificationIfNew({
        'id': 'digestion_complete_${DateTime.now().day}',
        'title': loc.loc('digestion_complete_title'),
        'subtitle': loc
            .loc('digestion_complete_body', {'name': _recentScans.first.name}),
        'icon': Icons.check_circle_outline,
        'color': Colors.green,
        'action': null,
      });
    }

    _addNotificationIfNew({
      'id': 'health_tip_${DateTime.now().day}',
      'title': loc.loc('quick_health_tip'),
      'subtitle': loc.loc('tip_${DateTime.now().day % 20}'),
      'icon': Icons.lightbulb_outline,
      'color': Colors.blueAccent,
      'action': null,
    });
  }

  Future<void> _loadDashboardData() async {
    if (!mounted) return;

    // ==========================================
    // THE UNIFIED MATH FIX (Single Source of Truth)
    // Both Dashboard and Profile now read the exact same limit directly from the DB state
    // ==========================================
    final profile =
        Provider.of<UserSessionProvider>(context, listen: false).profile;

    double activeCap = profile?.dynamicDailyCap ?? 15.0;

    final allItems = await widget.dbService.getPantryItems();
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

    if (mounted) {
      setState(() {
        _allItemsInMemory = allItems;
        _activeDailyCap = activeCap;
        _currentMentalState = mentalState;

        _totalScans = allItems.length;

        var sortedScans = List<PantryItem>.from(allItems);
        sortedScans.sort((a, b) => b.dateScanned.compareTo(a.dateScanned));
        _recentScans = sortedScans.take(3).toList();
      });

      _updateDigestionTimer();
      _generateNotifications();
    }
  }

  void _updateDigestionTimer() {
    if (!mounted) return;
    final now = DateTime.now();

    int symptomLogs = 0;
    double timeDegradedScore = 0.0;
    List<PantryItem> activeQueue = [];

    for (var item in _allItemsInMemory) {
      if (item.symptoms.isNotEmpty && item.symptoms != "None") {
        symptomLogs++;
      }

      if (!item.isConsumed) continue;

      final difference = now.difference(item.dateScanned);

      if (difference.inSeconds >= 0 && difference.inSeconds < 21600) {
        activeQueue.add(item);

        double remainingRatio = 1.0 - (difference.inSeconds / 21600.0);
        if (remainingRatio < 0) remainingRatio = 0;

        double trueScore = RiskTranslator.calculateTrueAcidLoad(
            item.acidScore.toDouble(),
            item.portionCount,
            item.portionMeasurement);

        timeDegradedScore += (trueScore * remainingRatio);
      }
    }

    activeQueue.sort((a, b) => a.dateScanned.compareTo(b.dateScanned));

    if (timeDegradedScore.isNaN || timeDegradedScore.isInfinite) {
      timeDegradedScore = 0.0;
    }

    double tempPercent = 0.0;
    if (_activeDailyCap <= 0.0) {
      tempPercent = timeDegradedScore > 0 ? 100.0 : 0.0;
    } else {
      tempPercent = (timeDegradedScore / _activeDailyCap) * 100;
    }

    if (tempPercent.isNaN || tempPercent.isInfinite) tempPercent = 0.0;
    if (tempPercent > 100) tempPercent = 100;

    setState(() {
      _symptomCount = symptomLogs;
      _cumulativeScore = timeDegradedScore.round();
      _riskPercentage = tempPercent;

      _activeQueue = activeQueue;
      if (_activeQueue.isNotEmpty &&
          _currentCarouselPage >= _activeQueue.length) {
        _currentCarouselPage = _activeQueue.length - 1;
      }
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

  void _markNotificationRead(Map<String, dynamic> notif) {
    setState(() {
      _dismissedNotifIds.add(notif['id']);
      _generatedNotifications.remove(notif);
      if (_generatedNotifications.isEmpty) _showNotifications = false;
    });
  }

  Widget _buildAvatarWidget(String? localPath, double size, AppColors colors) {
    if (localPath != null) {
      if (localPath.startsWith('preset_')) {
        int index = int.tryParse(localPath.split('_')[1]) ?? 0;
        List<IconData> icons = [
          Icons.water_drop,
          Icons.local_florist,
          Icons.shield,
          Icons.favorite,
          Icons.spa
        ];
        List<Color> presetColors = [
          Colors.blue,
          Colors.green,
          colors.primary,
          Colors.pink,
          Colors.teal
        ];
        return Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
              color: presetColors[index % presetColors.length].withOpacity(0.2),
              shape: BoxShape.circle),
          child: Icon(icons[index % icons.length],
              color: presetColors[index % presetColors.length],
              size: size * 0.5),
        );
      } else if (File(localPath).existsSync()) {
        return ClipOval(
            child: Image.file(File(localPath),
                width: size, height: size, fit: BoxFit.cover));
      }
    }

    if (_currentUser?.photoURL != null) {
      return ClipOval(
          child: Image.network(_currentUser!.photoURL!,
              width: size,
              height: size,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) =>
                  Image.asset('assets/images/man.png', fit: BoxFit.cover)));
    }

    return ClipOval(
        child: Image.asset('assets/images/man.png',
            width: size, height: size, fit: BoxFit.cover));
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final loc = AppLocalizations.of(context);
    final userSession = Provider.of<UserSessionProvider>(context);

    Color riskGradientStart =
        colors.isDark ? const Color(0xFF1E1E1E) : Colors.white;
    Color riskBorderColor = colors.primaryLight.withOpacity(0.3);
    Color riskAccentColor = colors.primary;

    if (_riskPercentage >= 80) {
      riskBorderColor = Colors.red.shade300;
      riskAccentColor = Colors.red;
    } else if (_riskPercentage >= 40) {
      riskBorderColor = Colors.orange.shade300;
      riskAccentColor = Colors.orange;
    }

    String targetLabel = _activeDailyCap <= 0.0
        ? loc.loc('target_strict')
        : loc.loc('cap', {'limit': _activeDailyCap.toStringAsFixed(1)});

    double pointsRemaining = _activeDailyCap - _cumulativeScore;
    if (pointsRemaining < 0) pointsRemaining = 0;

    return Scaffold(
      backgroundColor: colors.background,
      body: SafeArea(
        child: Stack(
          children: [
            RefreshIndicator(
              color: colors.primary,
              backgroundColor: Colors.white,
              onRefresh: _loadDashboardData,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(
                    parent: BouncingScrollPhysics()),
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
                            Text('Trigger',
                                style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w900,
                                    color: colors.primaryDark)),
                            Text('Lens',
                                style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w400,
                                    color: colors.primaryDark)),
                            const SizedBox(width: 5),
                            Image.asset('assets/images/triggerlens_icon.png',
                                width: 30),
                          ],
                        ),
                        Row(
                          children: [
                            GestureDetector(
                              onTap: () {
                                HapticFeedback.selectionClick();
                                setState(() {
                                  _showNotifications = true;
                                });
                              },
                              child: Stack(
                                clipBehavior: Clip.none,
                                children: [
                                  AnimatedBuilder(
                                      animation: _bellAnimation,
                                      builder: (context, child) {
                                        return Transform.scale(
                                          scale: _bellAnimation.value,
                                          child: Image.asset(
                                              'assets/images/active.png',
                                              width: 35,
                                              color: colors.textDark),
                                        );
                                      }),
                                  if (_generatedNotifications.isNotEmpty)
                                    Positioned(
                                      right: -2,
                                      top: -2,
                                      child: Container(
                                        padding: const EdgeInsets.all(5),
                                        decoration: BoxDecoration(
                                            color: colors.errorRed,
                                            shape: BoxShape.circle,
                                            border: Border.all(
                                                color: colors.background,
                                                width: 1.5)),
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
                                  color: colors.primaryLight.withOpacity(0.3),
                                ),
                                child: _buildAvatarWidget(
                                    userSession.avatarPath, 55, colors),
                              ),
                            ),
                          ],
                        )
                      ],
                    ),
                    const SizedBox(height: 15),
                    Text('${loc.loc('hi')} ${_getFirstName()}!',
                        style: TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.w900,
                            color: colors.textDark)),
                    if (userSession.profile != null) ...[
                      const SizedBox(height: 4),
                      Text(
                          '${userSession.profile!.clinicalStatus} • ${userSession.profile!.ageGroup}',
                          style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              color: colors.primary)),
                    ],
                    if (_currentMentalState != "Relaxed") ...[
                      const SizedBox(height: 8),
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
                            Flexible(
                              child: Text(loc.loc('stress_penalty_desc'),
                                  style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.orange.shade900)),
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 25),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(25),
                      decoration: BoxDecoration(
                          color: riskGradientStart,
                          borderRadius: BorderRadius.circular(25),
                          border: Border.all(color: riskBorderColor, width: 2),
                          boxShadow: [
                            BoxShadow(
                                color: riskAccentColor.withOpacity(0.15),
                                blurRadius: 20,
                                offset: const Offset(0, 8))
                          ]),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Expanded(
                                flex: 1,
                                child: Row(
                                  children: [
                                    Flexible(
                                      child: Text(loc.loc('cumulative_risk'),
                                          maxLines: 2,
                                          style: TextStyle(
                                              color: colors.textGrey,
                                              fontSize: 11,
                                              fontWeight: FontWeight.w900,
                                              letterSpacing: 0.5)),
                                    ),
                                    const SizedBox(width: 5),
                                    GestureDetector(
                                      onTap: () => _showInfoModal(
                                          loc.loc('cumulative_risk'),
                                          loc.loc('tooltip_cumulative'),
                                          colors),
                                      child: Icon(Icons.info_outline,
                                          color: colors.primary, size: 16),
                                    ),
                                  ],
                                ),
                              ),
                              if (_activeQueue.isEmpty)
                                Expanded(
                                  flex: 1,
                                  child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.end,
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Text('00 : 00 : 00',
                                            style: TextStyle(
                                                color: colors.textDark,
                                                fontSize: 16,
                                                fontWeight: FontWeight.w900)),
                                        const SizedBox(height: 2),
                                        Text(loc.loc('hr_mn_sec'),
                                            style: TextStyle(
                                                color: colors.textGrey,
                                                fontSize: 8,
                                                fontWeight: FontWeight.bold)),
                                        const SizedBox(height: 4),
                                        Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.end,
                                            children: [
                                              const Icon(
                                                  Icons.check_circle_outline,
                                                  color: Colors.green,
                                                  size: 10),
                                              const SizedBox(width: 4),
                                              Flexible(
                                                child: Text(
                                                    loc.loc('stomach_empty'),
                                                    textAlign: TextAlign.right,
                                                    maxLines: 2,
                                                    style: const TextStyle(
                                                        color: Colors.green,
                                                        fontSize: 9,
                                                        fontWeight:
                                                            FontWeight.bold)),
                                              ),
                                            ])
                                      ]),
                                )
                              else
                                Expanded(
                                  flex: 1,
                                  child: SizedBox(
                                    height: 65,
                                    child: Stack(
                                      alignment: Alignment.center,
                                      children: [
                                        PageView.builder(
                                            controller: _pageController,
                                            onPageChanged: (idx) {
                                              setState(() =>
                                                  _currentCarouselPage = idx);
                                              _pauseCarouselBriefly();
                                            },
                                            itemCount: _activeQueue.length,
                                            itemBuilder: (context, index) {
                                              final item = _activeQueue[index];
                                              final expireTime =
                                                  item.dateScanned.add(
                                                      const Duration(hours: 6));
                                              Duration remaining = expireTime
                                                  .difference(DateTime.now());
                                              if (remaining.isNegative) {
                                                remaining = Duration.zero;
                                              }

                                              String hr = remaining.inHours
                                                  .toString()
                                                  .padLeft(2, '0');
                                              String mn =
                                                  (remaining.inMinutes % 60)
                                                      .toString()
                                                      .padLeft(2, '0');
                                              String sc =
                                                  (remaining.inSeconds % 60)
                                                      .toString()
                                                      .padLeft(2, '0');

                                              return Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.end,
                                                mainAxisAlignment:
                                                    MainAxisAlignment.center,
                                                children: [
                                                  Text('$hr : $mn : $sc',
                                                      style: TextStyle(
                                                          color:
                                                              colors.textDark,
                                                          fontSize: 16,
                                                          fontWeight:
                                                              FontWeight.w900)),
                                                  const SizedBox(height: 2),
                                                  Text(loc.loc('hr_mn_sec'),
                                                      style: TextStyle(
                                                          color:
                                                              colors.textGrey,
                                                          fontSize: 8,
                                                          fontWeight:
                                                              FontWeight.bold)),
                                                  const SizedBox(height: 4),
                                                  Row(
                                                      mainAxisAlignment:
                                                          MainAxisAlignment.end,
                                                      children: [
                                                        Icon(Icons.restaurant,
                                                            color: colors
                                                                .primaryDark,
                                                            size: 10),
                                                        const SizedBox(
                                                            width: 4),
                                                        Flexible(
                                                          child: Text(item.name,
                                                              maxLines: 1,
                                                              overflow:
                                                                  TextOverflow
                                                                      .ellipsis,
                                                              style: TextStyle(
                                                                  color: colors
                                                                      .textDark,
                                                                  fontSize: 9,
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .bold)),
                                                        ),
                                                        Text(
                                                            ' (${index + 1}/${_activeQueue.length})',
                                                            style: TextStyle(
                                                                color: colors
                                                                    .primary,
                                                                fontSize: 9,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .bold)),
                                                      ])
                                                ],
                                              );
                                            }),
                                        if (_activeQueue.length > 1)
                                          Positioned(
                                            left: -15,
                                            child: GestureDetector(
                                              onTap: () {
                                                _pauseCarouselBriefly();
                                                _pageController.previousPage(
                                                    duration: const Duration(
                                                        milliseconds: 300),
                                                    curve: Curves.easeInOut);
                                              },
                                              child: Icon(Icons.chevron_left,
                                                  color: colors.primary,
                                                  size: 20),
                                            ),
                                          ),
                                        if (_activeQueue.length > 1)
                                          Positioned(
                                            right: -15,
                                            child: GestureDetector(
                                              onTap: () {
                                                _pauseCarouselBriefly();
                                                _pageController.nextPage(
                                                    duration: const Duration(
                                                        milliseconds: 300),
                                                    curve: Curves.easeInOut);
                                              },
                                              child: Icon(Icons.chevron_right,
                                                  color: colors.primary,
                                                  size: 20),
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                )
                            ],
                          ),
                          const SizedBox(height: 5),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Text('${_riskPercentage.toInt()}%',
                                  style: TextStyle(
                                      color: riskAccentColor,
                                      fontSize: 42,
                                      fontWeight: FontWeight.w900)),
                              const SizedBox(width: 15),
                              Expanded(
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 8),
                                  decoration: BoxDecoration(
                                      color: riskAccentColor.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(10)),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Expanded(
                                        child: Text(
                                          targetLabel,
                                          textAlign: TextAlign.center,
                                          style: TextStyle(
                                            color: riskAccentColor,
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                            letterSpacing: 0.5,
                                          ),
                                        ),
                                      ),
                                      GestureDetector(
                                        onTap: () => _showInfoModal(
                                            loc.loc('cap_label'),
                                            loc.loc('tooltip_daily_limit'),
                                            colors),
                                        child: Icon(Icons.info_outline,
                                            color: riskAccentColor, size: 16),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),
                          Stack(
                            alignment: Alignment.centerLeft,
                            children: [
                              Container(
                                  width: double.infinity,
                                  height: 12,
                                  decoration: BoxDecoration(
                                      color: colors.isDark
                                          ? Colors.white12
                                          : Colors.grey.shade200,
                                      borderRadius: BorderRadius.circular(10))),
                              AnimatedContainer(
                                  duration: const Duration(milliseconds: 500),
                                  curve: Curves.easeOutCubic,
                                  width: MediaQuery.of(context).size.width *
                                      0.8 *
                                      (_riskPercentage / 100),
                                  height: 12,
                                  decoration: BoxDecoration(
                                      color: riskAccentColor,
                                      borderRadius: BorderRadius.circular(10))),
                              if (_riskPercentage > 0)
                                AnimatedPositioned(
                                  duration: const Duration(milliseconds: 500),
                                  curve: Curves.easeOutCubic,
                                  left: (MediaQuery.of(context).size.width *
                                          0.8 *
                                          (_riskPercentage / 100)) -
                                      10,
                                  child: Container(
                                      width: 20,
                                      height: 20,
                                      decoration: BoxDecoration(
                                          color: Colors.white,
                                          shape: BoxShape.circle,
                                          border: Border.all(
                                              color: riskAccentColor, width: 3),
                                          boxShadow: const [
                                            BoxShadow(
                                                color: Colors.black12,
                                                blurRadius: 4)
                                          ])),
                                )
                            ],
                          ),
                          const SizedBox(height: 20),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                                color: colors.isDark
                                    ? Colors.white10
                                    : Colors.grey.shade100,
                                borderRadius: BorderRadius.circular(12)),
                            child: Row(
                              children: [
                                Icon(Icons.shield_outlined,
                                    color: colors.primary, size: 16),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    loc.loc('coffee_allowance', {
                                      'cups': pointsRemaining.toStringAsFixed(1)
                                    }),
                                    style: TextStyle(
                                        color: colors.textDark,
                                        fontSize: 11,
                                        fontStyle: FontStyle.italic,
                                        fontWeight: FontWeight.w600),
                                  ),
                                )
                              ],
                            ),
                          )
                        ],
                      ),
                    ),
                    const SizedBox(height: 30),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: _buildStatPill(
                              _totalScans.toString(),
                              loc.loc('scans'),
                              colors.primary,
                              colors.cardColor,
                              colors),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _buildStatPill(
                              _totalScans.toString(),
                              loc.loc('consumed'),
                              colors.successGreen,
                              colors.cardColor,
                              colors),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _buildStatPill(
                              _symptomCount.toString(),
                              loc.loc('symptoms'),
                              colors.accentOrange,
                              colors.cardColor,
                              colors),
                        ),
                      ],
                    ),
                    const SizedBox(height: 30),
                    Container(
                      width: double.infinity,
                      height: 60,
                      decoration: BoxDecoration(
                          color: colors.primary,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                                color: colors.primary.withOpacity(0.3),
                                blurRadius: 15,
                                offset: const Offset(0, 5))
                          ]),
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
                            Text(loc.loc('scan_sachet'),
                                style: const TextStyle(
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
                        Expanded(
                          child: Text(loc.loc('recent_scans'),
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w900,
                                  color: colors.textDark)),
                        ),
                        TextButton(
                            onPressed: () {
                              Navigator.pushAndRemoveUntil(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => MainLayoutScreen(
                                    dbService: widget.dbService,
                                    initialIndex: 2,
                                  ),
                                ),
                                (route) => false,
                              );
                            },
                            child: Text(loc.loc('view_all'),
                                style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w900,
                                    color: colors.primaryDark)))
                      ],
                    ),
                    const SizedBox(height: 10),
                    if (_recentScans.isEmpty)
                      Center(
                          child: Text(loc.loc('no_recent_scans'),
                              style: TextStyle(
                                  color: colors.textGrey,
                                  fontStyle: FontStyle.italic)))
                    else
                      ..._recentScans.asMap().entries.map((entry) {
                        int index = entry.key;
                        PantryItem item = entry.value;

                        Color riskColor = colors.successGreen;
                        if (item.riskLevel.toUpperCase().contains('HIGH') ||
                            item.riskLevel.toUpperCase().contains('RED')) {
                          riskColor = colors.errorRed;
                        } else if (item.riskLevel
                                .toUpperCase()
                                .contains('MEDIUM') ||
                            item.riskLevel.toUpperCase().contains('YELLOW')) {
                          riskColor = colors.accentOrange;
                        }

                        String formattedDate =
                            DateFormat('MM/dd/yyyy').format(item.dateScanned);

                        return _buildRecentScanCard(
                            item.name,
                            loc.loc('consumed_on', {'date': formattedDate}),
                            item.riskLevel
                                .toUpperCase()
                                .replaceAll(" RISK", ""),
                            riskColor,
                            index == 0,
                            colors);
                      }),
                    const SizedBox(height: 100),
                  ],
                ),
              ),
            ),
            if (_showNotifications)
              GestureDetector(
                onTap: () => setState(() => _showNotifications = false),
                child: Container(
                  color: Colors.black.withOpacity(0.5),
                ),
              ),
            AnimatedPositioned(
              duration: const Duration(milliseconds: 400),
              curve: Curves.fastOutSlowIn,
              top: _showNotifications ? 0 : -MediaQuery.of(context).size.height,
              left: 0,
              right: 0,
              child: _buildNotificationOverlay(colors, loc),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatPill(String number, String label, Color numColor,
      Color bgColor, AppColors colors) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 15),
      decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color: colors.isDark ? Colors.white24 : Colors.white, width: 2),
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
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: colors.textDark)),
        ],
      ),
    );
  }

  Widget _buildRecentScanCard(String title, String subtitle, String riskLabel,
      Color riskColor, bool isGradient, AppColors colors) {
    return Container(
      margin: const EdgeInsets.only(bottom: 15),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
          color: isGradient
              ? colors.primaryLight.withOpacity(0.1)
              : colors.cardColor,
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
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        color:
                            isGradient ? colors.primaryDark : colors.textDark)),
                const SizedBox(height: 4),
                Text(subtitle,
                    style: TextStyle(
                        fontSize: 11,
                        color: isGradient
                            ? (colors.isDark ? Colors.white70 : Colors.black54)
                            : colors.textGrey,
                        fontWeight: FontWeight.w600)),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (isGradient)
                Image.asset('assets/images/clock.png',
                    width: 16, color: colors.primaryDark),
              const SizedBox(height: 15),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                    color: colors.isDark ? Colors.black45 : Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                        color: colors.isDark
                            ? Colors.white12
                            : Colors.grey.shade200)),
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

  Widget _buildNotificationOverlay(AppColors colors, AppLocalizations loc) {
    return Container(
      width: double.infinity,
      height: MediaQuery.of(context).size.height * 0.85,
      padding: const EdgeInsets.only(top: 50, left: 25, right: 25, bottom: 25),
      decoration: BoxDecoration(
          color: colors.primaryDark,
          borderRadius: const BorderRadius.only(
            bottomLeft: Radius.circular(35),
            bottomRight: Radius.circular(35),
          ),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.5),
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
                icon: const Icon(Icons.close, color: Colors.white, size: 32),
                onPressed: () => setState(() => _showNotifications = false),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Text(loc.loc('updates_tips'),
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 32,
                  fontWeight: FontWeight.w900)),
          const SizedBox(height: 25),
          Expanded(
            child: _generatedNotifications.isEmpty
                ? Center(
                    child: Text(loc.loc('no_new_notifications'),
                        style: const TextStyle(color: Colors.white70)))
                : ListView.builder(
                    itemCount: _generatedNotifications.length,
                    itemBuilder: (context, index) {
                      final notif = _generatedNotifications[index];
                      return Dismissible(
                          key: Key(notif['id']),
                          direction: DismissDirection.horizontal,
                          onDismissed: (direction) =>
                              _markNotificationRead(notif),
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
                          child: _buildNotificationItem(notif, colors, loc));
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationItem(
      Map<String, dynamic> notif, AppColors colors, AppLocalizations loc) {
    return GestureDetector(
      onTap: () async {
        _markNotificationRead(notif);

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
                  child: Icon(notif['icon'],
                      color: notif['color'] ?? colors.primary, size: 28)),
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
                                ? loc.loc('scan_prompt_desc')
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
