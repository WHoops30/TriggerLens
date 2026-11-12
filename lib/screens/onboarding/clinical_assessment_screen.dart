import 'package:flutter/material.dart';
import '../../services/database_service.dart';
import '../../utils/ui_helpers.dart';
import '../../utils/app_localizations.dart';
import 'commit_screen.dart';
import 'onboarding_screen.dart';

class ClinicalAssessmentScreen extends StatefulWidget {
  final DatabaseService dbService;
  final String clinicalStatus;
  final String ageGroup;
  final String refluxFrequency;
  final String primaryGoal;

  const ClinicalAssessmentScreen({
    super.key,
    required this.dbService,
    required this.clinicalStatus,
    required this.ageGroup,
    required this.refluxFrequency,
    required this.primaryGoal,
  });

  @override
  State<ClinicalAssessmentScreen> createState() =>
      _ClinicalAssessmentScreenState();
}

class _ClinicalAssessmentScreenState extends State<ClinicalAssessmentScreen> {
  // 3 Questions for the Diagnosed GERD fork
  final List<int> _answers = List.filled(3, -1);

  void _submitAssessment(AppColors colors, AppLocalizations loc) {
    if (_answers.contains(-1)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              loc.loc('answer_all_questions') != 'answer_all_questions'
                  ? loc.loc('answer_all_questions')
                  : 'Please answer all questions to proceed.'),
          backgroundColor: colors.errorRed,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    // FIXED: Route to the Psychological Seal (Commit Screen)
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => CommitScreen(
          dbService: widget.dbService,
          clinicalStatus: widget.clinicalStatus,
          ageGroup: widget.ageGroup,
          refluxFrequency: widget.refluxFrequency,
          primaryGoal: widget.primaryGoal,
          // We pass a severity modifier based on their clinical answers
          clinicalSeverityScore: _answers.fold(0, (sum, item) => sum + item),
        ),
      ),
    );
  }

  Widget _buildQuestionCard(int questionIndex, String questionText,
      String? tooltipText, List<String> options, AppColors colors) {
    return Container(
      margin: const EdgeInsets.only(bottom: 25),
      padding: const EdgeInsets.all(20),
      constraints: const BoxConstraints(minHeight: 180),
      decoration: BoxDecoration(
        color: colors.cardColor,
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
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  questionText,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: colors.textDark,
                    height: 1.4,
                  ),
                ),
              ),
              if (tooltipText != null) ...[
                const SizedBox(width: 10),
                InfoTooltip(message: tooltipText),
              ]
            ],
          ),
          const SizedBox(height: 15),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: List.generate(options.length, (optionIndex) {
              bool isSelected = _answers[questionIndex] == optionIndex;
              return ChoiceChip(
                label: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(options[optionIndex]),
                ),
                selected: isSelected,
                selectedColor: colors.primary,
                labelStyle: TextStyle(
                  color: isSelected ? Colors.white : colors.textDark,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  fontSize: 12,
                ),
                backgroundColor:
                    colors.isDark ? Colors.black26 : Colors.grey.shade100,
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
    final colors = AppColors.of(context);
    final loc = AppLocalizations.of(context);

    // Question 1: Dysphagia
    final List<String> q1Options = [
      "0 Days",
      "1-2 Days",
      "3-5 Days",
      "6-7 Days"
    ];
    // Question 2: PPI Usage
    final List<String> q2Options = [
      "Daily",
      "As Needed",
      "Previously",
      "Never"
    ];
    // Question 3: Nighttime Awakenings
    final List<String> q3Options = [
      "0 Days",
      "1-2 Days",
      "3-5 Days",
      "6-7 Days"
    ];

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Image.asset('assets/images/back_1.png',
              width: 24, color: colors.textDark),
          onPressed: () {
            // Because we used pushReplacement to get here, popping would exit the app.
            // We safely route back to the start of onboarding if they hit back.
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (context) =>
                    OnboardingScreen(dbService: widget.dbService),
              ),
            );
          },
        ),
        title: Text(
          "Clinical Assessment",
          style: TextStyle(color: colors.textDark, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Diagnosed GERD",
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  color: colors.primary,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                "Because you have a clinical diagnosis, please answer these 3 targeted questions to help us accurately set your acid limits.",
                style: TextStyle(
                    fontSize: 14, color: colors.textGrey, height: 1.5),
              ),
              const SizedBox(height: 30),

              // Question 1 (Uses Tooltip for Dysphagia)
              _buildQuestionCard(
                0,
                "How often do you experience Dysphagia in a typical week?",
                "Dysphagia means difficulty or pain when swallowing food or liquids.",
                q1Options,
                colors,
              ),

              // Question 2 (Uses Tooltip for PPIs)
              _buildQuestionCard(
                1,
                "Are you currently taking PPI medications?",
                "Proton Pump Inhibitors (PPIs) are strong acid blockers like Omeprazole, Pantoprazole, or Esomeprazole.",
                q2Options,
                colors,
              ),

              // Question 3 (Uses Tooltip for Nighttime Awakenings)
              _buildQuestionCard(
                2,
                "How often do you wake up choking or coughing from acid at night?",
                "This indicates severe nighttime reflux bypassing your upper esophageal sphincter.",
                q3Options,
                colors,
              ),

              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: colors.primary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15),
                    ),
                  ),
                  onPressed: () => _submitAssessment(colors, loc),
                  child: const Text(
                    "Finalize Profile",
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
