import 'package:flutter/material.dart';
import 'dart:async';
import '../models/product.dart';
import '../services/data_service.dart';
import '../services/store_selection_service.dart';
import '../services/firebase_sync_service.dart';
import '../services/firestore_service.dart';
import 'notification_provider.dart';

class ProductProvider extends ChangeNotifier {
  List<Product> _products = [];
  List<Product> _filteredProducts = [];
  String _searchQuery = '';
  bool _isLoading = false;
  bool _isInitialized = false;
  String? _currentStoreId;

  final DataService _dataService = DataService();
  final FirebaseSyncService _syncService = FirebaseSyncService();
  final FirestoreService _firestoreService = FirestoreService.instance;
  NotificationProvider? _notificationProvider;

  // 🔥 Firebase Real-Time Stream
  StreamSubscription? _firebaseSubscription;
  bool _firebaseListenerStarted = false;

  // Constructor
  ProductProvider() {
    print('🏗️ ProductProvider constructor called');
  }

  // Getters
  List<Product> get products {
    if (_searchQuery.isNotEmpty) {
      return _filteredProducts;
    }
    return _products;
  }

  bool get isLoading => _isLoading;
  String get searchQuery => _searchQuery;
  String get currentStoreId => _currentStoreId ?? '';
  bool get isInitialized => _isInitialized;

  // Set notification provider
  void setNotificationProvider(NotificationProvider notificationProvider) {
    _notificationProvider = notificationProvider;
  }

  // Initialize store ID
  Future<void> _initializeStoreId() async {
    final storeId = await StoreSelectionService.instance.getCurrentStoreId();
    _currentStoreId = storeId;
    print('🆔 Store ID initialized: $_currentStoreId');
  }

  // Load products from local database
  Future<void> _loadProductsFromDatabase() async {
    final storeId = _currentStoreId ?? '';
    if (storeId.isNotEmpty) {
      _products = await _dataService.loadProductsByStore(storeId, limit: null);
      _filterProducts();
      notifyListeners();
    }
  }

  // Main load products method
  Future<void> loadProducts() async {
    print('🚀 LOAD PRODUCTS CALLED! Starting entire process...');
    setLoading(true);
    try {
      // Initialize store ID first
      await _initializeStoreId();
      print('🆔 Store ID initialized: $_currentStoreId');

      final storeId = _currentStoreId ?? '';
      if (storeId.isEmpty) {
        print('❌ EMPTY STORE ID - User not logged in');
        throw Exception('Kullanıcı giriş yapmamış');
      }

      print('✅ Store ID is valid: $storeId, starting product loading...');

      // First load from local database
      _products = await _dataService.loadProductsByStore(storeId, limit: null);
      _isInitialized = true;
      _filterProducts();
      notifyListeners(); // Show local data first

      // Then sync with Firebase
      print('🔄 Starting Firebase sync for products...');
      await _syncService.syncFromFirebase();

      // Reload after Firebase sync
      _products = await _dataService.loadProductsByStore(storeId, limit: null);
      _filterProducts();

      print('🔍 LOADED PRODUCTS COUNT: ${_products.length}');

      // Start Firebase real-time updates
      _startFirebaseRealTimeStream(storeId);

      // Check low stock and update notifications
      _notificationProvider?.checkLowStockProducts(_products);

      notifyListeners();
      print('🔔 notifyListeners() called after Firebase sync');
    } catch (e) {
      print('❌ Error loading products: $e');
    } finally {
      setLoading(false);
    }
  }

  // 🔥 Firebase Real-Time Stream
  void _startFirebaseRealTimeStream(String storeId) {
    if (_firebaseListenerStarted) {
      print('🔥 Firebase listener already started, skipping...');
      return;
    }

    print('🔥 Starting Firebase Real-Time Stream for store: $storeId');

    // Cancel previous subscription
    _firebaseSubscription?.cancel();

    // Start Firebase stream
    _firebaseSubscription =
        _firestoreService.getStoreProductsStream(storeId).listen(
      (snapshot) {
        print('🔥 Real-time update received: ${snapshot.docs.length} products');
        _handleFirebaseStreamUpdate(snapshot);
      },
      onError: (error) {
        print('❌ Firebase stream error: $error');
      },
    );

    _firebaseListenerStarted = true;
    print('🔥 Firebase listener started successfully');
  }

  // Handle Firebase stream updates
  void _handleFirebaseStreamUpdate(dynamic snapshot) async {
    try {
      print('🔄 Processing Firebase stream update...');

      // Convert Firebase data to Product models
      final firebaseProducts = snapshot.docs.map<Product>((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return Product.fromMap({...data, 'id': doc.id});
      }).toList();

      // Update local database
      for (final product in firebaseProducts) {
        await _dataService.saveProduct(product);
      }

      // Reload products from database
      await _loadProductsFromDatabase();

      print(
          '✅ Real-time update completed: ${firebaseProducts.length} products');
    } catch (e) {
      print('❌ Error processing Firebase stream update: $e');
    }
  }

