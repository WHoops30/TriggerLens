import '../models/pantry_item.dart';

class RiskCalculator {
  /// The stomach emptying time window. Set to 4 hours (240 minutes).
  static const int digestionWindowMinutes = 240;

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
      // E.g., at 120 minutes (2 hours), 50% of the score is decayed.
      double remainingPercentage =
          1.0 - (minutesSinceConsumption / digestionWindowMinutes);

      // Prevent negative math errors just in case dates are weird
      if (remainingPercentage < 0) remainingPercentage = 0;

      activeLoad += (item.acidScore * remainingPercentage);
    }

    return activeLoad;
  }
}
