import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../services/database_service.dart';
import '../models/user_profile.dart';
import '../models/pantry_item.dart';
import '../models/trigger_item.dart';
import '../utils/ui_helpers.dart';
import '../utils/app_localizations.dart';
import '../utils/keyword_mapping_algorithm.dart';
import 'onboarding/welcome_screen.dart';
import 'onboarding/onboarding_screen.dart';
import '../main.dart';

// ==========================================
// 1. THE REDESIGNED PROFILE DASHBOARD
// ==========================================
class ProfileScreen extends StatefulWidget {
  final DatabaseService dbService;
  const ProfileScreen({super.key, required this.dbService});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  User? _currentUser;
  UserProfile? _userProfile;
  bool _isLoading = true;
  String? _localAvatarPath;

  int _totalScans = 0;
  int _safeScans = 0;
  Map<String, int> _symptomCounts = {};
  Map<String, int> _triggerCounts = {};

  @override
  void initState() {
    super.initState();
    _loadDynamicUserData();
  }

  Future<void> _loadDynamicUserData() async {
    _currentUser = FirebaseAuth.instance.currentUser;

    if (_currentUser != null) {
      final prefs = await SharedPreferences.getInstance();
      _localAvatarPath = prefs.getString('local_avatar_${_currentUser!.uid}');
    }

    final profile = await widget.dbService.getUserProfile();
    final items = await widget.dbService.getPantryItems();
    final dbTriggers = await widget.dbService.getAllTriggers();

    int safeCount = 0;
    Map<String, int> sympCounts = {};
    Map<String, int> trigCounts = {};

    List<TriggerItem> sortedTriggers = List.from(dbTriggers);
    sortedTriggers.sort((a, b) {
      int aWords = a.name.split(' ').length;
      int bWords = b.name.split(' ').length;
      if (aWords == bWords) return b.name.length.compareTo(a.name.length);
      return bWords.compareTo(aWords);
    });

    for (var item in items) {
      if (item.riskLevel.toUpperCase().contains("GREEN") ||
          item.riskLevel.toUpperCase().contains("SAFE")) {
        safeCount++;
      }

      if (item.symptoms.isNotEmpty && item.symptoms != "None") {
        sympCounts[item.symptoms] = (sympCounts[item.symptoms] ?? 0) + 1;
      }

      if ((item.riskLevel.toUpperCase().contains("RED") ||
              item.riskLevel.toUpperCase().contains("YELLOW")) &&
          item.symptoms.isNotEmpty &&
          item.symptoms != "None") {
        String mutableText = KeywordMappingAlgorithm.cleanRawText(item.rawText);

        for (var trigger in sortedTriggers) {
          var match = KeywordMappingAlgorithm.findFuzzyMatch(
              mutableText, trigger.name.toLowerCase());

          if (match.found) {
            trigCounts[trigger.name] = (trigCounts[trigger.name] ?? 0) + 1;
            String mask = '*' * (match.endIndex - match.startIndex);
            mutableText = mutableText.replaceRange(
                match.startIndex, match.endIndex, mask);
          }
        }
      }
    }

    if (mounted) {
      setState(() {
        _userProfile = profile;
        _totalScans = items.length;
        _safeScans = safeCount;
        _symptomCounts = sympCounts;
        _triggerCounts = trigCounts;
        _isLoading = false;
      });
    }
  }

  String _getUserDisplayName(AppLocalizations loc) {
    if (_currentUser?.displayName != null &&
        _currentUser!.displayName!.trim().isNotEmpty) {
      return _currentUser!.displayName!;
    }
    if (_currentUser?.email != null && _currentUser!.email!.isNotEmpty) {
      return _currentUser!.email!.split('@').first;
    }
    return loc.loc('tummy_friend');
  }

  Map<String, dynamic> _getDynamicTolerance(double activeCap, double multiplier,
      AppColors colors, AppLocalizations loc) {
    if (multiplier >= 1.2 || activeCap < 12.0) {
      return {
        'level': loc.loc('highly_sensitive'),
        'desc': loc.loc('highly_sensitive_desc'),
        'color': colors.errorRed,
        'icon': Icons.local_fire_department_outlined
      };
    } else if (multiplier > 1.0 || activeCap < 15.0) {
      return {
        'level': loc.loc('slightly_sensitive'),
        'desc': loc.loc('slightly_sensitive_desc'),
        'color': colors.accentOrange,
        'icon': Icons.warning_amber_rounded
      };
    } else {
      return {
        'level': loc.loc('optimal_tolerance'),
        'desc': loc.loc('optimal_tolerance_desc'),
        'color': colors.successGreen,
        'icon': Icons.check_circle_outline
      };
    }
  }

