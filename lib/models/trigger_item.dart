import 'package:isar/isar.dart';

// IMPORTANT: This will show a red line until we run the build_runner again!
part 'trigger_item.g.dart';

@collection
class TriggerItem {
  Id id = Isar.autoIncrement;

  @Index(unique: true)
  late String name;

  late String category;

  late String riskLevel;
}
