import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../models/user_mode.dart';
import '../models/auth_result.dart';

class FirebaseAuthService {
  static const String _collectionUsers = 'users';
  static const String _collectionStores = 'stores';
  static const String _collectionStoreMembers = 'store_members';
  static const String _collectionAdminControls = 'admin_controls';

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Singleton pattern
  static FirebaseAuthService? _instance;
  static FirebaseAuthService get instance =>
      _instance ??= FirebaseAuthService._();
  FirebaseAuthService._();

  // Current user stream
  Stream<User?> get authStateChanges => _auth.authStateChanges();
  User? get currentUser => _auth.currentUser;

  /// Register new user with Firebase Auth + Firestore
  Future<AuthResult> registerWithEmailPassword({
    required String name,
    required String email,
    required String password,
    required String storeName,
    UserMode mode = UserMode.basic,
  }) async {
    try {
      // Check if user is banned
      final isBanned = await _checkUserBanned(email);
      if (isBanned) {
        return AuthResult.failure('Bu hesap yasaklanmış durumda');
      }

      // Create Firebase Auth account
      final UserCredential result = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      final User? user = result.user;
      if (user == null) {
        return AuthResult.failure('Hesap oluşturulamadı');
      }

      // Update display name
      await user.updateDisplayName(name);

      // Create store in Firestore
      final storeData = {
        'name': storeName,
        'ownerId': user.uid,
        'ownerEmail': email,
        'ownerName': name,
        'createdAt': FieldValue.serverTimestamp(),
        'isActive': true,
        'settings': {
          'currency': 'TRY',
          'timezone': 'Europe/Istanbul',
          'language': 'tr',
        },
        'subscriptionStatus': 'trial', // trial, active, expired
        'subscriptionPlan': mode.toString(),
      };

      final storeRef =
          await _firestore.collection(_collectionStores).add(storeData);
      final storeId = storeRef.id;

      // Create user document
      final userData = {
        'uid': user.uid,
        'email': email,
        'name': name,
        'storeId': storeId,
        'storeName': storeName,
        'mode': mode.toString(),
        'role': 'owner',
        'createdAt': FieldValue.serverTimestamp(),
        'lastLoginAt': FieldValue.serverTimestamp(),
        'isActive': true,
        'permissions': _getPermissionsByMode(mode),
      };

      await _firestore.collection(_collectionUsers).doc(user.uid).set(userData);

      // Add user as store owner in store_members collection
      await _firestore
          .collection(_collectionStoreMembers)
          .doc(storeId)
          .collection('members')
          .doc(user.uid)
          .set({
        'userId': user.uid,
        'email': email,
        'name': name,
        'role': 'owner',
        'permissions': _getPermissionsByMode(mode),
        'joinedAt': FieldValue.serverTimestamp(),
        'invitedBy': null, // Owner is not invited
        'isActive': true,
      });

      return AuthResult.success(
        message: 'Hesabınız başarıyla oluşturuldu',
        userId: user.uid,
        data: {
          'storeId': storeId,
          'storeName': storeName,
          'userMode': mode.toString(),
        },
      );
    } on FirebaseAuthException catch (e) {
      return AuthResult.failure(_getAuthErrorMessage(e.code));
    } catch (e) {
      // Debug print removed
      return AuthResult.failure('Kayıt sırasında bir hata oluştu');
    }
  }

