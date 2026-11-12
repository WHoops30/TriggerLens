import 'package:isar/isar.dart';

// IMPORTANT: This will show a red line until you run build_runner again!
part 'trigger_item.g.dart';

@collection
class TriggerItem {
  Id id = Isar.autoIncrement;

  @Index(unique: true)
  late String name;

  late String category;

  late String riskLevel;

  // ==========================================
  // PHASE 1: BIOLOGICAL & CLINICAL FIELDS
  // ==========================================

  // Categorizes the trigger (e.g., 'Valve Relaxer', 'Mucosa Irritant', 'Gastric Delay')
  late String interactionFamily;

  // The clinical explanation shown to the user on the UI
  late String clinicalDescription;

  // The exact numeric acid load used in the mathematical engine
  late double basePralScore;
}
