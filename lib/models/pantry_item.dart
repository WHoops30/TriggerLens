import 'package:isar/isar.dart';

part 'pantry_item.g.dart';

@collection
class PantryItem {
  Id id = Isar.autoIncrement;

  // NEW: Multi-User Identity Firewall
  @Index()
  late String userId;

  late String name;
  late DateTime dateScanned;
  late String symptoms;
  late String riskLevel;
  late bool isFavorite;
  late String rawText;
  late int acidScore;

  String? imagePath;

  // ==========================================
  // NEW: Consumption Context Multipliers
  // ==========================================
  bool isEmptyStomach = false; // If true -> 1.2x Risk Multiplier
  bool isDiluted = false; // If true -> 0.85x Risk Multiplier
}
