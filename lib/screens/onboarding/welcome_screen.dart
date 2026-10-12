import 'package:flutter/material.dart';
import '../../services/database_service.dart';
import '../../utils/ui_helpers.dart';
import 'sign_up_screen.dart';

class WelcomeScreen extends StatelessWidget {
  final DatabaseService dbService;
  const WelcomeScreen({super.key, required this.dbService});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        height: double.infinity,
        width: double.infinity,
        decoration: const BoxDecoration(gradient: AppColors.backgroundGradient),
        child: SafeArea(
          child: Column(
            children: [
              const Spacer(),

              // Uses the strictly stacked layout to match Figma
              const TriggerLensLogo(
                  size: 140, showText: true, isHorizontal: false),

              const Spacer(),

              Padding(
                padding: const EdgeInsets.only(bottom: 50.0),
                child: TextButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) =>
                              SignUpScreen(dbService: dbService)),
                    );
                  },
                  child: const Text(
                    'Get Started',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                      color: AppColors.primary,
                      decoration: TextDecoration.underline,
                      decorationColor: AppColors.primary,
                      decorationThickness: 2.0,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
