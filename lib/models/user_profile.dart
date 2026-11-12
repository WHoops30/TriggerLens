import 'package:isar/isar.dart';

part 'user_profile.g.dart';

@collection
class UserProfile {
  Id id = Isar.autoIncrement;

  // Multi-User Identity Firewall
  @Index()
  late String userId;

  // Privacy Policy Toggle
  bool cloudSyncEnabled = false;

  // NEW: Root Routing Flag (Anti-Loop Protection)
  // This explicitly tracks if the medical engine has been calibrated, separate from Firebase Auth.
  bool isSetupComplete = false;

  String phase = "Interactive Calibration";

  // Clinical Demographics
  String clinicalStatus =
      "Preventative"; // Diagnosed GERD, Occasional Reflux, Preventative
  String ageGroup = "26-45"; // <18, 18-25, 26-45, 46+
  String refluxFrequency =
      "Rarely"; // Almost every day, A few times a week, Rarely
  String primaryGoal = "Track my limit";

  double multiplier = 1.0;
  int dailyCap = 15;
  double targetDailyPral = 15.0;

  // BIOLOGICAL MULTIPLIERS
  double baseDailyCap = 15.0;
  double dynamicDailyCap = 15.0;
}
