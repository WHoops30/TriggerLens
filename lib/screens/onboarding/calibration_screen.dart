import 'package:flutter/material.dart';
import 'dart:async';
import '../../services/database_service.dart';
import '../../utils/ui_helpers.dart';
import '../../main.dart';

class CalibrationScreen extends StatefulWidget {
  final DatabaseService dbService;
  final String clinicalStatus;
  final String ageGroup;
  final String refluxFrequency;
  final String primaryGoal;
  final double targetPral;

  const CalibrationScreen({
    super.key,
    required this.dbService,
    required this.clinicalStatus,
    required this.ageGroup,
    required this.refluxFrequency,
    required this.primaryGoal,
    required this.targetPral,
  });

  @override
  State<CalibrationScreen> createState() => _CalibrationScreenState();
}

class _CalibrationScreenState extends State<CalibrationScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _progressController;
  late Animation<double> _progressAnimation;

  bool _step1Complete = false;
  bool _step2Complete = false;
  bool _step3Complete = false;
  bool _showSuccess = false;

  @override
  void initState() {
    super.initState();

    // The calibration sequence takes exactly 3.5 seconds
    _progressController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3500),
    );

    _progressAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _progressController,
        curve: Curves.easeInOutSine,
      ),
    );

    _progressController.addListener(() {
      setState(() {
        if (_progressAnimation.value >= 0.3) _step1Complete = true;
        if (_progressAnimation.value >= 0.6) _step2Complete = true;
        if (_progressAnimation.value >= 0.9) _step3Complete = true;
      });
    });

    _progressController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _triggerSuccessState();
      }
    });

    // Start the biological simulation
    _progressController.forward();
  }

  void _triggerSuccessState() async {
    setState(() {
      _showSuccess = true;
    });

    // Hold on the dopamine-inducing green success screen for 1.8 seconds
    await Future.delayed(const Duration(milliseconds: 1800));

    if (mounted) {
      // THE FINAL DESTRUCTIVE ROUTE: Wipes onboarding from memory and lands on the Dashboard
      Navigator.pushAndRemoveUntil(
        context,
        PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) =>
              MainLayoutScreen(dbService: widget.dbService, initialIndex: 0),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(opacity: animation, child: child);
          },
          transitionDuration: const Duration(milliseconds: 600),
        ),
        (route) => false,
      );
    }
  }

  @override
  void dispose() {
    _progressController.dispose();
    super.dispose();
  }

  Widget _buildChecklistItem(String text, bool isComplete, AppColors colors) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            width: 20,
            height: 20,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isComplete ? colors.primary : Colors.transparent,
              border: Border.all(
                color: isComplete
                    ? colors.primary
                    : colors.textGrey.withOpacity(0.5),
                width: 2,
              ),
            ),
            child: isComplete
                ? const Icon(Icons.check, size: 14, color: Colors.white)
                : null,
          ),
          const SizedBox(width: 15),
          Text(
            text,
            style: TextStyle(
              fontSize: 14,
              fontWeight: isComplete ? FontWeight.bold : FontWeight.w500,
              color: isComplete ? colors.textDark : colors.textGrey,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);

    return Scaffold(
      backgroundColor: colors.background,
      body: SafeArea(
        child: Center(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 500),
            child: _showSuccess
                ? _buildSuccessView(colors)
                : _buildCalibrationView(colors),
          ),
        ),
      ),
    );
  }

  Widget _buildCalibrationView(AppColors colors) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Spacer(flex: 2),

        // Progress Circle
        SizedBox(
          width: 150,
          height: 150,
          child: Stack(
            fit: StackFit.expand,
            children: [
              CircularProgressIndicator(
                value: _progressAnimation.value,
                strokeWidth: 8,
                backgroundColor:
                    colors.isDark ? Colors.white12 : Colors.grey.shade200,
                valueColor: AlwaysStoppedAnimation<Color>(colors.primary),
              ),
              Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      "${(_progressAnimation.value * 100).toInt()}%",
                      style: TextStyle(
                        fontSize: 36,
                        fontWeight: FontWeight.w900,
                        color: colors.textDark,
                      ),
                    ),
                    Text(
                      "Calibrating",
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: colors.textGrey,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 50),

        Text(
          "Analyzing reflux frequency\npatterns...",
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w900,
            color: colors.textDark,
            height: 1.3,
          ),
        ),

        const SizedBox(height: 30),

        // Dynamic Checklist
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildChecklistItem(
                "Reflux pattern mapped", _step1Complete, colors),
            _buildChecklistItem(
                "Target PRAL baseline configured", _step2Complete, colors),
            _buildChecklistItem(
                "Clinical modifiers applied", _step3Complete, colors),
          ],
        ),

        const Spacer(flex: 2),

        Text(
          "Tailoring TriggerLens to your digestive\nbiology",
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: colors.textGrey,
            height: 1.5,
          ),
        ),

        const SizedBox(height: 30),
      ],
    );
  }

  Widget _buildSuccessView(AppColors colors) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Pulsing Green Success Checkmark
        TweenAnimationBuilder<double>(
          tween: Tween<double>(begin: 0.5, end: 1.0),
          duration: const Duration(milliseconds: 600),
          curve: Curves.elasticOut,
          builder: (context, value, child) {
            return Transform.scale(
              scale: value,
              child: child,
            );
          },
          child: Container(
            width: 140,
            height: 140,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: colors.successGreen,
              boxShadow: [
                BoxShadow(
                  color: colors.successGreen.withOpacity(0.4),
                  blurRadius: 30,
                  spreadRadius: 10,
                )
              ],
              border: Border.all(
                color: Colors.white,
                width: 6,
              ),
            ),
            child: const Icon(
              Icons.check_rounded,
              color: Colors.white,
              size: 70,
            ),
          ),
        ),

        const SizedBox(height: 40),

        Text(
          "Congratulations! Welcome\nto TriggerLens.",
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w900,
            color: colors.successGreen,
            height: 1.3,
          ),
        ),
      ],
    );
  }
}
