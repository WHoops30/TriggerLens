import 'dart:math';
import '../models/trigger_item.dart';
import '../models/user_profile.dart';
import '../models/pantry_item.dart';

// ==========================================
// NEW: STRICT GARBAGE TEXT FILTER EXCEPTION
// Prevent non-food objects from entering the database
// ==========================================
class InvalidSachetException implements Exception {
  final String message;
  InvalidSachetException(
      [this.message =
          "No edible ingredients detected. This does not appear to be a consumable sachet."]);
  @override
  String toString() => message;
}

class ScanResult {
  final String cleanedText;
  final List<TriggerItem> detectedTriggers;
  String riskLevel;
  final double finalRiskScore;
  final String triggersSummary;
  final bool exceedsDailyCap;

  // Semantic categorization for dynamic portion control
  final String drinkCategory;

  ScanResult({
    required this.cleanedText,
    required this.detectedTriggers,
    required this.riskLevel,
    required this.finalRiskScore,
    required this.triggersSummary,
    required this.exceedsDailyCap,
    required this.drinkCategory,
  });
}

class FuzzyMatch {
  final bool found;
  final int startIndex;
  final int endIndex;
  FuzzyMatch(this.found, this.startIndex, this.endIndex);
}

class KeywordMappingAlgorithm {
  // Master Taxonomy to validate if a label is actually a food product
  static final List<String> semanticKeywords = [
    'acid',
    'sugar',
    'syrup',
    'extract',
    'color',
    'sodium',
    'potassium',
    'gum',
    'oil',
    'powder',
    'water',
    'milk',
    'flavor',
    'artificial',
    'preservative',
    'calcium',
    'starch',
    'citrate',
    'creamer',
    'whey',
    'sweetener',
    'corn',
    'soy',
    'ingredients',
    'sangkap',
    'contains',
    'caffeine',
    'tea',
    'coffee',
    'cocoa',
    'fructose',
    'dextrose',
    'maltodextrin',
    'natural',
    'puree',
    'juice',
    'blend',
    'leaf',
    'root'
  ];

  static String cleanRawText(String rawText) {
    String cleaned = rawText.toLowerCase();
    cleaned = cleaned.replaceAll('!', 'i');
    cleaned = cleaned.replaceAll('@', 'a');

    // FIXED: FDA Prefix Parsing. Fuse 'non-', 'no ', 'free' to prevent false positive base-word matching
    cleaned = cleaned.replaceAll(RegExp(r'\b(non|no)[-\s]+'), 'non');
    cleaned = cleaned.replaceAll(RegExp(r'\b(free)[-\s]+'), 'free');

    // Preserve commas for FDA array splitting, wipe other symbols
    cleaned = cleaned.replaceAll(RegExp(r'[^a-z0-9\s,]'), ' ');
    cleaned = cleaned.replaceAll(RegExp(r'\s+'), ' ');

    cleaned = cleaned.replaceAll('ascorbic acid', 'vitamin c');
    cleaned = cleaned.replaceAll('sodium ascorbate', 'vitamin c');
    cleaned = cleaned.replaceAll('whey powder', 'milk');
    cleaned = cleaned.replaceAll('whey', 'milk');
    cleaned = cleaned.replaceAll('cacao', 'chocolate');
    cleaned = cleaned.replaceAll('cocoa', 'chocolate');

    return cleaned.trim();
  }

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

  static FuzzyMatch findFuzzyMatch(String text, String trigger) {
    if (text.contains(trigger)) {
      int idx = text.indexOf(trigger);
      return FuzzyMatch(true, idx, idx + trigger.length);
    }

    int maxTypos = (trigger.length / 4).floor();
    if (trigger.length <= 4) {
      maxTypos = 0;
    } else {
      if (maxTypos < 1) maxTypos = 1;
      if (maxTypos > 3) maxTypos = 3;
    }

    List<String> textWords = text.split(RegExp(r'\s+'));
    List<String> triggerWords = trigger.split(RegExp(r'\s+'));
    int n = triggerWords.length;

    if (textWords.length < n) return FuzzyMatch(false, -1, -1);

    for (int i = 0; i <= textWords.length - n; i++) {
      String window = textWords.sublist(i, i + n).join(' ');
      if (levenshtein(window, trigger) <= maxTypos) {
        int idx = text.indexOf(window);
        if (idx != -1) return FuzzyMatch(true, idx, idx + window.length);
      }
    }

    if (n > 1) {
      for (int i = 0; i <= textWords.length - (n - 1); i++) {
        String window = textWords.sublist(i, i + (n - 1)).join('');
        String originalWindow = textWords.sublist(i, i + (n - 1)).join(' ');
        if (levenshtein(window, trigger.replaceAll(' ', '')) <= maxTypos) {
          int idx = text.indexOf(originalWindow);
          if (idx != -1) {
            return FuzzyMatch(true, idx, idx + originalWindow.length);
          }
        }
      }
    }

    return FuzzyMatch(false, -1, -1);
  }

