import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // ADDED: For Haptic Feedback
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../services/database_service.dart';
import '../../models/user_profile.dart';
import '../../utils/ui_helpers.dart';
import 'onboarding/welcome_screen.dart';
import 'gerdq_screen.dart';

// ==========================================
// 1. THE CLEANED UP PROFILE SCREEN
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

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    _currentUser = FirebaseAuth.instance.currentUser;
    final profile = await widget.dbService.getUserProfile();
    if (mounted) {
      setState(() {
        _userProfile = profile;
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

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: AppColors.background,
        body:
            Center(child: CircularProgressIndicator(color: AppColors.primary)),
      );
    }

    final isRecovery = _userProfile?.phase.toLowerCase() == 'recovery';
    final phaseName = _userProfile?.phase ?? "Maintenance";
    final multiplier = _userProfile?.multiplier ?? 1.0;
    final dailyCap = _userProfile?.dailyCap ?? 15;

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
        // NEW: The Settings Gear Icon
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined,
                color: AppColors.primaryDark, size: 28),
            onPressed: () async {
              // Add a subtle vibration when opening settings
              HapticFeedback.lightImpact();
              await Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) =>
                          SettingsScreen(dbService: widget.dbService)));
              _loadUserData(); // Refresh profile when returning in case they changed their name
            },
          ),
          const SizedBox(width: 10),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 25.0),
        child: Column(
          children: [
            const Text('My Profile',
                style: TextStyle(
                    color: AppColors.primaryDark,
                    fontWeight: FontWeight.w900,
                    fontSize: 20)),
            const SizedBox(height: 25),

            Center(
              child: Container(
                width: 105,
                height: 105,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.primaryLight.withOpacity(0.3),
                  border: Border.all(color: Colors.white, width: 4),
                  boxShadow: [
                    BoxShadow(
                        color: AppColors.primary.withOpacity(0.15),
                        blurRadius: 15,
                        offset: const Offset(0, 5))
                  ],
                ),
                child: ClipOval(
                  child: _currentUser?.photoURL != null
                      ? Image.network(_currentUser!.photoURL!,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Image.asset(
                              'assets/images/man.png',
                              fit: BoxFit.cover))
                      : Image.asset('assets/images/man.png', fit: BoxFit.cover),
                ),
              ),
            ),
            const SizedBox(height: 15),
            Text(_getUserDisplayName(),
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w900,
                    color: AppColors.textDark)),
            const SizedBox(height: 5),
            Text(_currentUser?.email ?? "No Email Connected",
                style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textGrey,
                    fontWeight: FontWeight.w500)),

            const SizedBox(height: 40),

            const Align(
              alignment: Alignment.centerLeft,
              child: Text('Sensitivity Profile',
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      color: AppColors.textDark)),
            ),
            const SizedBox(height: 10),

            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(25),
                boxShadow: [
                  BoxShadow(
                      color: Colors.black.withOpacity(0.04),
                      blurRadius: 12,
                      offset: const Offset(0, 4))
                ],
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Current Phase',
                          style: TextStyle(
                              fontSize: 13,
                              color: AppColors.textDark,
                              fontWeight: FontWeight.bold)),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 4),
                        decoration: BoxDecoration(
                          color: isRecovery
                              ? AppColors.errorRed.withOpacity(0.15)
                              : AppColors.successGreen.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(phaseName,
                            style: TextStyle(
                                color: isRecovery
                                    ? AppColors.errorRed
                                    : AppColors.successGreen,
                                fontSize: 12,
                                fontWeight: FontWeight.w900)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 15),
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                              color: AppColors.background,
                              borderRadius: BorderRadius.circular(15)),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Sensitivity Multiplier',
                                  style: TextStyle(
                                      fontSize: 10,
                                      color: AppColors.textGrey,
                                      fontWeight: FontWeight.bold)),
                              const SizedBox(height: 4),
                              Text('${multiplier.toStringAsFixed(1)}x',
                                  style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w900,
                                      color: AppColors.primaryDark)),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                              color: AppColors.background,
                              borderRadius: BorderRadius.circular(15)),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Daily Risk Cap',
                                  style: TextStyle(
                                      fontSize: 10,
                                      color: AppColors.textGrey,
                                      fontWeight: FontWeight.bold)),
                              const SizedBox(height: 4),
                              Text('$dailyCap pts',
                                  style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w900,
                                      color: AppColors.primaryDark)),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 15),
                  Text(
                    isRecovery
                        ? 'Recovery Mode active: Multiplier elevated to 1.5x with a lower daily acid threshold (10 pts).'
                        : 'Maintenance Mode active: Standard 1.0x baseline with a full 15 pt daily acid threshold.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        fontSize: 11, color: AppColors.textGrey, height: 1.4),
                  ),
                  const SizedBox(height: 15),
                  SizedBox(
                    width: double.infinity,
                    height: 45,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor:
                            AppColors.primaryLight.withOpacity(0.5),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(15)),
                      ),
                      onPressed: () async {
                        await Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (context) =>
                                    GerdqScreen(dbService: widget.dbService)));
                        _loadUserData();
                      },
                      child: const Text('Retake GerdQ Assessment',
                          style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w900,
                              color: AppColors.primaryDark)),
                    ),
                  )
                ],
              ),
            ),
            const SizedBox(height: 100), // Clean bottom space
          ],
        ),
      ),
    );
  }
}

