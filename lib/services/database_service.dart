import 'package:isar/isar.dart';
import 'package:path_provider/path_provider.dart';
import '../models/trigger_item.dart';
import '../models/consumption_log.dart';
import '../models/pantry_item.dart';
import '../models/user_profile.dart'; // ADDED USER PROFILE MODEL

class DatabaseService {
  late Isar isar;

  Future<void> initDB() async {
    final dir = await getApplicationDocumentsDirectory();
    isar = await Isar.open(
      // Added UserProfileSchema to the database blueprint
      [
        TriggerItemSchema,
        ConsumptionLogSchema,
        PantryItemSchema,
        UserProfileSchema
      ],
      directory: dir.path,
    );
  }

  Future<void> seedDefaultData() async {
    final count = await isar.triggerItems.count();
    if (count > 0) return;

    final defaultTriggers = [
      TriggerItem()
        ..name = 'milk'
        ..category = 'Dairy'
        ..riskLevel = 'Medium',
      TriggerItem()
        ..name = 'skimmed milk'
        ..category = 'Dairy'
        ..riskLevel = 'Medium',
      TriggerItem()
        ..name = 'palm oil'
        ..category = 'Lipids'
        ..riskLevel = 'High',
      TriggerItem()
        ..name = 'vitamin c'
        ..category = 'Acid'
        ..riskLevel = 'High',
      TriggerItem()
        ..name = 'caffeine'
        ..category = 'Alkaloids'
        ..riskLevel = 'High',
      TriggerItem()
        ..name = 'citric acid'
        ..category = 'Organic Acids'
        ..riskLevel = 'High',
    ];

    await isar.writeTxn(() async {
      await isar.triggerItems.putAll(defaultTriggers);
    });
  }

  Future<List<TriggerItem>> getAllTriggers() async {
    return await isar.triggerItems.where().findAll();
  }

  Future<bool> addTrigger(
      String name, String category, String riskLevel) async {
    try {
      final newItem = TriggerItem()
        ..name = name.trim()
        ..category = category
        ..riskLevel = riskLevel;
      await isar.writeTxn(() async {
        await isar.triggerItems.put(newItem);
      });
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<bool> deleteTrigger(int id) async {
    try {
      await isar.writeTxn(() async {
        await isar.triggerItems.delete(id);
      });
      return true;
    } catch (e) {
      return false;
    }
  }

  // 1. Save an item to the Digital Pantry
  Future<void> savePantryItem(PantryItem item) async {
    await isar.writeTxn(() async {
      await isar.pantryItems.put(item);
    });
  }

  // 2. Get all saved items for the Digital Pantry Screen
  Future<List<PantryItem>> getPantryItems() async {
    return await isar.pantryItems.where().sortByDateScannedDesc().findAll();
  }

  // 3. Delete an item from the Digital Pantry
  Future<void> deletePantryItem(int id) async {
    await isar.writeTxn(() async {
      await isar.pantryItems.delete(id);
    });
  }

  // 4. Toggle Favorite Status
  Future<void> toggleFavorite(int id, bool isFavorite) async {
    await isar.writeTxn(() async {
      final item = await isar.pantryItems.get(id);
      if (item != null) {
        item.isFavorite = isFavorite;
        await isar.pantryItems.put(item);
      }
    });
  }

  // ==========================================
  // NEW LOGIC: DYNAMIC USER SENSITIVITY
  // ==========================================

  // Save the result from the GerdQ Onboarding Screen
  Future<void> saveUserSensitivityProfile(
      String phase, double multiplier, int dailyCap) async {
    final profile = UserProfile()
      ..id =
          1 // We lock this to 1 so it always overwrites the previous profile instead of creating duplicates
      ..phase = phase
      ..multiplier = multiplier
      ..dailyCap = dailyCap;

    await isar.writeTxn(() async {
      await isar.userProfiles.put(profile);
    });
  }

  // Retrieve the profile for the dynamic math algorithm
  Future<UserProfile?> getUserProfile() async {
    // Returns null if the user hasn't completed the GerdQ assessment yet
    return await isar.userProfiles.get(1);
  }
}
