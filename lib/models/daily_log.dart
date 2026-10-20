import 'package:isar/isar.dart';

part 'daily_log.g.dart';

@collection
class DailyLog {
  Id id = Isar.autoIncrement;

  // NEW: Multi-User Identity Firewall
  @Index()
  late String userId;

  // We use unique: true with replace: true so logging multiple times a day updates the same record
  @Index(unique: true, replace: true)
  late DateTime date;

  late List<String> symptoms;
  late double severity;

  // ==========================================
  // NEW: Mental State for Stress Multiplier
  // ==========================================
  // Defaults to "Relaxed". Can be: Relaxed, Anxious, Stressed, Exhausted
  String mentalState = "Relaxed";
}