  Widget _buildDemographicRow(
      IconData icon, String label, String value, AppColors colors) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: colors.primaryDark),
        const SizedBox(width: 15),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: TextStyle(
                      color: colors.textGrey,
                      fontSize: 12,
                      fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text(value,
                  softWrap: true,
                  style: TextStyle(
                      color: colors.textDark,
                      fontWeight: FontWeight.w900,
                      fontSize: 14)),
            ],
          ),
        )
      ],
    );
  }

  Widget _buildAvatarWidget(double size, AppColors colors) {
    if (_localAvatarPath != null) {
      if (_localAvatarPath!.startsWith('preset_')) {
        int index = int.tryParse(_localAvatarPath!.split('_')[1]) ?? 0;
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
      } else if (File(_localAvatarPath!).existsSync()) {
        return ClipOval(
            child: Image.file(File(_localAvatarPath!),
                width: size, height: size, fit: BoxFit.cover));
      }
    }
    if (_currentUser?.photoURL != null) {
      return ClipOval(
          child: Image.network(_currentUser!.photoURL!,
              width: size, height: size, fit: BoxFit.cover));
    }
    return ClipOval(
        child: Image.asset('assets/images/man.png',
            width: size, height: size, fit: BoxFit.cover));
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

    final double activeCap = _userProfile?.dynamicDailyCap ?? 15.0;
    final double multiplier = _userProfile?.multiplier ?? 1.0;
    final tolerance = _getDynamicTolerance(activeCap, multiplier, colors, loc);

    var sortedSymptoms = _symptomCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    var sortedTriggers = _triggerCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
            icon: Image.asset('assets/images/back_1.png',
                width: 24, color: colors.primaryDark),
            onPressed: () => Navigator.pop(context)),
        actions: [
          IconButton(
            icon: Icon(Icons.settings_outlined,
                color: colors.primaryDark, size: 28),
            onPressed: () async {
              HapticFeedback.lightImpact();
              await Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) =>
                          SettingsScreen(dbService: widget.dbService)));
              _loadDynamicUserData();
            },
          ),
          const SizedBox(width: 10),
        ],
      ),
      body: RefreshIndicator(
        color: colors.primary,
        backgroundColor: colors.cardColor,
        onRefresh: _loadDynamicUserData,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(
              parent: BouncingScrollPhysics()),
          child: Column(
            children: [
              Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox(
                    width: 130,
                    height: 130,
                    child: CircularProgressIndicator(
                        value: activeCap / 15.0,
                        strokeWidth: 6,
                        backgroundColor: colors.primaryLight.withOpacity(0.1),
                        valueColor:
                            AlwaysStoppedAnimation<Color>(tolerance['color'])),
                  ),
                  Container(
                    width: 110,
                    height: 110,
                    decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: colors.cardColor, width: 4),
                        boxShadow: [
                          BoxShadow(
                              color: tolerance['color'].withOpacity(0.2),
                              blurRadius: 20,
                              offset: const Offset(0, 8))
                        ]),
                    child: _buildAvatarWidget(110, colors),
                  ),
                ],
              ),
              const SizedBox(height: 15),
              Text(_getUserDisplayName(loc),
                  style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w900,
                      color: colors.textDark)),
              Text(_currentUser?.email ?? loc.loc('no_email_connected'),
                  style: TextStyle(
                      fontSize: 13,
                      color: colors.textGrey,
                      fontWeight: FontWeight.w600)),
              const SizedBox(height: 25),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 25.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildStatColumn(loc.loc('total_scans'),
                        _totalScans.toString(), colors.primaryDark, colors),
                    Container(
                        width: 1, height: 40, color: Colors.grey.shade300),
                    _buildStatColumn(loc.loc('safe_drinks'),
                        _safeScans.toString(), colors.successGreen, colors),
                    Container(
                        width: 1, height: 40, color: Colors.grey.shade300),
                    _buildStatColumn(
                        loc.loc('triggers'),
                        _triggerCounts.length.toString(),
                        colors.errorRed,
                        colors),
                  ],
                ),
              ),
              const SizedBox(height: 35),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 25.0),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(25),
                  decoration: BoxDecoration(
                      color: colors.cardColor,
                      borderRadius: BorderRadius.circular(25),
                      boxShadow: [
                        BoxShadow(
                            color: Colors.black.withOpacity(0.04),
                            blurRadius: 15,
                            offset: const Offset(0, 5))
                      ]),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(loc.loc('medical_demographics'),
                          style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w900,
                              color: colors.textDark)),
                      const SizedBox(height: 20),
                      _buildDemographicRow(
                          Icons.medical_services_outlined,
                          loc.loc('clinical_status'),
                          _userProfile?.clinicalStatus ??
                              loc.loc('preventative'),
                          colors),
                      const Divider(height: 25, color: Colors.black12),
                      _buildDemographicRow(
                          Icons.cake_outlined,
                          loc.loc('age_group'),
                          _userProfile?.ageGroup ?? "26-45",
                          colors),
                      const Divider(height: 25, color: Colors.black12),
                      _buildDemographicRow(
                          Icons.flag_outlined,
                          loc.loc('primary_goal'),
                          _userProfile?.primaryGoal ?? loc.loc('track_limit'),
                          colors),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 25),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 25.0),
                child: Container(
                  decoration: BoxDecoration(
                      color: colors.cardColor,
                      borderRadius: BorderRadius.circular(25),
                      boxShadow: [
                        BoxShadow(
                            color: Colors.black.withOpacity(0.04),
                            blurRadius: 15,
                            offset: const Offset(0, 5))
                      ]),
                  child: Theme(
                    data: Theme.of(context)
                        .copyWith(dividerColor: Colors.transparent),
                    child: ExpansionTile(
                      tilePadding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 10),
                      childrenPadding: const EdgeInsets.only(
                          left: 20, right: 20, bottom: 20),
                      leading: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                              color: tolerance['color'].withOpacity(0.15),
                              shape: BoxShape.circle),
                          child: Icon(tolerance['icon'],
                              color: tolerance['color'], size: 24)),
                      title: Text(loc.loc('todays_tolerance'),
                          style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
                              color: colors.textGrey,
                              letterSpacing: 0.5)),
                      subtitle: Text(tolerance['level'],
                          style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                              color: tolerance['color'])),
                      children: [
                        Text(tolerance['desc'],
                            style: TextStyle(
                                fontSize: 13,
                                color: colors.textDark,
                                height: 1.5,
                                fontWeight: FontWeight.w500)),
                        const SizedBox(height: 15),
                        Container(
                          padding: const EdgeInsets.all(15),
                          decoration: BoxDecoration(
                              color: colors.background,
                              borderRadius: BorderRadius.circular(15)),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(loc.loc('standard_baseline'),
                                        style: TextStyle(
                                            fontSize: 11,
                                            color: colors.textGrey,
                                            fontWeight: FontWeight.bold)),
                                    Text('15.0 Points',
                                        style: TextStyle(
                                            fontSize: 14,
                                            color: colors.primaryDark,
                                            fontWeight: FontWeight.w900))
                                  ]),
                              Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(loc.loc('your_active_limit'),
                                        style: TextStyle(
                                            fontSize: 11,
                                            color: colors.textGrey,
                                            fontWeight: FontWeight.bold)),
                                    Text(
                                        '${activeCap.toStringAsFixed(1)} Points',
                                        style: TextStyle(
                                            fontSize: 14,
                                            color: tolerance['color'],
                                            fontWeight: FontWeight.w900)),
                                    Text(
                                        '≈ ${(activeCap / 4.0).toStringAsFixed(1)} ${loc.loc('coffee_cups')}',
                                        style: TextStyle(
                                            fontSize: 9,
                                            color: colors.textGrey,
                                            fontStyle: FontStyle.italic)),
                                  ]),
                            ],
                          ),
                        )
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 25),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 25.0),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(25),
                  decoration: BoxDecoration(
                      color: colors.cardColor,
                      borderRadius: BorderRadius.circular(25),
                      boxShadow: [
                        BoxShadow(
                            color: Colors.black.withOpacity(0.04),
                            blurRadius: 15,
                            offset: const Offset(0, 5))
                      ]),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(loc.loc('verified_personal_triggers'),
                          style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w900,
                              color: colors.textDark)),
                      const SizedBox(height: 10),
                      if (sortedTriggers.isEmpty)
                        Text(loc.loc('no_verified_triggers'),
                            style: TextStyle(
                                fontSize: 12,
                                color: colors.textGrey,
                                fontStyle: FontStyle.italic))
                      else
                        Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: sortedTriggers
                                .take(4)
                                .map((entry) => _buildInteractiveChip(entry.key,
                                    entry.value, colors.errorRed, colors, loc))
                                .toList()),
                      const Divider(height: 35, color: Colors.black12),
                      Text(loc.loc('frequent_symptoms'),
                          style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w900,
                              color: colors.textDark)),
                      const SizedBox(height: 10),
                      if (sortedSymptoms.isEmpty)
                        Text(loc.loc('no_symptoms_logged'),
                            style: TextStyle(
                                fontSize: 12,
                                color: colors.successGreen,
                                fontStyle: FontStyle.italic))
                      else
                        Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: sortedSymptoms
                                .take(4)
                                .map((entry) => _buildInteractiveChip(
                                    entry.key,
                                    entry.value,
                                    colors.accentOrange,
                                    colors,
                                    loc))
                                .toList()),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 35),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 25.0),
                child: SizedBox(
                  width: double.infinity,
                  height: 55,
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                        side: BorderSide(
                            color: colors.primaryLight.withOpacity(0.5),
                            width: 2),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20))),
                    onPressed: () async {
                      HapticFeedback.mediumImpact();
                      await Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (context) => OnboardingScreen(
                                  dbService: widget.dbService)));
                      _loadDynamicUserData();
                    },
                    child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.refresh,
                              color: colors.primaryDark, size: 20),
                          const SizedBox(width: 10),
                          Text(loc.loc('recalibrate_phase'),
                              style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w900,
                                  color: colors.primaryDark))
                        ]),
                  ),
                ),
              ),
              const SizedBox(height: 100),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatColumn(
      String label, String value, Color color, AppColors colors) {
    return Column(children: [
      Text(value,
          style: TextStyle(
              fontSize: 22, fontWeight: FontWeight.w900, color: color)),
      const SizedBox(height: 4),
      Text(label,
          style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: colors.textGrey))
    ]);
  }

  Widget _buildInteractiveChip(String name, int count, Color color,
      AppColors colors, AppLocalizations loc) {
    return ActionChip(
      backgroundColor: color.withOpacity(0.1),
      side: BorderSide(color: color.withOpacity(0.3)),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      label: Text(name.toUpperCase(),
          style: TextStyle(
              color: color, fontSize: 11, fontWeight: FontWeight.w900)),
      onPressed: () {
        HapticFeedback.selectionClick();
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text("${loc.loc('logged_times')} ($count)",
                style: const TextStyle(fontWeight: FontWeight.bold)),
            backgroundColor: color,
            duration: const Duration(seconds: 2),
            behavior: SnackBarBehavior.floating));
      },
    );
  }
}

