import 'package:flutter/material.dart';
import '../../services/database_service.dart';
import '../../utils/ui_helpers.dart';
import '../gerdq_screen.dart';
import '../../main.dart'; // REQUIRED: The Main Layout Wrapper

class PathScreen extends StatefulWidget {
  final DatabaseService dbService;
  const PathScreen({super.key, required this.dbService});

  @override
  State<PathScreen> createState() => _PathScreenState();
}

class _PathScreenState extends State<PathScreen> {
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _checkExistingProfile();
  }

  // THE SILENT CHECKPOINT
  Future<void> _checkExistingProfile() async {
    final profile = await widget.dbService.getUserProfile();

    if (profile != null && mounted) {
      // FIX: Routes to the Navigation Bar Wrapper
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
            builder: (context) =>
                MainLayoutScreen(dbService: widget.dbService)),
      );
    } else {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ALGORITHM 1: DIAGNOSED USER ROUTING
  void _showDiagnosisModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.all(30),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.only(
              topLeft: Radius.circular(30), topRight: Radius.circular(30)),
        ),
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
            const SizedBox(height: 20),
            const Text('Clinical Status',
                style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: AppColors.primary)),
            const SizedBox(height: 10),
            const Text(
                'Since you are medically diagnosed with GERD, we just need to know your current status to calibrate your scanner.',
                style: TextStyle(
                    fontSize: 14, color: AppColors.textGrey, height: 1.5)),
            const SizedBox(height: 30),
            const Text('When was your last severe acid reflux flare-up?',
                style: TextStyle(
                    fontWeight: FontWeight.bold, color: AppColors.textDark)),
            const SizedBox(height: 15),
            _buildModalOption(
              title: "Over a month ago.",
              onTap: () async {
                await widget.dbService
                    .saveUserSensitivityProfile("Maintenance", 1.0, 15);
                if (mounted) {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                        builder: (context) =>
                            MainLayoutScreen(dbService: widget.dbService)),
                  );
                }
              },
            ),
            _buildModalOption(
              title: "Within the last 2 weeks.",
              onTap: () async {
                await widget.dbService
                    .saveUserSensitivityProfile("Recovery", 1.5, 10);
                if (mounted) {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                        builder: (context) =>
                            MainLayoutScreen(dbService: widget.dbService)),
                  );
                }
              },
            ),
            _buildModalOption(
              title: "I am experiencing one right now.",
              onTap: () async {
                await widget.dbService
                    .saveUserSensitivityProfile("Recovery", 1.5, 10);
                if (mounted) {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                        builder: (context) =>
                            MainLayoutScreen(dbService: widget.dbService)),
                  );
                }
              },
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildModalOption(
      {required String title, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: Text(
          title,
          style: const TextStyle(
              fontWeight: FontWeight.bold, color: AppColors.textDark),
        ),
      ),
    );
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

    return Scaffold(
      body: Container(
        height: double.infinity,
        decoration: const BoxDecoration(gradient: AppColors.backgroundGradient),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(30.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const TriggerLensLogo(size: 60, showText: false),
                const SizedBox(height: 20),
                const Text('Choose Your\nPath',
                    style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.w900,
                        color: AppColors.textDark,
                        height: 1.2)),
                const SizedBox(height: 40),
                _buildPathCard(
                  context: context,
                  title: 'I have a Diagnosis',
                  subtitle:
                      'A doctor has officially confirmed I have GERD or acid reflux.',
                  onTap: _showDiagnosisModal,
                ),
                const SizedBox(height: 20),
                _buildPathCard(
                  context: context,
                  title: 'I want to screen myself',
                  subtitle:
                      'I want to screen my reactions to powdered beverages and identify my acidic triggers.',
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) =>
                            GerdqScreen(dbService: widget.dbService)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPathCard({
    required BuildContext context,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(25),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
                color: AppColors.primary.withOpacity(0.05),
                spreadRadius: 5,
                blurRadius: 15,
                offset: const Offset(0, 5)),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          color: AppColors.textDark)),
                  const SizedBox(height: 8),
                  Text(subtitle,
                      style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.textGrey,
                          height: 1.4)),
                ],
              ),
            ),
            const Icon(Icons.keyboard_double_arrow_right,
                color: AppColors.textGrey),
          ],
        ),
      ),
    );
  }
}
