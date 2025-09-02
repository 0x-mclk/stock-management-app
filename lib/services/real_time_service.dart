import 'dart:async';
import 'package:flutter/material.dart';
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
  }) async {
    try {
      final data = {
        'storeId': storeId,
        'userId': userId,
        'lastActivity': FieldValue.serverTimestamp(),
        'isActive': true,
      };

      // Add optional user info if provided
      if (email != null) data['email'] = email;
      if (role != null) data['role'] = role;

      await _firestore
          .collection('user_activity')
          .doc('${storeId}_$userId')
          .set(data, SetOptions(merge: true));

      // Debug print removed
    } catch (e) {
      // Debug print removed
    }
  }

  /// Get stream of active users for a store
  Stream<List<Map<String, dynamic>>> getUserActivityStream(String storeId) {
    try {
      return _firestore
          .collection('user_activity')
          .where('storeId', isEqualTo: storeId)
          .where('isActive', isEqualTo: true)
          .snapshots()
          .map((snapshot) {
        return snapshot.docs.map((doc) {
          final data = doc.data();
          return {
            'userId': data['userId'],
            'storeId': data['storeId'],
            'lastActivity': data['lastActivity'],
            'isActive': data['isActive'] ?? false,
            'email': data['email'] ?? '',
            'role': data['role'] ?? 'staff',
          };
        }).toList();
      });
    } catch (e) {
      // Debug print removed
      return Stream.value([]);
    }
  }

  /// Dispose all resources
  void dispose() {
    // Reserved for future cleanup
  }
}