// ==========================================
// 2. THE SETTINGS HUB
// ==========================================
class SettingsScreen extends StatefulWidget {
  final DatabaseService dbService;
  const SettingsScreen({super.key, required this.dbService});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _hapticEnabled = true;
  bool _autoFlashEnabled = false;
  bool _batchScanEnabled = false;
  bool _strictModeEnabled = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _hapticEnabled = prefs.getBool('setting_haptic') ?? true;
      _autoFlashEnabled = prefs.getBool('setting_flash') ?? false;
      _batchScanEnabled = prefs.getBool('setting_batch') ?? false;
      _strictModeEnabled = prefs.getBool('setting_strictness') ?? false;
    });
  }

  Future<void> _saveSetting(String key, bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(key, value);
    if (_hapticEnabled) HapticFeedback.lightImpact();
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
            onPressed: () => Navigator.pop(context)),
        title: Text(loc.loc('settings'),
            style: TextStyle(
                color: colors.primaryDark,
                fontWeight: FontWeight.w900,
                fontSize: 20)),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 25.0, vertical: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionHeader(loc.loc('account'), colors),
            _buildSettingsCard([
              _buildNavRow(
                  Icons.person_outline,
                  loc.loc('edit_profile'),
                  () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) => const PersonalDetailScreen())),
                  colors: colors),
            ], colors),
            const SizedBox(height: 25),
            _buildSectionHeader(loc.loc('customization'), colors),
            _buildSettingsCard([
              _buildNavRow(
                  Icons.color_lens_outlined,
                  loc.loc('appearance_theme'),
                  () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) =>
                              const AppearanceSettingsScreen())),
                  colors: colors),
            ], colors),
            const SizedBox(height: 25),
            _buildSectionHeader(loc.loc('pro_scanner_prefs'), colors),
            _buildSettingsCard([
              _buildToggleRow(Icons.bolt_outlined, loc.loc('batch_scan_mode'),
                  loc.loc('batch_scan_mode_desc'), _batchScanEnabled, (val) {
                setState(() => _batchScanEnabled = val);
                _saveSetting('setting_batch', val);
              }, colors),
              const Divider(height: 1, color: Colors.black12),
              _buildToggleRow(
                  Icons.health_and_safety_outlined,
                  loc.loc('strict_risk_filter'),
                  loc.loc('strict_risk_filter_desc'),
                  _strictModeEnabled, (val) {
                setState(() => _strictModeEnabled = val);
                _saveSetting('setting_strictness', val);
              }, colors),
              const Divider(height: 1, color: Colors.black12),
              _buildToggleRow(Icons.vibration, loc.loc('haptic_feedback'),
                  loc.loc('haptic_feedback_desc'), _hapticEnabled, (val) {
                setState(() => _hapticEnabled = val);
                _saveSetting('setting_haptic', val);
              }, colors),
              const Divider(height: 1, color: Colors.black12),
              _buildToggleRow(
                  Icons.highlight_outlined,
                  loc.loc('auto_flashlight'),
                  loc.loc('auto_flashlight_desc'),
                  _autoFlashEnabled, (val) {
                setState(() => _autoFlashEnabled = val);
                _saveSetting('setting_flash', val);
              }, colors),
            ], colors),
            const SizedBox(height: 25),
            _buildSectionHeader(loc.loc('security_legal'), colors),
            _buildSettingsCard([
              _buildNavRow(
                  Icons.shield_outlined,
                  loc.loc('medical_privacy_hub'),
                  () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) => PrivacySettingsScreen(
                              dbService: widget.dbService))),
                  colors: colors),
              const Divider(height: 1, color: Colors.black12),
              _buildNavRow(
                  Icons.info_outline,
                  loc.loc('info_support'),
                  () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) => const InformationScreen())),
                  colors: colors),
            ], colors),
            const SizedBox(height: 25),
            _buildSettingsCard([
              _buildNavRow(Icons.logout, loc.loc('log_out'),
                  () => _confirmLogout(context, colors, loc),
                  isDestructive: true, colors: colors),
            ], colors),
            const SizedBox(height: 50),
          ],
        ),
      ),
    );
  }

  void _confirmLogout(
      BuildContext context, AppColors colors, AppLocalizations loc) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: colors.cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(loc.loc('log_out_q'),
            style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: colors.errorRed)),
        content: Text(loc.loc('log_out_desc'),
            style: TextStyle(color: colors.textDark)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(loc.loc('cancel'),
                  style: const TextStyle(color: Colors.grey))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: colors.errorRed,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10))),
            onPressed: () async {
              Navigator.pop(context);
              await FirebaseAuth.instance.signOut();
              await GoogleSignIn().signOut();
              if (context.mounted) {
                Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(
                        builder: (context) =>
                            WelcomeScreen(dbService: widget.dbService)),
                    (route) => false);
              }
            },
            child: Text(loc.loc('log_out'),
                style: const TextStyle(
                    color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, AppColors colors) {
    return Padding(
        padding: const EdgeInsets.only(left: 10, bottom: 10),
        child: Text(title,
            style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w900,
                color: colors.textGrey)));
  }

  Widget _buildSettingsCard(List<Widget> children, AppColors colors) {
    return Container(
        decoration: BoxDecoration(
            color: colors.cardColor,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 10,
                  offset: const Offset(0, 4))
            ]),
        child: Column(children: children));
  }

  Widget _buildNavRow(IconData icon, String title, VoidCallback onTap,
      {bool isDestructive = false, required AppColors colors}) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      leading: Icon(icon,
          size: 22, color: isDestructive ? colors.errorRed : colors.textDark),
      title: Text(title,
          style: TextStyle(
              fontSize: 14,
              fontWeight: isDestructive ? FontWeight.w900 : FontWeight.bold,
              color: isDestructive ? colors.errorRed : colors.textDark)),
      trailing: isDestructive
          ? null
          : const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey),
      onTap: onTap,
    );
  }

  Widget _buildToggleRow(IconData icon, String title, String subtitle,
      bool value, ValueChanged<bool> onChanged, AppColors colors) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
      child: Row(
        children: [
          Icon(icon, size: 22, color: colors.textDark),
          const SizedBox(width: 15),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(title,
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: colors.textDark)),
                const SizedBox(height: 2),
                Text(subtitle,
                    style: const TextStyle(
                        fontSize: 10, color: Colors.grey, height: 1.3))
              ])),
          Switch(
              value: value,
              onChanged: onChanged,
              activeColor: colors.primaryDark,
              activeTrackColor: colors.primaryLight)
        ],
      ),
    );
  }
}

