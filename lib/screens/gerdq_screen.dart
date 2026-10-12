import 'package:flutter/material.dart';
import '../../services/database_service.dart';
import '../../utils/ui_helpers.dart';
import 'dashboard_screen.dart'; // NEW: Direct import

class GerdqScreen extends StatefulWidget {
  final DatabaseService dbService;

  const GerdqScreen({super.key, required this.dbService});

  @override
  State<GerdqScreen> createState() => _GerdqScreenState();
}

class _GerdqScreenState extends State<GerdqScreen> {
  final List<int> _answers = List.filled(6, -1);
  final List<String> _options = ['0 Days', '1 Day', '2-3 Days', '4-7 Days'];
  final List<String> _questions = [
    "1. How often did you have a burning feeling behind your breastbone (heartburn)?",
    "2. How often did stomach contents move upwards to your throat or mouth (regurgitation)?",
    "3. How often did you have pain in the center of your upper stomach?",
    "4. How often did you feel nauseated?",
    "5. How often did you have difficulty getting a good night's sleep because of your heartburn and/or regurgitation?",
    "6. How often did you take additional medication for your heartburn and/or regurgitation, other than what your physician prescribed (if any)?"
  ];

  void _calculateAndSubmit() async {
    if (_answers.contains(-1)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please answer all 6 questions to proceed.'),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    int totalScore = 0;
    for (int i = 0; i < _answers.length; i++) {
      if (i == 2 || i == 3) {
        totalScore += (3 - _answers[i]);
      } else {
        totalScore += _answers[i];
      }
    }

    String phase = "Maintenance";
    double multiplier = 1.0;
    int dailyCap = 15;

    if (totalScore >= 8) {
      phase = "Recovery";
      multiplier = 1.5;
      dailyCap = 10;
    }

    await widget.dbService
        .saveUserSensitivityProfile(phase, multiplier, dailyCap);

    if (mounted) {
      // FIX: Use MaterialPageRoute instead of named route
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
            builder: (context) => DashboardScreen(dbService: widget.dbService)),
      );
    }
  }

  Widget _buildQuestionCard(int questionIndex) {
    return Container(
      margin: const EdgeInsets.only(bottom: 25),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _questions[questionIndex],
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: AppColors.textDark,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 15),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: List.generate(_options.length, (optionIndex) {
              bool isSelected = _answers[questionIndex] == optionIndex;
              return ChoiceChip(
                label: Text(_options[optionIndex]),
                selected: isSelected,
                selectedColor: AppColors.primary,
                labelStyle: TextStyle(
                  color: isSelected ? Colors.white : AppColors.textDark,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
                backgroundColor: Colors.grey.shade100,
                onSelected: (selected) {
                  setState(() {
                    _answers[questionIndex] = optionIndex;
                  });
                },
              );
            }),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'Health Assessment',
          style:
              TextStyle(color: AppColors.textDark, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        iconTheme: const IconThemeData(color: AppColors.primary),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'GerdQ Assessment',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                'Please indicate how often you have experienced the following symptoms during the last 7 days.',
                style:
                    TextStyle(fontSize: 14, color: Colors.black54, height: 1.5),
              ),
              const SizedBox(height: 30),
              ...List.generate(6, (index) => _buildQuestionCard(index)),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15),
                    ),
                  ),
                  onPressed: _calculateAndSubmit,
                  child: const Text(
                    'Calculate My Risk Profile',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }
}
