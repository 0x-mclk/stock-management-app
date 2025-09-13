import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../services/firebase_auth_service.dart';
import '../services/data_service.dart';
import '../services/store_selection_service.dart';
import '../models/product.dart';
import '../models/sale.dart';
import '../models/supplier.dart';

class FirebaseSyncService {
  static final FirebaseSyncService _instance = FirebaseSyncService._internal();
  factory FirebaseSyncService() => _instance;
  FirebaseSyncService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final DataService _dataService = DataService();
  final FirebaseAuthService _authService = FirebaseAuthService.instance;

  bool _isSyncing = false;
  DateTime? _lastSyncTime;

  bool get isSyncing => _isSyncing;
  DateTime? get lastSyncTime => _lastSyncTime;

  // Connectivity check
  Future<bool> _hasConnection() async {
    final connectivityResult = await Connectivity().checkConnectivity();
    return connectivityResult != ConnectivityResult.none;
  }

  // Get store's Firestore collection path
  Future<String> _getStoreCollectionPath(String collection) async {
    final storeId = await StoreSelectionService.instance.getCurrentStoreId();
    if (storeId.isEmpty) throw Exception('Store ID bulunamadı');

    print('🔄 Firebase Sync - Store ID: $storeId, Collection: $collection');
    return 'stores/$storeId/$collection';
  }

  // Legacy method for backward compatibility
  String _getUserCollectionPath(String collection) {
    final userId = _authService.currentUser?.uid;
    if (userId == null) throw Exception('Kullanıcı oturumu bulunamadı');
    return 'users/$userId/$collection';
  }

  // Sync all data to Firebase
  Future<void> syncToFirebase() async {
    if (_isSyncing) return;
    if (!await _hasConnection()) throw Exception('İnternet bağlantısı yok');
    if (_authService.currentUser?.uid == null)
      throw Exception('Kullanıcı oturumu bulunamadı');

    _isSyncing = true;
    try {
      await _syncProductsToFirebase();
      await _syncSalesToFirebase();
      await _syncSuppliersToFirebase();

      _lastSyncTime = DateTime.now();
    } finally {
      _isSyncing = false;
    }
  }

  // Sync products to Firebase
  Future<void> _syncProductsToFirebase() async {
    try {
      // Get products for current store only
      final storeId = await StoreSelectionService.instance.getCurrentStoreId();
      final products =
          await _dataService.loadProductsByStore(storeId, limit: null);
      final batch = _firestore.batch();

      final storeCollectionPath = await _getStoreCollectionPath('products');
      final productsRef = _firestore.collection(storeCollectionPath);

      print('🔄 Syncing ${products.length} products to: $storeCollectionPath');

      for (final product in products) {
        final docRef = productsRef.doc(product.id.toString());
        final productData = {
          ...product.toMap(),
          'updatedAt': FieldValue.serverTimestamp(),
          'localId': product.id,
        };

        batch.set(docRef, productData);
      }

      print('🚀 Committing batch with ${products.length} products...');
      await batch.commit();
      print('✅ Products sync completed successfully!');
    } catch (e, stackTrace) {
      print('❌ ERROR in _syncProductsToFirebase: $e');
      print('📍 Stack trace: $stackTrace');
      rethrow;
    }
  }