// ==========================================
// 2. THE NEW DEDICATED SETTINGS HUB
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
    });
  }

  Future<void> _saveSetting(String key, bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(key, value);
    if (_hapticEnabled)
      HapticFeedback.lightImpact(); // Prove it works instantly
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
          onPressed: () => Navigator.pop(context),
        ),
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
                  'Edit Profile Details',
                  () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) => const PersonalDetailScreen()))),
            ]),
            const SizedBox(height: 25),
            _buildSectionHeader('Scanner Preferences'),
            _buildSettingsCard([
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
                  'Turn on flashlight automatically in scanner.',
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
                  'Data and Privacy Settings',
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
              _buildNavRow(Icons.logout, 'Log Out', () async {
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
              }, isDestructive: true),
            ]),
            const SizedBox(height: 50),
          ],
        ),
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
              color: AppColors.textGrey)),
    );
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
        ],
      ),
      child: Column(children: children),
    );
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
                    style: const TextStyle(fontSize: 10, color: Colors.grey)),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeColor: AppColors.primaryDark,
            activeTrackColor: AppColors.primaryLight,
          )
        ],
      ),
    );
  }
}

// ==========================================
// 3. THE RETAINED SUB-SCREENS (Unchanged)
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

  @override
  void initState() {
    super.initState();
    _nameController.text = user?.displayName ?? "";
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _updateDisplayName() async {
    final newName = _nameController.text.trim();
    if (newName.isEmpty) return;
    setState(() => _isSaving = true);
    try {
      await user?.updateDisplayName(newName);
      await user?.reload();
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Display name updated!'),
            backgroundColor: AppColors.successGreen));
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Failed: $e'), backgroundColor: AppColors.errorRed));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _sendPasswordReset() async {
    if (user?.email == null) return;
    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: user!.email!);
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Reset link sent to ${user!.email}'),
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
                child: Text('Personal Details',
                    style: TextStyle(
                        color: AppColors.primaryDark,
                        fontWeight: FontWeight.w900,
                        fontSize: 22))),
            const SizedBox(height: 30),
            Center(
              child: Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.primaryLight.withOpacity(0.3),
                    border: Border.all(color: Colors.white, width: 4)),
                child: ClipOval(
                    child: user?.photoURL != null
                        ? Image.network(user!.photoURL!, fit: BoxFit.cover)
                        : Image.asset('assets/images/man.png',
                            fit: BoxFit.cover)),
              ),
            ),
            const SizedBox(height: 30),
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
                        borderRadius: BorderRadius.circular(15)))),
            const SizedBox(height: 15),
            SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(15))),
                    onPressed: _isSaving ? null : _updateDisplayName,
                    child: const Text('Save Name',
                        style: TextStyle(color: Colors.white)))),
            const SizedBox(height: 30),
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
                    fillColor: Colors.grey.shade100,
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(15)))),
            const SizedBox(height: 30),
            SizedBox(
                width: double.infinity,
                height: 48,
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
                            fontWeight: FontWeight.bold)),
                    onPressed: _sendPasswordReset)),
          ],
        ),
      ),
    );
  }
}

class PrivacySettingsScreen extends StatefulWidget {
  final DatabaseService dbService;
  const PrivacySettingsScreen({super.key, required this.dbService});
  @override
  State<PrivacySettingsScreen> createState() => _PrivacySettingsScreenState();
}

class _PrivacySettingsScreenState extends State<PrivacySettingsScreen> {
  bool t1 = true, t2 = true, t3 = true;
  bool _isExporting = false;
  bool _isDeleting = false;

  @override
  void initState() {
    super.initState();
    _loadSavedToggles();
  }

