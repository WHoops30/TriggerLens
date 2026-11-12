import 'package:flutter/material.dart';
import '../services/database_service.dart';
import '../utils/ui_helpers.dart';
import '../utils/app_localizations.dart';
import 'onboarding/commit_screen.dart';
import 'onboarding/onboarding_screen.dart';

class GerdqScreen extends StatefulWidget {
  final DatabaseService dbService;
  final String clinicalStatus;
  final String ageGroup;
  final String refluxFrequency;
  final String primaryGoal;

  const GerdqScreen({
    super.key,
    required this.dbService,
    required this.clinicalStatus,
    required this.ageGroup,
    required this.refluxFrequency,
    required this.primaryGoal,
  });

  @override
  State<GerdqScreen> createState() => _GerdqScreenState();
}

class _GerdqScreenState extends State<GerdqScreen> {
  final List<int> _answers = List.filled(6, -1);

  void _calculateAndSubmit(AppColors colors, AppLocalizations loc) {
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

    int totalScore = 0;
    for (int i = 0; i < _answers.length; i++) {
      // In standard GerdQ, questions 3 and 4 (index 2 and 3) are reverse scored
      if (i == 2 || i == 3) {
        totalScore += (3 - _answers[i]);
      } else {
        totalScore += _answers[i];
      }
    }

    // FIXED: Route to the Psychological Seal (Commit Screen) instead of skipping to calibration
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => CommitScreen(
          dbService: widget.dbService,
          clinicalStatus: widget.clinicalStatus,
          ageGroup: widget.ageGroup,
          refluxFrequency: widget.refluxFrequency,
          primaryGoal: widget.primaryGoal,
          clinicalSeverityScore: totalScore,
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
              // FIXED: Tooltip is only rendered if a specific definition is needed
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
                showCheckmark: false,
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

    final List<String> options = [
      loc.loc('0_days'),
      loc.loc('1_day'),
      loc.loc('2_3_days'),
      loc.loc('4_7_days')
    ];

    // English Fallback array ensuring all 6 GerdQ standard questions exist
    final List<String> questions = [
      loc.loc('gerdq_q1_simple') != 'gerdq_q1_simple'
          ? loc.loc('gerdq_q1_simple')
          : "How often do you have heartburn?",
      loc.loc('gerdq_q2_simple') != 'gerdq_q2_simple'
          ? loc.loc('gerdq_q2_simple')
          : "How often do you have regurgitation?",
      loc.loc('gerdq_q3_simple') != 'gerdq_q3_simple'
          ? loc.loc('gerdq_q3_simple')
          : "How often do you have pain in the center of your upper stomach?",
      loc.loc('gerdq_q4_simple') != 'gerdq_q4_simple'
          ? loc.loc('gerdq_q4_simple')
          : "How often do you have nausea?",
      loc.loc('gerdq_q5_simple') != 'gerdq_q5_simple'
          ? loc.loc('gerdq_q5_simple')
          : "How often do you wake up due to heartburn or regurgitation?",
      loc.loc('gerdq_q6_simple') != 'gerdq_q6_simple'
          ? loc.loc('gerdq_q6_simple')
          : "How often do you take extra medication for your symptoms?"
    ];

    // FIXED: Cognitive easing tooltips defining specific medical symptoms
    final List<String?> tooltips = [
      "Heartburn: A burning sensation radiating from the middle of your chest.",
      "Regurgitation: Stomach contents or sour liquid coming back up into your throat or mouth.",
      null, // Simple enough, no tooltip needed
      "Nausea: A feeling of sickness in the stomach that makes you feel like you might vomit.",
      null, // Simple enough, no tooltip needed
      "Extra medication: Over-the-counter antacids like Tums, Gaviscon, or Maalox used on top of your normal routine.",
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
            // Safely route back to the start of onboarding instead of popping out of the app
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
          loc.loc('health_assessment') != 'health_assessment'
              ? loc.loc('health_assessment')
              : 'Health Assessment',
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
                "Symptom Check",
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  color: colors.primary,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                "To personalize your limits, please indicate how often you have experienced the following symptoms during the last 7 days.",
                style: TextStyle(
                    fontSize: 14, color: colors.textGrey, height: 1.5),
              ),
              const SizedBox(height: 30),
              ...List.generate(
                  6,
                  (index) => _buildQuestionCard(index, questions[index],
                      tooltips[index], options, colors)),
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
                  onPressed: () => _calculateAndSubmit(colors, loc),
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
