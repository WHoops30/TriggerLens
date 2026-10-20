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

import '../../services/database_service.dart';
import '../../models/user_profile.dart';
import '../../models/pantry_item.dart';
import '../../utils/ui_helpers.dart';
import 'onboarding/welcome_screen.dart';
import 'gerdq_screen.dart';

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

    int safeCount = 0;
    Map<String, int> sympCounts = {};
    Map<String, int> trigCounts = {};

    for (var item in items) {
      if (item.riskLevel == "GREEN") safeCount++;

      if (item.symptoms.isNotEmpty && item.symptoms != "None") {
        sympCounts[item.symptoms] = (sympCounts[item.symptoms] ?? 0) + 1;
      }
      if (item.riskLevel == "RED" || item.riskLevel == "YELLOW") {
        trigCounts[item.name] = (trigCounts[item.name] ?? 0) + 1;
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

  String _getUserDisplayName() {
    if (_currentUser?.displayName != null &&
        _currentUser!.displayName!.trim().isNotEmpty) {
      return _currentUser!.displayName!;
    }
    if (_currentUser?.email != null && _currentUser!.email!.isNotEmpty) {
      return _currentUser!.email!.split('@').first;
    }
    return "Tummy Friend";
  }

  Map<String, dynamic> _getDynamicTolerance(double baseCap, double activeCap) {
    double ratio = baseCap > 0 ? (activeCap / baseCap) : 1.0;

    if (ratio >= 1.0) {
      return {
        'level': 'Optimal Tolerance',
        'desc':
            'Your stomach is operating at its full personal baseline today. You have standard flexibility.',
        'color': AppColors.successGreen,
        'icon': Icons.check_circle_outline
      };
    } else if (ratio >= 0.75) {
      return {
        'level': 'Slightly Sensitive',
        'desc':
            'Your acid limit is slightly reduced today. Stick to milder drinks if possible.',
        'color': AppColors.accentOrange,
        'icon': Icons.warning_amber_rounded
      };
    } else {
      return {
        'level': 'Highly Sensitive',
        'desc':
            'Your tolerance is severely restricted due to recent symptoms or stress. Hydrate strictly with water.',
        'color': AppColors.errorRed,
        'icon': Icons.local_fire_department_outlined
      };
    }
  }

  Widget _buildAvatarWidget(double size) {
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
        List<Color> colors = [
          Colors.blue,
          Colors.green,
          AppColors.primary,
          Colors.pink,
          Colors.teal
        ];
        return Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
              color: colors[index % colors.length].withOpacity(0.2),
              shape: BoxShape.circle),
          child: Icon(icons[index % icons.length],
              color: colors[index % colors.length], size: size * 0.5),
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
    if (_isLoading)
      return const Scaffold(
          backgroundColor: AppColors.background,
          body: Center(
              child: CircularProgressIndicator(color: AppColors.primary)));

    final double baseCap = _userProfile?.baseDailyCap ?? 15.0;
    final double activeCap = _userProfile?.dynamicDailyCap ?? 15.0;
    final double multiplier = _userProfile?.multiplier ?? 1.0;
    final tolerance = _getDynamicTolerance(baseCap, activeCap);

    var sortedSymptoms = _symptomCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    var sortedTriggers = _triggerCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
            icon: Image.asset('assets/images/back_1.png',
                width: 24, color: AppColors.primaryDark),
            onPressed: () => Navigator.pop(context)),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined,
                color: AppColors.primaryDark, size: 28),
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
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Column(
          children: [
            Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 130,
                  height: 130,
                  child: CircularProgressIndicator(
                      value: baseCap > 0 ? (activeCap / baseCap) : 1.0,
                      strokeWidth: 6,
                      backgroundColor: Colors.grey.shade200,
                      valueColor:
                          AlwaysStoppedAnimation<Color>(tolerance['color'])),
                ),
                Container(
                  width: 110,
                  height: 110,
                  decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 4),
                      boxShadow: [
                        BoxShadow(
                            color: tolerance['color'].withOpacity(0.2),
                            blurRadius: 20,
                            offset: const Offset(0, 8))
                      ]),
                  child: _buildAvatarWidget(110),
                ),
              ],
            ),
            const SizedBox(height: 15),
            Text(_getUserDisplayName(),
                style: const TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w900,
                    color: AppColors.textDark)),
            Text(_currentUser?.email ?? "No Email Connected",
                style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.textGrey,
                    fontWeight: FontWeight.w600)),
            const SizedBox(height: 25),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 25.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildStatColumn("Total Scans", _totalScans.toString(),
                      AppColors.primaryDark),
                  Container(width: 1, height: 40, color: Colors.grey.shade300),
                  _buildStatColumn("Safe Drinks", _safeScans.toString(),
                      AppColors.successGreen),
                  Container(width: 1, height: 40, color: Colors.grey.shade300),
                  _buildStatColumn("Triggers", _triggerCounts.length.toString(),
                      AppColors.errorRed),
                ],
              ),
            ),
            const SizedBox(height: 35),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 25.0),
              child: Container(
                decoration: BoxDecoration(
                    color: Colors.white,
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
                    childrenPadding:
                        const EdgeInsets.only(left: 20, right: 20, bottom: 20),
                    leading: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                            color: tolerance['color'].withOpacity(0.15),
                            shape: BoxShape.circle),
                        child: Icon(tolerance['icon'],
                            color: tolerance['color'], size: 24)),
                    title: const Text('TODAY\'S TOLERANCE',
                        style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                            color: AppColors.textGrey,
                            letterSpacing: 0.5)),
                    subtitle: Text(tolerance['level'],
                        style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                            color: tolerance['color'])),
                    children: [
                      Text(tolerance['desc'],
                          style: const TextStyle(
                              fontSize: 13,
                              color: AppColors.textDark,
                              height: 1.5,
                              fontWeight: FontWeight.w500)),
                      const SizedBox(height: 15),
                      Container(
                        padding: const EdgeInsets.all(15),
                        decoration: BoxDecoration(
                            color: AppColors.background,
                            borderRadius: BorderRadius.circular(15)),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Baseline Cap:',
                                      style: TextStyle(
                                          fontSize: 11,
                                          color: AppColors.textGrey,
                                          fontWeight: FontWeight.bold)),
                                  Text('${baseCap.toStringAsFixed(1)} PRAL',
                                      style: const TextStyle(
                                          fontSize: 14,
                                          color: AppColors.primaryDark,
                                          fontWeight: FontWeight.w900))
                                ]),
                            Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  const Text('Current Multiplier:',
                                      style: TextStyle(
                                          fontSize: 11,
                                          color: AppColors.textGrey,
                                          fontWeight: FontWeight.bold)),
                                  Text('${multiplier.toStringAsFixed(2)}x',
                                      style: TextStyle(
                                          fontSize: 14,
                                          color: tolerance['color'],
                                          fontWeight: FontWeight.w900))
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
                    color: Colors.white,
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
                    const Text('Top Trigger Ingredients',
                        style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w900,
                            color: AppColors.textDark)),
                    const SizedBox(height: 10),
                    if (sortedTriggers.isEmpty)
                      const Text(
                          'You have no logged triggers! Great job staying safe.',
                          style: TextStyle(
                              fontSize: 12,
                              color: AppColors.successGreen,
                              fontStyle: FontStyle.italic))
                    else
                      Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: sortedTriggers
                              .take(4)
                              .map((entry) => _buildInteractiveChip(
                                  entry.key, entry.value, AppColors.errorRed))
                              .toList()),
                    const Divider(height: 35, color: Colors.black12),
                    const Text('Frequent Symptoms',
                        style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w900,
                            color: AppColors.textDark)),
                    const SizedBox(height: 10),
                    if (sortedSymptoms.isEmpty)
                      const Text('No symptoms logged. Keep up the good work.',
                          style: TextStyle(
                              fontSize: 12,
                              color: AppColors.successGreen,
                              fontStyle: FontStyle.italic))
                    else
                      Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: sortedSymptoms
                              .take(4)
                              .map((entry) => _buildInteractiveChip(entry.key,
                                  entry.value, AppColors.accentOrange))
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
                          color: AppColors.primaryLight.withOpacity(0.5),
                          width: 2),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20))),
                  onPressed: () async {
                    HapticFeedback.mediumImpact();
                    await Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (context) =>
                                GerdqScreen(dbService: widget.dbService)));
                    _loadDynamicUserData();
                  },
                  child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.refresh,
                            color: AppColors.primaryDark, size: 20),
                        SizedBox(width: 10),
                        Text('Recalibrate Phase (GerdQ)',
                            style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w900,
                                color: AppColors.primaryDark))
                      ]),
                ),
              ),
            ),
            const SizedBox(height: 100),
          ],
        ),
      ),
    );
  }

  Widget _buildStatColumn(String label, String value, Color color) {
    return Column(children: [
      Text(value,
          style: TextStyle(
              fontSize: 22, fontWeight: FontWeight.w900, color: color)),
      const SizedBox(height: 4),
      Text(label,
          style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: AppColors.textGrey))
    ]);
  }

  Widget _buildInteractiveChip(String name, int count, Color color) {
    return ActionChip(
      backgroundColor: color.withOpacity(0.1),
      side: BorderSide(color: color.withOpacity(0.3)),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      label: Text(name,
          style: TextStyle(
              color: color, fontSize: 11, fontWeight: FontWeight.w900)),
      onPressed: () {
        HapticFeedback.selectionClick();
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('You have logged "$name" $count times.',
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
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
            icon: Image.asset('assets/images/back_1.png',
                width: 24, color: AppColors.primaryDark),
            onPressed: () => Navigator.pop(context)),
        title: const Text('Settings',
            style: TextStyle(
                color: AppColors.primaryDark,
                fontWeight: FontWeight.w900,
                fontSize: 20)),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 25.0, vertical: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionHeader('Account'),
            _buildSettingsCard([
              _buildNavRow(
                  Icons.person_outline,
                  'Edit Profile & Avatar',
                  () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) => const PersonalDetailScreen()))),
            ]),
            const SizedBox(height: 25),
            _buildSectionHeader('Pro Scanner Preferences'),
            _buildSettingsCard([
              _buildToggleRow(
                  Icons.bolt_outlined,
                  'Batch Scanning Mode',
                  'Scan groceries consecutively without returning to the menu.',
                  _batchScanEnabled, (val) {
                setState(() => _batchScanEnabled = val);
                _saveSetting('setting_batch', val);
              }),
              const Divider(height: 1, color: Colors.black12),
              _buildToggleRow(
                  Icons.health_and_safety_outlined,
                  'Strict Risk Filter',
                  'Treats moderate (Yellow) triggers as high-risk (Red).',
                  _strictModeEnabled, (val) {
                setState(() => _strictModeEnabled = val);
                _saveSetting('setting_strictness', val);
              }),
              const Divider(height: 1, color: Colors.black12),
              _buildToggleRow(
                  Icons.vibration,
                  'Haptic Feedback',
                  'Vibrate on successful scans and alerts.',
                  _hapticEnabled, (val) {
                setState(() => _hapticEnabled = val);
                _saveSetting('setting_haptic', val);
              }),
              const Divider(height: 1, color: Colors.black12),
              _buildToggleRow(
                  Icons.highlight_outlined,
                  'Auto-Flashlight',
                  'Turn on flashlight automatically when opening the scanner.',
                  _autoFlashEnabled, (val) {
                setState(() => _autoFlashEnabled = val);
                _saveSetting('setting_flash', val);
              }),
            ]),
            const SizedBox(height: 25),
            _buildSectionHeader('Security & Legal'),
            _buildSettingsCard([
              _buildNavRow(
                  Icons.shield_outlined,
                  'Medical Privacy & Data Hub',
                  () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) => PrivacySettingsScreen(
                              dbService: widget.dbService)))),
              const Divider(height: 1, color: Colors.black12),
              _buildNavRow(
                  Icons.info_outline,
                  'Information & Support',
                  () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) => const InformationScreen()))),
            ]),
            const SizedBox(height: 25),
            _buildSettingsCard([
              _buildNavRow(
                  Icons.logout, 'Log Out', () => _confirmLogout(context),
                  isDestructive: true),
            ]),
            const SizedBox(height: 50),
          ],
        ),
      ),
    );
  }

  void _confirmLogout(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text("Log Out?",
            style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.errorRed)),
        content:
            const Text("Are you sure you want to log out of your account?"),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child:
                  const Text("Cancel", style: TextStyle(color: Colors.grey))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.errorRed,
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
            child: const Text("Log Out",
                style: TextStyle(
                    color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
        padding: const EdgeInsets.only(left: 10, bottom: 10),
        child: Text(title,
            style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w900,
                color: AppColors.textGrey)));
  }

  Widget _buildSettingsCard(List<Widget> children) {
    return Container(
        decoration: BoxDecoration(
            color: Colors.white,
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
      {bool isDestructive = false}) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      leading: Icon(icon,
          size: 22,
          color: isDestructive ? AppColors.errorRed : AppColors.textDark),
      title: Text(title,
          style: TextStyle(
              fontSize: 14,
              fontWeight: isDestructive ? FontWeight.w900 : FontWeight.bold,
              color: isDestructive ? AppColors.errorRed : AppColors.textDark)),
      trailing: isDestructive
          ? null
          : const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey),
      onTap: onTap,
    );
  }

  Widget _buildToggleRow(IconData icon, String title, String subtitle,
      bool value, ValueChanged<bool> onChanged) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
      child: Row(
        children: [
          Icon(icon, size: 22, color: AppColors.textDark),
          const SizedBox(width: 15),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(title,
                    style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textDark)),
                const SizedBox(height: 2),
                Text(subtitle,
                    style: const TextStyle(
                        fontSize: 10, color: Colors.grey, height: 1.3))
              ])),
          Switch(
              value: value,
              onChanged: onChanged,
              activeColor: AppColors.primaryDark,
              activeTrackColor: AppColors.primaryLight)
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

  Widget _buildAvatarWidget(double size) {
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
        List<Color> colors = [
          Colors.blue,
          Colors.green,
          AppColors.primary,
          Colors.pink,
          Colors.teal
        ];
        return Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
              color: colors[index % colors.length].withOpacity(0.2),
              shape: BoxShape.circle),
          child: Icon(icons[index % icons.length],
              color: colors[index % colors.length], size: size * 0.5),
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

  Future<void> _pickAvatarImage(ImageSource source) async {
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
        if (mounted)
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text('Avatar Updated!'),
              backgroundColor: AppColors.successGreen));
      } catch (e) {
        if (mounted)
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text('Failed to save image: $e'),
              backgroundColor: AppColors.errorRed));
      }
    }
  }

  void _setPresetAvatar(int index) async {
    if (user == null) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('local_avatar_${user!.uid}', 'preset_$index');
    setState(() => _localAvatarPath = 'preset_$index');
    Navigator.pop(context);
    if (mounted)
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Avatar Updated!'),
          backgroundColor: AppColors.successGreen));
  }

  void _showAvatarOptions() {
    showModalBottomSheet(
        context: context,
        shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(25))),
        builder: (BuildContext context) {
          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Update Profile Picture',
                      style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          color: AppColors.primaryDark)),
                  const SizedBox(height: 20),
                  ListTile(
                    leading: const Icon(Icons.camera_alt_outlined,
                        color: AppColors.textDark),
                    title: const Text('Take a Photo',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    onTap: () {
                      Navigator.pop(context);
                      _pickAvatarImage(ImageSource.camera);
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.photo_library_outlined,
                        color: AppColors.textDark),
                    title: const Text('Choose from Gallery',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    onTap: () {
                      Navigator.pop(context);
                      _pickAvatarImage(ImageSource.gallery);
                    },
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    child: Divider(),
                  ),
                  const Padding(
                    padding: EdgeInsets.only(bottom: 15),
                    child: Text('Or Choose a Preset Avatar',
                        style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: AppColors.textGrey,
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
                      List<Color> colors = [
                        Colors.blue,
                        Colors.green,
                        AppColors.primary,
                        Colors.pink,
                        Colors.teal
                      ];
                      return GestureDetector(
                        onTap: () => _setPresetAvatar(index),
                        child: Container(
                          width: 50,
                          height: 50,
                          decoration: BoxDecoration(
                              color: colors[index].withOpacity(0.2),
                              shape: BoxShape.circle),
                          child: Icon(icons[index],
                              color: colors[index], size: 25),
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

  void _confirmNameUpdate() {
    final newName = _nameController.text.trim();
    if (newName.isEmpty || newName == user?.displayName) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text("Confirm Name Change",
            style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.primaryDark)),
        content: Text(
            "Are you sure you want to change your display name to '$newName'?"),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child:
                  const Text("Cancel", style: TextStyle(color: Colors.grey))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10))),
            onPressed: () {
              Navigator.pop(context);
              _updateDisplayName(newName);
            },
            child: const Text("Save Changes",
                style: TextStyle(
                    color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Future<void> _updateDisplayName(String newName) async {
    setState(() => _isSaving = true);
    try {
      await user?.updateDisplayName(newName);
      await user?.reload();
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Display name updated successfully!'),
            backgroundColor: AppColors.successGreen));
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Update Failed: $e'),
            backgroundColor: AppColors.errorRed));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _confirmPasswordReset() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text("Send Reset Email?",
            style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.primaryDark)),
        content: Text("We will send a password reset link to:\n${user?.email}"),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child:
                  const Text("Cancel", style: TextStyle(color: Colors.grey))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10))),
            onPressed: () {
              Navigator.pop(context);
              _sendPasswordReset();
            },
            child: const Text("Send Email",
                style: TextStyle(
                    color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Future<void> _sendPasswordReset() async {
    if (user?.email == null) return;
    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: user!.email!);
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Secure reset link sent to ${user!.email}'),
            backgroundColor: AppColors.successGreen));
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Error: $e'), backgroundColor: AppColors.errorRed));
    }
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
              onPressed: () => Navigator.pop(context))),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(30.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Center(
                child: Text('Account Profile',
                    style: TextStyle(
                        color: AppColors.primaryDark,
                        fontWeight: FontWeight.w900,
                        fontSize: 22))),
            const SizedBox(height: 35),

            Center(
              child: GestureDetector(
                onTap: _showAvatarOptions,
                child: Stack(
                  alignment: Alignment.bottomRight,
                  children: [
                    Container(
                      width: 110,
                      height: 110,
                      decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.primaryLight.withOpacity(0.3),
                          border: Border.all(color: Colors.white, width: 4),
                          boxShadow: [
                            BoxShadow(
                                color: Colors.black.withOpacity(0.05),
                                blurRadius: 10,
                                offset: const Offset(0, 5))
                          ]),
                      child: _buildAvatarWidget(110),
                    ),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                          color: AppColors.primaryDark,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2)),
                      child: const Icon(Icons.camera_alt,
                          color: Colors.white, size: 18),
                    )
                  ],
                ),
              ),
            ),
            const SizedBox(height: 40),

            const Text('Display Name',
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                    color: AppColors.textDark)),
            const SizedBox(height: 10),
            TextField(
                controller: _nameController,
                decoration: InputDecoration(
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(15),
                        borderSide: BorderSide.none))),
            const SizedBox(height: 15),
            SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(15))),
                    onPressed: _isSaving ? null : _confirmNameUpdate,
                    child: _isSaving
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                                color: Colors.white, strokeWidth: 2))
                        : const Text('Save Changes',
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 15,
                                fontWeight: FontWeight.bold)))),
            const SizedBox(height: 40),

            const Text('Registered Email',
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                    color: AppColors.textDark)),
            const SizedBox(height: 10),
            TextField(
                readOnly: true,
                controller: TextEditingController(
                    text: user?.email ?? 'No email associated'),
                decoration: InputDecoration(
                    filled: true,
                    fillColor: Colors.grey.shade200,
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(15),
                        borderSide: BorderSide.none))),
            const SizedBox(height: 30),

            // UNLOCKED: Password Reset is now available for everyone
            SizedBox(
                width: double.infinity,
                height: 50,
                child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: AppColors.primary),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(15))),
                    icon:
                        const Icon(Icons.lock_reset, color: AppColors.primary),
                    label: const Text('Send Password Reset Email',
                        style: TextStyle(
                            color: AppColors.primary,
                            fontWeight: FontWeight.bold,
                            fontSize: 15)),
                    onPressed: _confirmPasswordReset)),
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

  Future<void> _toggleCloudSync(bool value) async {
    if (value == false) {
      bool? confirm = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text("Disable Cloud Backup?",
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.errorRed)),
          content: const Text(
              "If you disable Cloud Sync, your medical data will only live on this specific device. If you uninstall the app or log in on a new phone, all your scans and heuristic history will be permanently lost.\n\nAre you sure?"),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context, false),
                child:
                    const Text("Cancel", style: TextStyle(color: Colors.grey))),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.errorRed,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10))),
              onPressed: () => Navigator.pop(context, true),
              child: const Text("Disable Sync",
                  style: TextStyle(
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

  Future<void> _exportDataToCSV() async {
    setState(() => _isExporting = true);
    try {
      final items = await widget.dbService.getPantryItems();
      List<List<dynamic>> rows = [];
      rows.add([
        "Date Scanned",
        "Product Name",
        "Risk Level",
        "Acid Score",
        "Symptoms Logged"
      ]);
      for (var item in items) {
        rows.add([
          DateFormat('MM/dd/yyyy hh:mm a').format(item.dateScanned),
          item.name,
          item.riskLevel,
          item.acidScore,
          item.symptoms.isEmpty ? "None" : item.symptoms
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
      if (mounted)
        await Share.shareXFiles([XFile(path)],
            text: 'My TriggerLens Data Export');
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Export failed: $e'), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  void _confirmLocalWipe() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text("Erase Local Device Logs?",
            style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.errorRed)),
        content: const Text(
            "This will instantly delete all food scans and heuristic data from this phone. You will remain logged in.\n\nThis cannot be undone."),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child:
                  const Text("Cancel", style: TextStyle(color: Colors.grey))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.errorRed,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10))),
            onPressed: () async {
              Navigator.pop(context);
              await widget.dbService.wipeCurrentUserLocalData();
              if (mounted)
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                    content: Text('Local Device Data Erased.'),
                    backgroundColor: AppColors.successGreen));
            },
            child: const Text("Erase Local Data",
                style: TextStyle(
                    color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _confirmAccountDeletion() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(children: [
          Icon(Icons.warning_amber_rounded,
              color: AppColors.errorRed, size: 28),
          SizedBox(width: 10),
          Text("Delete Account?",
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.errorRed))
        ]),
        content: const Text(
            "This is the nuclear option. We will wipe all local data from this device, destroy your cloud backup, and permanently delete your authentication record.\n\nAre you absolutely sure?"),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child:
                  const Text("Cancel", style: TextStyle(color: Colors.grey))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.errorRed,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10))),
            onPressed: () async {
              Navigator.pop(context);
              try {
                await widget.dbService.wipeCurrentUserLocalData();
                await FirebaseAuth.instance.currentUser?.delete();
                await GoogleSignIn().signOut();
                if (context.mounted)
                  Navigator.pushAndRemoveUntil(
                      context,
                      MaterialPageRoute(
                          builder: (context) =>
                              WelcomeScreen(dbService: widget.dbService)),
                      (route) => false);
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                    content: Text(
                        'Security Requirement: Please log out and log back in to verify identity before deleting.'),
                    backgroundColor: Colors.red));
              }
            },
            child: const Text("PERMANENTLY DELETE",
                style: TextStyle(
                    color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading)
      return const Scaffold(
          backgroundColor: AppColors.background,
          body: Center(child: CircularProgressIndicator()));

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
              icon: Image.asset('assets/images/back_1.png',
                  width: 24, color: AppColors.primaryDark),
              onPressed: () => Navigator.pop(context))),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(30.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Medical Data &\nPrivacy Hub',
                style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w900,
                    color: AppColors.primaryDark,
                    height: 1.2)),
            const SizedBox(height: 40),
            const Text('Storage Policy',
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    color: AppColors.textDark)),
            const SizedBox(height: 20),
            _buildToggleRow(
                'Cloud Sync & Backup',
                'Store data securely in the cloud to access across devices. Turning this off restricts data strictly to this phone.',
                _cloudSyncEnabled,
                _toggleCloudSync),
            _buildToggleRow(
                'Anonymous Analytics',
                'Help TriggerLens improve by sharing non-identifiable scan speeds.',
                _analyticsEnabled,
                _toggleAnalytics),
            const SizedBox(height: 30),
            const Text('Data Portability (R.A. 10173)',
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    color: AppColors.textDark)),
            const SizedBox(height: 20),
            _buildActionRow(
                'Request Data Export',
                'Download a CSV copy of your historical data.',
                Icons.download_rounded,
                _isExporting ? null : _exportDataToCSV,
                isLoading: _isExporting),
            const SizedBox(height: 30),
            const Text('Danger Zone',
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    color: AppColors.errorRed)),
            const SizedBox(height: 20),
            _buildActionRow(
                'Erase Local Health Logs',
                'Clears scans and heuristic history from this device only.',
                Icons.phonelink_erase_outlined,
                _confirmLocalWipe,
                isDestructive: true),
            _buildActionRow(
                'Erase Account & Cloud Data',
                'Permanently destroy your entire account and all cloud backups.',
                Icons.delete_forever,
                _confirmAccountDeletion,
                isDestructive: true),
            const SizedBox(height: 100),
          ],
        ),
      ),
    );
  }

  Widget _buildToggleRow(
      String title, String subtitle, bool value, ValueChanged<bool> onChanged) {
    return Padding(
        padding: const EdgeInsets.only(bottom: 20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Expanded(
                child: Text(title,
                    style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                        color: AppColors.textDark))),
            Switch(
                value: value,
                onChanged: onChanged,
                activeColor: AppColors.primaryDark,
                activeTrackColor: AppColors.primaryLight)
          ]),
          const SizedBox(height: 4),
          Text(subtitle,
              style: const TextStyle(
                  fontSize: 10, color: Colors.grey, height: 1.4))
        ]));
  }

  Widget _buildActionRow(
      String title, String subtitle, IconData icon, VoidCallback? onTap,
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
                            ? AppColors.errorRed
                            : AppColors.primaryDark),
                const SizedBox(width: 15),
                Expanded(
                    child: Text(title,
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w900,
                            color: isDestructive
                                ? AppColors.errorRed
                                : AppColors.textDark)))
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
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
              icon: Image.asset('assets/images/back_1.png',
                  width: 24, color: AppColors.primaryDark),
              onPressed: () => Navigator.pop(context))),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(30.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Information',
                style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                    color: AppColors.primaryDark)),
            const SizedBox(height: 40),
            _buildSection('About TriggerLens', [
              _buildItem(
                  'Version 1.0.0', 'Automated ingredient analysis system.',
                  showArrow: false)
            ]),
            _buildSection('Help & Support', [
              _buildItem('How to Use the Scanner',
                  'Position sachets for accurate reading.',
                  showArrow: true)
            ]),
            _buildSection('Legal & Safety', [
              _buildItem('Medical Disclaimer',
                  'Not a replacement for medical diagnosis.',
                  showArrow: true)
            ]),
          ],
        ),
      ),
    );
  }

  Widget _buildSection(String title, List<Widget> items) {
    return Padding(
        padding: const EdgeInsets.only(bottom: 30),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title,
              style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  color: AppColors.textDark)),
          const SizedBox(height: 15),
          ...items
        ]));
  }

  Widget _buildItem(String title, String subtitle, {required bool showArrow}) {
    return Padding(
        padding: const EdgeInsets.only(bottom: 20, left: 10),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Text(title,
                style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                    color: AppColors.textDark))
          ]),
          const SizedBox(height: 5),
          Text(subtitle,
              style: const TextStyle(
                  fontSize: 10, color: Colors.grey, height: 1.4))
        ]));
  }
}