  /// Login with Firebase Auth
  Future<AuthResult> signInWithEmailPassword({
    required String email,
    required String password,
  }) async {
    try {
      // Check if user is banned
      final isBanned = await _checkUserBanned(email);
      if (isBanned) {
        return AuthResult.failure('Bu hesap yasaklanmış durumda');
      }

      final UserCredential result = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      final User? user = result.user;
      if (user == null) {
        return AuthResult.failure('Giriş yapılamadı');
      }

      // Update last login time (use set with merge to create document if it doesn't exist)
      await _firestore.collection(_collectionUsers).doc(user.uid).set({
        'lastLoginAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      // Get user data
      final userDoc =
          await _firestore.collection(_collectionUsers).doc(user.uid).get();
      if (!userDoc.exists) {
        // Create basic user document if it doesn't exist
        final basicUserData = {
          'uid': user.uid,
          'email': user.email ?? '',
          'name': user.displayName ?? '',
          'createdAt': FieldValue.serverTimestamp(),
          'lastLoginAt': FieldValue.serverTimestamp(),
          'isActive': true,
          'role': 'user',
        };
        await _firestore
            .collection(_collectionUsers)
            .doc(user.uid)
            .set(basicUserData);

        return AuthResult.success(
          message: 'Giriş başarılı - Profil güncellendi',
          userId: user.uid,
          data: basicUserData,
        );
      }

      final userData = userDoc.data()!;

      // Check if user has store information
      if (userData['storeId'] == null ||
          userData['storeId'].toString().isEmpty) {
        // User doesn't have a store - return success with limited data
        return AuthResult.success(
          message: 'Giriş başarılı - Mağaza bilgisi eksik',
          userId: user.uid,
          data: {
            'storeId': null,
            'storeName': null,
            'userMode': 'basic',
            'role': userData['role'] ?? 'user',
            'needsStoreSetup': true,
          },
        );
      }

      // Check if store is active
      final storeDoc = await _firestore
          .collection(_collectionStores)
          .doc(userData['storeId'])
          .get();
      if (!storeDoc.exists || !(storeDoc.data()?['isActive'] ?? false)) {
        return AuthResult.failure('Mağaza hesabı askıya alınmış');
      }

      return AuthResult.success(
        message: 'Giriş başarılı',
        userId: user.uid,
        data: {
          'storeId': userData['storeId'],
          'storeName': userData['storeName'],
          'userMode': userData['mode'],
          'role': userData['role'],
        },
      );
    } on FirebaseAuthException catch (e) {
      return AuthResult.failure(_getAuthErrorMessage(e.code));
    } catch (e) {
      // Debug print removed
      return AuthResult.failure('Giriş sırasında bir hata oluştu');
    }
  }

  /// Send password reset email
  Future<AuthResult> sendPasswordResetEmail({required String email}) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
      return AuthResult.success(
        message: 'Şifre sıfırlama bağlantısı e-posta adresinize gönderildi',
      );
    } on FirebaseAuthException catch (e) {
      return AuthResult.failure(_getAuthErrorMessage(e.code));
    } catch (e) {
      return AuthResult.failure('Şifre sıfırlama sırasında bir hata oluştu');
    }
  }

  /// Sign out
  Future<AuthResult> signOut() async {
    try {
      await _auth.signOut();
      return AuthResult.success(message: 'Çıkış yapıldı');
    } catch (e) {
      return AuthResult.failure('Çıkış sırasında bir hata oluştu');
    }
  }

  /// Get current user data from Firestore
  Future<Map<String, dynamic>?> getCurrentUserData() async {
    final user = currentUser;
    if (user == null) return null;

    try {
      final doc =
          await _firestore.collection(_collectionUsers).doc(user.uid).get();
      return doc.exists ? doc.data() : null;
    } catch (e) {
      // Debug print removed
      return null;
    }
  }

  /// Check if user is banned
  Future<bool> _checkUserBanned(String email) async {
    try {
      final adminDoc = await _firestore
          .collection(_collectionAdminControls)
          .doc('banned_users')
          .get();
      if (!adminDoc.exists) return false;

      final bannedUsers = List<String>.from(adminDoc.data()?['emails'] ?? []);
      return bannedUsers.contains(email.toLowerCase());
    } catch (e) {
      // Debug print removed
      return false;
    }
  }

  /// Get permissions by user mode
  List<String> _getPermissionsByMode(UserMode mode) {
    switch (mode) {
      case UserMode.guest:
        return ['read_inventory'];
      case UserMode.basic:
        return [
          'read_inventory',
          'write_inventory',
          'read_sales',
          'write_sales'
        ];
      case UserMode.pro:
        return [
          'read_inventory',
          'write_inventory',
          'read_sales',
          'write_sales',
          'manage_users',
          'advanced_reports',
          'export_data'
        ];
      case UserMode.proPlus:
        return [
          'read_inventory',
          'write_inventory',
          'read_sales',
          'write_sales',
          'manage_users',
          'advanced_reports',
          'export_data',
          'ai_analytics',
          'api_integrations',
          'full_access'
        ];
    }
  }

