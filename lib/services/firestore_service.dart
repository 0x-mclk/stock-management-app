import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';

class FirestoreService {
  static const String _collectionUsers = 'users';
  static const String _collectionStores = 'stores';
  static const String _collectionProducts = 'products';
  static const String _collectionAdminControls = 'admin_controls';

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Singleton pattern
  static FirestoreService? _instance;
  static FirestoreService get instance => _instance ??= FirestoreService._();
  FirestoreService._();

  /// Add or update product with retry mechanism
  Future<bool> saveProduct(String storeId, String? productId,
      Map<String, dynamic> productData) async {
    // ✅ StoreId validation
    if (storeId.isEmpty) {
      print('❌ SAVEPRODUCT FAILED: StoreId is empty!');
      return false;
    }

    // 🔄 RETRY MECHANISM - 3 attempts with exponential backoff
    for (int attempt = 1; attempt <= 3; attempt++) {
      try {
        productData['lastModified'] = FieldValue.serverTimestamp();
        productData['storeId'] = storeId; // ✅ Store ID'yi garantile

        if (productId == null) {
          // 🆕 Add new product - Firebase generates ID
          print('🔄 Attempt $attempt: Adding new product to Firebase...');
          final docRef = await _firestore
              .collection(_collectionStores)
              .doc(storeId)
              .collection(_collectionProducts)
              .add(productData);

          print('✅ New product added with Firebase ID: ${docRef.id}');
          return true; // Success - exit retry loop
        } else {
          // 🔄 Update existing product
          print('🔄 Attempt $attempt: Updating existing product: $productId');
          await _firestore
              .collection(_collectionStores)
              .doc(storeId)
              .collection(_collectionProducts)
              .doc(productId)
              .update(productData);

          print('✅ Product updated successfully: $productId');
          return true; // Success - exit retry loop
        }
      } catch (e) {
        print('❌ Firebase saveProduct error (attempt $attempt): $e');

        if (attempt == 3) {
          // Son deneme de başarısız
          print('💀 All retry attempts failed for saveProduct');
          return false;
        }

        // Exponential backoff - wait before retry
        final waitTime = Duration(milliseconds: 500 * attempt);
        print('⏳ Waiting ${waitTime.inMilliseconds}ms before retry...');
        await Future.delayed(waitTime);
      }
    }

    return false; // This shouldn't be reached
  }

  /// Delete product with retry mechanism
  Future<bool> deleteProduct(String storeId, String productId) async {
    // 🔄 RETRY MECHANISM - 3 attempts with exponential backoff
    for (int attempt = 1; attempt <= 3; attempt++) {
      try {
        print(
            '🔄 Attempt $attempt: Deleting product from Firebase: $productId in store: $storeId');

        await _firestore
            .collection(_collectionStores)
            .doc(storeId)
            .collection(_collectionProducts)
            .doc(productId)
            .delete();

        print('✅ Product deleted successfully from Firebase: $productId');
        return true; // Success - exit retry loop
      } catch (e) {
        print('❌ Firebase deleteProduct error (attempt $attempt): $e');

        if (attempt == 3) {
          // Son deneme de başarısız
          print('💀 All retry attempts failed for deleteProduct');
          return false;
        }

        // Exponential backoff - wait before retry
        final waitTime = Duration(milliseconds: 500 * attempt);
        print('⏳ Waiting ${waitTime.inMilliseconds}ms before retry...');
        await Future.delayed(waitTime);
      }
    }

    return false; // This shouldn't be reached
  }

  /// Get sales stream for a store
  Stream<QuerySnapshot> getSalesStream(String storeId,
      {DateTime? startDate, DateTime? endDate}) {
    Query query = _firestore
        .collection(_collectionStores)
        .doc(storeId)
        .collection('sales')
        .orderBy('saleDate', descending: true);

    if (startDate != null) {
      query = query.where('saleDate',
          isGreaterThanOrEqualTo: Timestamp.fromDate(startDate));
    }
    if (endDate != null) {
      query = query.where('saleDate',
          isLessThanOrEqualTo: Timestamp.fromDate(endDate));
    }

    return query.snapshots();
  }

  /// Add sale transaction
  Future<bool> addSale(String storeId, Map<String, dynamic> saleData) async {
    try {
      saleData['saleDate'] = FieldValue.serverTimestamp();

      await _firestore
          .collection(_collectionStores)
          .doc(storeId)
          .collection('sales')
          .add(saleData);
      return true;
    } catch (e) {
      // Debug print removed
      return false;
    }
  }