// ==========================================
// 3. UPGRADED PERSONAL DETAILS WITH UNLOCKED RESET
// ==========================================
class PersonalDetailScreen extends StatefulWidget {
  const PersonalDetailScreen({super.key});
  @override
  State<PersonalDetailScreen> createState() => _PersonalDetailScreenState();
}

class _PersonalDetailScreenState extends State<PersonalDetailScreen> {
  final _nameController = TextEditingController();
  final User? user = FirebaseAuth.instance.currentUser;

  bool _isSaving = false;
  String? _localAvatarPath;

  @override
  void initState() {
    super.initState();
    _nameController.text = user?.displayName ?? "";
    _loadCustomAvatar();
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _loadCustomAvatar() async {
    if (user != null) {
      final prefs = await SharedPreferences.getInstance();
      setState(() {
        _localAvatarPath = prefs.getString('local_avatar_${user!.uid}');
      });
    }
  }

  Widget _buildAvatarWidget(double size, AppColors colors) {
    if (_localAvatarPath != null) {
      if (_localAvatarPath!.startsWith('preset_')) {
        int index = int.tryParse(_localAvatarPath!.split('_')[1]) ?? 0;
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
      } else if (File(_localAvatarPath!).existsSync()) {
        return ClipOval(
            child: Image.file(File(_localAvatarPath!),
                width: size, height: size, fit: BoxFit.cover));
      }
    }
    if (user?.photoURL != null) {
      return ClipOval(
          child: Image.network(user!.photoURL!,
              width: size, height: size, fit: BoxFit.cover));
    }
    return ClipOval(
        child: Image.asset('assets/images/man.png',
            width: size, height: size, fit: BoxFit.cover));
  }

  Future<void> _pickAvatarImage(
      ImageSource source, AppColors colors, AppLocalizations loc) async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: source, imageQuality: 70);