  /// Register invited user - join existing store
  Future<AuthResult> registerInvitedUser({
    required String name,
    required String email,
    required String password,
    required String storeId,
    required String role,
    required List<String> permissions,
    required String invitedBy,
  }) async {
    try {
      // Debug print removed

      // Check if user is banned
      final isBanned = await _checkUserBanned(email);
      if (isBanned) {
        return AuthResult.failure('Bu hesap yasaklanmış durumda');
      }

      // Create Firebase Auth account
      final UserCredential result = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      final User? user = result.user;
      if (user == null) {
        return AuthResult.failure('Hesap oluşturulamadı');
      }

      // Update display name
      await user.updateDisplayName(name);

      // Get store name from existing store
      final storeDoc =
          await _firestore.collection(_collectionStores).doc(storeId).get();
      if (!storeDoc.exists) {
        return AuthResult.failure('Mağaza bulunamadı');
      }

      final storeName = storeDoc.data()?['name'] ?? 'Bilinmeyen Mağaza';

      // Create user document - invited user
      final userData = {
        'uid': user.uid,
        'email': email,
        'name': name,
        'storeId': storeId,
        'storeName': storeName,
        'mode': UserMode.basic.toString(),
        'role': role,
        'createdAt': FieldValue.serverTimestamp(),
        'lastLoginAt': FieldValue.serverTimestamp(),
        'isActive': true,
        'permissions': permissions,
        'invitedBy': invitedBy,
      };

      await _firestore.collection(_collectionUsers).doc(user.uid).set(userData);

      // Add user to store members collection
      await _firestore
          .collection(_collectionStoreMembers)
          .doc(storeId)
          .collection('members')
          .doc(user.uid)
          .set({
        'userId': user.uid,
        'email': email,
        'name': name,
        'role': role,
        'permissions': permissions,
        'joinedAt': FieldValue.serverTimestamp(),
        'invitedBy': invitedBy,
        'isActive': true,
        'status': 'accepted',
      });

      // Update the invitation status to completed
      final invitationQuery = await _firestore
          .collection('store_invitations')
          .where('email', isEqualTo: email.toLowerCase())
          .where('storeId', isEqualTo: storeId)
          .where('status', isEqualTo: 'accepted')
          .limit(1)
          .get();

      if (invitationQuery.docs.isNotEmpty) {
        await invitationQuery.docs.first.reference.update({
          'userId': user.uid,
          'status': 'completed',
          'respondedAt': FieldValue.serverTimestamp(),
        });
      }

      // Debug print removed

      return AuthResult.success(
        message: 'Mağaza takımına başarıyla katıldınız',
        userId: user.uid,
        data: {
          'storeId': storeId,
          'storeName': storeName,
          'userMode': UserMode.basic.toString(),
          'role': role,
          'isInvitedUser': true,
        },
      );
    } on FirebaseAuthException catch (e) {
      // Debug print removed
      return AuthResult.failure(_getAuthErrorMessage(e.code));
    } catch (e) {
      // Debug print removed
      return AuthResult.failure('Kayıt sırasında bir hata oluştu: $e');
    }
  }

  /// Get Firebase Auth error message in Turkish
  String _getAuthErrorMessage(String errorCode) {
    switch (errorCode) {
      case 'user-not-found':
        return 'Bu e-posta adresine sahip kullanıcı bulunamadı';
      case 'wrong-password':
        return 'Hatalı şifre';
      case 'email-already-in-use':
        return 'Bu e-posta adresi zaten kullanılıyor';
      case 'invalid-email':
        return 'Geçersiz e-posta adresi';
      case 'weak-password':
        return 'Şifre çok zayıf (en az 6 karakter olmalı)';
      case 'user-disabled':
        return 'Bu kullanıcı hesabı devre dışı bırakılmış';
      case 'too-many-requests':
        return 'Çok fazla deneme yapıldı, lütfen daha sonra tekrar deneyin';
      case 'operation-not-allowed':
        return 'Bu işlem şu anda izin verilmiyor';
      case 'network-request-failed':
        return 'Ağ bağlantısı hatası';
      default:
        return 'Bir hata oluştu: $errorCode';
    }
  }
}




