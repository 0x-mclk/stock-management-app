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
          print('🏪 Store name for single user activity: $finalStoreName');
        } catch (e) {
          print('⚠️ Could not get store name for single user activity: $e');
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

      print(
          '🔄 User activity updated: $userId for store: $storeId with store name: $finalStoreName');
    } catch (e) {
      print('❌ Error updating user activity: $e');
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
          print('🏪 Store name for user activity: $finalStoreName');
        } catch (e) {
          print('⚠️ Could not get store name for user activity: $e');
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
      print(
          '🔄 Batch updated ${users.length} users activity for store: $storeId with store name: $finalStoreName');
    } catch (e) {
      print('❌ Error in batch update: $e');
    }
  }

  /// Get stream of active users for a store
  Stream<List<Map<String, dynamic>>> getUserActivityStream(String storeId) {
    print('🔍 getUserActivityStream başlatıldı: StoreID = $storeId');
    try {
      return _firestore
          .collection('user_activity')
          .where('storeId', isEqualTo: storeId)
          .where('isActive', isEqualTo: true)
          .snapshots()
          .map((snapshot) {
        print('📊 User Activity snapshot: ${snapshot.docs.length} doküman');

        final users = snapshot.docs.map((doc) {
          final data = doc.data();
          print('📄 Activity doküman: ${doc.id}, data: $data');
          return {
            'userId': data['userId'],
            'storeId': data['storeId'],
            'lastActivity': data['lastActivity'],
            'isActive': data['isActive'] ?? false,
            'email': data['email'] ?? '',
            'role': data['role'] ?? 'staff',
          };
        }).toList();

        print('👥 User Activity sonuç: ${users.length} kullanıcı');
        return users;
      });
    } catch (e) {
      print('❌ getUserActivityStream hatası: $e');
      return Stream.value([]);
    }
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

      print(
          '🔍 Store $storeId için ${activityDocs.docs.length} user activity kaydı bulundu');

      // Yanlış kayıtları sil
      for (final doc in activityDocs.docs) {
        final data = doc.data();
        final recordUserId = data['userId'];
        final recordEmail = data['email'] ?? '';

        // Eğer doğru kullanıcı değilse ve email farklıysa, sil
        if (recordUserId != correctUserId &&
            recordEmail.isNotEmpty &&
            recordEmail != correctEmail) {
          print(
              '❌ Yanlış user activity kaydı siliniyor: $recordEmail (${doc.id})');
          await doc.reference.delete();
        } else {
          print('✅ Doğru user activity kaydı korunuyor: $recordUserId');
        }
      }
    } catch (e) {
      print('❌ Error cleaning up user activities: $e');
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
      print('🔄 FORCE updating user activity with correct store name');

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
        print('🏪 FORCE update - Firebase den alınan mağaza adı: $storeName');
      } catch (e) {
        print('⚠️ FORCE update - Could not get store name: $e');
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

      print(
          '✅ FORCE updated user activity: $userId for store: $storeId with store name: $storeName');
    } catch (e) {
      print('❌ Error in force update: $e');
    }
  }

  void dispose() {
    // Reserved for future cleanup
  }
}
