import 'package:flutter/material.dart';
import '../../services/database_service.dart';
import '../../utils/ui_helpers.dart';
import 'quiz_screen.dart';

class PrivacyScreen extends StatelessWidget {
  final DatabaseService dbService;
  const PrivacyScreen({super.key, required this.dbService});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: Container(
          margin: const EdgeInsets.all(30),
          padding: const EdgeInsets.all(30),
          decoration: BoxDecoration(
              gradient: AppColors.primaryGradient,
              borderRadius: BorderRadius.circular(30),
              boxShadow: [
                BoxShadow(
                    color: AppColors.primaryLight.withOpacity(0.5),
                    blurRadius: 20,
                    spreadRadius: 2)
              ]),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back_ios,
                    color: Colors.white, size: 20),
                padding: EdgeInsets.zero,
                alignment: Alignment.centerLeft,
                onPressed: () => Navigator.pop(context),
              ),
              const SizedBox(height: 10),
              const Text('Data Privacy\nNotice',
                  style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      height: 1.2)),
              const SizedBox(height: 20),
              const Text(
                'To calculate your personal Sensitivity Multiplier, we need to ask a few questions about your symptoms and medical history. Your answers are used solely to help our algorithm analyze powdered drink labels and provide accurate warnings.\n\nYour information is kept strictly confidential and processed in accordance with the Data Privacy Act of 2012. We do not sell or share your data with third parties.\n\nThis is a decision-support tool, not a replacement for professional medical diagnosis.',
                style:
                    TextStyle(fontSize: 12, color: Colors.white, height: 1.6),
              ),
              const SizedBox(height: 40),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(25)),
                  ),
                  onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) =>
                              QuizScreen(dbService: dbService))),
                  child: const Text('I Agree - Start Quiz',
                      style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w900,
                          color: AppColors.primary)),
                ),
              )
            ],
          ),
        ),
      ),
    );
  }
}
