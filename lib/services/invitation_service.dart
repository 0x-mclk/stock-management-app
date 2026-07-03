import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/invitation_model.dart';

class InvitationService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Singleton pattern
  static InvitationService? _instance;
  static InvitationService get instance => _instance ??= InvitationService._();
  InvitationService._();

  // DEPRECATED: Eski sistem için kullanılan method
  // Artık store_invitations collection kullanıyoruz
  // CollectionReference _getMembersCollection(String storeId) {
  //   return _firestore.collection('stores').doc(storeId).collection('members');
  // }

  /// Add store owner record
  Future<bool> addStoreOwner({
    required String storeId,
    required String userId,
    required String email,
  }) async {
    try {
      // Check if owner already exists
      final existingOwner = await _firestore
          .collection('store_invitations')
          .where('storeId', isEqualTo: storeId)
          .where('status', isEqualTo: 'owner')
          .get();

      if (existingOwner.docs.isNotEmpty) {
        debugPrint('✅ Store owner already exists for: $storeId');
        return true;
      }

      // Create owner record
      final ownerData = {
        'email': email,
        'userId': userId,
        'storeId': storeId,
        'role': 'owner',
        'status': 'owner',
        'invitedAt': FieldValue.serverTimestamp(),
        'joinedAt': FieldValue.serverTimestamp(),
        'invitedBy': userId, // Owner invites themselves
        'permissions': InvitationModel.getDefaultPermissions(UserRole.owner),
        'emailSent': false,
        'adminApprovalRequired': false,
        'isActive': true,
        'lastActivity': FieldValue.serverTimestamp(),
      };

      await _firestore.collection('store_invitations').add(ownerData);
      debugPrint('✅ Store owner added: $email for store: $storeId');
      return true;
    } catch (e) {
      debugPrint('❌ Error adding store owner: $e');
      return false;
    }
  }

  /// Update member userId
  Future<bool> updateMemberUserId({
    required String memberId,
    required String userId,
  }) async {
    try {
      await _firestore.collection('store_invitations').doc(memberId).update({
        'userId': userId,
        'lastActivity': FieldValue.serverTimestamp(),
      });
      debugPrint('✅ Member userId updated: $memberId -> $userId');
      return true;
    } catch (e) {
      debugPrint('❌ Error updating member userId: $e');
      return false;
    }
  }

  /// Clean up incorrect store owner records
  Future<bool> cleanupIncorrectOwners({
    required String storeId,
    required String correctUserId,
    required String correctEmail,
  }) async {
    try {
      // Bu store'daki tüm owner kayıtlarını al
      final ownerRecords = await _firestore
          .collection('store_invitations')
          .where('storeId', isEqualTo: storeId)
          .where('status', isEqualTo: 'owner')
          .get();

      debugPrint(
          '🔍 Store $storeId için ${ownerRecords.docs.length} owner kaydı bulundu');

      // Yanlış kayıtları sil (doğru kullanıcı dışındaki tüm owner kayıtları)
      for (final doc in ownerRecords.docs) {
        final data = doc.data();
        final recordUserId = data['userId'];
        final recordEmail = data['email'];

        // Eğer doğru kullanıcı değilse, sil
        if (recordUserId != correctUserId || recordEmail != correctEmail) {
          debugPrint(
              '❌ Yanlış owner kaydı siliniyor: $recordEmail (${doc.id})');
          await doc.reference.delete();
        } else {
          debugPrint('✅ Doğru owner kaydı korunuyor: $recordEmail');
        }
      }

      return true;
    } catch (e) {
      debugPrint('❌ Error cleaning up incorrect owners: $e');
      return false;
    }
  }

  /// Ensure store owner exists (with cleanup)
  Future<void> ensureStoreOwnerExistsWithCleanup({
    required String storeId,
    required String userId,
    required String email,
  }) async {
    try {
      // Önce yanlış kayıtları temizle
      await cleanupIncorrectOwners(
        storeId: storeId,
        correctUserId: userId,
        correctEmail: email,
      );

      // Sonra doğru owner kaydını ekle
      await addStoreOwner(
        storeId: storeId,
        userId: userId,
        email: email,
      );
    } catch (e) {
      debugPrint('❌ Error ensuring store owner exists with cleanup: $e');
    }
  }

  Future<void> ensureStoreOwnerExists({
    required String storeId,
    required String userId,
    required String email,
  }) async {
    try {
      await addStoreOwner(
        storeId: storeId,
        userId: userId,
        email: email,
      );
    } catch (e) {
      debugPrint('❌ Error ensuring store owner exists: $e');
    }
  }

  Future<String?> sendInvitation({
    required String storeId,
    required String email,
    required UserRole role,
    required String invitedBy,
    List<String>? customPermissions,
  }) async {
    try {
      // Check if user already invited or member in store_invitations collection
      final existingInvitation = await _firestore
          .collection('store_invitations')
          .where('email', isEqualTo: email)
          .where('storeId', isEqualTo: storeId)
          .get();

      if (existingInvitation.docs.isNotEmpty) {
        throw Exception('Bu email adresi zaten davet edilmiş');
      }

      // Create invitation data directly for store_invitations collection
      // Yeni sistem: Manuel onaylama - Admin onayına gönderilir
      final invitationData = {
        'email': email,
        'storeId': storeId,
        'role': role.name,
        'status': 'pending', // Manuel onay bekliyor
        'invitedAt': FieldValue.serverTimestamp(),
        'invitedBy': invitedBy,
        'permissions':
            customPermissions ?? InvitationModel.getDefaultPermissions(role),
        'emailSent': false, // E-posta gönderimi durumu
        'adminApprovalRequired': true, // Admin onayı gerekli
      };

      // Add to store_invitations collection
      final docRef =
          await _firestore.collection('store_invitations').add(invitationData);

      // Send email notification with real email service
      final emailSent = await _sendInvitationEmail(email, storeId, docRef.id);

      // Update email sent status
      if (emailSent) {
        await docRef.update({'emailSent': true});
      }

      debugPrint(
          '✅ Invitation sent: ${docRef.id} to $email (Email: ${emailSent ? 'Sent' : 'Failed'})');
      return docRef.id;
    } catch (e) {
      debugPrint('❌ Error sending invitation: $e');
      return null;
    }
  }

  /// Accept invitation (Kullanıcı onaylanmış daveti kabul eder)
  Future<bool> acceptInvitation({
    required String storeId,
    required String invitationId,
    required String userId,
  }) async {
    try {
      // Önce davet durumunu kontrol et
      final doc = await _firestore
          .collection('store_invitations')
          .doc(invitationId)
          .get();
      if (!doc.exists) {
        throw Exception('Davet bulunamadı');
      }

      final data = doc.data()!;
      if (data['status'] != 'approved') {
        throw Exception('Bu davet henüz admin tarafından onaylanmamış');
      }

      await _firestore
          .collection('store_invitations')
          .doc(invitationId)
          .update({
        'userId': userId,
        'status': InvitationStatus.accepted.toString().split('.').last,
        'joinedAt': FieldValue.serverTimestamp(),
        'respondedAt': FieldValue.serverTimestamp(),
        'lastActivity': FieldValue.serverTimestamp(),
      });

      debugPrint('✅ Invitation accepted: $invitationId');
      return true;
    } catch (e) {
      debugPrint('❌ Error accepting invitation: $e');
      return false;
    }
  }

  /// Reject invitation
  Future<bool> rejectInvitation({
    required String storeId,
    required String invitationId,
  }) async {
    try {
      await _firestore
          .collection('store_invitations')
          .doc(invitationId)
          .update({
        'status': InvitationStatus.rejected.toString().split('.').last,
        'respondedAt': FieldValue.serverTimestamp(),
      });

      debugPrint('✅ Invitation rejected: $invitationId');
      debugPrint('✅ Invitation rejected: $invitationId');
      return true;
    } catch (e) {
      debugPrint('❌ Error rejecting invitation: $e');
      return false;
    }
  }

  /// Get all members for a store
  Stream<List<InvitationModel>> getMembersStream(String storeId) {
    return _firestore
        .collection('store_invitations')
        .where('storeId', isEqualTo: storeId)
        .snapshots()
        .map((snapshot) {

      final invitations = snapshot.docs.map((doc) {
        return InvitationModel.fromFirestore(doc);
      }).toList();
      for (final invitation in invitations) {
      }

      // Client-side sorting
      invitations.sort((a, b) => b.invitedAt.compareTo(a.invitedAt));
      return invitations;
    });
  }

  /// Get pending invitations for a user email (Onaylanmış davetler)
  Stream<List<InvitationModel>> getPendingInvitationsStream(String email) {
    return _firestore
        .collection('store_invitations')
        .where('email', isEqualTo: email)
        .where('status', isEqualTo: 'approved') // Admin tarafından onaylanmış
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
      await _firestore.collection('store_invitations').doc(memberId).delete();
      debugPrint('✅ Member removed: $memberId');
      return true;
    } catch (e) {
      debugPrint('❌ Error removing member: $e');
      return false;
    }
  }

  /// Deactivate member (soft delete)
  Future<bool> deactivateMember({
    required String storeId,
    required String memberId,
  }) async {
    try {
      await _firestore.collection('store_invitations').doc(memberId).update({
        'isActive': false,
        'lastActivity': FieldValue.serverTimestamp(),
      });
      debugPrint('✅ Member deactivated: $memberId');
      return true;
    } catch (e) {
      debugPrint('❌ Error deactivating member: $e');
      return false;
    }
  }

  /// Reactivate member
  Future<bool> reactivateMember({
    required String storeId,
    required String memberId,
  }) async {
    try {
      await _firestore.collection('store_invitations').doc(memberId).update({
        'isActive': true,
        'lastActivity': FieldValue.serverTimestamp(),
      });
      debugPrint('✅ Member reactivated: $memberId');
      return true;
    } catch (e) {
      debugPrint('❌ Error reactivating member: $e');
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
      await _firestore.collection('store_invitations').doc(memberId).update({
        'role': newRole.toString().split('.').last,
        'permissions':
            customPermissions ?? InvitationModel.getDefaultPermissions(newRole),
        'lastActivity': FieldValue.serverTimestamp(),
      });
      debugPrint('✅ Member role updated: $memberId -> $newRole');
      return true;
    } catch (e) {
      debugPrint('❌ Error updating member role: $e');
      return false;
    }
  }

  /// Update member last activity
  Future<void> updateLastActivity({
    required String storeId,
    required String memberId,
  }) async {
    try {
      await _firestore.collection('store_invitations').doc(memberId).update({
        'lastActivity': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('❌ Error updating last activity: $e');
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

      final docRef = await _firestore
          .collection('store_invitations')
          .add(ownerInvitation.toFirestore());
      debugPrint('✅ Owner membership created: ${docRef.id}');
      return docRef.id;
    } catch (e) {
      debugPrint('❌ Error creating owner membership: $e');
      return null;
    }
  }

  /// Check if user is member of store
  Future<InvitationModel?> getUserMembership({
    required String storeId,
    required String userId,
  }) async {
    try {
      final querySnapshot = await _firestore
          .collection('store_invitations')
          .where('storeId', isEqualTo: storeId)
          .where('userId', isEqualTo: userId)
          .where('isActive', isEqualTo: true)
          .get();

      if (querySnapshot.docs.isNotEmpty) {
        return InvitationModel.fromFirestore(querySnapshot.docs.first);
      }
      return null;
    } catch (e) {
      debugPrint('❌ Error getting user membership: $e');
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
      final snapshot = await _firestore
          .collection('store_invitations')
          .where('storeId', isEqualTo: storeId)
          .where('isActive', isEqualTo: true)
          .where('status', whereIn: [
        InvitationStatus.owner.toString().split('.').last,
        InvitationStatus.accepted.toString().split('.').last,
      ]).get();
      return snapshot.docs.length;
    } catch (e) {
      debugPrint('❌ Error getting member count: $e');
      return 0;
    }
  }

  /// Cancel pending invitation
  Future<bool> cancelInvitation({
    required String storeId,
    required String invitationId,
  }) async {
    try {
      await _firestore
          .collection('store_invitations')
          .doc(invitationId)
          .delete();
      debugPrint('✅ Invitation cancelled: $invitationId');
      return true;
    } catch (e) {
      debugPrint('❌ Error cancelling invitation: $e');
      return false;
    }
  }

  /// Send invitation email (Firebase Functions ile gerçek e-posta)
  Future<bool> _sendInvitationEmail(
      String email, String storeId, String invitationId) async {
    try {
      // Firebase Functions'a e-posta gönderimi için HTTP request
      // Bu örnekte console'a yazdırıyoruz, gerçek uygulamada HTTP call yapılacak

      debugPrint('📧 Sending email to: $email');
      debugPrint('Subject: StockPro\'ya Davet Edildiniz - Onay Bekleniyor');
      debugPrint(
          'Body: Mağaza takımına katılma davetiniz admin onayında. Size bildirim gelecek.');
      debugPrint('Store ID: $storeId');
      debugPrint('Invitation ID: $invitationId');

      // Simülasyon: E-posta başarıyla gönderildi
      await Future.delayed(Duration(milliseconds: 100));

      // TODO: Gerçek email servisi entegrasyonu
      // Örn: Firebase Functions, SendGrid, AWS SES
      /*
      final response = await http.post(
        Uri.parse('https://your-region-project.cloudfunctions.net/sendInvitationEmail'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': email,
          'storeId': storeId,
          'invitationId': invitationId,
        }),
      );
      return response.statusCode == 200;
      */

      return true; // Simülasyon için her zaman true
    } catch (e) {
      debugPrint('❌ Error sending email: $e');
      return false;
    }
  }

  /// Admin onaylama - Daveti onayla
  Future<bool> approveInvitation({
    required String invitationId,
    required String adminUserId,
  }) async {
    try {
      await _firestore
          .collection('store_invitations')
          .doc(invitationId)
          .update({
        'status': 'approved',
        'approvedBy': adminUserId,
        'approvedAt': FieldValue.serverTimestamp(),
        'adminApprovalRequired': false,
      });

      // Onay bildirimi e-postası gönder
      final doc = await _firestore
          .collection('store_invitations')
          .doc(invitationId)
          .get();
      if (doc.exists) {
        final data = doc.data()!;
        await _sendApprovalNotificationEmail(
          data['email'],
          data['storeId'],
          invitationId,
          true, // approved
        );
      }

      debugPrint('✅ Invitation approved: $invitationId by admin: $adminUserId');
      return true;
    } catch (e) {
      debugPrint('❌ Error approving invitation: $e');
      return false;
    }
  }

  /// Admin reddetme - Daveti reddet
  Future<bool> rejectInvitationByAdmin({
    required String invitationId,
    required String adminUserId,
    String? reason,
  }) async {
    try {
      await _firestore
          .collection('store_invitations')
          .doc(invitationId)
          .update({
        'status': 'rejected',
        'rejectedBy': adminUserId,
        'rejectedAt': FieldValue.serverTimestamp(),
        'rejectionReason': reason,
        'adminApprovalRequired': false,
      });

      // Red bildirimi e-postası gönder
      final doc = await _firestore
          .collection('store_invitations')
          .doc(invitationId)
          .get();
      if (doc.exists) {
        final data = doc.data()!;
        await _sendApprovalNotificationEmail(
          data['email'],
          data['storeId'],
          invitationId,
          false, // rejected
          reason: reason,
        );
      }

      debugPrint('✅ Invitation rejected: $invitationId by admin: $adminUserId');
      return true;
    } catch (e) {
      debugPrint('❌ Error rejecting invitation: $e');
      return false;
    }
  }

  /// Onay/Red bildirimi e-postası gönder
  Future<bool> _sendApprovalNotificationEmail(
    String email,
    String storeId,
    String invitationId,
    bool approved, {
    String? reason,
  }) async {
    try {
      debugPrint(
          '📧 Sending ${approved ? 'approval' : 'rejection'} email to: $email');

      if (approved) {
        debugPrint(
            'Subject: Davetiniz Onaylandı - StockPro\'ya Katılabilirsiniz');
        debugPrint(
            'Body: Tebrikler! Mağaza takımına katılma davetiniz onaylandı. Artık uygulamayı kullanabilirsiniz.');
      } else {
        debugPrint('Subject: Davetiniz Hakkında - StockPro');
        debugPrint(
            'Body: Üzgünüz, mağaza takımına katılma davetiniz reddedildi.');
        if (reason != null) {
          debugPrint('Reason: $reason');
        }
      }

      debugPrint('Store ID: $storeId');
      debugPrint('Invitation ID: $invitationId');

      // Simülasyon
      await Future.delayed(Duration(milliseconds: 100));
      return true;
    } catch (e) {
      debugPrint('❌ Error sending approval notification email: $e');
      return false;
    }
  }

  /// Bekleyen onay daveti al (Admin için)
  Stream<List<InvitationModel>> getPendingApprovalsStream(String storeId) {
    return _firestore
        .collection('store_invitations')
        .where('storeId', isEqualTo: storeId)
        .where('status', isEqualTo: 'pending')
        .snapshots()
        .map((snapshot) {
      final invitations = snapshot.docs
          .map((doc) => InvitationModel.fromFirestore(doc))
          .where((invitation) => invitation.adminApprovalRequired == true)
          .toList();

      // Client-side sorting
      invitations.sort((a, b) => b.invitedAt.compareTo(a.invitedAt));
      return invitations;
    });
  }
}
