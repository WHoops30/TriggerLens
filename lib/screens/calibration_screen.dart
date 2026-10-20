import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/database_service.dart';
import 'onboarding/welcome_screen.dart';
import '../main.dart';

class CalibrationScreen extends StatefulWidget {
  final DatabaseService dbService;
  final int goalIndex;
  final int frequencyIndex;
  final int baselineIndex;
  final double targetPral;

  const CalibrationScreen({
    Key? key,
    required this.dbService,
    required this.goalIndex,
    required this.frequencyIndex,
    required this.baselineIndex,
    required this.targetPral,
  }) : super(key: key);

  @override
  State<CalibrationScreen> createState() => _CalibrationScreenState();
}

class _CalibrationScreenState extends State<CalibrationScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3200),
    );

    _animation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOutCubic,
    );

    _controller.forward();

    _saveAndNavigate();
  }

  Future<void> _saveAndNavigate() async {
    // 1. Commit baseline profile to local Isar storage
    await widget.dbService.saveInteractiveOnboarding(
      goalIndex: widget.goalIndex,
      frequencyIndex: widget.frequencyIndex,
      baselineIndex: widget.baselineIndex,
      targetPral: widget.targetPral,
    );

    // 2. Wait for the 3.2s animation to finish
    await Future.delayed(const Duration(milliseconds: 3400));

    if (!mounted) return;

    // 3. Flo Funnel Route: If not logged into Firebase yet, go to Welcome/Auth screen.
    // Otherwise, route straight to Dashboard.
    final Widget destination = FirebaseAuth.instance.currentUser == null
        ? WelcomeScreen(dbService: widget.dbService)
        : MainLayoutScreen(dbService: widget.dbService);

    Navigator.pushReplacement(
      context,
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 600),
        pageBuilder: (_, __, ___) => destination,
        transitionsBuilder: (_, animation, __, child) {
          return FadeTransition(opacity: animation, child: child);
        },
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String _getStatusMessage(double progress) {
    if (progress < 0.30) {
      return "Analyzing reflux frequency patterns...";
    } else if (progress < 0.65) {
      return "Calculating target PRAL baseline thresholds...";
    } else if (progress < 0.90) {
      return "Calibrating Lower Esophageal Sphincter triggers...";
    } else {
      return "Personalized dietary profile ready!";
    }
  }

  @override
  Widget build(BuildContext context) {
    const primaryPink = Color(0xFFFF4B72);

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: AnimatedBuilder(
          animation: _animation,
          builder: (context, child) {
            final progress = _animation.value;
            final percentage = (progress * 100).toInt();

            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Spacer(),

                  // Circular Flo Progress Ring
                  Stack(
                    alignment: Alignment.center,
                    children: [
                      SizedBox(
                        width: 190,
                        height: 190,
                        child: CircularProgressIndicator(
                          value: progress,
                          strokeWidth: 10,
                          backgroundColor: const Color(0xFFFFF0F3),
                          valueColor:
                              const AlwaysStoppedAnimation<Color>(primaryPink),
                          strokeCap: StrokeCap.round,
                        ),
                      ),
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            "$percentage%",
                            style: const TextStyle(
                              fontSize: 42,
                              fontWeight: FontWeight.w900,
                              color: Colors.black87,
                              letterSpacing: -1.0,
                            ),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            "Calibrating",
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),

                  const SizedBox(height: 48),

                  // Dynamic Stage Title
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    child: Text(
                      _getStatusMessage(progress),
                      key: ValueKey<String>(_getStatusMessage(progress)),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: Colors.black87,
                        height: 1.3,
                      ),
                    ),
                  ),

                  const SizedBox(height: 32),

                  // Metric Checklist
                  _buildStatusItem("Reflux pattern mapped", progress >= 0.30),
                  _buildStatusItem(
                      "Target PRAL baseline configured", progress >= 0.65),
                  _buildStatusItem(
                      "LES-relaxer watchlist initialized", progress >= 0.90),

                  const Spacer(),
                  const Text(
                    "Tailoring TriggerLens to your digestive biology",
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 13, color: Colors.grey),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildStatusItem(String label, bool isComplete) {
    const primaryPink = Color(0xFFFF4B72);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            isComplete ? Icons.check_circle : Icons.radio_button_unchecked,
            color: isComplete ? primaryPink : Colors.grey[300],
            size: 20,
          ),
          const SizedBox(width: 10),
          Text(
            label,
            style: TextStyle(
              fontSize: 15,
              fontWeight: isComplete ? FontWeight.w600 : FontWeight.normal,
              color: isComplete ? Colors.black87 : Colors.grey[400],
            ),
          ),
        ],
      ),
    );
  }
}
