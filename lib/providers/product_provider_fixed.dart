import 'package:flutter/material.dart';
import '../models/product.dart';
import '../services/data_service.dart';

class ProductProvider extends ChangeNotifier {
  List<Product> _products = [];
  List<Product> _filteredProducts = [];
  String _searchQuery = '';
  bool _isLoading = false;
  bool _isInitialized = false;
  final DataService _dataService = DataService();

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
      _products = await _dataService.loadProducts();
      _isInitialized = true;
      _filterProducts();
      notifyListeners();
    } catch (e) {
      print('Error loading products: $e');
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
      await _dataService.saveProduct(product);
      await refreshProducts(); // Force refresh to get updated data
    } catch (e) {
      print('Error adding product: $e');
      rethrow;
    }
  }

  Future<void> updateProduct(Product product) async {
    try {
      await _dataService.saveProduct(product);
      final index = _products.indexWhere((p) => p.id == product.id);
      if (index != -1) {
        _products[index] = product;
        _filterProducts();
        notifyListeners();
      }
    } catch (e) {
      print('Error updating product: $e');
      rethrow;
    }
  }

  Future<void> removeProduct(String productId) async {
    try {
      await _dataService.deleteProduct(productId);
      _products.removeWhere((p) => p.id == productId);
      _filterProducts();
      notifyListeners();
    } catch (e) {
      print('Error removing product: $e');
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
}
