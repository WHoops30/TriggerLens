import 'package:isar/isar.dart';

part 'consumption_log.g.dart';

@collection
class ConsumptionLog {
  Id id = Isar.autoIncrement;

  late DateTime consumedAt;

  // The calculated acid risk of the product (e.g., 1 = Low, 2 = Mod, 3 = High)
  late int acidScore;

  late String productDetails;
}