  // Force reload products
  Future<void> refreshProducts() async {
    _isInitialized = false;
    await loadProducts();
  }

  void setLoading(bool loading) {
    if (_isLoading != loading) {
      _isLoading = loading;
      notifyListeners();
    }
  }

  Future<void> addProduct(Product product) async {
    try {
      final storeId = _currentStoreId ?? '';
      if (storeId.isEmpty) {
        throw Exception('Kullanıcı giriş yapmamış');
      }

      final productWithStore = product.copyWith(storeId: storeId);
      await _dataService.saveProduct(productWithStore);

      // Sync to Firebase
      print('🔄 Syncing new product to Firebase...');
      await _syncService.syncToFirebase();

      await refreshProducts();
    } catch (e) {
      print('❌ Error adding product: $e');
      rethrow;
    }
  }

  Future<void> updateProduct(Product product) async {
    try {
      final storeId = _currentStoreId ?? '';
      if (storeId.isEmpty) {
        throw Exception('Kullanıcı giriş yapmamış');
      }

      if (product.storeId != storeId && product.storeId.isNotEmpty) {
        throw Exception('Bu ürünü düzenleme yetkiniz yok');
      }

      await _dataService.saveProduct(product);
      final index = _products.indexWhere((p) => p.id == product.id);
      if (index != -1) {
        _products[index] = product;
        _filterProducts();
        _notificationProvider?.checkLowStockProducts(_products);
        notifyListeners();
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<void> removeProduct(String productId) async {
    try {
      final storeId = _currentStoreId ?? '';
      if (storeId.isEmpty) {
        throw Exception('Kullanıcı giriş yapmamış');
      }

      final product = _products.firstWhere((p) => p.id == productId,
          orElse: () => throw Exception('Ürün bulunamadı'));
      if (product.storeId != storeId) {
        throw Exception('Bu ürünü silme yetkiniz yok');
      }

      await _dataService.deleteProduct(productId);
      _products.removeWhere((p) => p.id == productId);
      _filterProducts();
      notifyListeners();
    } catch (e) {
      rethrow;
    }
  }

  void setProducts(List<Product> products) {
    _products = products;
    _filterProducts();
    notifyListeners();
  }

  void searchProducts(String query) {
    _searchQuery = query;
    _filterProducts();
    notifyListeners();
  }

  void _filterProducts() {
    if (_searchQuery.isEmpty) {
      _filteredProducts = [];
    } else {
      _filteredProducts = _products.where((product) {
        return product.name
                .toLowerCase()
                .contains(_searchQuery.toLowerCase()) ||
            product.barcode.contains(_searchQuery) ||
            (product.description
                    ?.toLowerCase()
                    .contains(_searchQuery.toLowerCase()) ??
                false);
      }).toList();
    }
  }

  void clearSearch() {
    _searchQuery = '';
    _filteredProducts = [];
    notifyListeners();
  }

  Product? getProductByBarcode(String barcode) {
    try {
      return _products.firstWhere((product) => product.barcode == barcode);
    } catch (e) {
      return null;
    }
  }

  List<Product> getLowStockProducts() {
    return _products.where((product) => product.isLowStock).toList();
  }

  void updateStock(String productId, int newStock) {
    final index = _products.indexWhere((p) => p.id == productId);
    if (index != -1) {
      _products[index] = _products[index].copyWith(
        stock: newStock,
        updatedAt: DateTime.now(),
      );
      _filterProducts();
      notifyListeners();
    }
  }

  // Migration methods for Firestore
  Future<Map<String, dynamic>> getMigrationStatus() async {
    try {
      return {
        'sqliteCount': _products.length,
        'firestoreCount': 0,
        'needsMigration': _products.isNotEmpty,
        'hasStore': true,
        'storeId': 'default_store',
      };
    } catch (e) {
      return {
        'sqliteCount': 0,
        'firestoreCount': 0,
        'needsMigration': false,
        'hasStore': false,
        'storeId': null,
      };
    }
  }

  Future<bool> migrateProductsToFirestore() async {
    try {
      setLoading(true);
      await refreshProducts();
      return true;
    } catch (e) {
      return false;
    } finally {
      setLoading(false);
    }
  }

  // Clean up resources when provider is disposed
  @override
  void dispose() {
    _firebaseSubscription?.cancel();
    _firebaseListenerStarted = false;
    print('🧹 ProductProvider disposed - Firebase listener cancelled');
    super.dispose();
  }
}
