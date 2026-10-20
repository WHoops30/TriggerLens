import 'package:isar/isar.dart';
import 'package:path_provider/path_provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/trigger_item.dart';
import '../models/consumption_log.dart';
import '../models/pantry_item.dart';
import '../models/user_profile.dart';
import '../models/daily_log.dart';

class DatabaseService {
  late Isar isar;

  // THE FIREWALL: Automatically routes data to the active logged-in user
  String get _activeUid =>
      FirebaseAuth.instance.currentUser?.uid ?? 'local_guest';

  Future<void> initDB() async {
    final dir = await getApplicationDocumentsDirectory();
    isar = await Isar.open(
      [
        TriggerItemSchema,
        ConsumptionLogSchema,
        PantryItemSchema,
        UserProfileSchema,
        DailyLogSchema,
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

  // RESTORED: All original trigger functions
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

  // ==========================================
  // MULTI-USER ISOLATED METHODS
  // ==========================================

  Future<void> savePantryItem(PantryItem item) async {
    item.userId = _activeUid; // Locks data to the active account
    await isar.writeTxn(() async {
      await isar.pantryItems.put(item);
    });
  }

  Future<List<PantryItem>> getPantryItems() async {
    // Only fetches scans that belong to the person holding the phone
    return await isar.pantryItems
        .filter()
        .userIdEqualTo(_activeUid)
        .sortByDateScannedDesc()
        .findAll();
  }

  Future<void> deletePantryItem(int id) async {
    await isar.writeTxn(() async {
      await isar.pantryItems.delete(id);
    });
  }

  // RESTORED: Toggle Favorite Function
  Future<void> toggleFavorite(int id, bool isFavorite) async {
    await isar.writeTxn(() async {
      final item = await isar.pantryItems.get(id);
      if (item != null) {
        item.isFavorite = isFavorite;
        await isar.pantryItems.put(item);
      }
    });
  }

  Future<UserProfile?> getUserProfile() async {
    // Dynamically fetches the profile for the specific account instead of hardcoding "id: 1"
    return await isar.userProfiles
        .filter()
        .userIdEqualTo(_activeUid)
        .findFirst();
  }

  Future<void> saveUserSensitivityProfile(
      String phase, double multiplier, int dailyCap) async {
    final existingProfile = await getUserProfile();
    final profile = existingProfile ?? UserProfile();

    profile
      ..userId = _activeUid
      ..phase = phase
      ..multiplier = multiplier
      ..dailyCap = dailyCap
      ..baseDailyCap = dailyCap.toDouble()
      ..dynamicDailyCap = dailyCap.toDouble();

    await isar.writeTxn(() async {
      await isar.userProfiles.put(profile);
    });
  }

  Future<void> saveInteractiveOnboarding(
      {required int goalIndex,
      required int frequencyIndex,
      required int baselineIndex,
      required double targetPral}) async {
    final existingProfile = await getUserProfile();
    final profile = existingProfile ?? UserProfile();

    profile
      ..userId = _activeUid
      ..phase = "Interactive Calibration"
      ..multiplier = 1.0
      ..dailyCap = targetPral.toInt()
      ..baseDailyCap = targetPral
      ..dynamicDailyCap = targetPral
      ..goalIndex = goalIndex
      ..refluxFrequencyIndex = frequencyIndex
      ..baselineStrictnessIndex = baselineIndex
      ..targetDailyPral = targetPral;

    await isar.writeTxn(() async {
      await isar.userProfiles.put(profile);
    });
  }

  // ==========================================
  // PHASE 5: BIO-FEEDBACK AUTO-CORRECTION LOOP
  // ==========================================
  Future<void> saveDailyLog(DailyLog log) async {
    log.userId = _activeUid;

    final now = DateTime.now();
    // Only check today's items for THIS specific user
    final todayItems = await getPantryItems();
    double todayLoad = 0;

    for (var item in todayItems) {
      if (item.dateScanned.year == now.year &&
          item.dateScanned.month == now.month &&
          item.dateScanned.day == now.day) {
        todayLoad += item.acidScore;
      }
    }

    final profile = await getUserProfile();
    if (profile != null) {
      bool profileChanged = false;

      if (todayLoad > profile.baseDailyCap && log.severity <= 1) {
        profile.baseDailyCap *= 1.10;
        profileChanged = true;
      } else if (todayLoad <= profile.baseDailyCap && log.severity >= 5) {
        profile.baseDailyCap *= 0.90;
        profileChanged = true;
      }

      if (profile.baseDailyCap < 5.0) profile.baseDailyCap = 5.0;
      if (profile.baseDailyCap > 50.0) profile.baseDailyCap = 50.0;

      profile.dynamicDailyCap = profile.baseDailyCap;

      if (profileChanged) {
        await isar.writeTxn(() async {
          await isar.userProfiles.put(profile);
        });
      }
    }

    await isar.writeTxn(() async {
      await isar.dailyLogs.put(log);
    });
  }

  Future<List<DailyLog>> getDailyLogs() async {
    return await isar.dailyLogs
        .filter()
        .userIdEqualTo(_activeUid)
        .sortByDate()
        .findAll();
  }

  // NEW: A destructive method for the Privacy Center
  Future<void> wipeCurrentUserLocalData() async {
    await isar.writeTxn(() async {
      await isar.pantryItems.filter().userIdEqualTo(_activeUid).deleteAll();
      await isar.dailyLogs.filter().userIdEqualTo(_activeUid).deleteAll();
      await isar.consumptionLogs.filter().userIdEqualTo(_activeUid).deleteAll();
      await isar.userProfiles.filter().userIdEqualTo(_activeUid).deleteAll();
    });
  }
}