  // Sync sales to Firebase
  Future<void> _syncSalesToFirebase() async {
    // ✅ KRITIK DÜZELTME: Sadece current store'un sales'lerini yükle
    final currentStoreId =
        await StoreSelectionService.instance.getCurrentStoreId();
    if (currentStoreId.isEmpty) {
      print('❌ Cannot sync sales: No current store ID');
      return;
    }

    // ✅ Store ID ile filtrelenmiş sales'leri yükle
    final sales =
        await _dataService.loadSalesByStore(currentStoreId, limit: null);
    final batch = _firestore.batch();

    final storeCollectionPath = await _getStoreCollectionPath('sales');
    final salesRef = _firestore.collection(storeCollectionPath);

    print(
        '🔄 Syncing ${sales.length} sales for store $currentStoreId to: $storeCollectionPath');

    for (final sale in sales) {
      // ✅ Store ID doğrulaması
      if (sale.storeId != currentStoreId) {
        print(
            '⚠️ Skipping sale ${sale.id} - wrong store ID: ${sale.storeId} vs $currentStoreId');
        continue;
      }

      final docRef = salesRef.doc(sale.id.toString());
      final saleData = {
        ...sale.toMap(),
        'updatedAt': FieldValue.serverTimestamp(),
        'localId': sale.id,
        'storeId': currentStoreId, // ✅ Explicit store ID
      };

      print(
          '🔄 Syncing sale: ${sale.id} -> ${docRef.path} for store: $currentStoreId');
      batch.set(docRef, saleData);
    }

    await batch.commit();
    print('✅ Sales sync completed for store: $currentStoreId');
  }

  // Sync suppliers to Firebase
  Future<void> _syncSuppliersToFirebase() async {
    // ✅ KRITIK DÜZELTME: Sadece current store'un suppliers'lerini yükle
    final currentStoreId =
        await StoreSelectionService.instance.getCurrentStoreId();
    if (currentStoreId.isEmpty) {
      print('❌ Cannot sync suppliers: No current store ID');
      return;
    }

    // ✅ Store ID ile filtrelenmiş suppliers'leri yükle
    final suppliers = await _dataService.loadSuppliersByStore(currentStoreId);
    final batch = _firestore.batch();

    final storeCollectionPath = await _getStoreCollectionPath('suppliers');
    final suppliersRef = _firestore.collection(storeCollectionPath);

    print(
        '🔄 Syncing ${suppliers.length} suppliers for store $currentStoreId to: $storeCollectionPath');

    for (final supplier in suppliers) {
      // ✅ Store ID doğrulaması
      if (supplier.storeId != currentStoreId) {
        print(
            '⚠️ Skipping supplier ${supplier.id} - wrong store ID: ${supplier.storeId} vs $currentStoreId');
        continue;
      }

      final docRef = suppliersRef.doc(supplier.id.toString());
      final supplierData = {
        ...supplier.toMap(),
        'updatedAt': FieldValue.serverTimestamp(),
        'localId': supplier.id,
        'storeId': currentStoreId, // ✅ Explicit store ID
      };

      batch.set(docRef, supplierData);
    }

    await batch.commit();
    print('✅ Suppliers sync completed for store: $currentStoreId');
  }

  // Sync from Firebase to local database
  Future<void> syncFromFirebase() async {
    if (_isSyncing) return;
    if (!await _hasConnection()) throw Exception('İnternet bağlantısı yok');
    if (_authService.currentUser?.uid == null)
      throw Exception('Kullanıcı oturumu bulunamadı');

    _isSyncing = true;
    try {
      await _syncProductsFromFirebase();
      await _syncSalesFromFirebase();
      await _syncSuppliersFromFirebase();

      _lastSyncTime = DateTime.now();
    } finally {
      _isSyncing = false;
    }
  }