  static String _detectDrinkCategory(String cleanedText) {
    int teaScore = 0;
    int powderScore = 0;
    int concentrateScore = 0;

    final teaKeywords = [
      'tea',
      'matcha',
      'leaves',
      'herbal',
      'chamomile',
      'brew',
      'infusion'
    ];
    final powderKeywords = [
      'coffee',
      'creamer',
      'milk',
      'whey',
      'cocoa',
      'powder',
      'caseinate',
      'malt'
    ];
    final concentrateKeywords = [
      'syrup',
      'concentrate',
      'juice',
      'flavoring',
      'puree',
      'extract',
      'cordial'
    ];

    for (var word in teaKeywords) {
      if (cleanedText.contains(word)) teaScore++;
    }
    for (var word in powderKeywords) {
      if (cleanedText.contains(word)) powderScore++;
    }
    for (var word in concentrateKeywords) {
      if (cleanedText.contains(word)) concentrateScore++;
    }

    if (teaScore > powderScore && teaScore > concentrateScore)
      return "Herbal Tea";
    if (concentrateScore > powderScore && concentrateScore > teaScore)
      return "Liquid Concentrate";
    if (powderScore > teaScore && powderScore > concentrateScore)
      return "Heavy Powder";

    return "General Beverage";
  }

  static ScanResult analyze(
      String rawText,
      List<TriggerItem> databaseTriggers,
      UserProfile? userProfile,
      double currentDailyAccumulatedLoad,
      List<PantryItem> recentItems,
      {bool isEmptyStomach = false,
      bool isDiluted = false}) {
    int totalChars = rawText.length > 0 ? rawText.length : 1;
    int gibberishCount = rawText.replaceAll(RegExp(r'[a-zA-Z\s,]'), '').length;

    // GARBAGE FILTER 1: Visual Distortions / Laptop Stickers / Corrupted Scans
    if (totalChars > 15 && (gibberishCount / totalChars) > 0.30) {
      throw InvalidSachetException(
          "Text is too blurry, distorted, or contains unrecognized characters. Please flatten the sachet and try again.");
    }

    String cleanedText = cleanRawText(rawText);
    String mutableText = cleanedText;
    int totalTextLength = cleanedText.length > 0 ? cleanedText.length : 1;

    String detectedCategory = _detectDrinkCategory(cleanedText);

    List<TriggerItem> detectedTriggers = [];
    List<String> seenNames = [];
    List<String> detailedSummaries = [];
    Set<String> currentInteractionFamilies = {};

    // Baseline is 0.0. Pure water or safe ingredients return 0 acid points.
    double highestBaseScore = 0.0;

    // FDA HIERARCHY PREP: Split by commas to analyze ingredient order weight
    List<String> fdaArray =
        cleanedText.split(RegExp(r'[,;]|\band\b|\bcontains\b'));
    fdaArray =
        fdaArray.map((e) => e.trim()).where((e) => e.isNotEmpty).toList();

    List<TriggerItem> sortedTriggers = List.from(databaseTriggers);
    sortedTriggers.sort((a, b) {
      int aWords = a.name.split(' ').length;
      int bWords = b.name.split(' ').length;
      if (aWords == bWords) return b.name.length.compareTo(a.name.length);
      return bWords.compareTo(aWords);
    });

    for (var trigger in sortedTriggers) {
      String cleanTriggerName = cleanRawText(trigger.name);
      FuzzyMatch match = findFuzzyMatch(mutableText, cleanTriggerName);

      if (match.found && !seenNames.contains(cleanTriggerName)) {
        seenNames.add(cleanTriggerName);
        detectedTriggers.add(trigger);
        currentInteractionFamilies.add(trigger.interactionFamily);

        String mask = '*' * (match.endIndex - match.startIndex);
        mutableText =
            mutableText.replaceRange(match.startIndex, match.endIndex, mask);

        // ==========================================
        // NEW: FDA HIERARCHY ENGINE
        // Extracts the exact percentage tier of the ingredient based on order
        // ==========================================
        int fdaIndex = -1;
        for (int i = 0; i < fdaArray.length; i++) {
          if (findFuzzyMatch(fdaArray[i], cleanTriggerName).found) {
            fdaIndex = i;
            break;
          }
        }

        double positionalMultiplier = 1.0;
        String concentrationLabel = "Standard Concentration";

        if (fdaArray.length > 2 && fdaIndex != -1) {
          if (fdaIndex == 0) {
            positionalMultiplier = 1.4;
            concentrationLabel = "Primary Base Ingredient (~40%+)";
          } else if (fdaIndex == 1) {
            positionalMultiplier = 1.2;
            concentrationLabel = "Major Ingredient (~20%)";
          } else if (fdaIndex <= 4) {
            positionalMultiplier = 1.0;
            concentrationLabel = "Standard Concentration";
          } else {
            positionalMultiplier = 0.4;
            concentrationLabel = "Trace/Preservative Amount (<2%)";
          }
        } else {
          // Fallback to proportional string distance if no commas were found
          double positionRatio = match.startIndex / totalTextLength;
          if (positionRatio <= 0.25) {
            positionalMultiplier = 1.2;
            concentrationLabel = "Primary Concentration";
          } else if (positionRatio >= 0.75) {
            positionalMultiplier = 0.4;
            concentrationLabel = "Trace/Preservative Amount";
          }
        }

        double adjustedScore = trigger.basePralScore * positionalMultiplier;
        if (adjustedScore > highestBaseScore) highestBaseScore = adjustedScore;

        detailedSummaries.add(
            "${trigger.name.toUpperCase()} [$concentrationLabel]\n   ↳ ${trigger.clinicalDescription}");
      }
    }

    // ==========================================
    // GARBAGE FILTER 2: Semantic Integrity Check
    // If no triggers are found AND the text contains zero food-related words, it's not a drink.
    // ==========================================
    if (detectedTriggers.isEmpty) {
      bool containsFoodKeywords =
          semanticKeywords.any((kw) => cleanedText.contains(kw));
      if (!containsFoodKeywords) {
        throw InvalidSachetException(
            "No edible ingredients detected. This does not appear to be a consumable sachet.");
      }
    }

    // ==========================================
    // PRO FEATURE: TIME-DECAY SYNERGY ENGINE
    // ==========================================
    double highestSynergyMultiplier = 1.0;
    String synergyWarning = "";
    DateTime now = DateTime.now();

    for (var item in recentItems) {
      Set<String> pastItemFamilies = {};
      String pastText = item.rawText.toLowerCase();
      for (var trigger in databaseTriggers) {
        if (findFuzzyMatch(pastText, trigger.name.toLowerCase()).found) {
          pastItemFamilies.add(trigger.interactionFamily);
        }
      }

      Duration gap = now.difference(item.dateScanned);
      double hoursPassed = gap.inSeconds / 3600.0;
      if (hoursPassed < 0) hoursPassed = 0;
      if (hoursPassed > 6) continue;

      double decayFactor = 1.0 - (hoursPassed / 6.0);

      int minutes = gap.inMinutes;
      String timeStr = minutes < 60
          ? "$minutes minutes"
          : "${hoursPassed.toStringAsFixed(1)} hours";

      bool hasDoorOpener =
          currentInteractionFamilies.contains('Stomach Door Opener') ||
              pastItemFamilies.contains('Stomach Door Opener');
      bool hasStinger =
          currentInteractionFamilies.contains('Stomach Stinger') ||
              pastItemFamilies.contains('Stomach Stinger');

      if (hasDoorOpener && hasStinger) {
        double penalty = 1.0 + (0.5 * decayFactor);
        if (penalty > highestSynergyMultiplier) {
          highestSynergyMultiplier = penalty;
          synergyWarning =
              "\n\n⚠️ COMPOUND SYNERGY: You combined a 'Stomach Door Opener' with a 'Stomach Stinger' just $timeStr apart. The door is open, and the stinger is causing irritation! Penalty scaled by proximity.";
        }
      }

      bool hasTrafficJam = currentInteractionFamilies.contains('Traffic Jam') ||
          pastItemFamilies.contains('Traffic Jam');
      bool hasGasBubble = currentInteractionFamilies.contains('Gas Bubble') ||
          pastItemFamilies.contains('Gas Bubble');

      if (hasTrafficJam && hasGasBubble) {
        double penalty = 1.0 + (0.3 * decayFactor);
        if (penalty > highestSynergyMultiplier) {
          highestSynergyMultiplier = penalty;
          synergyWarning =
              "\n\n⚠️ COMPOUND SYNERGY: You combined a 'Traffic Jam' with a 'Gas Bubble' just $timeStr apart. Pressure is building up fast! Penalty scaled by proximity.";
        }
      }
    }

    double sensitivityMultiplier = userProfile?.multiplier ?? 1.0;

    double finalRiskScore =
        highestBaseScore * sensitivityMultiplier * highestSynergyMultiplier;

    if (isEmptyStomach) finalRiskScore *= 1.2;
    if (isDiluted) finalRiskScore *= 0.85;

    double activeDailyCap = userProfile?.dynamicDailyCap ?? 15.0;
    double projectedDailyLoad = currentDailyAccumulatedLoad + finalRiskScore;

    String uiColor = "GREEN";
    String warningMessage = "Safe to Consume.";
    bool exceedsCap = false;

    if (projectedDailyLoad > activeDailyCap) {
      uiColor = "RED";
      warningMessage =
          "Pacing Warning: Consuming this item breaches your safe acid threshold for today.";
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

    String summary = "";
    if (detectedTriggers.isEmpty) {
      summary =
          "Great news! No known stomach triggers were detected in this product.";
    } else {
      summary =
          "Clinical Analysis:\n• ${detailedSummaries.join('\n• ')}$synergyWarning\n\nVerdict: $warningMessage";
    }

    return ScanResult(
      cleanedText: cleanedText,
      detectedTriggers: detectedTriggers,
      riskLevel: uiColor,
      finalRiskScore: finalRiskScore,
      triggersSummary: summary,
      exceedsDailyCap: exceedsCap,
      drinkCategory: detectedCategory,
    );
  }
}
