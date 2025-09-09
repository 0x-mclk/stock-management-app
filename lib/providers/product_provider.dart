import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart'; // ✅ Firebase Auth eklendi
import '../models/product.dart';
import '../services/data_service.dart';
import 'notification_provider.dart';

class ProductProvider extends ChangeNotifier {
  List<Product> _products = [];
  List<Product> _filteredProducts = [];
  String _searchQuery = '';
  bool _isLoading = false;
  bool _isInitialized = false;
  final DataService _dataService = DataService();
  NotificationProvider? _notificationProvider;

  // ✅ Current store ID getter
  String get currentStoreId {
    final currentUser = FirebaseAuth.instance.currentUser;
    return currentUser != null ? 'store_${currentUser.uid}' : '';
  }

  // NotificationProvider referansını set etmek için
  void setNotificationProvider(NotificationProvider notificationProvider) {
    _notificationProvider = notificationProvider;
  }

  List<Product> get products =>
      _filteredProducts.isEmpty && _searchQuery.isEmpty
          ? _products
          : _filteredProducts;

  bool get isLoading => _isLoading;
  String get searchQuery => _searchQuery;
  bool get isInitialized => _isInitialized;

  // Initialize and load data from database
  Future<void> loadProducts() async {
    setLoading(true);
    try {
      // ✅ Store ID ile filtrelenmiş ürünleri yükle
      final storeId = currentStoreId;
      if (storeId.isEmpty) {
        throw Exception('Kullanıcı giriş yapmamış');
      }

      _products = await _dataService.loadProductsByStore(storeId);
      _isInitialized = true;
      _filterProducts();

      // Stok kontrolü yap ve bildirimleri güncelle
      _notificationProvider?.checkLowStockProducts(_products);

      notifyListeners();
    } catch (e) {
      // // Debug print removed // Removed for production
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
      final storeId = currentStoreId;
      if (storeId.isEmpty) {
        throw Exception('Kullanıcı giriş yapmamış');
      }

      final productWithStore = product.copyWith(storeId: storeId);
      await _dataService.saveProduct(productWithStore);
      await refreshProducts(); // Force refresh to get updated data
    } catch (e) {
      // // Debug print removed // Removed for production
      rethrow;
    }
  }

  Future<void> updateProduct(Product product) async {
    try {
      // ✅ Store ID kontrolü - güvenlik için
      final storeId = currentStoreId;
      if (storeId.isEmpty) {
        throw Exception('Kullanıcı giriş yapmamış');
      }
      if (product.storeId != storeId) {
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
      final storeId = currentStoreId;
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