  Future<void> _loadSavedToggles() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      t1 = prefs.getBool('t1_health_profile') ?? true;
      t2 = prefs.getBool('t2_ocr_history') ?? true;
      t3 = prefs.getBool('t3_usage_data') ?? true;
    });
  }

  Future<void> _saveToggle(String key, bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(key, value);
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

  void _showPrivacyPolicyModal() {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Container(
          padding: const EdgeInsets.all(25),
          decoration: BoxDecoration(
              color: Colors.white, borderRadius: BorderRadius.circular(20)),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Privacy Policy',
                        style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                            color: AppColors.primaryDark)),
                    Icon(Icons.policy_outlined,
                        color: AppColors.primaryDark, size: 28)
                  ]),
              const SizedBox(height: 15),
              Container(
                height: 250,
                padding: const EdgeInsets.all(15),
                decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(15),
                    border: Border.all(color: Colors.grey.shade200)),
                child: const SingleChildScrollView(
                    child: Text(
                        "TriggerLens complies with R.A. 10173.\n\n1. Local Storage: Data is stored offline via Isar.\n2. No Third-Party Sales: We do not sell your data.\n3. Deletion Rights: You can export or erase your account at any time.",
                        style: TextStyle(
                            fontSize: 12, color: Colors.black87, height: 1.5))),
              ),
              const SizedBox(height: 20),
              SizedBox(
                  width: double.infinity,
                  height: 45,
                  child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(15))),
                      onPressed: () => Navigator.pop(context),
                      child: const Text('I Understand',
                          style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold)))),
            ],
          ),
        ),
      ),
    );
  }

  void _confirmAccountDeletion() {
    showDialog(
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
              const Icon(Icons.warning_amber_rounded,
                  color: AppColors.errorRed, size: 50),
              const SizedBox(height: 15),
              const Text('Delete Account?',
                  style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      color: AppColors.textDark)),
              const SizedBox(height: 10),
              const Text('This action is irreversible.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontSize: 13, color: AppColors.textGrey, height: 1.4)),
              const SizedBox(height: 25),
              _isDeleting
                  ? const CircularProgressIndicator(color: AppColors.errorRed)
                  : Row(
                      children: [
                        Expanded(
                            child: TextButton(
                                onPressed: () => Navigator.pop(context),
                                child: const Text('Cancel',
                                    style: TextStyle(
                                        color: AppColors.textGrey,
                                        fontWeight: FontWeight.bold)))),
                        Expanded(
                            child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.errorRed,
                                    shape: RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius.circular(10))),
                                onPressed: () async {
                                  setState(() => _isDeleting = true);
                                  try {
                                    await FirebaseAuth.instance.currentUser
                                        ?.delete();
                                    await GoogleSignIn().signOut();
                                    if (context.mounted)
                                      Navigator.pushAndRemoveUntil(
                                          context,
                                          MaterialPageRoute(
                                              builder: (context) =>
                                                  WelcomeScreen(
                                                      dbService:
                                                          widget.dbService)),
                                          (route) => false);
                                  } catch (e) {
                                    Navigator.pop(context);
                                    ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(
                                            content: Text(
                                                'Please log out and log back in to verify identity before deleting.'),
                                            backgroundColor: Colors.red));
                                  } finally {
                                    if (mounted)
                                      setState(() => _isDeleting = false);
                                  }
                                },
                                child: const Text('Delete',
                                    style: TextStyle(color: Colors.white)))),
                      ],
                    )
            ],
          ),
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
              onPressed: () => Navigator.pop(context))),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(30.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Data and\nPrivacy Settings',
                style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w900,
                    color: AppColors.primaryDark,
                    height: 1.2)),
            const SizedBox(height: 40),
            const Text('Data Collection & Storage',
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    color: AppColors.textDark)),
            const SizedBox(height: 20),
            _buildToggleRow(
                'Health Profile', 'Store my GERD assessment phase locally.', t1,
                (v) {
              setState(() => t1 = v);
              _saveToggle('t1_health_profile', v);
            }),
            _buildToggleRow(
                'OCR Scan History', 'Save past powdered drink scans.', t2, (v) {
              setState(() => t2 = v);
              _saveToggle('t2_ocr_history', v);
            }),
            _buildToggleRow('Share Anonymous Usage',
                'Help Improve TriggerLens performance.', t3, (v) {
              setState(() => t3 = v);
              _saveToggle('t3_usage_data', v);
            }),
            const SizedBox(height: 30),
            const Text('Privacy Rights (R.A. 10173)',
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    color: AppColors.textDark)),
            const SizedBox(height: 20),
            _buildActionRow(
                'Request Data Export',
                'Download a CSV copy of your data.',
                Icons.download_rounded,
                _isExporting ? null : _exportDataToCSV,
                isLoading: _isExporting),
            _buildActionRow(
                'Review Data Privacy Notice',
                'Re-read how we process your information.',
                Icons.policy_outlined,
                _showPrivacyPolicyModal),
            _buildActionRow(
                'Delete Account & Data',
                'Permanently erase all personal health inputs.',
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