  // Sync products from Firebase
  Future<void> _syncProductsFromFirebase() async {
    final storeCollectionPath = await _getStoreCollectionPath('products');
    final snapshot = await _firestore.collection(storeCollectionPath).get();

    print(
        '🔄 Syncing ${snapshot.docs.length} products from: $storeCollectionPath');

    // Get current store ID for filtering
    final storeId = await StoreSelectionService.instance.getCurrentStoreId();

    // ✅ Load existing products ONCE before the loop to prevent conflicts
    final existingProducts =
        await _dataService.loadProductsByStore(storeId, limit: null);
    print('📊 Before sync - Local products count: ${existingProducts.length}');

    // Create a map for faster barcode lookup
    final Map<String, Product> existingProductsByBarcode = {
      for (final product in existingProducts) product.barcode: product
    };

    for (final doc in snapshot.docs) {
      final data = doc.data();
      final product = Product.fromMap(data);

      // ✅ Use pre-loaded products map for fast lookup
      final existingProduct = existingProductsByBarcode[product.barcode];

      if (existingProduct == null) {
        // Add new product with proper store ID, but remove Firebase ID to let local DB generate new one
        final productWithStore = product.copyWith(
          forceNullId: true, // ⚠️ FORCE ID to be null for new products
          storeId: storeId,
        );
        print(
            '🆕 Adding NEW product - Firebase ID: ${product.id}, Name: ${product.name}, Barcode: ${product.barcode}');
        await _dataService.saveProduct(productWithStore);
        print('✅ Successfully added new product: ${product.name}');
      } else {
        // Update existing product if Firebase version is newer
        final firebaseUpdatedAt = (data['updatedAt'] as Timestamp?)?.toDate();

        if (firebaseUpdatedAt != null &&
            firebaseUpdatedAt.isAfter(existingProduct.updatedAt)) {
          final updatedProduct = product.copyWith(
            id: existingProduct.id, // Use local DB ID, not Firebase ID
            storeId: storeId, // Ensure store ID is preserved
          );
          print(
              '🔄 Updating existing product - Local ID: ${existingProduct.id}, Firebase ID: ${product.id}, Name: ${product.name}');
          await _dataService.saveProduct(updatedProduct);
          print('✅ Successfully updated product: ${product.name}');
        }
      }
    }

    // Log final local product count after sync
    final finalLocalProducts =
        await _dataService.loadProductsByStore(storeId, limit: null);
    print('📊 After sync - Local products count: ${finalLocalProducts.length}');
    print('✅ Products sync from Firebase completed');
  }

  // Sync sales from Firebase
  Future<void> _syncSalesFromFirebase() async {
    final storeCollectionPath = await _getStoreCollectionPath('sales');
    final snapshot = await _firestore.collection(storeCollectionPath).get();

    print(
        '🔄 Syncing ${snapshot.docs.length} sales from: $storeCollectionPath');

    // Get current store ID for validation
    final currentStoreId =
        await StoreSelectionService.instance.getCurrentStoreId();

    if (currentStoreId.isEmpty) {
      print('❌ Cannot sync sales from Firebase: No current store ID');
      return;
    }

    int syncedCount = 0;
    int skippedCount = 0;

    for (final doc in snapshot.docs) {
      final data = doc.data();
      var sale = Sale.fromMap(data);

      // ✅ Store ID validasyonu ve düzeltmesi
      if (sale.storeId.isEmpty) {
        print(
            '⚠️ Sale without store ID, assigning current store: $currentStoreId');
        sale = sale.copyWith(storeId: currentStoreId);
      }

      // ✅ KRITIK: Sadece current store'a ait sales'leri işle
      if (sale.storeId != currentStoreId) {
        print(
            '⚠️ Skipping sale ${sale.id} from different store: ${sale.storeId} vs current: $currentStoreId');
        skippedCount++;
        continue;
      }

      // Check if sale exists locally by checking if we have a sale with same timestamp and amount
      final existingSales =
          await _dataService.loadSalesByStore(currentStoreId, limit: null);
      final existingSale = existingSales
          .where((s) =>
              s.createdAt == sale.createdAt &&
              s.finalAmount == sale.finalAmount)
          .firstOrNull;

      if (existingSale == null) {
        // Add new sale with validated store ID
        await _dataService.saveSale(sale);
        print('➕ Added new sale: ${sale.id} for store: ${sale.storeId}');
        syncedCount++;
      }
      // Sales usually don't get updated, so we don't need to check for updates
    }

    print(
        '✅ Sales sync from Firebase completed - Synced: $syncedCount, Skipped: $skippedCount');
  }

