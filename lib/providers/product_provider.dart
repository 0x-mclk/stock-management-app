import 'package:flutter/material.dart';
import '../models/product.dart';
import '../services/data_service.dart';
import '../services/store_selection_service.dart';
import '../services/firebase_sync_service.dart';
import 'notification_provider.dart';

class ProductProvider extends ChangeNotifier {
  List<Product> _products = [];
  List<Product> _filteredProducts = [];
  String _searchQuery = '';
  bool _isLoading = false;
  bool _isInitialized = false;
  final DataService _dataService = DataService();
  final FirebaseSyncService _syncService = FirebaseSyncService();
  NotificationProvider? _notificationProvider;

  // ✅ Current store ID getter
  String get currentStoreId {
    return _currentStoreId ?? '';
  }

  String? _currentStoreId;

  // Initialize store ID
  Future<void> _initializeStoreId() async {
    final storeId = await StoreSelectionService.instance.getCurrentStoreId();
    _currentStoreId = storeId;
    notifyListeners();
  }

  // NotificationProvider referansını set etmek için
  void setNotificationProvider(NotificationProvider notificationProvider) {
    _notificationProvider = notificationProvider;
  }

  List<Product> get products {
    // Search varsa filtered products, yoksa tüm products
    if (_searchQuery.isNotEmpty) {
      print('🔍 GETTER - Returning filtered: ${_filteredProducts.length}');
      return _filteredProducts;
    }
    print('🔍 GETTER - Returning all: ${_products.length}');
    return _products;
  }

  bool get isLoading => _isLoading;
  String get searchQuery => _searchQuery;
  bool get isInitialized => _isInitialized;

  // Initialize and load data from database
  Future<void> loadProducts() async {
    setLoading(true);
    try {
      // Initialize store ID first
      await _initializeStoreId();

      // ✅ Store ID ile filtrelenmiş ürünleri yükle
      final storeId = _currentStoreId ?? '';
      if (storeId.isEmpty) {
        throw Exception('Kullanıcı giriş yapmamış');
      }

      // First load from local database - NO LIMIT to get all products
      _products = await _dataService.loadProductsByStore(storeId, limit: null);
      _isInitialized = true;
      _filterProducts();
      notifyListeners(); // Show local data first

      // Then sync with Firebase
      print('🔄 Starting Firebase sync for products...');
      await _syncService.syncFromFirebase();

      // Reload after Firebase sync - NO LIMIT to get all products
      _products = await _dataService.loadProductsByStore(storeId, limit: null);
      _filterProducts();

      print('🔍 LOADED PRODUCTS COUNT: ${_products.length}');
      print('🔍 FILTERED PRODUCTS COUNT: ${_filteredProducts.length}');
      print('🔍 SEARCH QUERY: "$_searchQuery"');

      // Stok kontrolü yap ve bildirimleri güncelle
      _notificationProvider?.checkLowStockProducts(_products);

      notifyListeners();
      print('🔔 notifyListeners() called after Firebase sync');
    } catch (e) {
      print('❌ Error loading products: $e');
    } finally {
      setLoading(false);
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
      // ✅ Store ID'sini otomatik ata
      final storeId = _currentStoreId ?? '';
      if (storeId.isEmpty) {
        throw Exception('Kullanıcı giriş yapmamış');
      }

      print('🔍 ADD CHECK - Current Store: $storeId');
      print('🔍 ADD CHECK - Original Product Store: ${product.storeId}');

      final productWithStore = product.copyWith(storeId: storeId);
      print('🔍 ADD CHECK - Final Product Store: ${productWithStore.storeId}');

      await _dataService.saveProduct(productWithStore);

      // Immediately sync to Firebase
      print('🔄 Syncing new product to Firebase...');
      await _syncService.syncToFirebase();

      await refreshProducts(); // Force refresh to get updated data
    } catch (e) {
      print('❌ Error adding product: $e');
      rethrow;
    }
  }

  Future<void> updateProduct(Product product) async {
    try {
      // ✅ Store ID kontrolü - güvenlik için
      final storeId = _currentStoreId ?? '';
      if (storeId.isEmpty) {
        throw Exception('Kullanıcı giriş yapmamış');
      }

      // Debug store ID comparison
      print('🔍 UPDATE CHECK - Current Store: $storeId');
      print('🔍 UPDATE CHECK - Product Store: ${product.storeId}');
      print('🔍 UPDATE CHECK - Match: ${product.storeId == storeId}');

      if (product.storeId != storeId && product.storeId.isNotEmpty) {
        throw Exception('Bu ürünü düzenleme yetkiniz yok');
      }

      await _dataService.saveProduct(product);
      final index = _products.indexWhere((p) => p.id == product.id);
      if (index != -1) {
        _products[index] = product;
        _filterProducts();

        // Stok kontrolü yap ve bildirimleri güncelle
        _notificationProvider?.checkLowStockProducts(_products);

        notifyListeners();
      }
    } catch (e) {
      // // Debug print removed // Removed for production
      rethrow;
    }
  }

  Future<void> removeProduct(String productId) async {
    try {
      // ✅ Store ID kontrolü - güvenlik için
      final storeId = _currentStoreId ?? '';
      if (storeId.isEmpty) {
        throw Exception('Kullanıcı giriş yapmamış');
      }

      // Ürünün bu store'a ait olduğunu kontrol et
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
      // // Debug print removed // Removed for production
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
      // Return migration status information
      return {
        'sqliteCount': _products.length,
        'firestoreCount': 0, // This would come from Firestore count
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
      // Add migration logic here if needed
      // For now, just refresh products and return success
      await refreshProducts();
      return true;
    } catch (e) {
      // // Debug print removed // Removed for production
      return false;
    } finally {
      setLoading(false);
    }
  }
}
