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
    final sales = await _dataService.loadSales();
    final batch = _firestore.batch();

    final storeCollectionPath = await _getStoreCollectionPath('sales');
    final salesRef = _firestore.collection(storeCollectionPath);

    print('🔄 Syncing ${sales.length} sales to: $storeCollectionPath');

    for (final sale in sales) {
      final docRef = salesRef.doc(sale.id.toString());
      final saleData = {
        ...sale.toMap(),
        'updatedAt': FieldValue.serverTimestamp(),
        'localId': sale.id,
      };

      print('🔄 Syncing sale: ${sale.id} -> ${docRef.path}');
      batch.set(docRef, saleData);
    }

    await batch.commit();
    print('✅ Sales sync completed');
  }

  // Sync suppliers to Firebase
  Future<void> _syncSuppliersToFirebase() async {
    final suppliers = await _dataService.loadSuppliers();
    final batch = _firestore.batch();

    final storeCollectionPath = await _getStoreCollectionPath('suppliers');
    final suppliersRef = _firestore.collection(storeCollectionPath);

    print('🔄 Syncing ${suppliers.length} suppliers to: $storeCollectionPath');

    for (final supplier in suppliers) {
      final docRef = suppliersRef.doc(supplier.id.toString());
      batch.set(docRef, {
        ...supplier.toMap(),
        'updatedAt': FieldValue.serverTimestamp(),
        'localId': supplier.id,
      });
    }

    await batch.commit();
    print('✅ Suppliers sync completed');
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

    for (final doc in snapshot.docs) {
      final data = doc.data();
      final sale = Sale.fromMap(data);

      // Check if sale exists locally by checking if we have a sale with same timestamp and amount
      final existingSales = await _dataService.loadSales();
      final existingSale = existingSales
          .where((s) =>
              s.createdAt == sale.createdAt &&
              s.finalAmount == sale.finalAmount)
          .firstOrNull;

      if (existingSale == null) {
        // Add new sale
        await _dataService.saveSale(sale);
        print('➕ Added new sale: ${sale.id}');
      }
      // Sales usually don't get updated, so we don't need to check for updates
    }
    print('✅ Sales sync from Firebase completed');
  }

  // Sync suppliers from Firebase
  Future<void> _syncSuppliersFromFirebase() async {
    final storeCollectionPath = await _getStoreCollectionPath('suppliers');
    final snapshot = await _firestore.collection(storeCollectionPath).get();

    print(
        '🔄 Syncing ${snapshot.docs.length} suppliers from: $storeCollectionPath');

    for (final doc in snapshot.docs) {
      final data = doc.data();
      final supplier = Supplier.fromMap(data);

      // Check if supplier exists locally by name (assuming names are unique)
      final existingSuppliers = await _dataService.loadSuppliers();
      final existingSupplier =
          existingSuppliers.where((s) => s.name == supplier.name).firstOrNull;

      if (existingSupplier == null) {
        // Add new supplier
        await _dataService.saveSupplier(supplier);
        print('➕ Added new supplier: ${supplier.name}');
      } else {
        // Update existing supplier if Firebase version is newer
        final firebaseUpdatedAt = (data['updatedAt'] as Timestamp?)?.toDate();

        if (firebaseUpdatedAt != null &&
            firebaseUpdatedAt.isAfter(existingSupplier.updatedAt)) {
          await _dataService
              .saveSupplier(supplier.copyWith(id: existingSupplier.id));
          print('🔄 Updated supplier: ${supplier.name}');
        }
      }
    }
    print('✅ Suppliers sync from Firebase completed');
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
