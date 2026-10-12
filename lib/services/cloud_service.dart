import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/trigger_item.dart';

class CloudService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// Backs up a locally saved trigger to the Cloud (Firestore)
  Future<void> backupTriggerToCloud(TriggerItem item) async {
    try {
      await _db
          .collection('users')
          .doc('demo_user')
          .collection('digital_pantry')
          .doc(item.name)
          .set({
        'name': item.name,
        'category': item.category,
        'riskLevel': item.riskLevel,
        'syncedAt': FieldValue.serverTimestamp(),
      });
      print("☁️ Successfully backed up ${item.name} to Firebase Cloud!");
    } catch (e) {
      print("⚠️ Cloud sync skipped (User might be offline): $e");
    }
  }
}
