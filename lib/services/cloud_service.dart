import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/trigger_item.dart';

class CloudService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String get _userId => _auth.currentUser?.uid ?? 'demo_user';

  Future<void> backupTriggerToCloud(TriggerItem item) async {
    try {
      await _db
          .collection('users')
          .doc(_userId)
          .collection('digital_pantry')
          .doc(item.name)
          .set({
        'name': item.name,
        'category': item.category,
        'riskLevel': item.riskLevel,
        'syncedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print("⚠️ Cloud sync skipped: $e");
    }
  }

  // ==========================================
  // CHAT HISTORY CLOUD MANAGEMENT
  // ==========================================

  Future<String?> saveChatMessage(String text, bool isUser) async {
    try {
      final docRef = await _db
          .collection('users')
          .doc(_userId)
          .collection('chat_history')
          .add({
        'text': text,
        'isUser': isUser,
        'timestamp': FieldValue.serverTimestamp(),
      });
      return docRef.id;
    } catch (e) {
      print("⚠️ Failed to save chat to cloud: $e");
      return null;
    }
  }

  Future<List<Map<String, dynamic>>> getChatHistory() async {
    try {
      final snapshot = await _db
          .collection('users')
          .doc(_userId)
          .collection('chat_history')
          .orderBy('timestamp', descending: false)
          .get();

      return snapshot.docs.map((doc) {
        return {
          'id': doc.id,
          'text': doc['text'],
          'isUser': doc['isUser'],
          'timestamp': doc['timestamp'] != null
              ? (doc['timestamp'] as Timestamp).toDate()
              : DateTime.now(),
        };
      }).toList();
    } catch (e) {
      print("⚠️ Failed to fetch chat history: $e");
      return [];
    }
  }

  Future<void> deleteMessage(String docId) async {
    try {
      await _db
          .collection('users')
          .doc(_userId)
          .collection('chat_history')
          .doc(docId)
          .delete();
    } catch (e) {
      print("⚠️ Failed to delete specific message: $e");
    }
  }

  Future<void> deleteSession(DateTime startOfDay, DateTime endOfDay) async {
    try {
      var snapshots = await _db
          .collection('users')
          .doc(_userId)
          .collection('chat_history')
          .where('timestamp', isGreaterThanOrEqualTo: startOfDay)
          .where('timestamp', isLessThanOrEqualTo: endOfDay)
          .get();

      for (var doc in snapshots.docs) {
        await doc.reference.delete();
      }
    } catch (e) {
      print("⚠️ Failed to delete session: $e");
    }
  }

  Future<void> clearChatHistory() async {
    try {
      var snapshots = await _db
          .collection('users')
          .doc(_userId)
          .collection('chat_history')
          .get();
      for (var doc in snapshots.docs) {
        await doc.reference.delete();
      }
    } catch (e) {
      print("⚠️ Failed to clear chat history: $e");
    }
  }
}
