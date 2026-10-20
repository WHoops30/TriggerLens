import 'dart:math';
import '../models/trigger_item.dart';
import '../models/user_profile.dart';

class ScanResult {
  final String cleanedText;
  final List<TriggerItem> detectedTriggers;
  String
      riskLevel; // UNLOCKED: Removed 'final' so the scanner can override this
  final double finalRiskScore;
  final String triggersSummary;
  final bool exceedsDailyCap;

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
  /// STEP 1: Text Cleaning
  static String cleanRawText(String rawText) {
    String cleaned = rawText.toLowerCase();

    // Fix common OCR number-to-letter hallucinations proactively
    cleaned = cleaned.replaceAll('!', 'i');
    cleaned = cleaned.replaceAll('@', 'a');

    // Keep numbers and letters, strip weird punctuation
    cleaned = cleaned.replaceAll(RegExp(r'[^a-z0-9\s]'), ' ');
    cleaned = cleaned.replaceAll(RegExp(r'\s+'), ' ');

    // MEDICAL SYNONYM MAPPING
    cleaned = cleaned.replaceAll('ascorbic acid', 'vitamin c');
    cleaned = cleaned.replaceAll('sodium ascorbate', 'vitamin c');
    cleaned = cleaned.replaceAll('whey powder', 'milk');
    cleaned = cleaned.replaceAll('whey', 'milk');
    cleaned = cleaned.replaceAll('cacao', 'chocolate');
    cleaned = cleaned.replaceAll('cocoa', 'chocolate');

    return cleaned.trim();
  }

  /// STEP 2: The Levenshtein Distance Function (Fuzzy Matching Engine)
  static int levenshtein(String a, String b) {
    if (a.isEmpty) return b.length;
    if (b.isEmpty) return a.length;

    List<int> v0 = List<int>.generate(b.length + 1, (i) => i);
    List<int> v1 = List<int>.filled(b.length + 1, 0);

    for (int i = 0; i < a.length; i++) {
      v1[0] = i + 1;
      for (int j = 0; j < b.length; j++) {
        int cost = (a[i] == b[j]) ? 0 : 1;
        v1[j + 1] = min(v1[j] + 1, min(v0[j + 1] + 1, v0[j] + cost));
      }
      for (int j = 0; j < v0.length; j++) {
        v0[j] = v1[j];
      }
    }
    return v1[b.length];
  }

  /// STEP 3: Sliding Window Fuzzy Search
  static bool fuzzyContains(String text, String trigger) {
    if (text.contains(trigger)) return true;

    int maxTypos = (trigger.length / 4).floor();
    if (maxTypos < 1) maxTypos = 1;
    if (maxTypos > 3) maxTypos = 3;

    List<String> textWords = text.split(RegExp(r'\s+'));
    List<String> triggerWords = trigger.split(RegExp(r'\s+'));
    int n = triggerWords.length;

    if (textWords.length < n) return false;

    for (int i = 0; i <= textWords.length - n; i++) {
      String window = textWords.sublist(i, i + n).join(' ');
      if (levenshtein(window, trigger) <= maxTypos) {
        return true;
      }
    }

    if (n > 1) {
      for (int i = 0; i <= textWords.length - (n - 1); i++) {
        String window = textWords.sublist(i, i + (n - 1)).join('');
        if (levenshtein(window, trigger.replaceAll(' ', '')) <= maxTypos) {
          return true;
        }
      }
    }

    return false;
  }

  /// STEP 4: The Dynamic Multi-Attribute Scoring Logic (UPDATED FOR BIOLOGY)
  static ScanResult analyze(String rawText, List<TriggerItem> databaseTriggers,
      UserProfile? userProfile, double currentDailyAccumulatedLoad,
      {bool isEmptyStomach = false, bool isDiluted = false}) {
    // NEW PARAMETERS

    String cleanedText = cleanRawText(rawText);
    List<TriggerItem> detectedTriggers = [];
    List<String> seenNames = [];

    // CORE MEDICAL DICTIONARY
    final Map<String, double> coreDictionary = {
      'citric acid': 9.0,
      'vitamin c': 9.0,
      'caffeine': 8.0,
      'coffee': 8.0,
      'palm oil': 7.0,
      'creamer': 7.0,
      'milk': 5.0,
      'skimmed milk': 5.0,
      'chocolate': 5.0,
      'sugar': 2.0,
      'salt': 2.0,
    };

    double highestBaseScore = 0.0;

    // Scan against Core Dictionary
    coreDictionary.forEach((ingredient, baseScore) {
      if (fuzzyContains(cleanedText, ingredient)) {
        seenNames.add(ingredient);

        String severityText = "Low";
        if (baseScore >= 7)
          severityText = "High Risk";
        else if (baseScore >= 5) severityText = "Medium Risk";

        detectedTriggers.add(TriggerItem()
          ..name = ingredient
          ..riskLevel = severityText
          ..category = 'Built-in');

        if (baseScore > highestBaseScore) highestBaseScore = baseScore;
      }
    });

    // Scan against Custom User Database
    for (var trigger in databaseTriggers) {
      String name = trigger.name.toLowerCase();
      if (fuzzyContains(cleanedText, name) && !seenNames.contains(name)) {
        seenNames.add(name);
        detectedTriggers.add(trigger);

        if (trigger.riskLevel.toLowerCase().contains('high') &&
            highestBaseScore < 7) {
          highestBaseScore = 7.0;
        } else if (trigger.riskLevel.toLowerCase().contains('medium') &&
            highestBaseScore < 5) {
          highestBaseScore = 5.0;
        }
      }
    }

    if (highestBaseScore == 0.0) highestBaseScore = 1.0;

    // ==========================================
    // NEW: BIOLOGICAL MULTIPLIERS
    // ==========================================
    double sensitivityMultiplier = userProfile?.multiplier ?? 1.0;

    // 1. Base Score * General Sensitivity Phase
    double finalRiskScore = highestBaseScore * sensitivityMultiplier;

    // 2. Immediate Context Modifiers
    if (isEmptyStomach) {
      finalRiskScore *= 1.2; // 20% penalty for empty stomach
    }
    if (isDiluted) {
      finalRiskScore *= 0.85; // 15% safety buffer for dilution
    }

    // Use the new dynamic cap instead of the old int cap
    double activeDailyCap = userProfile?.dynamicDailyCap ?? 15.0;

    double projectedDailyLoad = currentDailyAccumulatedLoad + finalRiskScore;

    String uiColor = "GREEN";
    String warningMessage = "Safe to Consume.";
    bool exceedsCap = false;

    // Liability-safe phrasing applied here
    if (projectedDailyLoad > activeDailyCap) {
      uiColor = "RED";
      warningMessage =
          "Pacing Warning: Consuming this item breaches your theoretical safe acid threshold for today.";
      exceedsCap = true;
    } else if (finalRiskScore > 7) {
      uiColor = "RED";
      warningMessage =
          "High Risk: Elevated acid load detected. Your stomach may be sensitive to this right now.";
    } else if (finalRiskScore > 4) {
      uiColor = "YELLOW";
      warningMessage =
          "Moderate Risk: Proceed with caution or consider diluting with water.";
    }

    String summary = detectedTriggers.isEmpty
        ? "No known acid reflux triggers detected."
        : "Known triggers detected: ${detectedTriggers.map((e) => e.name).join(', ')}. $warningMessage";

    return ScanResult(
      cleanedText: cleanedText,
      detectedTriggers: detectedTriggers,
      riskLevel: uiColor,
      finalRiskScore: finalRiskScore,
      triggersSummary: summary,
      exceedsDailyCap: exceedsCap,
    );
  }
}
