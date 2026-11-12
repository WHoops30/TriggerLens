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

  // ==========================================
  // NEW: 14-DAY AUTOMATED DATA PURGE (Garbage Collection)
  // Keeps the database blazing fast and memory footprint tiny
  // ==========================================
  Future<void> purgeOldData() async {
    final cutoffDate = DateTime.now().subtract(const Duration(days: 14));

    try {
      await isar.writeTxn(() async {
        // 1. Delete consumed items (History Logs) older than 14 days
        await isar.pantryItems
            .filter()
            .userIdEqualTo(_activeUid)
            .isConsumedEqualTo(true)
            .dateScannedLessThan(cutoffDate)
            .build()
            .deleteAll();

        // 2. Delete Daily Logs older than 14 days
        await isar.dailyLogs
            .filter()
            .userIdEqualTo(_activeUid)
            .dateLessThan(cutoffDate)
            .build()
            .deleteAll();
      });
      print("✅ Successfully purged heuristic data older than 14 days.");
    } catch (e) {
      print("⚠️ Failed to purge old data: $e");
    }
  }

  Future<List<DailyLog>> getDailyLogs() async {
    return await isar.dailyLogs
        .filter()
        .userIdEqualTo(_activeUid)
        .sortByDate()
        .findAll();
  }

  // ==========================================
  // PHASE 3: THE JARGON-FREE (ELI5) DATABASE
  // ==========================================
  Future<void> seedDefaultData() async {
    final count = await isar.triggerItems.count();
    if (count > 0) return;

    TriggerItem buildTrigger(String name, String risk, double score,
        String family, String desc, String category) {
      return TriggerItem()
        ..name = name
        ..category = category
        ..riskLevel = risk
        ..basePralScore = score
        ..interactionFamily = family
        ..clinicalDescription = desc;
    }

    final defaultTriggers = [
      // STOMACH STINGERS (Mucosa Irritants)
      buildTrigger(
          'Phosphoric Acid',
          'High',
          9.5,
          'Stomach Stinger',
          'Acts like lemon juice on a paper cut. Extremely acidic and can quickly irritate your throat and stomach lining.',
          'Acid'),
      buildTrigger(
          'Citric Acid',
          'High',
          9.0,
          'Stomach Stinger',
          'A very sour powder that sharply lowers your stomach’s pH and stings sensitive spots.',
          'Acid'),
      buildTrigger(
          'Ascorbic Acid',
          'High',
          8.5,
          'Stomach Stinger',
          'Artificial Vitamin C. It is highly acidic and can cause immediate burning if your stomach is empty.',
          'Acid'),
      buildTrigger(
          'Malic Acid',
          'High',
          8.0,
          'Stomach Stinger',
          'Often used to make apple or fruit drinks taste tart. It makes the stomach very acidic very quickly.',
          'Acid'),
      buildTrigger(
          'Tartaric Acid',
          'High',
          7.5,
          'Stomach Stinger',
          'Used in grape-flavored drinks. It is highly sour and aggressive on an empty tummy.',
          'Acid'),
      buildTrigger(
          'Lactic Acid',
          'High',
          7.0,
          'Stomach Stinger',
          'Used to enhance flavor. It can mildly irritate tissues in your throat if they are already sensitive.',
          'Acid'),
      buildTrigger(
          'Fumaric Acid',
          'High',
          7.0,
          'Stomach Stinger',
          'Used in powdered juices. It dissolves slowly, meaning it continuously stings the stomach over a long period.',
          'Acid'),
      buildTrigger(
          'Acetic Acid',
          'Med',
          6.5,
          'Stomach Stinger',
          'A vinegar-like ingredient. Mildly stinging, especially if you drink multiple glasses.',
          'Acid'),
      buildTrigger(
          'Sodium Benzoate',
          'Med',
          5.5,
          'Stomach Stinger',
          'A common preservative. Can create minor irritants when mixed with Vitamin C inside your drink.',
          'Preservative'),
      buildTrigger(
          'Potassium Sorbate',
          'Med',
          5.0,
          'Stomach Stinger',
          'A preservative that can cause mild tummy upsets in highly sensitive people.',
          'Preservative'),
      buildTrigger(
          'Calcium Propionate',
          'Med',
          4.5,
          'Stomach Stinger',
          'A mild preservative sometimes used in thick drinks. Gentle, but can still irritate.',
          'Preservative'),
      buildTrigger(
          'Sodium Erythorbate',
          'Med',
          4.0,
          'Stomach Stinger',
          'An antioxidant that has a very mild acidic bite to it.',
          'Preservative'),

      // STOMACH DOOR OPENERS (Valve Relaxers)
      buildTrigger(
          'Guarana Extract',
          'High',
          9.0,
          'Stomach Door Opener',
          'A very strong energy booster. It forces the tiny door at the top of your stomach to stay open, letting acid splash up.',
          'Stimulant'),
      buildTrigger(
          'Caffeine',
          'High',
          8.0,
          'Stomach Door Opener',
          'Wakes you up, but unfortunately also relaxes the muscle that keeps acid safely locked inside your stomach.',
          'Stimulant'),
      buildTrigger(
          'Coffee Solids',
          'High',
          8.0,
          'Stomach Door Opener',
          'Powdered coffee. It is highly acidic and naturally forces your stomach valve to relax and open.',
          'Stimulant'),
      buildTrigger(
          'Green Tea Extract',
          'High',
          7.5,
          'Stomach Door Opener',
          'Contains natural compounds that irritate the stomach wall while simultaneously opening the upper stomach door.',
          'Stimulant'),
      buildTrigger(
          'Theobromine',
          'High',
          7.5,
          'Stomach Door Opener',
          'The main ingredient in chocolate. It causes the muscles of your stomach valve to stay loose for a long time.',
          'Stimulant'),
      buildTrigger(
          'Cocoa Powder',
          'High',
          7.0,
          'Stomach Door Opener',
          'A classic trigger. Chocolate powders force your stomach door open, making heartburn very likely.',
          'Stimulant'),
      buildTrigger(
          'Yerba Mate',
          'High',
          7.0,
          'Stomach Door Opener',
          'An energy blend that contains stimulants known to loosen the throat muscles.',
          'Stimulant'),
      buildTrigger(
          'Peppermint Extract',
          'Med',
          6.5,
          'Stomach Door Opener',
          'Mint is a powerful muscle relaxer. It accidentally causes the stomach door to open when it shouldn’t.',
          'Herbal'),
      buildTrigger(
          'Spearmint',
          'Med',
          6.0,
          'Stomach Door Opener',
          'Milder than peppermint, but still actively relaxes the muscles that keep acid down.',
          'Herbal'),
      buildTrigger(
          'Black Tea Extract',
          'Med',
          6.0,
          'Stomach Door Opener',
          'Contains caffeine and natural compounds that contribute to acid splashing up.',
          'Herbal'),
      buildTrigger(
          'Taurine',
          'Med',
          5.0,
          'Stomach Door Opener',
          'Found in energy drinks. Can cause your body to pump out extra stomach acid.',
          'Stimulant'),

      // TRAFFIC JAMS (Gastric Delays)
      buildTrigger(
          'Hydrogenated Vegetable Oil',
          'High',
          8.5,
          'Traffic Jam',
          'A heavy fat heavily used in 3-in-1 coffees. It stays in your stomach for a very long time, creating heavy upward pressure.',
          'Lipid'),
      buildTrigger(
          'Palm Kernel Oil',
          'High',
          7.5,
          'Traffic Jam',
          'A fat used in cheap creamers. It is hard to digest, keeping the stomach full, bloated, and pressurized.',
          'Lipid'),
      buildTrigger(
          'Palm Oil',
          'Med',
          7.0,
          'Traffic Jam',
          'A common fat that slows down digestion, increasing upward pressure in your tummy over time.',
          'Lipid'),
      buildTrigger(
          'Carrageenan',
          'High',
          7.0,
          'Traffic Jam',
          'Used to make milk teas thick. Known to cause tummy inflammation and make existing heartburn feel worse.',
          'Thickener'),
      buildTrigger(
          'Non-Dairy Creamer',
          'Med',
          6.5,
          'Traffic Jam',
          'Made of processed fats that severely slow down your digestion and bloat your stomach.',
          'Lipid'),
      buildTrigger(
          'Coconut Oil Powder',
          'Med',
          6.0,
          'Traffic Jam',
          'A fat that slows down stomach emptying, though slightly easier to digest than palm oil.',
          'Lipid'),
      buildTrigger(
          'Whey Protein Concentrate',
          'Med',
          6.0,
          'Traffic Jam',
          'Digests slowly and contains dairy, causing bloating and increased belly pressure.',
          'Protein'),
      buildTrigger(
          'Xanthan Gum',
          'Med',
          5.0,
          'Traffic Jam',
          'A thickener that can cause a bloated, heavy feeling in high amounts.',
          'Thickener'),
      buildTrigger(
          'Guar Gum',
          'Med',
          5.0,
          'Traffic Jam',
          'A fiber that slows digestion and can cause trapped gas to push against the stomach door.',
          'Thickener'),
      buildTrigger(
          'Cellulose Gum',
          'Med',
          4.5,
          'Traffic Jam',
          'Adds thickness to your drink, making it sit in your stomach longer than water.',
          'Thickener'),
      buildTrigger(
          'Calcium Caseinate',
          'Med',
          4.5,
          'Traffic Jam',
          'A milk protein that turns into a slow-digesting gel in your stomach, prolonging acid exposure.',
          'Protein'),
      buildTrigger(
          'Sodium Caseinate',
          'Med',
          4.5,
          'Traffic Jam',
          'Another milk protein used in creamers that keeps your stomach full for longer.',
          'Protein'),
      buildTrigger(
          'Whole Milk Powder',
          'Med',
          4.0,
          'Traffic Jam',
          'It initially coats the stomach, but the heavy fat eventually slows digestion and causes an acid rebound.',
          'Protein'),

      // GAS BUBBLES (Osmotic Stressors)
      buildTrigger(
          'High Fructose Corn Syrup',
          'Med',
          6.0,
          'Gas Bubble',
          'Creates trapped air and gas bubbles in your tummy very quickly, causing burping that pushes acid upward.',
          'Sweetener'),
      buildTrigger(
          'Corn Syrup Solids',
          'Med',
          6.0,
          'Gas Bubble',
          'A heavy sugar that draws water into the stomach, causing sudden and uncomfortable bloating.',
          'Sweetener'),
      buildTrigger(
          'Maltodextrin',
          'Med',
          5.5,
          'Gas Bubble',
          'A processed carb filler. It ferments quickly in the gut, causing gas and upward pressure.',
          'Carbohydrate'),
      buildTrigger(
          'Xylitol',
          'Med',
          5.0,
          'Gas Bubble',
          'A sugar alternative. It ferments in the lower tummy, creating severe gas that pushes acid up into the throat.',
          'Sweetener'),
      buildTrigger(
          'Erythritol',
          'Med',
          5.0,
          'Gas Bubble',
          'A common "sugar-free" sweetener that can cause severe bloating and gas bubbles.',
          'Sweetener'),
      buildTrigger(
          'Sorbitol',
          'Med',
          5.0,
          'Gas Bubble',
          'An artificial sweetener known for causing upset tummies, bloating, and secondary heartburn.',
          'Sweetener'),
      buildTrigger(
          'Dextrose',
          'Med',
          4.5,
          'Gas Bubble',
          'A simple sugar that rapidly increases the heaviness of your stomach contents.',
          'Sweetener'),
      buildTrigger(
          'Inulin (Chicory Root)',
          'Med',
          4.5,
          'Gas Bubble',
          'A fiber added to "healthy" drinks. Often causes extreme bloating and burping that pushes acid upward.',
          'Carbohydrate'),
      buildTrigger(
          'Fructose',
          'Med',
          4.5,
          'Gas Bubble',
          'Pure fruit sugar. It is harder to absorb than regular sugar, often leading to tummy gas.',
          'Sweetener'),
      buildTrigger(
          'Polydextrose',
          'Med',
          4.5,
          'Gas Bubble',
          'A synthetic fiber used as a low-calorie filler. It causes gas and bloating in sensitive stomachs.',
          'Carbohydrate'),
      buildTrigger(
          'Sucralose',
          'Med',
          4.0,
          'Gas Bubble',
          'An artificial sweetener that can draw excess water into the intestines, causing indirect bloating.',
          'Sweetener'),
      buildTrigger(
          'Refined White Sugar',
          'Med',
          4.0,
          'Gas Bubble',
          'Draws water into the stomach rapidly, which can cause a suddenly full or bloated feeling.',
          'Sweetener'),
      buildTrigger(
          'Aspartame',
          'Med',
          3.5,
          'Gas Bubble',
          'An artificial sweetener. Less bloating than others, but can still trigger sensitivity.',
          'Sweetener'),
      buildTrigger(
          'Acesulfame Potassium',
          'Med',
          3.5,
          'Gas Bubble',
          'Often paired with other sweeteners; causes very mild stomach bubbling.',
          'Sweetener'),
      buildTrigger(
          'Saccharin',
          'Low',
          3.0,
          'Gas Bubble',
          'An older artificial sweetener. Low risk for heartburn, though often avoided for other reasons.',
          'Sweetener'),

      // STOMACH SOOTHERS (Buffers / Safe)
      buildTrigger(
          'Sodium Bicarbonate',
          'Buffer',
          -2.0,
          'Stomach Soother',
          'Baking soda! This is extremely gentle and actively neutralizes burning stomach acid.',
          'Buffer'),
      buildTrigger(
          'Potassium Citrate',
          'Buffer',
          -1.5,
          'Stomach Soother',
          'An alkaline salt that acts as a soothing buffer against acid.',
          'Buffer'),
      buildTrigger(
          'Calcium Carbonate',
          'Buffer',
          -1.5,
          'Stomach Soother',
          'This is the active ingredient in most antacids; it directly fights stomach burn.',
          'Buffer'),
      buildTrigger(
          'Magnesium Hydroxide',
          'Buffer',
          -1.0,
          'Stomach Soother',
          'A gentle compound that helps buffer acid and keeps digestion moving smoothly.',
          'Buffer'),
      buildTrigger(
          'Stevia Extract',
          'Low',
          1.0,
          'Safe',
          'A natural plant-based sweetener. It does not cause gas bubbles or trigger acid spikes.',
          'Sweetener'),
      buildTrigger(
          'Monk Fruit Extract',
          'Low',
          1.0,
          'Safe',
          'A highly stable natural sweetener. It is very gentle on the tummy.',
          'Sweetener'),
      buildTrigger(
          'Muscovado Sugar',
          'Low',
          1.5,
          'Trace Mineral',
          'An unrefined sugar. Because it digests slower, it prevents the sudden bloating caused by white sugar.',
          'Sweetener'),

      // HERBAL TRIGGERS
      buildTrigger(
          'Hibiscus Extract',
          'High',
          8.0,
          'Stomach Stinger',
          'Contains high levels of natural acids. It drops stomach pH rapidly, acting like a Stinger to a sensitive throat.',
          'Herbal'),
      buildTrigger(
          'Matcha Powder',
          'High',
          7.5,
          'Stomach Door Opener',
          'Highly concentrated green tea. It stings the stomach while simultaneously forcing the stomach door open.',
          'Herbal'),
      buildTrigger(
          'Eucalyptus Extract',
          'Med',
          6.5,
          'Stomach Door Opener',
          'Found in soothing teas. It acts as a powerful muscle relaxer that accidentally forces the stomach valve to stay open.',
          'Herbal'),
      buildTrigger(
          'Ginger Root Powder',
          'Med',
          5.0,
          'Stomach Stinger',
          'While fresh ginger is great for digestion, the dry powder in sachets can sometimes cause direct heartburn.',
          'Herbal'),
      buildTrigger(
          'Chamomile Extract',
          'Med',
          4.5,
          'Stomach Door Opener',
          'Generally soothing, but it relaxes smooth muscle tissue. In severe cases, this can inadvertently relax the stomach door.',
          'Herbal'),
    ];

    await isar.writeTxn(() async {
      await isar.triggerItems.putAll(defaultTriggers);
    });
  }

  Future<List<TriggerItem>> getAllTriggers() async {
    return await isar.triggerItems.where().findAll();
  }

  Future<bool> addTrigger({
    required String name,
    required String category,
    required String riskLevel,
    required double basePralScore,
    required String interactionFamily,
    required String clinicalDescription,
  }) async {
    try {
      final newItem = TriggerItem()
        ..name = name.trim()
        ..category = category
        ..riskLevel = riskLevel
        ..basePralScore = basePralScore
        ..interactionFamily = interactionFamily
        ..clinicalDescription = clinicalDescription;
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

  Future<void> savePantryItem(PantryItem item) async {
    item.userId = _activeUid;
    await isar.writeTxn(() async {
      await isar.pantryItems.put(item);
    });
  }

  Future<List<PantryItem>> getPantryItems() async {
    return await isar.pantryItems
        .filter()
        .userIdEqualTo(_activeUid)
        .isConsumedEqualTo(true)
        .sortByDateScannedDesc()
        .findAll();
  }

  Future<List<PantryItem>> getAllSavedAndConsumedItems() async {
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

  Future<void> saveInteractiveOnboarding({
    required String clinicalStatus,
    required String ageGroup,
    required String refluxFrequency,
    required String primaryGoal,
    required double targetPral,
  }) async {
    final existingProfile = await getUserProfile();
    final profile = existingProfile ?? UserProfile();

    profile
      ..userId = _activeUid
      ..phase = "Interactive Calibration"
      ..clinicalStatus = clinicalStatus
      ..ageGroup = ageGroup
      ..refluxFrequency = refluxFrequency
      ..primaryGoal = primaryGoal
      ..multiplier = 1.0
      ..dailyCap = targetPral.toInt()
      ..baseDailyCap = targetPral
      ..dynamicDailyCap = targetPral
      ..targetDailyPral = targetPral;

    await isar.writeTxn(() async {
      await isar.userProfiles.put(profile);
    });
  }

  Future<void> markSetupComplete() async {
    final profile = await getUserProfile();
    if (profile != null) {
      profile.isSetupComplete = true;
      await isar.writeTxn(() async {
        await isar.userProfiles.put(profile);
      });
    }
  }

  Future<void> saveDailyLog(DailyLog log) async {
    log.userId = _activeUid;

    final now = DateTime.now();
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

  Future<void> wipeCurrentUserLocalData() async {
    await isar.writeTxn(() async {
      await isar.pantryItems
          .filter()
          .userIdEqualTo(_activeUid)
          .build()
          .deleteAll();
      await isar.dailyLogs
          .filter()
          .userIdEqualTo(_activeUid)
          .build()
          .deleteAll();
      await isar.consumptionLogs
          .filter()
          .userIdEqualTo(_activeUid)
          .build()
          .deleteAll();
      await isar.userProfiles
          .filter()
          .userIdEqualTo(_activeUid)
          .build()
          .deleteAll();
    });
  }
}
