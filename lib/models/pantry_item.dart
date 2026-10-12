import 'package:isar/isar.dart';

// IMPORTANT: This will show a red line until we run the build_runner command later!
part 'pantry_item.g.dart';

@collection
class PantryItem {
  Id id = Isar.autoIncrement;

  late String name;
  late DateTime dateScanned;
  late String symptoms;
  late String riskLevel;
  late bool isFavorite;
  late String rawText;
  late int acidScore; // Used for calculating the 6-hour session risk later
}
