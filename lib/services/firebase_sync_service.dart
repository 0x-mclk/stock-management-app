import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../services/firebase_auth_service.dart';
import '../services/data_service.dart';
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

  // Get user's Firestore collection path
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
    final products = await _dataService.loadProducts();
    final batch = _firestore.batch();

    final productsRef =
        _firestore.collection(_getUserCollectionPath('products'));

    for (final product in products) {
      final docRef = productsRef.doc(product.id.toString());
      batch.set(docRef, {
        ...product.toMap(),
        'updatedAt': FieldValue.serverTimestamp(),
        'localId': product.id,
      });
    }

    await batch.commit();
  }

  // Sync sales to Firebase
  Future<void> _syncSalesToFirebase() async {
    final sales = await _dataService.loadSales();
    final batch = _firestore.batch();

    final salesRef = _firestore.collection(_getUserCollectionPath('sales'));

    for (final sale in sales) {
      final docRef = salesRef.doc(sale.id.toString());
      batch.set(docRef, {
        ...sale.toMap(),
        'updatedAt': FieldValue.serverTimestamp(),
        'localId': sale.id,
      });
    }

    await batch.commit();
  }

  // Sync suppliers to Firebase
  Future<void> _syncSuppliersToFirebase() async {
    final suppliers = await _dataService.loadSuppliers();
    final batch = _firestore.batch();

    final suppliersRef =
        _firestore.collection(_getUserCollectionPath('suppliers'));

    for (final supplier in suppliers) {
      final docRef = suppliersRef.doc(supplier.id.toString());
      batch.set(docRef, {
        ...supplier.toMap(),
        'updatedAt': FieldValue.serverTimestamp(),
        'localId': supplier.id,
      });
    }

    await batch.commit();
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
    final snapshot =
        await _firestore.collection(_getUserCollectionPath('products')).get();

    for (final doc in snapshot.docs) {
      final data = doc.data();
      final product = Product.fromMap(data);

      // Get all existing products and check if this one exists by barcode
      final existingProducts = await _dataService.loadProducts();
      final existingProduct = existingProducts
          .where((p) => p.barcode == product.barcode)
          .firstOrNull;

      if (existingProduct == null) {
        // Add new product
        await _dataService.saveProduct(product);
      } else {
        // Update existing product if Firebase version is newer
        final firebaseUpdatedAt = (data['updatedAt'] as Timestamp?)?.toDate();

        if (firebaseUpdatedAt != null &&
            firebaseUpdatedAt.isAfter(existingProduct.updatedAt)) {
          await _dataService
              .saveProduct(product.copyWith(id: existingProduct.id));
        }
      }
    }
  }

  // Sync sales from Firebase
  Future<void> _syncSalesFromFirebase() async {
    final snapshot =
        await _firestore.collection(_getUserCollectionPath('sales')).get();

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
      }
      // Sales usually don't get updated, so we don't need to check for updates
    }
  }

  // Sync suppliers from Firebase
  Future<void> _syncSuppliersFromFirebase() async {
    final snapshot =
        await _firestore.collection(_getUserCollectionPath('suppliers')).get();

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
      } else {
        // Update existing supplier if Firebase version is newer
        final firebaseUpdatedAt = (data['updatedAt'] as Timestamp?)?.toDate();

        if (firebaseUpdatedAt != null &&
            firebaseUpdatedAt.isAfter(existingSupplier.updatedAt)) {
          await _dataService
              .saveSupplier(supplier.copyWith(id: existingSupplier.id));
        }
      }
    }
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
