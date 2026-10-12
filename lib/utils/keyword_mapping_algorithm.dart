import '../models/trigger_item.dart';
import '../models/user_profile.dart'; // REQUIRED: Import the UserProfile

// A helper class to bundle all the results together neatly
class ScanResult {
  final String cleanedText;
  final List<TriggerItem> detectedTriggers;
  final String riskLevel; // GREEN, YELLOW, or RED
  final double
      finalRiskScore; // Replaced int percentage with double for precise math
  final String triggersSummary;
  final bool exceedsDailyCap; // NEW: Guardrail check

  ScanResult({
    required this.cleanedText,
    required this.detectedTriggers,
    required this.riskLevel,
    required this.finalRiskScore,
    required this.triggersSummary,
    required this.exceedsDailyCap,
  });
}

class KeywordMappingAlgorithm {
  /// STEP 1: Text Cleaning and Synonym Normalization
  static String cleanRawText(String rawText) {
    String cleaned = rawText.toLowerCase();

    // Fix common OCR number-to-letter hallucinations
    cleaned = cleaned.replaceAll('1', 'i');
    cleaned = cleaned.replaceAll('0', 'o');
    cleaned = cleaned.replaceAll('!', 'i');
    cleaned = cleaned.replaceAll('@', 'a');
    cleaned = cleaned.replaceAll('5', 's');

    // Remove weird punctuation but keep spaces
    cleaned = cleaned.replaceAll(RegExp(r'[^a-z\s]'), ' ');
    cleaned = cleaned.replaceAll(RegExp(r'\s+'), ' ');

    // MEDICAL SYNONYM MAPPING (Translate complex names to Core Triggers)
    cleaned = cleaned.replaceAll('ascorbic acid', 'vitamin c');
    cleaned = cleaned.replaceAll('sodium ascorbate', 'vitamin c');
    cleaned = cleaned.replaceAll('whey powder', 'milk');
    cleaned = cleaned.replaceAll('whey', 'milk');
    cleaned = cleaned.replaceAll('cacao', 'chocolate');
    cleaned = cleaned.replaceAll('cocoa', 'chocolate');

    return cleaned.trim();
  }

  /// STEP 2: The Dynamic Matching & Scoring Logic
  static ScanResult analyze(
      String rawText,
      List<TriggerItem> databaseTriggers,
      UserProfile? userProfile, // NEW: We need the user's phase
      double
          currentDailyAccumulatedLoad // NEW: We need to know what they've drank today
      ) {
    String cleanedText = cleanRawText(rawText);
    List<TriggerItem> detectedTriggers = [];
    List<String> seenNames = [];

    // 1. BUILT-IN CORE MEDICAL DICTIONARY (Updated to Base Acid Scores out of 10)
    final Map<String, double> coreDictionary = {
      'citric acid': 9.0, // High Risk
      'vitamin c': 9.0, // High Risk
      'caffeine': 8.0, // High Risk
      'coffee': 8.0, // High Risk
      'palm oil': 7.0, // High Risk
      'creamer': 7.0, // High Risk
      'milk': 5.0, // Medium Risk
      'skimmed milk': 5.0, // Medium Risk
      'chocolate': 5.0, // Medium Risk
      'sugar': 2.0, // Low Risk
      'salt': 2.0, // Low Risk
    };

    // Scan against the Core Dictionary first
    double highestBaseScore =
        0.0; // We take the highest risk item found as the base score

    coreDictionary.forEach((ingredient, baseScore) {
      if (cleanedText.contains(ingredient)) {
        seenNames.add(ingredient);

        // Map numbers back to text for the UI Display
        String severityText = "Low";
        if (baseScore >= 7)
          severityText = "High Risk";
        else if (baseScore >= 5) severityText = "Medium Risk";

        detectedTriggers.add(TriggerItem()
          ..name = ingredient
          ..riskLevel = severityText
          ..category = 'Built-in');

        if (baseScore > highestBaseScore) {
          highestBaseScore = baseScore;
        }
      }
    });

    // Scan against User Database
    for (var trigger in databaseTriggers) {
      String name = trigger.name.toLowerCase();
      if (cleanedText.contains(name) && !seenNames.contains(name)) {
        seenNames.add(name);
        detectedTriggers.add(trigger);

        // Estimate a base score for custom items if they are dangerous
        if (trigger.riskLevel.toLowerCase().contains('high') &&
            highestBaseScore < 7) {
          highestBaseScore = 7.0;
        } else if (trigger.riskLevel.toLowerCase().contains('medium') &&
            highestBaseScore < 5) {
          highestBaseScore = 5.0;
        }
      }
    }

    // Default safety base score if nothing is found
    if (highestBaseScore == 0.0) {
      highestBaseScore = 1.0;
    }

    // 2. DYNAMIC MULTI-ATTRIBUTE ALGORITHM
    // Default to Maintenance (1.0) and standard cap (15) if profile isn't loaded yet
    double sensitivityMultiplier = userProfile?.multiplier ?? 1.0;
    int dailyCap = userProfile?.dailyCap ?? 15;

    // STEP 1: Compute Individual Adjusted Risk Score
    double finalRiskScore = highestBaseScore * sensitivityMultiplier;

    // STEP 2: Session and Daily Cumulative Threshold Guardrail
    double projectedDailyLoad = currentDailyAccumulatedLoad + finalRiskScore;

    String uiColor = "GREEN";
    String warningMessage = "Safe to Consume.";
    bool exceedsCap = false;

    if (projectedDailyLoad > dailyCap) {
      uiColor = "RED";
      warningMessage =
          "Daily Limit Exceeded: Consuming this item breaches your personalized safe acid threshold for today.";
      exceedsCap = true;
    } else if (finalRiskScore > 7) {
      uiColor = "RED";
      warningMessage =
          "High Risk: Elevated acid load detected for your current sensitivity state.";
    } else if (finalRiskScore > 4) {
      uiColor = "YELLOW";
      warningMessage =
          "Moderate Risk: Proceed with caution or dilute with water.";
    }

    // 4. SUMMARY GENERATION FOR UI
    String summary = detectedTriggers.isEmpty
        ? "No known acid reflux triggers detected."
        : "Known triggers detected: ${detectedTriggers.map((e) => e.name).join(', ')}. $warningMessage";

    return ScanResult(
      cleanedText: cleanedText,
      detectedTriggers: detectedTriggers,
      riskLevel: uiColor, // Changed to return the color code
      finalRiskScore: finalRiskScore,
      triggersSummary: summary,
      exceedsDailyCap: exceedsCap,
    );
  }
}