    if (pickedFile != null && user != null) {
      try {
        final directory = await getApplicationDocumentsDirectory();
        final timestamp = DateTime.now().millisecondsSinceEpoch;
        final savedImage = await File(pickedFile.path)
            .copy('${directory.path}/avatar_${user!.uid}_$timestamp.jpg');

        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('local_avatar_${user!.uid}', savedImage.path);

        setState(() => _localAvatarPath = savedImage.path);

        if (mounted) {
          Provider.of<UserSessionProvider>(context, listen: false)
              .refreshSession();
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text(loc.loc('avatar_updated')),
              backgroundColor: colors.successGreen));
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text("${loc.loc('error_msg')}: ${e.toString()}"),
              backgroundColor: colors.errorRed));
        }
      }
    }
  }

  void _setPresetAvatar(
      int index, AppColors colors, AppLocalizations loc) async {
    if (user == null) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('local_avatar_${user!.uid}', 'preset_$index');
    setState(() => _localAvatarPath = 'preset_$index');

    if (mounted) {
      Provider.of<UserSessionProvider>(context, listen: false).refreshSession();
    }

    Navigator.pop(context);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(loc.loc('avatar_updated')),
          backgroundColor: colors.successGreen));
    }
  }

  void _showAvatarOptions(AppColors colors, AppLocalizations loc) {
    showModalBottomSheet(
        context: context,
        backgroundColor: colors.cardColor,
        shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(25))),
        builder: (BuildContext context) {
          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(loc.loc('update_profile_pic'),
                      style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          color: colors.primaryDark)),
                  const SizedBox(height: 20),
                  ListTile(
                    leading:
                        Icon(Icons.camera_alt_outlined, color: colors.textDark),
                    title: Text(loc.loc('take_photo'),
                        style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: colors.textDark)),
                    onTap: () {
                      Navigator.pop(context);
                      _pickAvatarImage(ImageSource.camera, colors, loc);
                    },
                  ),
                  ListTile(
                    leading: Icon(Icons.photo_library_outlined,
                        color: colors.textDark),
                    title: Text(loc.loc('choose_gallery'),
                        style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: colors.textDark)),
                    onTap: () {
                      Navigator.pop(context);
                      _pickAvatarImage(ImageSource.gallery, colors, loc);
                    },
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    child: Divider(),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 15),
                    child: Text(loc.loc('choose_preset_avatar'),
                        style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: colors.textGrey,
                            fontSize: 12)),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: List.generate(5, (index) {
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
                      return GestureDetector(
                        onTap: () => _setPresetAvatar(index, colors, loc),
                        child: Container(
                          width: 50,
                          height: 50,
                          decoration: BoxDecoration(
                              color: presetColors[index].withOpacity(0.2),
                              shape: BoxShape.circle),
                          child: Icon(icons[index],
                              color: presetColors[index], size: 25),
                        ),
                      );
                    }),
                  )
                ],
              ),
            ),
          );
        });
  }

  void _confirmNameUpdate(AppColors colors, AppLocalizations loc) {
    final newName = _nameController.text.trim();
    if (newName.isEmpty || newName == user?.displayName) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: colors.cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(loc.loc('confirm_name_change'),
            style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: colors.primaryDark)),
        content: Text("${loc.loc('confirm_name_desc')} $newName?",
            style: TextStyle(color: colors.textDark)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(loc.loc('cancel'),
                  style: const TextStyle(color: Colors.grey))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: colors.primary,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10))),
            onPressed: () {
              Navigator.pop(context);
              _updateDisplayName(newName, colors, loc);
            },
            child: Text(loc.loc('save_changes'),
                style: const TextStyle(
                    color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Future<void> _updateDisplayName(
      String newName, AppColors colors, AppLocalizations loc) async {
    setState(() => _isSaving = true);
    try {
      await user?.updateDisplayName(newName);
      await user?.reload();
      if (mounted) {
        Provider.of<UserSessionProvider>(context, listen: false)
            .refreshSession();
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(loc.loc('name_updated')),
            backgroundColor: colors.successGreen));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text("${loc.loc('error_msg')}: ${e.toString()}"),
            backgroundColor: colors.errorRed));
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _confirmPasswordReset(AppColors colors, AppLocalizations loc) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: colors.cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(loc.loc('send_reset_email'),
            style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: colors.primaryDark)),
        content: Text("${loc.loc('send_reset_desc')}\n${user?.email}",
            style: TextStyle(color: colors.textDark)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(loc.loc('cancel'),
                  style: const TextStyle(color: Colors.grey))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: colors.primary,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10))),
            onPressed: () {
              Navigator.pop(context);
              _sendPasswordReset(colors, loc);
            },
            child: Text(loc.loc('send_email'),
                style: const TextStyle(
                    color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Future<void> _sendPasswordReset(
      AppColors colors, AppLocalizations loc) async {
    if (user?.email == null) return;
    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: user!.email!);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text("${loc.loc('reset_link_sent')} ${user!.email!}"),
            backgroundColor: colors.successGreen));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text("${loc.loc('error_msg')}: ${e.toString()}"),
            backgroundColor: colors.errorRed));
      }
    }
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
              onPressed: () => Navigator.pop(context))),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(30.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
                child: Text(loc.loc('account_profile'),
                    style: TextStyle(
                        color: colors.primaryDark,
                        fontWeight: FontWeight.w900,
                        fontSize: 22))),
            const SizedBox(height: 35),
            Center(
              child: GestureDetector(
                onTap: () => _showAvatarOptions(colors, loc),
                child: Stack(
                  alignment: Alignment.bottomRight,
                  children: [
                    Container(
                      width: 110,
                      height: 110,
                      decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: colors.primaryLight.withOpacity(0.3),
                          border: Border.all(color: colors.cardColor, width: 4),
                          boxShadow: [
                            BoxShadow(
                                color: Colors.black.withOpacity(0.05),
                                blurRadius: 10,
                                offset: const Offset(0, 5))
                          ]),
                      child: _buildAvatarWidget(110, colors),
                    ),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                          color: colors.primaryDark,
                          shape: BoxShape.circle,
                          border:
                              Border.all(color: colors.cardColor, width: 2)),
                      child: const Icon(Icons.camera_alt,
                          color: Colors.white, size: 18),
                    )
                  ],
                ),
              ),
            ),
            const SizedBox(height: 40),
            Text(loc.loc('display_name'),
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                    color: colors.textDark)),
            const SizedBox(height: 10),
            TextField(
                controller: _nameController,
                style: TextStyle(color: colors.textDark),
                decoration: InputDecoration(
                    filled: true,
                    fillColor: colors.cardColor,
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(15),
                        borderSide: BorderSide.none))),
            const SizedBox(height: 15),
            SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                        backgroundColor: colors.primary,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(15))),
                    onPressed: _isSaving
                        ? null
                        : () => _confirmNameUpdate(colors, loc),
                    child: _isSaving
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                                color: Colors.white, strokeWidth: 2))
                        : Text(loc.loc('save_changes'),
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 15,
                                fontWeight: FontWeight.bold)))),
            const SizedBox(height: 40),
            Text(loc.loc('registered_email'),
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                    color: colors.textDark)),
            const SizedBox(height: 10),
            TextField(
                readOnly: true,
                style: TextStyle(color: colors.textDark),
                controller: TextEditingController(
                    text: user?.email ?? loc.loc('no_email_associated')),
                decoration: InputDecoration(
                    filled: true,
                    fillColor:
                        colors.isDark ? Colors.black26 : Colors.grey.shade200,
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(15),
                        borderSide: BorderSide.none))),
            const SizedBox(height: 30),
            SizedBox(
                width: double.infinity,
                height: 50,
                child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                        side: BorderSide(color: colors.primary),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(15))),
                    icon: Icon(Icons.lock_reset, color: colors.primary),
                    label: Text(loc.loc('send_password_reset'),
                        style: TextStyle(
                            color: colors.primary,
                            fontWeight: FontWeight.bold,
                            fontSize: 15)),
                    onPressed: () => _confirmPasswordReset(colors, loc))),
          ],
        ),
      ),
    );
  }
}

