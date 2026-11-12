import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../services/database_service.dart';
import '../../utils/ui_helpers.dart';
import '../../utils/risk_calculator.dart';
import 'calibration_screen.dart';

class CommitScreen extends StatefulWidget {
  final DatabaseService dbService;
  final String clinicalStatus;
  final String ageGroup;
  final String refluxFrequency;
  final String primaryGoal;
  final int clinicalSeverityScore;

  const CommitScreen({
    super.key,
    required this.dbService,
    required this.clinicalStatus,
    required this.ageGroup,
    required this.refluxFrequency,
    required this.primaryGoal,
    required this.clinicalSeverityScore,
  });

  @override
  State<CommitScreen> createState() => _CommitScreenState();
}

class _CommitScreenState extends State<CommitScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  bool _isLocked = false;
  double _lastHapticValue = 0.0;

  @override
  void initState() {
    super.initState();
    // 2-second hold to ensure deliberate commitment
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    );

    _controller.addListener(_onAnimationUpdate);
  }

  void _onAnimationUpdate() {
    if (_isLocked) return;

    // Trigger escalating haptics every 10% of progress to create tactile tension
    if (_controller.value - _lastHapticValue >= 0.1) {
      HapticFeedback.selectionClick();
      _lastHapticValue = _controller.value;
    }

    if (_controller.value == 1.0) {
      _lockAndProceed();
    }

    // Force UI rebuild for the glowing circle
    setState(() {});
  }

  Future<void> _lockAndProceed() async {
    setState(() {
      _isLocked = true;
    });

    // The massive dopamine hit vibration upon completion
    HapticFeedback.heavyImpact();
    await Future.delayed(const Duration(milliseconds: 100));
    HapticFeedback.heavyImpact();

    // 1. Calculate the final base limit
    double calculatedCap = RiskCalculator.calculatePersonalizedCap(
      widget.clinicalStatus,
      widget.ageGroup,
    );

    // Apply severity penalty if they scored high on GERD/Clinical quizzes
    if (widget.clinicalSeverityScore >= 8) {
      calculatedCap *= 0.85;
    }

    // 2. Save the complete profile to the local Isar database
    await widget.dbService.saveInteractiveOnboarding(
      clinicalStatus: widget.clinicalStatus,
      ageGroup: widget.ageGroup,
      refluxFrequency: widget.refluxFrequency,
      primaryGoal: widget.primaryGoal,
      targetPral: calculatedCap,
    );

    // 3. SECURE THE FIREWALL: Permanently mark setup as complete
    await widget.dbService.markSetupComplete();

    if (mounted) {
      // 4. Route to the final visual calibration loading screen
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => CalibrationScreen(
            dbService: widget.dbService,
            clinicalStatus: widget.clinicalStatus,
            ageGroup: widget.ageGroup,
            refluxFrequency: widget.refluxFrequency,
            primaryGoal: widget.primaryGoal,
            targetPral: calculatedCap,
          ),
        ),
      );
    }
  }

  void _onPointerDown(PointerDownEvent event) {
    if (!_isLocked) {
      HapticFeedback.lightImpact();
      _controller.forward();
    }
  }

  void _onPointerUp(PointerUpEvent event) {
    _cancelHold();
  }

  void _onPointerCancel(PointerCancelEvent event) {
    _cancelHold();
  }

  void _cancelHold() {
    if (!_isLocked) {
      _controller.reverse();
      _lastHapticValue = 0.0; // Reset haptic stepping
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_onAnimationUpdate);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);

    // Calculate glow and scale dynamically based on hold progress
    final double scale = 1.0 + (_controller.value * 0.15);
    final double glowOpacity = 0.2 + (_controller.value * 0.6);

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Image.asset('assets/images/back_1.png',
              width: 24, color: colors.textDark),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Spacer(flex: 2),

            Text(
              "Secure Your Baseline",
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.w900,
                color: colors.primaryDark,
              ),
            ),
            const SizedBox(height: 15),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40),
              child: Text(
                "TriggerLens uses military-grade encryption for local data. Hold the shield to lock your medical profile securely to your device.",
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: colors.textGrey,
                  height: 1.5,
                ),
              ),
            ),

            const Spacer(flex: 2),

            // THE TACTILE HOLD INTERACTION
            Listener(
              onPointerDown: _onPointerDown,
              onPointerUp: _onPointerUp,
              onPointerCancel: _onPointerCancel,
              child: Transform.scale(
                scale: scale,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // Outer glowing effect
                    Container(
                      width: 200,
                      height: 200,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: colors.primary.withOpacity(glowOpacity),
                            blurRadius: 40,
                            spreadRadius: 10 * _controller.value,
                          ),
                        ],
                      ),
                    ),

                    // Circular Progress Indicator mapping to hold duration
                    SizedBox(
                      width: 180,
                      height: 180,
                      child: CircularProgressIndicator(
                        value: _controller.value,
                        strokeWidth: 8,
                        backgroundColor: colors.isDark
                            ? Colors.white12
                            : Colors.grey.shade200,
                        valueColor:
                            AlwaysStoppedAnimation<Color>(colors.primary),
                      ),
                    ),

                    // Inner Shield Button
                    Container(
                      width: 140,
                      height: 140,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: colors.primaryDark,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.2),
                            blurRadius: 15,
                            offset: const Offset(0, 5),
                          )
                        ],
                      ),
                      child: Center(
                        child: Icon(
                          _isLocked
                              ? Icons.check_rounded
                              : Icons.shield_rounded,
                          color: Colors.white,
                          size: 60,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 40),

            AnimatedOpacity(
              opacity: _controller.value == 0 ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 300),
              child: Text(
                "PRESS AND HOLD",
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 2.0,
                  color: colors.primary,
                ),
              ),
            ),

            const Spacer(flex: 3),
          ],
        ),
      ),
    );
  }
}