  /// Admin: Get all stores
  Stream<QuerySnapshot> getAllStoresStream() {
    return _firestore
        .collection(_collectionStores)
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  /// Admin: Ban/unban store
  Future<bool> toggleStoreBan(String storeId, bool isBanned) async {
    try {
      await _firestore.collection(_collectionStores).doc(storeId).update({
        'isActive': !isBanned,
        'bannedAt':
            isBanned ? FieldValue.serverTimestamp() : FieldValue.delete(),
      });
      return true;
    } catch (e) {
      // Debug print removed
      return false;
    }
  }

  /// Admin: Ban/unban user
  Future<bool> toggleUserBan(String userEmail, bool isBanned) async {
    try {
      final adminDoc =
          _firestore.collection(_collectionAdminControls).doc('banned_users');

      if (isBanned) {
        await adminDoc.update({
          'emails': FieldValue.arrayUnion([userEmail.toLowerCase()]),
        });
      } else {
        await adminDoc.update({
          'emails': FieldValue.arrayRemove([userEmail.toLowerCase()]),
        });
      }
      return true;
    } catch (e) {
      // Debug print removed
      return false;
    }
  }

  /// Get store data
  Future<DocumentSnapshot> getStoreData(String storeId) {
    return _firestore.collection(_collectionStores).doc(storeId).get();
  }

  /// Update store settings
  Future<bool> updateStoreSettings(
      String storeId, Map<String, dynamic> settings) async {
    try {
      await _firestore.collection(_collectionStores).doc(storeId).update({
        'settings': settings,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      return true;
    } catch (e) {
      // Debug print removed
      return false;
    }
  }

  /// Batch update multiple documents (for data migration)
  Future<bool> batchUpdate(List<Map<String, dynamic>> updates) async {
    try {
      final batch = _firestore.batch();

      for (final update in updates) {
        final docRef = _firestore.doc(update['path']);
        batch.update(docRef, update['data']);
      }

      await batch.commit();
      return true;
    } catch (e) {
      // Debug print removed
      return false;
    }
  }

  /// ===== USERS COLLECTION METHODS =====

  /// Create a new user document
  Future<bool> createUser({
    required String userId,
    required String email,
    required String name,
    String? phone,
    String subscriptionMode = 'basic',
    Map<String, dynamic>? settings,
  }) async {
    try {
      final userData = {
        'email': email,
        'name': name,
        'phone': phone ?? '',
        'subscriptionMode': subscriptionMode,
        'createdAt': FieldValue.serverTimestamp(),
        'lastLogin': FieldValue.serverTimestamp(),
        'isActive': true,
        'settings': settings ?? {},
      };

      await _firestore
          .collection(_collectionUsers)
          .doc(userId)
          .set(userData, SetOptions(merge: true));

      // Debug print removed
      return true;
    } catch (e) {
      // Debug print removed
      return false;
    }
  }

  /// Get user document
  Future<Map<String, dynamic>?> getUser(String userId) async {
    try {
      final doc =
          await _firestore.collection(_collectionUsers).doc(userId).get();

      if (doc.exists) {
        final data = doc.data()!;
        data['id'] = doc.id;
        return data;
      }
      return null;
    } catch (e) {
      // Debug print removed
      return null;
    }
  }

  /// Update user document
  Future<bool> updateUser({
    required String userId,
    String? name,
    String? phone,
    String? subscriptionMode,
    Map<String, dynamic>? settings,
  }) async {
    try {
      final updateData = <String, dynamic>{};

      if (name != null) updateData['name'] = name;
      if (phone != null) updateData['phone'] = phone;
      if (subscriptionMode != null) {
        updateData['subscriptionMode'] = subscriptionMode;
      }
      if (settings != null) updateData['settings'] = settings;

      updateData['updatedAt'] = FieldValue.serverTimestamp();

      await _firestore
          .collection(_collectionUsers)
          .doc(userId)
          .update(updateData);

      // Debug print removed
      return true;
    } catch (e) {
      // Debug print removed
      return false;
    }
  }

  /// Update user last login
  Future<bool> updateUserLastLogin(String userId) async {
    try {
      await _firestore.collection(_collectionUsers).doc(userId).update({
        'lastLogin': FieldValue.serverTimestamp(),
      });

      // Debug print removed
      return true;
    } catch (e) {
      // Debug print removed
      return false;
    }
  }

  /// Check if user exists
  Future<bool> userExists(String userId) async {
    try {
      final doc =
          await _firestore.collection(_collectionUsers).doc(userId).get();
      return doc.exists;
    } catch (e) {
      // Debug print removed
      return false;
    }
  }

  /// Get user by email (for invitation checks)
  Future<Map<String, dynamic>?> getUserByEmail(String email) async {
    try {
      final query = await _firestore
          .collection(_collectionUsers)
          .where('email', isEqualTo: email)
          .limit(1)
          .get();

      if (query.docs.isNotEmpty) {
        final doc = query.docs.first;
        final data = doc.data();
        data['id'] = doc.id;
        return data;
      }
      return null;
    } catch (e) {
      // Debug print removed
      return null;
    }
  }

  /// Test Firestore connection
  Future<bool> testConnection() async {
    try {
      await _firestore.enableNetwork();
      // Debug print removed
      return true;
    } catch (e) {
      // Debug print removed
      return false;
    }
  }

  /// ===== STORES COLLECTION METHODS =====

  /// Create a new store document
  Future<bool> createStore({
    required String storeId,
    required String name,
    required String ownerId,
    required String ownerEmail,
    required String ownerName,
    String? address,
    String? city,
    String? phone,
    String? email,
    String? taxNumber,
    Map<String, dynamic>? settings,
  }) async {
    try {
      final storeData = {
        'name': name,
        'ownerId': ownerId,
        'address': address ?? '',
        'city': city ?? '',
        'phone': phone ?? '',
        'email': email ?? '',
        'taxNumber': taxNumber ?? '',
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'isActive': true,
        'settings': settings ??
            {
              'currency': 'TL',
              'taxRate': 18,
              'autoBackup': true,
              'notifications': {},
            },
      };

      await _firestore
          .collection(_collectionStores)
          .doc(storeId)
          .set(storeData, SetOptions(merge: true));

      // Add owner as store member
      final ownerAdded = await addStoreOwner(
        storeId: storeId,
        userId: ownerId,
        email: ownerEmail,
        name: ownerName,
      );

      if (!ownerAdded) {
        // Debug print removed
      }

      // Debug print removed
      return true;
    } catch (e) {
      // Debug print removed
      return false;
    }
  }

  /// Get store document
  Future<Map<String, dynamic>?> getStore(String storeId) async {
    try {
      final doc =
          await _firestore.collection(_collectionStores).doc(storeId).get();

      if (doc.exists) {
        final data = doc.data()!;
        data['id'] = doc.id;
        return data;
      }
      return null;
    } catch (e) {
      // Debug print removed
      return null;
    }
  }

  /// Update store document
  Future<bool> updateStore({
    required String storeId,
    String? name,
    String? address,
    String? city,
    String? phone,
    String? email,
    String? taxNumber,
    Map<String, dynamic>? settings,
  }) async {
    try {
      final updateData = <String, dynamic>{};

      if (name != null) updateData['name'] = name;
      if (address != null) updateData['address'] = address;
      if (city != null) updateData['city'] = city;
      if (phone != null) updateData['phone'] = phone;
      if (email != null) updateData['email'] = email;
      if (taxNumber != null) updateData['taxNumber'] = taxNumber;
      if (settings != null) updateData['settings'] = settings;

      updateData['updatedAt'] = FieldValue.serverTimestamp();

      await _firestore
          .collection(_collectionStores)
          .doc(storeId)
          .update(updateData);

      // Debug print removed
      return true;
    } catch (e) {
      // Debug print removed
      return false;
    }
  }

  /// Get stores owned by user
  Future<List<Map<String, dynamic>>> getUserStores(String ownerId) async {
    try {
      final query = await _firestore
          .collection(_collectionStores)
          .where('ownerId', isEqualTo: ownerId)
          .where('isActive', isEqualTo: true)
          .orderBy('createdAt', descending: true)
          .get();

      return query.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return data;
      }).toList();
    } catch (e) {
      // Debug print removed
      return [];
    }
  }

  /// Check if store exists
  Future<bool> storeExists(String storeId) async {
    try {
      final doc =
          await _firestore.collection(_collectionStores).doc(storeId).get();
      return doc.exists;
    } catch (e) {
      // Debug print removed
      return false;
    }
  }

  // ===============================
  // STORE MEMBERS COLLECTION METHODS
  // ===============================

  /// Add owner as member when store is created
  Future<bool> addStoreOwner({
    required String storeId,
    required String userId,
    required String email,
    required String name,
  }) async {
    try {
      await _firestore
          .collection(_collectionStores)
          .doc(storeId)
          .collection('members')
          .doc(userId)
          .set({
        'userId': userId,
        'email': email.toLowerCase(),
        'name': name,
        'role': 'owner',
        'permissions': ['read', 'write', 'delete', 'admin'],
        'status': 'owner',
        'joinedAt': FieldValue.serverTimestamp(),
        'invitedAt': FieldValue.serverTimestamp(),
        'invitedBy': null, // Owner is self-added
        'respondedAt': FieldValue.serverTimestamp(),
        'lastActivity': FieldValue.serverTimestamp(),
        'isActive': true,
      });

      // Debug print removed
      return true;
    } catch (e) {
      // Debug print removed
      return false;
    }
  }

  /// Invite user to store
  Future<bool> inviteUserToStore({
    required String storeId,
    required String inviteeEmail,
    required String role, // "manager" | "staff" | "partner"
    required List<String> permissions,
    required String invitedByUserId,
    required String invitedByName,
  }) async {
    try {
      // Check if user is already a member
      final existingMember = await _firestore
          .collection(_collectionStores)
          .doc(storeId)
          .collection('members')
          .where('email', isEqualTo: inviteeEmail.toLowerCase())
          .get();

      if (existingMember.docs.isNotEmpty) {
        // Debug print removed
        return false;
      }

      // Generate invitation ID
      final invitationId = 'invite_${DateTime.now().millisecondsSinceEpoch}';

      // Add pending invitation to store members
      await _firestore
          .collection(_collectionStores)
          .doc(storeId)
          .collection('members')
          .doc(invitationId)
          .set({
        'userId': null, // Will be set when user accepts
        'email': inviteeEmail.toLowerCase(),
        'name': null, // Will be set when user accepts
        'role': role,
        'permissions': permissions,
        'status': 'invited',
        'joinedAt': null, // Will be set when user accepts
        'invitedAt': FieldValue.serverTimestamp(),
        'invitedBy': invitedByUserId,
        'invitedByName': invitedByName,
        'respondedAt': null, // Will be set when user responds
        'lastActivity': null,
        'isActive': true,
        'invitationId': invitationId,
      });

      // Debug print removed
      return true;
    } catch (e) {
      // Debug print removed
      return false;
    }
  }

  /// Accept store invitation
  Future<bool> acceptStoreInvitation({
    required String storeId,
    required String invitationId,
    required String userId,
    required String userName,
  }) async {
    try {
      // Get invitation document
      final invitationDoc = await _firestore
          .collection(_collectionStores)
          .doc(storeId)
          .collection('members')
          .doc(invitationId)
          .get();

      if (!invitationDoc.exists) {
        // Debug print removed
        return false;
      }

      final invitationData = invitationDoc.data()!;

      // Update invitation with user acceptance
      await _firestore
          .collection(_collectionStores)
          .doc(storeId)
          .collection('members')
          .doc(userId) // Change doc ID to userId
          .set({
        'userId': userId,
        'email': invitationData['email'],
        'name': userName,
        'role': invitationData['role'],
        'permissions': invitationData['permissions'],
        'status': 'accepted',
        'joinedAt': FieldValue.serverTimestamp(),
        'invitedAt': invitationData['invitedAt'],
        'invitedBy': invitationData['invitedBy'],
        'invitedByName': invitationData['invitedByName'],
        'respondedAt': FieldValue.serverTimestamp(),
        'lastActivity': FieldValue.serverTimestamp(),
        'isActive': true,
      });

      // Delete old invitation document
      await _firestore
          .collection(_collectionStores)
          .doc(storeId)
          .collection('members')
          .doc(invitationId)
          .delete();

      // Debug print removed
      return true;
    } catch (e) {
      // Debug print removed
      return false;
    }
  }

  /// Reject store invitation
  Future<bool> rejectStoreInvitation({
    required String storeId,
    required String invitationId,
    required String userId,
  }) async {
    try {
      // Update invitation status to rejected
      await _firestore
          .collection(_collectionStores)
          .doc(storeId)
          .collection('members')
          .doc(invitationId)
          .update({
        'status': 'rejected',
        'respondedAt': FieldValue.serverTimestamp(),
      });

      // Debug print removed
      return true;
    } catch (e) {
      // Debug print removed
      return false;
    }
  }

  /// Get store members (accepted, invited, rejected)
  Future<List<Map<String, dynamic>>> getStoreMembers(String storeId) async {
    try {
      final querySnapshot = await _firestore
          .collection(_collectionStores)
          .doc(storeId)
          .collection('members')
          .orderBy('status') // owner, accepted, invited, rejected
          .orderBy('joinedAt', descending: true)
          .get();

      final members = querySnapshot.docs.map((doc) {
        return {
          'id': doc.id,
          ...doc.data(),
        };
      }).toList();

      // Debug print removed
      return members;
    } catch (e) {
      // Debug print removed
      return [];
    }
  }

  /// Get store members stream (real-time)
  Stream<QuerySnapshot> getStoreMembersStream(String storeId) {
    return _firestore
        .collection(_collectionStores)
        .doc(storeId)
        .collection('members')
        .orderBy('status')
        .orderBy('joinedAt', descending: true)
        .snapshots();
  }

  /// Get user's store invitations (pending)
  Future<List<Map<String, dynamic>>> getUserInvitations(
      String userEmail) async {
    try {
      // Search across all stores for invitations to this email
      final storesSnapshot =
          await _firestore.collection(_collectionStores).get();

      List<Map<String, dynamic>> invitations = [];

      for (var storeDoc in storesSnapshot.docs) {
        final storeId = storeDoc.id;
        final storeData = storeDoc.data();

        // Get invitations for this user in this store
        final invitationsSnapshot = await _firestore
            .collection(_collectionStores)
            .doc(storeId)
            .collection('members')
            .where('email', isEqualTo: userEmail.toLowerCase())
            .where('status', isEqualTo: 'invited')
            .get();

        for (var invitationDoc in invitationsSnapshot.docs) {
          final invitationData = invitationDoc.data();
          invitations.add({
            'id': invitationDoc.id,
            'storeId': storeId,
            'storeName': storeData['name'],
            'storeOwner': storeData['ownerId'],
            ...invitationData,
          });
        }
      }

      // Debug print removed
      return invitations;
    } catch (e) {
      // Debug print removed
      return [];
    }
  }

  /// Update member role and permissions
  Future<bool> updateMemberRole({
    required String storeId,
    required String memberId,
    required String newRole,
    required List<String> newPermissions,
  }) async {
    try {
      await _firestore
          .collection(_collectionStores)
          .doc(storeId)
          .collection('members')
          .doc(memberId)
          .update({
        'role': newRole,
        'permissions': newPermissions,
        'lastActivity': FieldValue.serverTimestamp(),
      });

      // Debug print removed
      return true;
    } catch (e) {
      // Debug print removed
      return false;
    }
  }

  /// Deactivate store member
  Future<bool> deactivateMember({
    required String storeId,
    required String memberId,
  }) async {
    try {
      await _firestore
          .collection(_collectionStores)
          .doc(storeId)
          .collection('members')
          .doc(memberId)
          .update({
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

  /// Remove store member completely
  Future<bool> removeMember({
    required String storeId,
    required String memberId,
  }) async {
    try {
      await _firestore
          .collection(_collectionStores)
          .doc(storeId)
          .collection('members')
          .doc(memberId)
          .delete();

      // Debug print removed
      return true;
    } catch (e) {
      // Debug print removed
      return false;
    }
  }

  /// Update member last activity
  Future<bool> updateMemberActivity({
    required String storeId,
    required String memberId,
  }) async {
    try {
      await _firestore
          .collection(_collectionStores)
          .doc(storeId)
          .collection('members')
          .doc(memberId)
          .update({
        'lastActivity': FieldValue.serverTimestamp(),
      });

      return true;
    } catch (e) {
      // Debug print removed
      return false;
    }
  }

  /// Check if user is member of store
  Future<Map<String, dynamic>?> getStoreMembership({
    required String storeId,
    required String userId,
  }) async {
    try {
      final doc = await _firestore
          .collection(_collectionStores)
          .doc(storeId)
          .collection('members')
          .doc(userId)
          .get();

      if (doc.exists) {
        return {
          'id': doc.id,
          ...doc.data()!,
        };
      }
      return null;
    } catch (e) {
      // Debug print removed
      return null;
    }
  }

  /// Delete store document
  Future<bool> deleteStore(String storeId) async {
    try {
      await _firestore
          .collection(_collectionStores)
          .doc(storeId)
          .update({'isActive': false});

      // Debug print removed
      return true;
    } catch (e) {
      // Debug print removed
      return false;
    }
  }

  /// ===== PRODUCTS COLLECTION METHODS =====

  /// Create a new product in store
  Future<bool> createProduct({
    required String storeId,
    required String productId,
    required String barcode,
    required String name,
    String? description,
    required double salePrice,
    required double purchasePrice,
    required int stock,
    int? minStock,
    double? taxRate,
    String? category,
    required String lastModifiedBy,
  }) async {
    try {
      final productData = {
        'barcode': barcode,
        'name': name,
        'description': description ?? '',
        'salePrice': salePrice,
        'purchasePrice': purchasePrice,
        'stock': stock,
        'minStock': minStock ?? 0,
        'taxRate': taxRate ?? 18.0,
        'category': category ?? 'general',
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'lastModifiedBy': lastModifiedBy,
        'isActive': true,
      };

      await _firestore
          .collection(_collectionStores)
          .doc(storeId)
          .collection('products')
          .doc(productId)
          .set(productData, SetOptions(merge: true));

      // Debug print removed
      return true;
    } catch (e) {
      // Debug print removed
      return false;
    }
  }

  /// Get all products for a store
  Future<List<Map<String, dynamic>>> getStoreProducts(String storeId) async {
    try {
      final querySnapshot = await _firestore
          .collection(_collectionStores)
          .doc(storeId)
          .collection('products')
          .where('isActive', isEqualTo: true)
          .orderBy('name')
          .get();

      return querySnapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return data;
      }).toList();
    } catch (e) {
      // Debug print removed
      return [];
    }
  }

  /// Get products stream for real-time updates
  Stream<QuerySnapshot> getStoreProductsStream(String storeId) {
    return _firestore
        .collection(_collectionStores)
        .doc(storeId)
        .collection(_collectionProducts)
        .orderBy('name')
        .snapshots();
  }

  /// Update product information
  Future<bool> updateProduct({
    required String storeId,
    required String productId,
    String? barcode,
    String? name,
    String? description,
    double? salePrice,
    double? purchasePrice,
    int? stock,
    int? minStock,
    double? taxRate,
    String? category,
    required String lastModifiedBy,
  }) async {
    try {
      final updateData = <String, dynamic>{
        'updatedAt': FieldValue.serverTimestamp(),
        'lastModifiedBy': lastModifiedBy,
      };

      if (barcode != null) updateData['barcode'] = barcode;
      if (name != null) updateData['name'] = name;
      if (description != null) updateData['description'] = description;
      if (salePrice != null) updateData['salePrice'] = salePrice;
      if (purchasePrice != null) updateData['purchasePrice'] = purchasePrice;
      if (stock != null) updateData['stock'] = stock;
      if (minStock != null) updateData['minStock'] = minStock;
      if (taxRate != null) updateData['taxRate'] = taxRate;
      if (category != null) updateData['category'] = category;

      await _firestore
          .collection(_collectionStores)
          .doc(storeId)
          .collection('products')
          .doc(productId)
          .update(updateData);

      // Debug print removed
      return true;
    } catch (e) {
      // Debug print removed
      return false;
    }
  }

  /// Update product stock
  Future<bool> updateProductStock({
    required String storeId,
    required String productId,
    required int newStock,
    required String lastModifiedBy,
    String? reason,
  }) async {
    try {
      await _firestore
          .collection(_collectionStores)
          .doc(storeId)
          .collection('products')
          .doc(productId)
          .update({
        'stock': newStock,
        'updatedAt': FieldValue.serverTimestamp(),
        'lastModifiedBy': lastModifiedBy,
      });

      // TODO: Add inventory change log here
      // Debug print removed
      return true;
    } catch (e) {
      // Debug print removed
      return false;
    }
  }

  /// Get product by barcode
  Future<Map<String, dynamic>?> getProductByBarcode({
    required String storeId,
    required String barcode,
  }) async {
    try {
      final querySnapshot = await _firestore
          .collection(_collectionStores)
          .doc(storeId)
          .collection('products')
          .where('barcode', isEqualTo: barcode)
          .where('isActive', isEqualTo: true)
          .limit(1)
          .get();

      if (querySnapshot.docs.isNotEmpty) {
        final data = querySnapshot.docs.first.data();
        data['id'] = querySnapshot.docs.first.id;
        return data;
      }
      return null;
    } catch (e) {
      // Debug print removed
      return null;
    }
  }

  /// Search products by name
  Future<List<Map<String, dynamic>>> searchProducts({
    required String storeId,
    required String searchTerm,
  }) async {
    try {
      final querySnapshot = await _firestore
          .collection(_collectionStores)
          .doc(storeId)
          .collection('products')
          .where('isActive', isEqualTo: true)
          .orderBy('name')
          .startAt([searchTerm]).endAt(['$searchTerm\uf8ff']).get();

      return querySnapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return data;
      }).toList();
    } catch (e) {
      // Debug print removed
      return [];
    }
  }

  /// Deactivate product (soft delete)
  Future<bool> deactivateProduct({
    required String storeId,
    required String productId,
    required String lastModifiedBy,
  }) async {
    try {
      await _firestore
          .collection(_collectionStores)
          .doc(storeId)
          .collection('products')
          .doc(productId)
          .update({
        'isActive': false,
        'updatedAt': FieldValue.serverTimestamp(),
        'lastModifiedBy': lastModifiedBy,
      });

      // Debug print removed
      return true;
    } catch (e) {
      // Debug print removed
      return false;
    }
  }

  /// Get low stock products
  Future<List<Map<String, dynamic>>> getLowStockProducts(String storeId) async {
    try {
      final querySnapshot = await _firestore
          .collection(_collectionStores)
          .doc(storeId)
          .collection('products')
          .where('isActive', isEqualTo: true)
          .get();

      // Filter products where stock <= minStock
      final lowStockProducts = <Map<String, dynamic>>[];
      for (final doc in querySnapshot.docs) {
        final data = doc.data();
        final stock = data['stock'] as int? ?? 0;
        final minStock = data['minStock'] as int? ?? 0;

        if (stock <= minStock) {
          data['id'] = doc.id;
          lowStockProducts.add(data);
        }
      }

      return lowStockProducts;
    } catch (e) {
      // Debug print removed
      return [];
    }
  }

  /// ===== SALES COLLECTION METHODS =====

  /// Create a new sale transaction
  Future<bool> createSale({
    required String storeId,
    required String saleId,
    required String userId,
    required double totalAmount,
    required double discount,
    required double finalAmount,
    required String paymentMethod,
    required List<Map<String, dynamic>> items,
    required String cashierName,
    String? customerId,
    String? notes,
  }) async {
    try {
      final saleData = {
        'userId': userId,
        'cashierName': cashierName,
        'customerId': customerId,
        'totalAmount': totalAmount,
        'discount': discount,
        'finalAmount': finalAmount,
        'paymentMethod': paymentMethod,
        'items': items,
        'notes': notes ?? '',
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'isActive': true,
      };

      await _firestore
          .collection(_collectionStores)
          .doc(storeId)
          .collection('sales')
          .doc(saleId)
          .set(saleData);

      // Debug print removed
      return true;
    } catch (e) {
      // Debug print removed
      return false;
    }
  }

  /// Get all sales for a store
  Future<List<Map<String, dynamic>>> getStoreSales(String storeId,
      {int? limit}) async {
    try {
      Query query = _firestore
          .collection(_collectionStores)
          .doc(storeId)
          .collection('sales')
          .where('isActive', isEqualTo: true)
          .orderBy('createdAt', descending: true);

      if (limit != null) {
        query = query.limit(limit);
      }

      final querySnapshot = await query.get();

      return querySnapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        data['id'] = doc.id;
        return data;
      }).toList();
    } catch (e) {
      // Debug print removed
      return [];
    }
  }

  /// Get sales stream for real-time updates
  Stream<QuerySnapshot> getStoreSalesStream(String storeId) {
    return _firestore
        .collection(_collectionStores)
        .doc(storeId)
        .collection('sales')
        .where('isActive', isEqualTo: true)
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  /// Get sales by date range
  Future<List<Map<String, dynamic>>> getSalesByDateRange({
    required String storeId,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    try {
      final querySnapshot = await _firestore
          .collection(_collectionStores)
          .doc(storeId)
          .collection('sales')
          .where('saleDate',
              isGreaterThanOrEqualTo: Timestamp.fromDate(startDate))
          .where('saleDate', isLessThanOrEqualTo: Timestamp.fromDate(endDate))
          .orderBy('saleDate', descending: true)
          .get();

      return querySnapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return data;
      }).toList();
    } catch (e) {
      // Debug print removed
      return [];
    }
  }

  /// Get sales by user
  Future<List<Map<String, dynamic>>> getSalesByUser({
    required String storeId,
    required String userId,
    int? limit,
  }) async {
    try {
      Query query = _firestore
          .collection(_collectionStores)
          .doc(storeId)
          .collection('sales')
          .where('isActive', isEqualTo: true)
          .where('userId', isEqualTo: userId)
          .orderBy('createdAt', descending: true);

      if (limit != null) {
        query = query.limit(limit);
      }

      final querySnapshot = await query.get();

      return querySnapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        data['id'] = doc.id;
        return data;
      }).toList();
    } catch (e) {
      // Debug print removed
      return [];
    }
  }

  /// Get daily sales total
  Future<double> getDailySalesTotal(String storeId, DateTime date) async {
    try {
      final startOfDay = DateTime(date.year, date.month, date.day);
      final endOfDay = DateTime(date.year, date.month, date.day, 23, 59, 59);

      final querySnapshot = await _firestore
          .collection(_collectionStores)
          .doc(storeId)
          .collection('sales')
          .where('isActive', isEqualTo: true)
          .where('createdAt',
              isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
          .where('createdAt', isLessThanOrEqualTo: Timestamp.fromDate(endOfDay))
          .get();

      double total = 0.0;
      for (final doc in querySnapshot.docs) {
        final data = doc.data();
        total += (data['finalAmount'] as num?)?.toDouble() ?? 0.0;
      }

      return total;
    } catch (e) {
      // Debug print removed
      return 0.0;
    }
  }

  /// Get sales statistics for dashboard
  Future<Map<String, dynamic>> getSalesStatistics({
    required String storeId,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    try {
      final querySnapshot = await _firestore
          .collection(_collectionStores)
          .doc(storeId)
          .collection('sales')
          .where('isActive', isEqualTo: true)
          .where('createdAt',
              isGreaterThanOrEqualTo: Timestamp.fromDate(startDate))
          .where('createdAt', isLessThanOrEqualTo: Timestamp.fromDate(endDate))
          .get();

      double totalRevenue = 0.0;
      double totalDiscount = 0.0;
      int totalTransactions = querySnapshot.docs.length;
      Map<String, int> paymentMethods = {};
      Map<String, double> dailySales = {};

      for (final doc in querySnapshot.docs) {
        final data = doc.data();
        final finalAmount = (data['finalAmount'] as num?)?.toDouble() ?? 0.0;
        final discount = (data['discount'] as num?)?.toDouble() ?? 0.0;
        final paymentMethod = data['paymentMethod'] as String? ?? 'cash';
        final createdAt = (data['createdAt'] as Timestamp?)?.toDate();

        totalRevenue += finalAmount;
        totalDiscount += discount;

        // Count payment methods
        paymentMethods[paymentMethod] =
            (paymentMethods[paymentMethod] ?? 0) + 1;

        // Group by day
        if (createdAt != null) {
          final dayKey =
              '${createdAt.year}-${createdAt.month.toString().padLeft(2, '0')}-${createdAt.day.toString().padLeft(2, '0')}';
          dailySales[dayKey] = (dailySales[dayKey] ?? 0.0) + finalAmount;
        }
      }

      return {
        'totalRevenue': totalRevenue,
        'totalDiscount': totalDiscount,
        'totalTransactions': totalTransactions,
        'averageTransaction':
            totalTransactions > 0 ? totalRevenue / totalTransactions : 0.0,
        'paymentMethods': paymentMethods,
        'dailySales': dailySales,
      };
    } catch (e) {
      // Debug print removed
      return {};
    }
  }

  /// Update sale information
  Future<bool> updateSale({
    required String storeId,
    required String saleId,
    String? notes,
    String? customerId,
    required String lastModifiedBy,
  }) async {
    try {
      final updateData = <String, dynamic>{
        'updatedAt': FieldValue.serverTimestamp(),
        'lastModifiedBy': lastModifiedBy,
      };

      if (notes != null) updateData['notes'] = notes;
      if (customerId != null) updateData['customerId'] = customerId;

      await _firestore
          .collection(_collectionStores)
          .doc(storeId)
          .collection('sales')
          .doc(saleId)
          .update(updateData);

      // Debug print removed
      return true;
    } catch (e) {
      // Debug print removed
      return false;
    }
  }

  /// Cancel sale (soft delete)
  Future<bool> cancelSale({
    required String storeId,
    required String saleId,
    required String lastModifiedBy,
    String? reason,
  }) async {
    try {
      await _firestore
          .collection(_collectionStores)
          .doc(storeId)
          .collection('sales')
          .doc(saleId)
          .update({
        'isActive': false,
        'cancelledAt': FieldValue.serverTimestamp(),
        'cancelledBy': lastModifiedBy,
        'cancelReason': reason ?? '',
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Debug print removed
      return true;
    } catch (e) {
      // Debug print removed
      return false;
    }
  }

  /// Get best selling products
  Future<List<Map<String, dynamic>>> getBestSellingProducts({
    required String storeId,
    required DateTime startDate,
    required DateTime endDate,
    int limit = 10,
  }) async {
    try {
      final querySnapshot = await _firestore
          .collection(_collectionStores)
          .doc(storeId)
          .collection('sales')
          .where('isActive', isEqualTo: true)
          .where('createdAt',
              isGreaterThanOrEqualTo: Timestamp.fromDate(startDate))
          .where('createdAt', isLessThanOrEqualTo: Timestamp.fromDate(endDate))
          .get();

      Map<String, Map<String, dynamic>> productSales = {};

      for (final doc in querySnapshot.docs) {
        final data = doc.data();
        final items = data['items'] as List<dynamic>? ?? [];

        for (final item in items) {
          final productId = item['productId'] as String? ?? '';
          final productName = item['productName'] as String? ?? '';
          final quantity = (item['quantity'] as num?)?.toInt() ?? 0;
          final totalPrice = (item['totalPrice'] as num?)?.toDouble() ?? 0.0;

          if (productSales.containsKey(productId)) {
            productSales[productId]!['totalQuantity'] += quantity;
            productSales[productId]!['totalRevenue'] += totalPrice;
          } else {
            productSales[productId] = {
              'productId': productId,
              'productName': productName,
              'totalQuantity': quantity,
              'totalRevenue': totalPrice,
            };
          }
        }
      }

      final sortedProducts = productSales.values.toList();
      sortedProducts.sort((a, b) =>
          (b['totalQuantity'] as int).compareTo(a['totalQuantity'] as int));

      return sortedProducts.take(limit).toList();
    } catch (e) {
      // Debug print removed
      return [];
    }
  }

  // ==========================================
  // SUPPLIER OPERATIONS
  // ==========================================

  /// Add or update supplier with retry mechanism
  /// Returns the Firebase document ID for new suppliers, or the existing ID for updates
  Future<String?> saveSupplier(String storeId, String? supplierId,
      Map<String, dynamic> supplierData) async {
    // ✅ StoreId validation
    if (storeId.isEmpty) {
      print('❌ SAVESUPPLIER FAILED: StoreId is empty!');
      return null;
    }

    // 🔄 RETRY MECHANISM - 3 attempts with exponential backoff
    for (int attempt = 1; attempt <= 3; attempt++) {
      try {
        supplierData['lastModified'] = FieldValue.serverTimestamp();
        supplierData['storeId'] = storeId; // ✅ Store ID'yi garantile

        if (supplierId == null) {
          // 🆕 Add new supplier - Firebase generates ID
          print('🔄 Attempt $attempt: Adding new supplier to Firebase...');
          print('🔍 DEBUG: StoreId: $storeId');
          print('🔍 DEBUG: Supplier data: $supplierData');

          final docRef = await _firestore
              .collection(_collectionStores)
              .doc(storeId)
              .collection('suppliers')
              .add(supplierData);

          print('✅ New supplier added with Firebase ID: ${docRef.id}');
          print('🔍 DEBUG: Full path: /stores/$storeId/suppliers/${docRef.id}');
          return docRef.id; // Return Firebase document ID
        } else {
          // 🔄 Update existing supplier
          print('🔄 Attempt $attempt: Updating existing supplier: $supplierId');
          await _firestore
              .collection(_collectionStores)
              .doc(storeId)
              .collection('suppliers')
              .doc(supplierId)
              .update(supplierData);

          print('✅ Supplier updated successfully: $supplierId');
          return supplierId; // Return existing supplier ID
        }
      } catch (e) {
        print('❌ Firebase saveSupplier error (attempt $attempt): $e');

        if (attempt == 3) {
          // Son deneme de başarısız
          print('� All retry attempts failed for saveSupplier');
          return null;
        }

        // Exponential backoff - wait before retry
        final waitTime = Duration(milliseconds: 500 * attempt);
        print('⏳ Waiting ${waitTime.inMilliseconds}ms before retry...');
        await Future.delayed(waitTime);
      }
    }

    return null; // This shouldn't be reached
  }

  /// Delete supplier with cascade delete (related data cleanup)
  Future<bool> deleteSupplier(String storeId, String supplierId) async {
    // 🔄 RETRY MECHANISM - 3 attempts with exponential backoff
    for (int attempt = 1; attempt <= 3; attempt++) {
      try {
        print(
            '🔄 Attempt $attempt: Deleting supplier and related data from Firebase: $supplierId in store: $storeId');

        // ✅ CASCADE DELETE - Delete related data first
        print('🗑️ Step 1: Deleting all purchases for supplier...');
        await deleteAllPurchasesForSupplier(storeId, supplierId);

        print('🗑️ Step 2: Deleting all payment transactions for supplier...');
        await deleteAllPaymentTransactionsForSupplier(storeId, supplierId);

        // ✅ Finally delete the supplier document itself
        print('🗑️ Step 3: Deleting supplier document...');
        await _firestore
            .collection(_collectionStores)
            .doc(storeId)
            .collection('suppliers')
            .doc(supplierId)
            .delete();

        print(
            '✅ Supplier and all related data deleted successfully from Firebase: $supplierId');
        return true; // Success - exit retry loop
      } catch (e) {
        print(
            '❌ Firebase deleteSupplier (cascade) error (attempt $attempt): $e');

        if (attempt == 3) {
          // Son deneme de başarısız
          print('💀 All retry attempts failed for deleteSupplier (cascade)');
          return false;
        }

        // Exponential backoff - wait before retry
        final waitTime = Duration(milliseconds: 500 * attempt);
        print('⏳ Waiting ${waitTime.inMilliseconds}ms before retry...');
        await Future.delayed(waitTime);
      }
    }

    return false; // This shouldn't be reached
  }

  /// Get suppliers stream for a store
  Stream<QuerySnapshot> getSuppliersStream(String storeId) {
    return _firestore
        .collection(_collectionStores)
        .doc(storeId)
        .collection('suppliers')
        .where('isActive', isEqualTo: true)
        .orderBy('name')
        .snapshots();
  }

  /// Get specific supplier
  Future<DocumentSnapshot?> getSupplier(
      String storeId, String supplierId) async {
    try {
      final doc = await _firestore
          .collection(_collectionStores)
          .doc(storeId)
          .collection('suppliers')
          .doc(supplierId)
          .get();

      return doc.exists ? doc : null;
    } catch (e) {
      print('❌ Firebase getSupplier error: $e');
      return null;
    }
  }

  // ==================== PURCHASE OPERATIONS ====================

  /// Save purchase to supplier subcollection with retry mechanism
  Future<bool> savePurchase(String storeId, String supplierId,
      String? purchaseId, Map<String, dynamic> purchaseData) async {
    if (storeId.isEmpty || supplierId.isEmpty) {
      print('❌ SAVEPURCHASE FAILED: StoreId or SupplierId is empty!');
      return false;
    }

    // 🔄 RETRY MECHANISM - 3 attempts
    for (int attempt = 1; attempt <= 3; attempt++) {
      try {
        purchaseData['lastModified'] = FieldValue.serverTimestamp();
        purchaseData['storeId'] = storeId;
        purchaseData['supplierId'] = supplierId;

        if (purchaseId == null) {
          // 🆕 Add new purchase
          print('🔄 Attempt $attempt: Adding new purchase to Firebase...');
          final docRef = await _firestore
              .collection(_collectionStores)
              .doc(storeId)
              .collection('suppliers')
              .doc(supplierId)
              .collection('purchases')
              .add(purchaseData);

          print('✅ New purchase added with Firebase ID: ${docRef.id}');
          return true;
        } else {
          // 🔄 Update existing purchase
          print('🔄 Attempt $attempt: Updating existing purchase: $purchaseId');
          await _firestore
              .collection(_collectionStores)
              .doc(storeId)
              .collection('suppliers')
              .doc(supplierId)
              .collection('purchases')
              .doc(purchaseId)
              .set(purchaseData, SetOptions(merge: true));

          print('✅ Purchase updated: $purchaseId');
          return true;
        }
      } catch (e) {
        print('❌ Purchase save attempt $attempt failed: $e');
        if (attempt == 3) {
          print('❌ All purchase save attempts failed');
          return false;
        }
        // Wait before retry (exponential backoff)
        await Future.delayed(Duration(milliseconds: 500 * attempt));
      }
    }
    return false;
  }

  /// Delete purchase from supplier subcollection
  Future<bool> deletePurchase(
      String storeId, String supplierId, String purchaseId) async {
    try {
      await _firestore
          .collection(_collectionStores)
          .doc(storeId)
          .collection('suppliers')
          .doc(supplierId)
          .collection('purchases')
          .doc(purchaseId)
          .delete();

      print('✅ Purchase deleted: $purchaseId');
      return true;
    } catch (e) {
      print('❌ Firebase deletePurchase error: $e');
      return false;
    }
  }

  /// Get purchases stream for a supplier
  Stream<QuerySnapshot> getPurchasesStream(String storeId, String supplierId) {
    try {
      print(
          '🔄 Getting purchases stream for supplier: $supplierId in store: $storeId');
      return _firestore
          .collection(_collectionStores)
          .doc(storeId)
          .collection('suppliers')
          .doc(supplierId)
          .collection('purchases')
          .orderBy('purchaseDate', descending: true)
          .snapshots();
    } catch (e) {
      print('❌ Error creating purchases stream: $e');
      // Fallback: orderBy olmadan dene
      return _firestore
          .collection(_collectionStores)
          .doc(storeId)
          .collection('suppliers')
          .doc(supplierId)
          .collection('purchases')
          .snapshots();
    }
  }

  /// Get all purchases for a store (across all suppliers)
  Stream<QuerySnapshot> getAllPurchasesStream(String storeId) {
    return _firestore
        .collectionGroup('purchases')
        .where('storeId', isEqualTo: storeId)
        .orderBy('purchaseDate', descending: true)
        .snapshots();
  }

  // ==========================================
  // PAYMENT HISTORY OPERATIONS
  // ==========================================

  /// Save payment/debt transaction to Firebase
  Future<bool> savePaymentHistory(String storeId, String supplierId,
      String? transactionId, Map<String, dynamic> paymentData) async {
    // 🔄 RETRY MECHANISM - 3 attempts with exponential backoff
    for (int attempt = 1; attempt <= 3; attempt++) {
      try {
        paymentData['lastModified'] = FieldValue.serverTimestamp();
        paymentData['storeId'] = storeId;
        paymentData['supplierId'] = supplierId;

        if (transactionId == null) {
          // 🆕 Add new payment transaction - Firebase generates ID
          print(
              '🔄 Attempt $attempt: Adding new payment transaction to Firebase...');
          final docRef = await _firestore
              .collection(_collectionStores)
              .doc(storeId)
              .collection('suppliers')
              .doc(supplierId)
              .collection('supplier_transactions')
              .add(paymentData);

          print(
              '✅ New payment transaction added with Firebase ID: ${docRef.id}');
          return true; // Success - exit retry loop
        } else {
          // 🔄 Update existing payment transaction
          print(
              '🔄 Attempt $attempt: Updating existing payment transaction: $transactionId');
          await _firestore
              .collection(_collectionStores)
              .doc(storeId)
              .collection('suppliers')
              .doc(supplierId)
              .collection('supplier_transactions')
              .doc(transactionId)
              .set(paymentData, SetOptions(merge: true));

          print('✅ Payment transaction updated successfully: $transactionId');
          return true; // Success - exit retry loop
        }
      } catch (e) {
        print('❌ Firebase savePaymentHistory error (attempt $attempt): $e');

        if (attempt == 3) {
          // Son deneme de başarısız
          print('💀 All retry attempts failed for savePaymentHistory');
          return false;
        }

        // Exponential backoff - wait before retry
        final waitTime = Duration(milliseconds: 500 * attempt);
        print('⏳ Waiting ${waitTime.inMilliseconds}ms before retry...');
        await Future.delayed(waitTime);
      }
    }

    return false;
  }

  /// Get payment history for a specific supplier
  Future<QuerySnapshot?> getPaymentHistory(
      String storeId, String supplierId) async {
    try {
      print(
          '🔄 Getting payment history from Firebase for supplier: $supplierId');

      final querySnapshot = await _firestore
          .collection(_collectionStores)
          .doc(storeId)
          .collection('suppliers')
          .doc(supplierId)
          .collection('supplier_transactions')
          .orderBy('created_at', descending: true)
          .get();

      print(
          '✅ Payment history retrieved: ${querySnapshot.docs.length} transactions');
      return querySnapshot;
    } catch (e) {
      print('❌ Error getting payment history from Firebase: $e');
      return null;
    }
  }

  /// Get payment history stream for real-time updates
  Stream<QuerySnapshot> getPaymentHistoryStream(
      String storeId, String supplierId) {
    return _firestore
        .collection(_collectionStores)
        .doc(storeId)
        .collection('suppliers')
        .doc(supplierId)
        .collection('supplier_transactions')
        .orderBy('created_at', descending: true)
        .snapshots();
  }

  /// Get all payment transactions stream for a store
  /// NOT IMPLEMENTED - With new schema structure, this would require
  /// listening to multiple sub-collections simultaneously
  /// Use getPaymentHistoryStream for specific suppliers instead
  @deprecated
  Stream<QuerySnapshot> getAllPaymentTransactionsStream(String storeId) {
    throw UnimplementedError(
        'getAllPaymentTransactionsStream is not compatible with new schema structure. Use getPaymentHistoryStream for specific suppliers.');
  }

  /// Delete payment transaction from Firebase
  Future<bool> deletePaymentTransaction(
      String storeId, String supplierId, String transactionId) async {
    // 🔄 RETRY MECHANISM - 3 attempts with exponential backoff
    for (int attempt = 1; attempt <= 3; attempt++) {
      try {
        print(
            '🔄 Attempt $attempt: Deleting payment transaction from Firebase: $transactionId');

        await _firestore
            .collection(_collectionStores)
            .doc(storeId)
            .collection('suppliers')
            .doc(supplierId)
            .collection('supplier_transactions')
            .doc(transactionId)
            .delete();

        print(
            '✅ Payment transaction deleted successfully from Firebase: $transactionId');
        return true; // Success - exit retry loop
      } catch (e) {
        print(
            '❌ Firebase deletePaymentTransaction error (attempt $attempt): $e');

        if (attempt == 3) {
          // Son deneme de başarısız
          print('💀 All retry attempts failed for deletePaymentTransaction');
          return false;
        }

        // Exponential backoff - wait before retry
        final waitTime = Duration(milliseconds: 500 * attempt);
        print('⏳ Waiting ${waitTime.inMilliseconds}ms before retry...');
        await Future.delayed(waitTime);
      }
    }

    return false;
  }

  /// Delete all purchases for a specific supplier
  Future<bool> deleteAllPurchasesForSupplier(
      String storeId, String supplierId) async {
    try {
      print('🔄 Deleting all purchases for supplier: $supplierId');

      final querySnapshot = await _firestore
          .collection(_collectionStores)
          .doc(storeId)
          .collection('suppliers')
          .doc(supplierId)
          .collection('purchases')
          .get();

      final batch = _firestore.batch();
      for (final doc in querySnapshot.docs) {
        batch.delete(doc.reference);
      }

      await batch.commit();
      print(
          '✅ All purchases deleted for supplier: $supplierId (${querySnapshot.docs.length} purchases)');
      return true;
    } catch (e) {
      print('❌ Error deleting purchases for supplier: $e');
      return false;
    }
  }

  /// Delete all payment transactions for a specific supplier
  Future<bool> deleteAllPaymentTransactionsForSupplier(
      String storeId, String supplierId) async {
    try {
      print('🔄 Deleting all payment transactions for supplier: $supplierId');

      final querySnapshot = await _firestore
          .collection(_collectionStores)
          .doc(storeId)
          .collection('suppliers')
          .doc(supplierId)
          .collection('supplier_transactions')
          .get();

      final batch = _firestore.batch();
      for (final doc in querySnapshot.docs) {
        batch.delete(doc.reference);
      }

      await batch.commit();
      print(
          '✅ All payment transactions deleted for supplier: $supplierId (${querySnapshot.docs.length} transactions)');
      return true;
    } catch (e) {
      print('❌ Error deleting payment transactions for supplier: $e');
      return false;
    }
  }
}