// ==========================================
// 4. THE MEDICAL DATA & PRIVACY HUB
// ==========================================
class PrivacySettingsScreen extends StatefulWidget {
  final DatabaseService dbService;
  const PrivacySettingsScreen({super.key, required this.dbService});
  @override
  State<PrivacySettingsScreen> createState() => _PrivacySettingsScreenState();
}

class _PrivacySettingsScreenState extends State<PrivacySettingsScreen> {
  bool _cloudSyncEnabled = false;
  bool _analyticsEnabled = true;
  bool _isLoading = true;
  bool _isExporting = false;

  UserProfile? _profile;

  @override
  void initState() {
    super.initState();
    _loadPrivacyState();
  }

  Future<void> _loadPrivacyState() async {
    final prefs = await SharedPreferences.getInstance();
    final profile = await widget.dbService.getUserProfile();

    setState(() {
      _profile = profile;
      _cloudSyncEnabled = profile?.cloudSyncEnabled ?? false;
      _analyticsEnabled = prefs.getBool('t3_usage_data') ?? true;
      _isLoading = false;
    });
  }

  Future<void> _toggleCloudSync(
      bool value, AppColors colors, AppLocalizations loc) async {
    if (value == false) {
      bool? confirm = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: colors.cardColor,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(loc.loc('disable_cloud_backup_q'),
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: colors.errorRed)),
          content: Text(loc.loc('disable_cloud_desc'),
              style: TextStyle(color: colors.textDark)),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text(loc.loc('cancel'),
                    style: const TextStyle(color: Colors.grey))),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: colors.errorRed,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10))),
              onPressed: () => Navigator.pop(context, true),
              child: Text(loc.loc('disable_sync'),
                  style: const TextStyle(
                      color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      );
      if (confirm != true) return;
    }

    if (_profile != null) {
      _profile!.cloudSyncEnabled = value;
      await widget.dbService.isar.writeTxn(() async {
        await widget.dbService.isar.userProfiles.put(_profile!);
      });
      setState(() => _cloudSyncEnabled = value);
    }
  }

  Future<void> _toggleAnalytics(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('t3_usage_data', value);
    setState(() => _analyticsEnabled = value);
  }

  Future<void> _exportDataToCSV(AppLocalizations loc) async {
    setState(() => _isExporting = true);
    try {
      final items = await widget.dbService.getPantryItems();
      List<List<dynamic>> rows = [];
      rows.add([
        loc.loc('csv_date_scanned'),
        loc.loc('csv_product_name'),
        loc.loc('csv_risk_level'),
        loc.loc('csv_acid_score'),
        loc.loc('csv_symptoms_logged')
      ]);
      for (var item in items) {
        rows.add([
          DateFormat('MM/dd/yyyy hh:mm a').format(item.dateScanned),
          item.name,
          item.riskLevel,
          item.acidScore,
          item.symptoms.isEmpty ? loc.loc('csv_none') : item.symptoms
        ]);
      }
      String csv = rows
          .map((row) => row.map((field) {
                String str = field.toString();
                return (str.contains(',') ||
                        str.contains('"') ||
                        str.contains('\n'))
                    ? '"${str.replaceAll('"', '""')}"'
                    : str;
              }).join(','))
          .join('\n');
      final directory = await getTemporaryDirectory();
      final path = "${directory.path}/TriggerLens_Data_Export.csv";
      await File(path).writeAsString(csv);
      if (mounted) {
        await Share.shareXFiles([XFile(path)],
            text: loc.loc('csv_export_title'));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('${loc.loc('export_failed')}: $e'),
            backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  void _confirmLocalWipe(AppColors colors, AppLocalizations loc) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: colors.cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(loc.loc('erase_local_logs_q'),
            style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: colors.errorRed)),
        content: Text(loc.loc('erase_local_desc'),
            style: TextStyle(color: colors.textDark)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(loc.loc('cancel'),
                  style: const TextStyle(color: Colors.grey))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: colors.errorRed,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10))),
            onPressed: () async {
              Navigator.pop(context);
              await widget.dbService.wipeCurrentUserLocalData();
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text(loc.loc('local_data_erased')),
                    backgroundColor: colors.successGreen));
              }
            },
            child: Text(loc.loc('erase_local_data'),
                style: const TextStyle(
                    color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _confirmAccountDeletion(AppColors colors, AppLocalizations loc) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: colors.cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(children: [
          Icon(Icons.warning_amber_rounded, color: colors.errorRed, size: 28),
          const SizedBox(width: 10),
          Text(loc.loc('delete_account_q'),
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: colors.errorRed))
        ]),
        content: Text(loc.loc('delete_account_desc'),
            style: TextStyle(color: colors.textDark)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(loc.loc('cancel'),
                  style: const TextStyle(color: Colors.grey))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: colors.errorRed,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10))),
            onPressed: () async {
              Navigator.pop(context);
              try {
                await widget.dbService.wipeCurrentUserLocalData();
                await FirebaseAuth.instance.currentUser?.delete();
                await GoogleSignIn().signOut();
                if (context.mounted) {
                  Navigator.pushAndRemoveUntil(
                      context,
                      MaterialPageRoute(
                          builder: (context) =>
                              WelcomeScreen(dbService: widget.dbService)),
                      (route) => false);
                }
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text(loc.loc('security_requirement_delete')),
                    backgroundColor: Colors.red));
              }
            },
            child: Text(loc.loc('permanently_delete'),
                style: const TextStyle(
                    color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final loc = AppLocalizations.of(context);

    if (_isLoading) {
      return Scaffold(
          backgroundColor: colors.background,
          body: const Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
              icon: Image.asset('assets/images/back_1.png',
                  width: 24, color: colors.primaryDark),
              onPressed: () => Navigator.pop(context))),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(30.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(loc.loc('medical_data_hub_title'),
                style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w900,
                    color: colors.primaryDark,
                    height: 1.2)),
            const SizedBox(height: 40),
            Text(loc.loc('storage_policy'),
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    color: colors.textDark)),
            const SizedBox(height: 20),
            _buildToggleRow(
                loc.loc('cloud_sync'),
                loc.loc('cloud_sync_desc'),
                _cloudSyncEnabled,
                (val) => _toggleCloudSync(val, colors, loc),
                colors),
            _buildToggleRow(
                loc.loc('anonymous_analytics'),
                loc.loc('anonymous_analytics_desc'),
                _analyticsEnabled,
                _toggleAnalytics,
                colors),
            const SizedBox(height: 30),
            Text(loc.loc('data_portability'),
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    color: colors.textDark)),
            const SizedBox(height: 20),
            _buildActionRow(
                loc.loc('request_data_export'),
                loc.loc('request_data_export_desc'),
                Icons.download_rounded,
                _isExporting ? null : () => _exportDataToCSV(loc),
                colors,
                isLoading: _isExporting),
            const SizedBox(height: 30),
            Text(loc.loc('danger_zone'),
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    color: colors.errorRed)),
            const SizedBox(height: 20),
            _buildActionRow(
                loc.loc('erase_local_logs'),
                loc.loc('erase_local_logs_desc'),
                Icons.phonelink_erase_outlined,
                () => _confirmLocalWipe(colors, loc),
                colors,
                isDestructive: true),
            _buildActionRow(
                loc.loc('erase_account'),
                loc.loc('erase_account_desc'),
                Icons.delete_forever,
                () => _confirmAccountDeletion(colors, loc),
                colors,
                isDestructive: true),
            const SizedBox(height: 100),
          ],
        ),
      ),
    );
  }

  Widget _buildToggleRow(String title, String subtitle, bool value,
      ValueChanged<bool> onChanged, AppColors colors) {
    return Padding(
        padding: const EdgeInsets.only(bottom: 20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Expanded(
                child: Text(title,
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                        color: colors.textDark))),
            Switch(
                value: value,
                onChanged: onChanged,
                activeColor: colors.primaryDark,
                activeTrackColor: colors.primaryLight)
          ]),
          const SizedBox(height: 4),
          Text(subtitle,
              style: const TextStyle(
                  fontSize: 10, color: Colors.grey, height: 1.4))
        ]));
  }

  Widget _buildActionRow(String title, String subtitle, IconData icon,
      VoidCallback? onTap, AppColors colors,
      {bool isDestructive = false, bool isLoading = false}) {
    return InkWell(
        onTap: onTap,
        child: Padding(
            padding: const EdgeInsets.only(bottom: 20, top: 10),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                isLoading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : Icon(icon,
                        size: 20,
                        color: isDestructive
                            ? colors.errorRed
                            : colors.primaryDark),
                const SizedBox(width: 15),
                Expanded(
                    child: Text(title,
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w900,
                            color: isDestructive
                                ? colors.errorRed
                                : colors.textDark)))
              ]),
              const SizedBox(height: 8),
              Text(subtitle,
                  style: const TextStyle(
                      fontSize: 10, color: Colors.grey, height: 1.4))
            ])));
  }
}

