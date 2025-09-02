import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../models/invitation_model.dart';

class InvitationService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Singleton pattern
  static InvitationService? _instance;
  static InvitationService get instance => _instance ??= InvitationService._();
  InvitationService._();

  /// Get members collection reference for a store
  CollectionReference _getMembersCollection(String storeId) {
    return _firestore.collection('stores').doc(storeId).collection('members');
  }

  /// Send invitation to join store
  Future<String?> sendInvitation({
    required String storeId,
    required String email,
    required UserRole role,
    required String invitedBy,
    List<String>? customPermissions,
  }) async {
    try {
      // Check if user already invited or member
      final existingInvitation = await _getMembersCollection(storeId)
          .where('email', isEqualTo: email)
          .get();

      if (existingInvitation.docs.isNotEmpty) {
        throw Exception('Bu email adresi zaten davet edilmiş');
      }

      // Create invitation
      final invitation = InvitationModel(
        userId: '', // Will be filled when user accepts
        email: email,
        storeId: storeId,
        role: role,
        permissions:
            customPermissions ?? InvitationModel.getDefaultPermissions(role),
        status: InvitationStatus.invited,
        invitedAt: DateTime.now(),
        invitedBy: invitedBy,
      );

      // Add to Firestore
      final docRef =
          await _getMembersCollection(storeId).add(invitation.toFirestore());

      // Debug print removed
      return docRef.id;
    } catch (e) {
      // Debug print removed
      return null;
    }
  }

  /// Accept invitation
  Future<bool> acceptInvitation({
    required String storeId,
    required String invitationId,
    required String userId,
  }) async {
    try {
      await _getMembersCollection(storeId).doc(invitationId).update({
        'userId': userId,
        'status': InvitationStatus.accepted.toString().split('.').last,
        'joinedAt': FieldValue.serverTimestamp(),
        'respondedAt': FieldValue.serverTimestamp(),
        'lastActivity': FieldValue.serverTimestamp(),
      });

      // Debug print removed
      return true;
    } catch (e) {
      // Debug print removed
      return false;
    }
  }

  /// Reject invitation
  Future<bool> rejectInvitation({
    required String storeId,
    required String invitationId,
  }) async {
    try {
      await _getMembersCollection(storeId).doc(invitationId).update({
        'status': InvitationStatus.rejected.toString().split('.').last,
        'respondedAt': FieldValue.serverTimestamp(),
      });

      // Debug print removed
      return true;
    } catch (e) {
      // Debug print removed
      return false;
    }
  }

  /// Get all members for a store
  Stream<List<InvitationModel>> getMembersStream(String storeId) {
    return _getMembersCollection(storeId)
        .orderBy('invitedAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => InvitationModel.fromFirestore(doc))
            .toList());
  }

  /// Get pending invitations for a user email
  Stream<List<InvitationModel>> getPendingInvitationsStream(String email) {
    return _firestore
        .collectionGroup('members')
        .where('email', isEqualTo: email)
        .where('status',
            isEqualTo: InvitationStatus.invited.toString().split('.').last)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => InvitationModel.fromFirestore(doc))
            .toList());
  }

  /// Remove member from store
  Future<bool> removeMember({
    required String storeId,
    required String memberId,
  }) async {
    try {
      await _getMembersCollection(storeId).doc(memberId).delete();
      // Debug print removed
      return true;
    } catch (e) {
      // Debug print removed
      return false;
    }
  }

  /// Deactivate member (soft delete)
  Future<bool> deactivateMember({
    required String storeId,
    required String memberId,
  }) async {
    try {
      await _getMembersCollection(storeId).doc(memberId).update({
        'isActive': false,
        'lastActivity': FieldValue.serverTimestamp(),
      });
      // Debug print removed
      return true;
    } catch (e) {
      // Debug print removed
      return false;
    }
  }

  /// Reactivate member
  Future<bool> reactivateMember({
    required String storeId,
    required String memberId,
  }) async {
    try {
      await _getMembersCollection(storeId).doc(memberId).update({
        'isActive': true,
        'lastActivity': FieldValue.serverTimestamp(),
      });
      // Debug print removed
      return true;
    } catch (e) {
      // Debug print removed
      return false;
    }
  }

  /// Update member role and permissions
  Future<bool> updateMemberRole({
    required String storeId,
    required String memberId,
    required UserRole newRole,
    List<String>? customPermissions,
  }) async {
    try {
      await _getMembersCollection(storeId).doc(memberId).update({
        'role': newRole.toString().split('.').last,
        'permissions':
            customPermissions ?? InvitationModel.getDefaultPermissions(newRole),
        'lastActivity': FieldValue.serverTimestamp(),
      });
      // Debug print removed
      return true;
    } catch (e) {
      // Debug print removed
      return false;
    }
  }

  /// Update member last activity
  Future<void> updateLastActivity({
    required String storeId,
    required String memberId,
  }) async {
    try {
      await _getMembersCollection(storeId).doc(memberId).update({
        'lastActivity': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      // Debug print removed
    }
  }

  /// Create owner membership when store is created
  Future<String?> createOwnerMembership({
    required String storeId,
    required String userId,
    required String email,
  }) async {
    try {
      final ownerInvitation = InvitationModel(
        userId: userId,
        email: email,
        storeId: storeId,
        role: UserRole.owner,
        permissions: InvitationModel.getDefaultPermissions(UserRole.owner),
        status: InvitationStatus.owner,
        invitedAt: DateTime.now(),
        joinedAt: DateTime.now(),
        lastActivity: DateTime.now(),
      );

      final docRef = await _getMembersCollection(storeId)
          .add(ownerInvitation.toFirestore());
      // Debug print removed
      return docRef.id;
    } catch (e) {
      // Debug print removed
      return null;
    }
  }

  /// Check if user is member of store
  Future<InvitationModel?> getUserMembership({
    required String storeId,
    required String userId,
  }) async {
    try {
      final querySnapshot = await _getMembersCollection(storeId)
          .where('userId', isEqualTo: userId)
          .where('isActive', isEqualTo: true)
          .get();

      if (querySnapshot.docs.isNotEmpty) {
        return InvitationModel.fromFirestore(querySnapshot.docs.first);
      }
      return null;
    } catch (e) {
      // Debug print removed
      return null;
    }
  }

  /// Get all stores where user is member
  Stream<List<InvitationModel>> getUserStoresStream(String userId) {
    return _firestore
        .collectionGroup('members')
        .where('userId', isEqualTo: userId)
        .where('isActive', isEqualTo: true)
        .where('status', whereIn: [
          InvitationStatus.owner.toString().split('.').last,
          InvitationStatus.accepted.toString().split('.').last,
        ])
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => InvitationModel.fromFirestore(doc))
            .toList());
  }

  /// Get member count for store
  Future<int> getMemberCount(String storeId) async {
    try {
      final snapshot = await _getMembersCollection(storeId)
          .where('isActive', isEqualTo: true)
          .where('status', whereIn: [
        InvitationStatus.owner.toString().split('.').last,
        InvitationStatus.accepted.toString().split('.').last,
      ]).get();
      return snapshot.docs.length;
    } catch (e) {
      // Debug print removed
      return 0;
    }
  }

  /// Check if email has pending accepted invitation
  Future<InvitationModel?> checkAcceptedInvitation(String email) async {
    try {
      // Debug print removed

      // Query all store_invitations collection for this email with accepted status
      final querySnapshot = await _firestore
          .collection('store_invitations')
          .where('email', isEqualTo: email.toLowerCase())
          .where('status',
              isEqualTo: InvitationStatus.accepted.toString().split('.').last)
          .limit(1)
          .get();

      if (querySnapshot.docs.isNotEmpty) {
        final doc = querySnapshot.docs.first;
        final data = doc.data();
        // Debug print removed

        // Get store name from stores collection
        String? storeName;
        try {
          final storeDoc =
              await _firestore.collection('stores').doc(data['storeId']).get();
          storeName = storeDoc.data()?['name'];
        } catch (e) {
          // Debug print removed
          storeName = 'Bilinmeyen Mağaza';
        }

        return InvitationModel(
          id: doc.id,
          userId: data['userId'] ?? '',
          email: data['email'],
          storeId: data['storeId'],
          storeName: storeName,
          role: UserRole.values.firstWhere(
            (role) => role.toString().split('.').last == data['role'],
            orElse: () => UserRole.staff,
          ),
          permissions: List<String>.from(data['permissions'] ?? []),
          status: InvitationStatus.accepted,
          invitedAt: (data['invitedAt'] as Timestamp).toDate(),
          invitedBy: data['invitedBy'],
          respondedAt: data['respondedAt'] != null
              ? (data['respondedAt'] as Timestamp).toDate()
              : null,
        );
      }

      // Debug print removed
      return null;
    } catch (e) {
      // Debug print removed
      return null;
    }
  }

  /// Cancel pending invitation
  Future<bool> cancelInvitation({
    required String storeId,
    required String invitationId,
  }) async {
    try {
      await _getMembersCollection(storeId).doc(invitationId).delete();
      // Debug print removed
      return true;
    } catch (e) {
      // Debug print removed
      return false;
    }
  }
}




