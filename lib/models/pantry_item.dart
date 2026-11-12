import 'package:isar/isar.dart';

part 'pantry_item.g.dart';

@collection
class PantryItem {
  Id id = Isar.autoIncrement;

  // Multi-User Identity Firewall (Restored)
  @Index()
  late String userId;

  late String name;
  late DateTime dateScanned;

  // Stored as "None" or the specific symptom (e.g., "Burning pain")
  late String symptoms;

  // "GREEN", "YELLOW", "RED"
  late String riskLevel;

  bool isFavorite = false;

  // The raw OCR string or manual entry
  late String rawText;

  // The base calculated load *before* portion scaling
  late int acidScore;

  String? imagePath;

  // Contextual biological flags
  bool isEmptyStomach = false;
  bool isDiluted = false;
  bool isConsumed = false;

  // ==========================================
  // DYNAMIC DOSAGE & CATEGORIZATION METRICS
  // ==========================================

  // Automatically detected via KeywordMappingAlgorithm (e.g., "Heavy Powder", "Herbal Tea")
  String drinkCategory = "General Beverage";

  // The unit of measurement the user selected (e.g., "Sachet", "Tablespoon", "Tea Bag")
  String portionMeasurement = "Sachet";

  // The exact amount consumed.
  double portionCount = 1.0;
}