class InformationScreen extends StatelessWidget {
  const InformationScreen({super.key});
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
              onPressed: () => Navigator.pop(context))),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(30.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(loc.loc('information'),
                style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                    color: colors.primaryDark)),
            const SizedBox(height: 40),
            _buildSection(
                loc.loc('about_triggerlens'),
                [
                  _buildItem('Version 1.0.0', loc.loc('version_desc'), colors,
                      showArrow: false)
                ],
                colors),
            _buildSection(
                loc.loc('help_support'),
                [
                  _buildItem(loc.loc('how_to_use_scanner'),
                      loc.loc('how_to_use_scanner_desc'), colors,
                      showArrow: true)
                ],
                colors),
            _buildSection(
                loc.loc('legal_safety'),
                [
                  _buildItem(loc.loc('medical_disclaimer'),
                      loc.loc('medical_disclaimer_desc'), colors,
                      showArrow: true)
                ],
                colors),
          ],
        ),
      ),
    );
  }

  Widget _buildSection(String title, List<Widget> items, AppColors colors) {
    return Padding(
        padding: const EdgeInsets.only(bottom: 30),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title,
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  color: colors.textDark)),
          const SizedBox(height: 15),
          ...items
        ]));
  }

  Widget _buildItem(String title, String subtitle, AppColors colors,
      {required bool showArrow}) {
    return Padding(
        padding: const EdgeInsets.only(bottom: 20, left: 10),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text(title,
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                    color: colors.textDark)),
            if (showArrow)
              Icon(Icons.arrow_forward_ios, size: 12, color: colors.textGrey)
          ]),
          const SizedBox(height: 5),
          Text(subtitle,
              style: const TextStyle(
                  fontSize: 10, color: Colors.grey, height: 1.4))
        ]));
  }
}

// ==========================================
// 5. NEW: INTERACTIVE APPEARANCE & THEME SCREEN
// ==========================================
class AppearanceSettingsScreen extends StatelessWidget {
  const AppearanceSettingsScreen({super.key});

