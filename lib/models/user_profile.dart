import 'package:isar/isar.dart';

part 'user_profile.g.dart';

@collection
class UserProfile {
  Id id = Isar.autoIncrement;

  // NEW: Multi-User Identity Firewall
  @Index()
  late String userId;

  // NEW: Privacy Policy Toggle
  bool cloudSyncEnabled = false;

  String phase = "Interactive Calibration";
  double multiplier = 1.0;
  int dailyCap = 15;

  int goalIndex = 0;
  int refluxFrequencyIndex = 0;
  int baselineStrictnessIndex = 0;
  double targetDailyPral = 15.0;

  // NEW BIOLOGICAL MULTIPLIERS
  double baseDailyCap = 15.0;
  double dynamicDailyCap = 15.0;
}
