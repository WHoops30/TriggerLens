import '../models/user_profile.dart';
import '../utils/app_localizations.dart'; // NEW: Added localization injection

class RiskTranslator {
  // ==========================================
  // TRUE LOAD CALCULATOR
  // Multiplies the base PRAL score by the exact physical volume the user is consuming.
  // ==========================================
  static double calculateTrueAcidLoad(
      double baseScore, double count, String measurement) {
    double scaleFactor = 1.0;

    switch (measurement) {
      case "Sachet":
        scaleFactor = 1.0 * count; // Base assumption: 1 sachet = 1 full serving
        break;
      case "Tablespoon":
        scaleFactor = 0.5 * count; // 1 Tbsp is roughly half a standard sachet
        break;
      case "Teaspoon":
        scaleFactor = 0.16 * count; // 3 Tsp in 1 Tbsp
        break;
      case "Tea Bag":
        scaleFactor = 0.8 *
            count; // Tea bags generally release slightly less mass than instant powders
        break;
      case "Drop/Dash":
        scaleFactor = 0.05 * count; // Trace amounts
        break;
      default:
        scaleFactor = 1.0 * count;
    }

    return baseScore * scaleFactor;
  }

  // ==========================================
  // HUMANIZED MATH TRANSLATOR
  // Translates abstract points into real-world equivalents dynamically!
  // ==========================================
  static String getHumanizedScoreDescription(
      double trueScore, AppLocalizations loc) {
    if (trueScore <= 1.0) {
      return loc
          .loc('humanized_score_low', {'score': trueScore.toStringAsFixed(1)});
    } else if (trueScore <= 4.0) {
      return loc
          .loc('humanized_score_med', {'score': trueScore.toStringAsFixed(1)});
    } else if (trueScore <= 8.0) {
      return loc
          .loc('humanized_score_high', {'score': trueScore.toStringAsFixed(1)});
    } else {
      return loc.loc(
          'humanized_score_extreme', {'score': trueScore.toStringAsFixed(1)});
    }
  }

  // ==========================================
  // DASHBOARD IMPACT CALCULATOR
  // Links the isolated scan to the global profile gauge dynamically!
  // ==========================================
  static String getDashboardImpactText(
      double trueScore, UserProfile? profile, AppLocalizations loc) {
    double dailyCap = profile?.dynamicDailyCap ?? 15.0;
    if (dailyCap <= 0) {
      return loc.loc('impact_breach_fasting');
    }

    double percentage = (trueScore / dailyCap) * 100;
    if (percentage > 100) percentage = 100;

    return loc.loc('impact_percentage', {
      'percentage': percentage.toStringAsFixed(0),
      'cap': dailyCap.toStringAsFixed(0)
    });
  }

  // ==========================================
  // REALISTIC DOSAGE ENGINE
  // Provides logical recommendations based on category and remaining cap dynamically!
  // ==========================================
  static String getSmartRecommendation(String category, double projectedScore,
      double remainingCap, AppLocalizations loc) {
    bool hasPlentyOfRoom = projectedScore < (remainingCap * 0.5);

    if (hasPlentyOfRoom) {
      return loc.loc('rec_plenty_room');
    }

    // If they don't have plenty of room, we give category-specific harm reduction advice.
    switch (category) {
      case "Heavy Powder":
        return loc.loc('rec_heavy_powder');
      case "Liquid Concentrate":
        return loc.loc('rec_liquid_concentrate');
      case "Herbal Tea":
        return loc.loc('rec_herbal_tea');
      default:
        return loc.loc('rec_default');
    }
  }
}
