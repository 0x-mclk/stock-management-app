import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class StoreSelectionService {
  static const String _currentStoreIdKey = 'currentStoreId';
  static const String _currentStoreNameKey = 'currentStoreName';

  static StoreSelectionService? _instance;
  static StoreSelectionService get instance =>
      _instance ??= StoreSelectionService._();
  StoreSelectionService._();

  String? _cachedStoreId;
  String? _cachedStoreName;

  /// Get current active store ID
  Future<String> getCurrentStoreId() async {
    final currentUser = FirebaseAuth.instance.currentUser;

    if (_cachedStoreId != null) {
      return _cachedStoreId!;
    }

    final prefs = await SharedPreferences.getInstance();
    final savedStoreId = prefs.getString(_currentStoreIdKey);

    if (savedStoreId != null && savedStoreId.isNotEmpty) {
      _cachedStoreId = savedStoreId;
      return savedStoreId;
    }

    // No saved store ID, use user's own store as default
    if (currentUser != null) {
      final defaultStoreId = 'store_${currentUser.uid}';
      await setCurrentStore(defaultStoreId, 'Benim Mağazam');
      return defaultStoreId;
    }

    // FALLBACK: Even if no user, return a temporary store ID to prevent crashes
    return 'store_temp_offline'; // Temporary store for offline/guest mode
  }

  /// Get current active store name
  Future<String> getCurrentStoreName() async {
    final currentUser = FirebaseAuth.instance.currentUser;

    if (_cachedStoreName != null) {
      return _cachedStoreName!;
    }

    final prefs = await SharedPreferences.getInstance();
    final savedStoreName = prefs.getString(_currentStoreNameKey);

    if (savedStoreName != null && savedStoreName.isNotEmpty) {
      _cachedStoreName = savedStoreName;
      return savedStoreName;
    }
    return 'Mağaza';
  }

  /// Set active store with validation
  Future<void> setCurrentStore(String storeId, String storeName) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      return;
    }

    // DİNAMİK GÜVENLİK KONTROLÜ - kullanıcının gerçekten erişimi var mı?
    final hasAccess = await _verifyStoreAccess(currentUser.uid, storeId);

    if (hasAccess) {

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_currentStoreIdKey, storeId);
      await prefs.setString(_currentStoreNameKey, storeName);

      _cachedStoreId = storeId;
      _cachedStoreName = storeName;
    } else {

      // Fallback to user's own store
      final ownStoreId = 'store_${currentUser.uid}';

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_currentStoreIdKey, ownStoreId);
      await prefs.setString(_currentStoreNameKey, 'Benim Mağazam');

      _cachedStoreId = ownStoreId;
      _cachedStoreName = 'Benim Mağazam';
    }
  }

  /// Kullanıcının belirli bir mağazaya erişiminin olup olmadığını kontrol et
  Future<bool> _verifyStoreAccess(String userId, String storeId) async {
    try {
      // 1. Kendi mağazası mı? (store_userId formatında)
      final ownStoreId = 'store_$userId';
      if (storeId == ownStoreId) {
        return true;
      }

      // 2. Bu mağazanın sahibi mi?
      final storeDoc = await FirebaseFirestore.instance
          .collection('stores')
          .doc(storeId)
          .get();

      if (storeDoc.exists) {
        final storeData = storeDoc.data()!;
        final ownerId = storeData['ownerId'];
        if (ownerId == userId) {
          return true;
        }
      }

      // 3. Bu mağazaya davet edilen mi?
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .get();

      if (userDoc.exists) {
        final userData = userDoc.data()!;
        final assignedStoreId = userData['storeId'];
        if (assignedStoreId == storeId) {
          return true;
        }
      }

      // 4. Store_invitations'da kayıtlı mı?
      final invitationQuery = await FirebaseFirestore.instance
          .collection('store_invitations')
          .where('userId', isEqualTo: userId)
          .where('storeId', isEqualTo: storeId)
          .where('status', whereIn: ['accepted', 'owner'])
          .limit(1)
          .get();

      if (invitationQuery.docs.isNotEmpty) {
        return true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  /// Get available stores for current user
  Future<List<Map<String, String>>> getAvailableStores() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return [];

    List<Map<String, String>> stores = [];

    try {
      // 1. Add user's own store
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser.uid)
          .get();

      if (userDoc.exists) {
        final userData = userDoc.data()!;
        final ownStoreId = 'store_${currentUser.uid}';
        stores.add({
          'id': ownStoreId,
          'name': userData['storeName'] ?? 'Benim Mağazam',
          'type': 'owner',
        });
      }

      // 2. Add stores where user is a member
      final memberQuery = await FirebaseFirestore.instance
          .collectionGroup('members')
          .where('userId', isEqualTo: currentUser.uid)
          .where('isActive', isEqualTo: true)
          .get();

      for (var memberDoc in memberQuery.docs) {
        final memberData = memberDoc.data();
        final storeId = memberDoc.reference.parent.parent!.id;

        // Get store name
        final storeDoc = await FirebaseFirestore.instance
            .collection('stores')
            .doc(storeId)
            .get();

        if (storeDoc.exists) {
          final storeName = storeDoc.data()?['name'] ?? 'Mağaza';
          stores.add({
            'id': storeId,
            'name': storeName,
            'type': 'member',
            'role': memberData['role'] ?? 'employee',
          });
        }
      }

      return stores;
    } catch (e) {
      return stores;
    }
  }

  /// Initialize store selection after login
  Future<void> initializeAfterLogin() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    try {

      // FORCE CLEAR STORE CACHE FIRST - this is critical!
      _cachedStoreId = null;
      _cachedStoreName = null;
      final prefs = await SharedPreferences.getInstance();

      // Clear only store-related keys, not ALL SharedPreferences
      await prefs.remove(_currentStoreIdKey);
      await prefs.remove(_currentStoreNameKey);

      // Check if user document exists and get user data
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser.uid)
          .get();

      if (userDoc.exists) {
        final userData = userDoc.data()!;
        final userRole = userData['role'];
        final userStoreId = userData['storeId'];
        final userStoreName = userData['storeName'];

        // If user is invited (has role other than owner), use the assigned store
        if (userRole != 'owner' &&
            userStoreId != null &&
            userStoreId.isNotEmpty &&
            userStoreId != 'store_${currentUser.uid}') {

          // Davet edilen kullanıcı için doğru mağaza adını Firebase'den al
          String realStoreName = 'Mağaza';
          try {
            final storeDoc = await FirebaseFirestore.instance
                .collection('stores')
                .doc(userStoreId)
                .get();
            if (storeDoc.exists) {
              realStoreName = storeDoc.data()?['name'] ?? 'Mağaza';
              // Eğer mağaza adı boşsa, default kullan
              if (realStoreName.isEmpty || realStoreName == 'Mağaza') {
                realStoreName = 'mhmmdclk97\'in Mağazası'; // Geçici test adı
              }
            } else {
              realStoreName = 'mhmmdclk97\'in Mağazası'; // Mağaza bulunamazsa
            }
          } catch (e) {
            realStoreName = 'Davet Edildiğim Mağaza';
          }

          await setCurrentStore(userStoreId, realStoreName);
          return;
        }

        // If user's assigned storeId is different from their own store, they are invited
        final ownStoreId = 'store_${currentUser.uid}';
        if (userStoreId != null &&
            userStoreId.isNotEmpty &&
            userStoreId != ownStoreId) {

          // Davet edilen kullanıcı için doğru mağaza adını Firebase'den al
          String realStoreName = 'Mağaza';
          try {
            final storeDoc = await FirebaseFirestore.instance
                .collection('stores')
                .doc(userStoreId)
                .get();
            if (storeDoc.exists) {
              realStoreName = storeDoc.data()?['name'] ?? 'Mağaza';
              // Eğer mağaza adı boşsa, default kullan
              if (realStoreName.isEmpty || realStoreName == 'Mağaza') {
                realStoreName = 'mhmmdclk97\'in Mağazası'; // Geçici test adı
              }
            } else {
              realStoreName = 'mhmmdclk97\'in Mağazası'; // Mağaza bulunamazsa
            }
          } catch (e) {
            realStoreName = 'Davet Edildiğim Mağaza';
          }

          await setCurrentStore(userStoreId, realStoreName);
          return;
        }
        // If user is owner or no specific store assigned, use their own store

        // Get store name from stores collection
        String storeName = 'Benim Mağazam';
        try {
          final storeDoc = await FirebaseFirestore.instance
              .collection('stores')
              .doc(ownStoreId)
              .get();

          if (storeDoc.exists) {
            storeName = storeDoc.data()?['name'] ?? 'Benim Mağazam';
            if (storeName.isEmpty) storeName = 'Benim Mağazam';
          } else {
          }
        } catch (e) {
        }

        await setCurrentStore(ownStoreId, storeName);
        return;
      }

      // No user document, use default logic
      await getCurrentStoreId();
    } catch (e) {
      // Fallback to default
      await getCurrentStoreId();
    }
  }

  /// Clear cache and SharedPreferences (for logout)
  Future<void> clearCache() async {

    // Clear in-memory cache
    _cachedStoreId = null;
    _cachedStoreName = null;

    // Clear ONLY store-related SharedPreferences, not ALL
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_currentStoreIdKey);
    await prefs.remove(_currentStoreNameKey);
  }
}
