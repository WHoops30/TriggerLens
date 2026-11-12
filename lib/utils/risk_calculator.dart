import '../models/pantry_item.dart';

class RiskCalculator {
  /// The stomach emptying time window. Set to 4 hours (240 minutes).
  static const int digestionWindowMinutes = 240;

  /// The standard human baseline PRAL limit.
  static const double absoluteBaseCap = 15.0;

  /// Calculates the true biological acid load in the stomach right now.
  /// Instead of stacking numbers permanently, it subtracts acid over 4 hours.
  static double calculateActiveLoad(List<PantryItem> todayItems) {
    double activeLoad = 0.0;
    final now = DateTime.now();

    for (var item in todayItems) {
      // Find out how many minutes ago the user consumed this item
      final minutesSinceConsumption =
          now.difference(item.dateScanned).inMinutes;

      // If it has been more than 4 hours, it's fully digested. Skip it.
      if (minutesSinceConsumption >= digestionWindowMinutes) {
        continue;
      }

      // If it was consumed recently, calculate how much of it is left.
      double remainingPercentage =
          1.0 - (minutesSinceConsumption / digestionWindowMinutes);

      // Prevent negative math errors just in case dates are weird
      if (remainingPercentage < 0) remainingPercentage = 0;

      activeLoad += (item.acidScore * remainingPercentage);
    }

    return activeLoad;
  }

  /// Calculates the user's initial daily PRAL cap based on their clinical status and age.
  /// This is the rigid baseline established during onboarding.
  static double calculatePersonalizedCap(
      String clinicalStatus, String ageGroup) {
    double cap = absoluteBaseCap;

    // 1. Clinical Status Modifier (Heaviest Weight)
    if (clinicalStatus == "Diagnosed GERD") {
      cap *= 0.60; // 40% reduction for chronic mucosal damage
    } else if (clinicalStatus == "Occasional Reflux") {
      cap *= 0.80; // 20% reduction for moderate sensitivity
    }

    // 2. Age Modifier
    if (ageGroup == "46 and older") {
      cap *= 0.85; // 15% reduction for age-related LES weakening
    } else if (ageGroup == "Under 18") {
      cap *= 1.10; // 10% buffer for youth resilience
    }

    return cap;
  }

  /// FIXED: The Adaptive Algorithm. Continuously adjusts the cap based on the user's logged symptoms.
  static double calculateDynamicDailyCap(
      double baseCap, List<PantryItem> recentLogs) {
    double dynamicCap = baseCap;
    final now = DateTime.now();

    int recentFlareUps = 0;
    bool hasRecentSevereSymptom = false;
    int symptomFreeDays = 3;

    for (var item in recentLogs) {
      final daysAgo = now.difference(item.dateScanned).inDays;
      if (daysAgo > 7) continue;

      if (item.symptoms.isNotEmpty && item.symptoms != "None") {
        recentFlareUps++;
        symptomFreeDays = 0;

        // If they had a flare up in the last 48 hours, heavily penalize the limit to force recovery.
        if (daysAgo <= 2) {
          hasRecentSevereSymptom = true;
        }
      } else if (daysAgo < symptomFreeDays) {
        symptomFreeDays = daysAgo;
      }
    }

    // Apply Penalties
    if (hasRecentSevereSymptom) {
      dynamicCap *= 0.85; // 15% strict reduction to allow the stomach to heal
    } else if (recentFlareUps >= 3) {
      dynamicCap *= 0.90; // 10% reduction for chronic mild irritation
    }

    // Apply Recovery/Healing Rewards
    if (symptomFreeDays >= 3) {
      dynamicCap *= 1.05; // 5% recovery boost
    }
    if (symptomFreeDays >= 7) {
      dynamicCap *= 1.10; // 10% recovery boost for a great week
    }

    // Guardrails to ensure the limit never goes fatally low or dangerously high
    if (dynamicCap < (baseCap * 0.5)) dynamicCap = baseCap * 0.5;
    if (dynamicCap > (baseCap * 1.2)) dynamicCap = baseCap * 1.2;

    return dynamicCap;
  }
}
