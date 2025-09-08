import 'package:flutter/material.dart';
import '../models/sale.dart';
import '../models/product.dart';
import '../services/data_service.dart';
import 'product_provider.dart';

class CartItem {
  final Product product;
  int quantity;
  double discount;

  CartItem({
    required this.product,
    this.quantity = 1,
    this.discount = 0.0,
  });

  double get totalPrice => (product.salePrice * quantity) - discount;
}

class SalesProvider extends ChangeNotifier {
  final List<CartItem> _cartItems = [];
  List<Sale> _sales = [];
  String _paymentMethod = 'cash';
  double _totalDiscount = 0.0;
  bool _isLoading = false;
  bool _isInitialized = false;
  final DataService _dataService = DataService();

  List<CartItem> get cartItems => _cartItems;
  List<Sale> get sales => _sales;
  String get paymentMethod => _paymentMethod;
  double get totalDiscount => _totalDiscount;
  bool get isLoading => _isLoading;
  bool get isInitialized => _isInitialized;

  double get cartTotal {
    return _cartItems.fold(0.0, (total, item) => total + item.totalPrice);
  }

  double get finalTotal => cartTotal - _totalDiscount;

  // Initialize and load data from database
  Future<void> loadSales() async {
    setLoading(true);
    try {
      _sales = await _dataService.loadSales(limit: null); // Tüm satışları yükle
      _isInitialized = true;
      notifyListeners();
    } catch (e) {
      // // Debug print removed // Removed for production
    } finally {
      setLoading(false);
    }
  }

  // Force reload sales
  Future<void> refreshSales() async {
    _isInitialized = false;
    await loadSales();
  }

  void setLoading(bool loading) {
    if (_isLoading != loading) {
      _isLoading = loading;
      notifyListeners();
    }
  }

  void addToCart(Product product, {int quantity = 1}) {
    final existingIndex =
        _cartItems.indexWhere((item) => item.product.id == product.id);

    if (existingIndex != -1) {
      _cartItems[existingIndex].quantity += quantity;
    } else {
      _cartItems.add(CartItem(product: product, quantity: quantity));
    }

    notifyListeners();
  }

  void removeFromCart(String productId) {
    _cartItems.removeWhere((item) => item.product.id == productId);
    notifyListeners();
  }

  void updateQuantity(String productId, int quantity) {
    final index = _cartItems.indexWhere((item) => item.product.id == productId);
    if (index != -1) {
      if (quantity > 0) {
        _cartItems[index].quantity = quantity;
      } else {
        _cartItems.removeAt(index);
      }
      notifyListeners();
    }
  }

  void setPaymentMethod(String method) {
    _paymentMethod = method;
    notifyListeners();
  }

  void setTotalDiscount(double discount) {
    _totalDiscount = discount;
    notifyListeners();
  }

  void clearCart() {
    _cartItems.clear();
    _totalDiscount = 0.0;
    _paymentMethod = 'cash';
    notifyListeners();
  }

  void setSales(List<Sale> sales) {
    _sales = sales;
    notifyListeners();
  }

  Future<void> addSale(Sale sale) async {
    try {
      // // Debug print removed // Removed for production
      // // Debug print removed // Removed for production
      if (sale.items.isNotEmpty) {
        for (int i = 0; i < sale.items.length; i++) {
          // // Debug print removed // Removed for production
        }
      }

      await _dataService.saveSale(sale);
      await refreshSales(); // Force refresh to get updated data
    } catch (e) {
      // // Debug print removed // Removed for production
      rethrow;
    }
  }

  Future<void> updateSale(Sale updatedSale) async {
    try {
      await _dataService.updateSale(updatedSale);
      final index = _sales.indexWhere((sale) => sale.id == updatedSale.id);
      if (index != -1) {
        _sales[index] = updatedSale;
        notifyListeners();
      }
    } catch (e) {
      // // Debug print removed // Removed for production
      rethrow;
    }
  }

  Future<void> deleteSale(String saleId) async {
    try {
      await _dataService.deleteSale(saleId);
      _sales.removeWhere((sale) => sale.id == saleId);
      notifyListeners();
    } catch (e) {
      // // Debug print removed // Removed for production
      rethrow;
    }
  }

  double getTotalSalesAmount({DateTime? startDate, DateTime? endDate}) {
    var filteredSales = _sales;

    if (startDate != null && endDate != null) {
      filteredSales = _sales.where((sale) {
        return sale.createdAt
                .isAfter(startDate.subtract(const Duration(days: 1))) &&
            sale.createdAt.isBefore(endDate.add(const Duration(days: 1)));
      }).toList();
    }

    return filteredSales.fold(0.0, (total, sale) => total + sale.finalAmount);
  }

  List<Sale> getSalesByDateRange(DateTime startDate, DateTime endDate) {
    return _sales.where((sale) {
      return sale.createdAt
              .isAfter(startDate.subtract(const Duration(days: 1))) &&
          sale.createdAt.isBefore(endDate.add(const Duration(days: 1)));
    }).toList();
  }

  // Günlük satış kârı hesaplama
  double getDailyProfit(ProductProvider productProvider) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final tomorrow = today.add(const Duration(days: 1));

    final todaysSales = _sales.where((sale) {
      return sale.createdAt
              .isAfter(today.subtract(const Duration(milliseconds: 1))) &&
          sale.createdAt.isBefore(tomorrow);
    }).toList();

    double totalProfit = 0.0;

    for (final sale in todaysSales) {
      for (final item in sale.items) {
        // Ürünü product provider'dan bul
        final product = productProvider.products.firstWhere(
          (p) => p.id == item.productId,
          orElse: () => Product(
            barcode: item.productBarcode,
            name: item.productName,
            purchasePrice: 0.0, // Eğer ürün bulunamadıysa kâr hesaplayamayız
            salePrice: item.unitPrice,
            stock: 0,
          ),
        );

        // Kar = (Satış Fiyatı - Alış Fiyatı) * Miktar
        double itemProfit =
            (item.unitPrice - (product.purchasePrice ?? 0.0)) * item.quantity;
        totalProfit += itemProfit;
      }
    }

    return totalProfit;
  }

  // Günlük toplam satış miktarı
  double getDailyTotal() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final tomorrow = today.add(const Duration(days: 1));

    final todaysSales = _sales.where((sale) {
      return sale.createdAt
              .isAfter(today.subtract(const Duration(milliseconds: 1))) &&
          sale.createdAt.isBefore(tomorrow);
    }).toList();

    return todaysSales.fold(0.0, (total, sale) => total + sale.finalAmount);
  }
}