  void _confirmLanguageChange(BuildContext context, String langCode,
      String langName, AppColors colors, AppLocalizations loc) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: colors.cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(langCode == 'en' ? 'Change Language?' : 'Palitan ang Wika?',
            style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: colors.primaryDark)),
        content: Text(
            langCode == 'en'
                ? 'Are you sure you want to change the language to $langName?'
                : 'Sigurado ka bang gusto mong palitan ang wika sa $langName?',
            style: TextStyle(color: colors.textDark)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(langCode == 'en' ? 'Cancel' : 'Kanselahin',
                  style: const TextStyle(color: Colors.grey))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: colors.primary,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10))),
            onPressed: () {
              Navigator.pop(context);
              loc.languageProvider.setLanguage(langCode);
            },
            child: Text(langCode == 'en' ? 'Confirm' : 'Kumpirmahin',
                style: const TextStyle(
                    color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final loc = AppLocalizations.of(context);
    final themeProvider = Provider.of<ThemeProvider>(context);

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
            icon: Image.asset('assets/images/back_1.png',
                width: 24, color: colors.primaryDark),
            onPressed: () => Navigator.pop(context)),
        title: Text(loc.loc('appearance_theme'),
            style: TextStyle(
                color: colors.primaryDark,
                fontWeight: FontWeight.w900,
                fontSize: 20)),
        centerTitle: true,
      ),
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 500),
        transitionBuilder: (Widget child, Animation<double> animation) {
          return FadeTransition(opacity: animation, child: child);
        },
        child: SingleChildScrollView(
          key: ValueKey<String>(loc.languageProvider.currentLanguage),
          padding: const EdgeInsets.all(25.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // LIVE PREVIEW CARD
              Text(loc.loc('live_preview'),
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                      color: colors.textGrey)),
              const SizedBox(height: 15),
              Container(
                padding: const EdgeInsets.all(25),
                decoration: BoxDecoration(
                    gradient: colors.primaryGradient,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                          color: colors.primary.withOpacity(0.4),
                          blurRadius: 20,
                          offset: const Offset(0, 10))
                    ]),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      const Icon(Icons.check_circle_outline,
                          color: Colors.white),
                      const SizedBox(width: 10),
                      Text(loc.loc('theme_active'),
                          style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 16))
                    ]),
                    const SizedBox(height: 15),
                    Text(loc.loc('theme_preview_desc'),
                        style: const TextStyle(
                            color: Colors.white70, fontSize: 12, height: 1.4)),
                    const SizedBox(height: 20),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(10)),
                      child: Center(
                          child: Text(loc.loc('sample_button'),
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold))),
                    )
                  ],
                ),
              ),
              const SizedBox(height: 40),

              // LIGHT/DARK MODE TOGGLE
              Text(loc.loc('display_mode'),
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                      color: colors.textGrey)),
              const SizedBox(height: 15),
              Container(
                decoration: BoxDecoration(
                    color: colors.cardColor,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                          color: Colors.black.withOpacity(0.04),
                          blurRadius: 10,
                          offset: const Offset(0, 4))
                    ]),
                child: SwitchListTile(
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 5),
                  title: Text(loc.loc('dark_mode'),
                      style: TextStyle(
                          fontWeight: FontWeight.bold, color: colors.textDark)),
                  subtitle: Text(loc.loc('dark_mode_desc'),
                      style: TextStyle(fontSize: 11, color: colors.textGrey)),
                  value: themeProvider.themeMode == ThemeMode.dark,
                  onChanged: (val) {
                    themeProvider
                        .setThemeMode(val ? ThemeMode.dark : ThemeMode.light);
                  },
                  activeColor: colors.primaryDark,
                  activeTrackColor: colors.primaryLight,
                ),
              ),
              const SizedBox(height: 40),

              // 10-COLOR THEME SELECTOR
              Text(loc.loc('accent_color'),
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                      color: colors.textGrey)),
              const SizedBox(height: 15),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                child: Row(
                  children: ThemeProvider.availableThemes.map((themeColor) {
                    bool isSelected =
                        themeProvider.seedColor.value == themeColor.value;
                    return GestureDetector(
                      onTap: () {
                        HapticFeedback.lightImpact();
                        themeProvider.setSeedColor(themeColor);
                      },
                      child: Container(
                        margin: const EdgeInsets.only(right: 15),
                        width: 55,
                        height: 55,
                        decoration: BoxDecoration(
                          color: themeColor,
                          shape: BoxShape.circle,
                          border: isSelected
                              ? Border.all(color: colors.textDark, width: 4)
                              : null,
                          boxShadow: [
                            if (isSelected)
                              BoxShadow(
                                  color: themeColor.withOpacity(0.4),
                                  blurRadius: 10,
                                  spreadRadius: 2)
                          ],
                        ),
                        child: isSelected
                            ? const Icon(Icons.check,
                                color: Colors.white, size: 28)
                            : null,
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 40),

              // LANGUAGE TOGGLE
              Text(loc.loc('language'),
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                      color: colors.textGrey)),
              const SizedBox(height: 15),
              // NEW: Smooth Animated Segmented Control for Language Switcher
              Container(
                height: 55,
                decoration: BoxDecoration(
                  color: colors.isDark ? Colors.white10 : Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Stack(
                  children: [
                    AnimatedAlign(
                      alignment: loc.languageProvider.currentLanguage == 'en'
                          ? Alignment.centerLeft
                          : Alignment.centerRight,
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeOutCubic,
                      child: FractionallySizedBox(
                        widthFactor: 0.5,
                        heightFactor: 1.0,
                        child: Container(
                          decoration: BoxDecoration(
                              color: colors.primary,
                              borderRadius: BorderRadius.circular(15),
                              boxShadow: [
                                BoxShadow(
                                    color: colors.primary.withOpacity(0.3),
                                    blurRadius: 8,
                                    offset: const Offset(0, 4))
                              ]),
                        ),
                      ),
                    ),
                    Row(
                      children: [
                        Expanded(
                          child: GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: () {
                              if (loc.languageProvider.currentLanguage !=
                                  'en') {
                                HapticFeedback.lightImpact();
                                _confirmLanguageChange(
                                    context, 'en', 'English', colors, loc);
                              }
                            },
                            child: Center(
                              child: AnimatedDefaultTextStyle(
                                duration: const Duration(milliseconds: 300),
                                style: TextStyle(
                                  fontFamily: 'Nunito',
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                  color: loc.languageProvider.currentLanguage ==
                                          'en'
                                      ? Colors.white
                                      : colors.textGrey,
                                ),
                                child: const Text('English'),
                              ),
                            ),
                          ),
                        ),
                        Expanded(
                          child: GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: () {
                              if (loc.languageProvider.currentLanguage !=
                                  'tl') {
                                HapticFeedback.lightImpact();
                                _confirmLanguageChange(
                                    context, 'tl', 'Tagalog', colors, loc);
                              }
                            },
                            child: Center(
                              child: AnimatedDefaultTextStyle(
                                duration: const Duration(milliseconds: 300),
                                style: TextStyle(
                                  fontFamily: 'Nunito',
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                  color: loc.languageProvider.currentLanguage ==
                                          'tl'
                                      ? Colors.white
                                      : colors.textGrey,
                                ),
                                child: const Text('Tagalog'),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
