import 'package:flutter/material.dart';
import '../../services/database_service.dart';
import '../../utils/ui_helpers.dart';
import '../../main.dart'; // Navigates into the main app dashboard

class ResultScreen extends StatelessWidget {
  final DatabaseService dbService;
  final int finalScore; // Dynamically received from QuizScreen

  const ResultScreen(
      {super.key, required this.dbService, required this.finalScore});

  @override
  Widget build(BuildContext context) {
    // Logic to determine Phase based on score from Gerd-Q
    String phaseTitle = "Maintenance Phase";
    String phaseDesc =
        "Your symptoms are currently stable. TriggerLens is set to standard. The scanner will monitor your cumulative risk and only warn you about highly acidic ingredients.";
    Color phaseColor = Colors.green;
    IconData phaseIcon = Icons.health_and_safety;

    if (finalScore >= 10) {
      phaseTitle = "High Sensitivity Phase";
      phaseDesc =
          "Your score indicates severe recent flare-ups. TriggerLens will strictly monitor your intake and warn you about ALL potential triggers to prevent immediate discomfort.";
      phaseColor = Colors.redAccent;
      phaseIcon = Icons.warning_amber_rounded;
    } else if (finalScore >= 6) {
      phaseTitle = "Caution Phase";
      phaseDesc =
          "You are showing moderate symptoms. TriggerLens is set to sensitive to help you avoid a full flare-up.";
      phaseColor = Colors.orangeAccent;
      phaseIcon = Icons.shield_outlined;
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
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('TriggerLens',
                            style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textDark)),
                        Text('Result',
                            style: TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.w900,
                                color: AppColors.textDark)),
                      ],
                    ),
                    const TriggerLensLogo(size: 50, showText: false),
                  ],
                ),

                const SizedBox(height: 30),

                // Result Card UI matching screenshot exactly
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                          color: AppColors.primary.withOpacity(0.1),
                          blurRadius: 20,
                          offset: const Offset(0, 10))
                    ],
                  ),
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(25),
                        decoration: const BoxDecoration(
                          gradient: AppColors.primaryGradient,
                          borderRadius: BorderRadius.only(
                              topLeft: Radius.circular(20),
                              topRight: Radius.circular(20)),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                                child: Text(phaseTitle,
                                    style: const TextStyle(
                                        fontSize: 22,
                                        fontWeight: FontWeight.w900,
                                        color: Colors.white,
                                        height: 1.2))),
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.2),
                                  shape: BoxShape.circle),
                              child:
                                  Icon(phaseIcon, color: phaseColor, size: 40),
                            )
                          ],
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(25.0),
                        child: Column(
                          children: [
                            // Placeholder for the "Estimated Safe Consumption Timeline" graph graphic
                            Container(
                              height: 100,
                              width: double.infinity,
                              decoration: BoxDecoration(
                                  color: Colors.grey.shade100,
                                  borderRadius: BorderRadius.circular(10),
                                  border:
                                      Border.all(color: Colors.grey.shade300)),
                              child: const Center(
                                  child: Icon(Icons.bar_chart,
                                      color: Colors.grey, size: 50)),
                            ),
                            const SizedBox(height: 20),
                            Text(
                              phaseDesc,
                              style: const TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textGrey,
                                  height: 1.5),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const Spacer(),

                GradientButton(
                  text: 'Get Started',
                  onPressed: () => Navigator.pushAndRemoveUntil(
                      context,
                      MaterialPageRoute(
                          builder: (context) =>
                              MainLayoutScreen(dbService: dbService)),
                      (Route<dynamic> route) => false),
                ),
                const SizedBox(height: 10),
                Center(
                  child: TextButton(
                      onPressed: () => Navigator.pop(
                          context), // Pops back to let them retake it
                      child: const Text('Retake Quiz',
                          style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textDark,
                              decoration: TextDecoration.underline))),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