  // Sync suppliers from Firebase
  Future<void> _syncSuppliersFromFirebase() async {
    final storeCollectionPath = await _getStoreCollectionPath('suppliers');
    final snapshot = await _firestore.collection(storeCollectionPath).get();

    print(
        '🔄 Syncing ${snapshot.docs.length} suppliers from: $storeCollectionPath');

    // Get current store ID for validation
    final currentStoreId =
        await StoreSelectionService.instance.getCurrentStoreId();

    if (currentStoreId.isEmpty) {
      print('❌ Cannot sync suppliers from Firebase: No current store ID');
      return;
    }

    int syncedCount = 0;
    int skippedCount = 0;

    for (final doc in snapshot.docs) {
      final data = doc.data();
      final supplier = Supplier.fromMap(data);

      // ✅ Store ID validasyonu
      if (supplier.storeId.isNotEmpty && supplier.storeId != currentStoreId) {
        print(
            '⚠️ Skipping supplier ${supplier.id} from different store: ${supplier.storeId} vs current: $currentStoreId');
        skippedCount++;
        continue;
      }

      // Check if supplier exists locally by name (assuming names are unique)
      final existingSuppliers =
          await _dataService.loadSuppliersByStore(currentStoreId);
      final existingSupplier =
          existingSuppliers.where((s) => s.name == supplier.name).firstOrNull;

      if (existingSupplier == null) {
        // Add new supplier with validated store ID
        final supplierWithStore = supplier.storeId.isEmpty
            ? supplier.copyWith(storeId: currentStoreId)
            : supplier;
        await _dataService.saveSupplier(supplierWithStore);
        print(
            '➕ Added new supplier: ${supplierWithStore.name} for store: ${supplierWithStore.storeId}');
        syncedCount++;
      } else {
        // Update existing supplier if Firebase version is newer
        final firebaseUpdatedAt = (data['updatedAt'] as Timestamp?)?.toDate();

        if (firebaseUpdatedAt != null &&
            firebaseUpdatedAt.isAfter(existingSupplier.updatedAt)) {
          final updatedSupplier = supplier.copyWith(
            id: existingSupplier.id,
            storeId: currentStoreId,
          );
          await _dataService.saveSupplier(updatedSupplier);
          print(
              '🔄 Updated supplier: ${updatedSupplier.name} for store: ${updatedSupplier.storeId}');
          syncedCount++;
        }
      }
    }

    print(
        '✅ Suppliers sync from Firebase completed - Synced: $syncedCount, Skipped: $skippedCount');
  }

  // Bidirectional sync (recommended)
  Future<void> performFullSync() async {
    if (!await _hasConnection()) throw Exception('İnternet bağlantısı yok');

    // First sync local changes to Firebase
    await syncToFirebase();

    // Then sync Firebase changes to local
    await syncFromFirebase();
  }

  // Real-time listeners for live sync
  Stream<List<Product>> getProductsStream() {
    if (_authService.currentUser?.uid == null) {
      return Stream.value([]);
    }

    return _firestore
        .collection(_getUserCollectionPath('products'))
        .orderBy('updatedAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        return Product.fromMap(doc.data());
      }).toList();
    });
  }

  Stream<List<Sale>> getSalesStream() {
    if (_authService.currentUser?.uid == null) {
      return Stream.value([]);
    }

    return _firestore
        .collection(_getUserCollectionPath('sales'))
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        return Sale.fromMap(doc.data());
      }).toList();
    });
  }

  // Auto-sync setup (call this once when user logs in)
  void setupAutoSync() {
    // Sync every 5 minutes if connected
    Timer.periodic(const Duration(minutes: 5), (timer) async {
      if (await _hasConnection() && _authService.currentUser?.uid != null) {
        try {
          await performFullSync();
        } catch (e) {
          // Log error but don't stop timer
          print('Auto-sync error: $e');
        }
      }
    });
  }

  // Manual sync trigger
  Future<void> forceSync() async {
    await performFullSync();
  }

  // Get sync status
  Map<String, dynamic> getSyncStatus() {
    return {
      'isSyncing': _isSyncing,
      'lastSyncTime': _lastSyncTime?.toIso8601String(),
      'isLoggedIn': _authService.currentUser?.uid != null,
    };
  }
}
