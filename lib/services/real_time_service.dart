import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';

class RealTimeService {
  // Singleton pattern
  static RealTimeService? _instance;
  static RealTimeService get instance => _instance ??= RealTimeService._();
  RealTimeService._();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Basic connectivity check for future use
  Future<bool> checkConnection() async {
    try {
      return true; // Firebase is initialized and available
    } catch (e) {
      // Debug print removed
      return false;
    }
  }

  /// Update user activity for real-time tracking
  Future<void> updateUserActivity({
    required String storeId,
    required String userId,
    String? email,
    String? role,
    String? storeName,
  }) async {
    try {
      // Eğer storeName verilmemişse, Firebase'den al
      String finalStoreName = storeName ?? 'Mağaza';
      if (storeName == null || storeName.isEmpty) {
        try {
          final storeDoc =
              await _firestore.collection('stores').doc(storeId).get();
          if (storeDoc.exists) {
            finalStoreName = storeDoc.data()?['name'] ?? 'Mağaza';
            if (finalStoreName.isEmpty) {
              finalStoreName = 'Mağaza';
            }
          }
        } catch (e) {
        }
      }

      final data = {
        'storeId': storeId,
        'userId': userId,
        'storeName': finalStoreName, // Doğru mağaza adını ekle
        'lastActivity': FieldValue.serverTimestamp(),
        'isActive': true,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      // Add optional user info if provided
      if (email != null) data['email'] = email;
      if (role != null) data['role'] = role;

      await _firestore
          .collection('user_activity')
          .doc('${storeId}_$userId')
          .set(data, SetOptions(merge: true));
    } catch (e) {
    }
  }

  /// Batch update multiple users' activity
  Future<void> batchUpdateUserActivity({
    required String storeId,
    required List<Map<String, String>> users, // [{userId, email, role}, ...]
    String? storeName,
  }) async {
    try {
      final batch = _firestore.batch();

      // Eğer storeName verilmemişse, Firebase'den al
      String finalStoreName = storeName ?? 'Mağaza';
      if (storeName == null || storeName.isEmpty) {
        try {
          final storeDoc =
              await _firestore.collection('stores').doc(storeId).get();
          if (storeDoc.exists) {
            finalStoreName = storeDoc.data()?['name'] ?? 'Mağaza';
            if (finalStoreName.isEmpty) {
              finalStoreName = 'Mağaza';
            }
          }
        } catch (e) {
        }
      }

      for (final user in users) {
        final userId = user['userId'];
        if (userId == null || userId.isEmpty) continue;

        final docRef =
            _firestore.collection('user_activity').doc('${storeId}_$userId');

        final data = {
          'storeId': storeId,
          'userId': userId,
          'storeName': finalStoreName, // Doğru mağaza adını ekle
          'lastActivity': FieldValue.serverTimestamp(),
          'isActive': true,
          'updatedAt': FieldValue.serverTimestamp(),
        };

        if (user['email'] != null) data['email'] = user['email']!;
        if (user['role'] != null) data['role'] = user['role']!;

        batch.set(docRef, data, SetOptions(merge: true));
      }

      await batch.commit();
    } catch (e) {
    }
  }

  /// Get stream of active users for a store.
  /// Uses a per-store cache to throttle Firestore events (max 1 rebuild / 10 s).
  final Map<String, StreamController<List<Map<String, dynamic>>>>
      _activityControllers = {};
  final Map<String, StreamSubscription<QuerySnapshot>> _activitySubs = {};
  final Map<String, DateTime> _activityLastEmit = {};

  Stream<List<Map<String, dynamic>>> getUserActivityStream(String storeId) {
    if (!_activityControllers.containsKey(storeId)) {
      final ctrl =
          StreamController<List<Map<String, dynamic>>>.broadcast();
      _activityControllers[storeId] = ctrl;

      _activitySubs[storeId] = _firestore
          .collection('user_activity')
          .where('storeId', isEqualTo: storeId)
          .where('isActive', isEqualTo: true)
          .snapshots()
          .listen((snapshot) {
        final now = DateTime.now();
        final last = _activityLastEmit[storeId];
        if (last != null &&
            now.difference(last).inSeconds < 10) {
          return; // throttle — en fazla 10 sn'de 1 kez emit et
        }
        _activityLastEmit[storeId] = now;

        final users = snapshot.docs.map((doc) {
          final data = doc.data() as Map<String, dynamic>;
          return {
            'userId': data['userId'],
            'storeId': data['storeId'],
            'lastActivity': data['lastActivity'],
            'isActive': data['isActive'] ?? false,
            'email': data['email'] ?? '',
            'role': data['role'] ?? 'staff',
          };
        }).toList();

        if (!ctrl.isClosed) ctrl.add(users);
      }, onError: (e) {
        if (!ctrl.isClosed) ctrl.add([]);
      });
    }
    return _activityControllers[storeId]!.stream;
  }

  /// Clean up incorrect user activity records
  Future<void> cleanupIncorrectUserActivities({
    required String storeId,
    required String correctUserId,
    required String correctEmail,
  }) async {
    try {
      // Bu store'daki tüm user activity kayıtlarını al
      final activityDocs = await _firestore
          .collection('user_activity')
          .where('storeId', isEqualTo: storeId)
          .get();

      // Yanlış kayıtları sil
      for (final doc in activityDocs.docs) {
        final data = doc.data();
        final recordUserId = data['userId'];
        final recordEmail = data['email'] ?? '';

        // Eğer doğru kullanıcı değilse ve email farklıysa, sil
        if (recordUserId != correctUserId &&
            recordEmail.isNotEmpty &&
            recordEmail != correctEmail) {
          await doc.reference.delete();
        } else {
        }
      }
    } catch (e) {
    }
  }

  /// Force update user activity with correct store name
  Future<void> forceUpdateUserActivityWithCorrectStoreName({
    required String storeId,
    required String userId,
    String? email,
    String? role,
  }) async {
    try {

      // Firebase'den mağaza adını al
      String storeName = 'Mağaza';
      try {
        final storeDoc =
            await _firestore.collection('stores').doc(storeId).get();
        if (storeDoc.exists) {
          storeName = storeDoc.data()?['name'] ?? 'Mağaza';
          if (storeName.isEmpty) {
            storeName = 'Mağaza';
          }
        }
      } catch (e) {
      }

      final data = {
        'storeId': storeId,
        'userId': userId,
        'storeName': storeName,
        'lastActivity': FieldValue.serverTimestamp(),
        'isActive': true,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (email != null) data['email'] = email;
      if (role != null) data['role'] = role;

      await _firestore
          .collection('user_activity')
          .doc('${storeId}_$userId')
          .set(data, SetOptions(merge: true));
    } catch (e) {
    }
  }

  void dispose() {
    // Reserved for future cleanup
  }
}
