import 'package:flutter/material.dart';
import '../models/sale.dart';
import '../models/product.dart';
import '../services/data_service.dart';
import '../services/store_selection_service.dart';
import '../services/firebase_sync_service.dart';
import 'product_provider.dart';
import 'realtime_product_provider.dart';

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

  // ✅ Store ID getter - Store Selection Service kullanarak
  String get currentStoreId {
    // Async operation - use FutureBuilder or initialize in advance
    return _currentStoreId ?? '';
  }

  String? _currentStoreId;

  // Initialize store ID
  Future<void> _initializeStoreId() async {
    final storeId = await StoreSelectionService.instance.getCurrentStoreId();
    _currentStoreId = storeId;
    notifyListeners();
  }

  double get cartTotal {
    return _cartItems.fold(0.0, (total, item) => total + item.totalPrice);
  }

  double get finalTotal => cartTotal - _totalDiscount;

  // Initialize and load data from database
  Future<void> loadSales() async {
    setLoading(true);
    try {
      // Initialize store ID first
      await _initializeStoreId();

      // ✅ Store ID ile filtrelenmiş satışları yükle
      final storeId = _currentStoreId ?? '';
      if (storeId.isEmpty) {
        throw Exception('Kullanıcı giriş yapmamış');
      }

      _sales = await _dataService.loadSalesByStore(storeId,
          limit: null); // Tüm satışları yükle
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
      // ✅ Store ID'sini otomatik ata ve doğrula
      final storeId = _currentStoreId ?? '';
      if (storeId.isEmpty) {
        throw Exception('Kullanıcı giriş yapmamış');
      }

      // ✅ Store ID'si boş olan satışlara store ID ata
      final saleWithStore =
          sale.storeId.isEmpty ? sale.copyWith(storeId: storeId) : sale;

      // ✅ Store ID uyuşmazlığı kontrolü
      if (saleWithStore.storeId != storeId) {
        print(
            '⚠️ Sale store ID mismatch: ${saleWithStore.storeId} vs current: $storeId');
        throw Exception('Satış mağaza ID uyuşmazlığı');
      }

      // // Debug print removed // Removed for production
      // // Debug print removed // Removed for production
      if (saleWithStore.items.isNotEmpty) {
        for (int i = 0; i < saleWithStore.items.length; i++) {
          // // Debug print removed // Removed for production
        }
      }

      await _dataService.saveSale(saleWithStore);
      await refreshSales(); // Force refresh to get updated data

      // 🔄 Satış kaydedildikten sonra hemen sync yap
      print('🔄 Sale saved, triggering immediate sync...');
      try {
        await FirebaseSyncService().performFullSync();
        print('✅ Immediate sync completed after sale');
      } catch (syncError) {
        print('⚠️ Immediate sync failed: $syncError');
        // Sync hata verirse de devam et, auto-sync sonra halleder
      }
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
    // Önce tedarikçi alışverişlerini çıkar (sadece müşteri satışları)
    var filteredSales =
        _sales.where((sale) => sale.supplierId == null).toList();

    if (startDate != null && endDate != null) {
      filteredSales = filteredSales.where((sale) {
        // Sadece belirtilen tarih aralığındaki satışları al (başlangıç ve bitiş dahil)
        return sale.createdAt.isAtSameMomentAs(startDate) ||
            sale.createdAt.isAfter(startDate) &&
                (sale.createdAt.isBefore(endDate) ||
                    sale.createdAt.isAtSameMomentAs(endDate));
      }).toList();
    }

    return filteredSales.fold(0.0, (total, sale) => total + sale.finalAmount);
  }

  List<Sale> getSalesByDateRange(DateTime startDate, DateTime endDate) {
    return _sales.where((sale) {
      // Önce tedarikçi alışverişlerini çıkar (sadece müşteri satışları)
      if (sale.supplierId != null) return false;

      // Sadece belirtilen tarih aralığındaki satışları al (başlangıç ve bitiş dahil)
      return sale.createdAt.isAtSameMomentAs(startDate) ||
          sale.createdAt.isAfter(startDate) &&
              (sale.createdAt.isBefore(endDate) ||
                  sale.createdAt.isAtSameMomentAs(endDate));
    }).toList();
  }

  // Günlük satış kârı hesaplama (RealtimeProductProvider overload)
  double getDailyProfitFromRealtime(RealtimeProductProvider realtimeProvider) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final tomorrow = DateTime(now.year, now.month, now.day + 1);

    final todaysSales = _sales.where((sale) {
      if (sale.supplierId != null) return false;
      return sale.createdAt.isAtSameMomentAs(today) ||
          sale.createdAt.isAfter(today) && sale.createdAt.isBefore(tomorrow);
    }).toList();

    double totalProfit = 0.0;

    for (final sale in todaysSales) {
      for (final item in sale.items) {
        final product = realtimeProvider.products.firstWhere(
          (p) => p.id == item.productId,
          orElse: () => Product(
            barcode: item.productBarcode,
            name: item.productName,
            purchasePrice: 0.0,
            salePrice: item.unitPrice,
            stock: 0,
            storeId: currentStoreId,
          ),
        );

        double itemProfit =
            (item.unitPrice - (product.purchasePrice ?? 0.0)) * item.quantity;
        totalProfit += itemProfit;
      }
    }

    return totalProfit;
  }

  // Günlük satış kârı hesaplama (eski ProductProvider - backward compatibility)
  double getDailyProfit(ProductProvider productProvider) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final tomorrow = DateTime(now.year, now.month, now.day + 1);

    // Önce tedarikçi alışverişlerini çıkar, sonra bugünün satışlarını al
    final todaysSales = _sales.where((sale) {
      // Sadece müşteri satışları (supplierId null olanlar)
      if (sale.supplierId != null) return false;

      // Sadece bugünün satışlarını al (00:00:00 - 23:59:59)
      return sale.createdAt.isAtSameMomentAs(today) ||
          sale.createdAt.isAfter(today) && sale.createdAt.isBefore(tomorrow);
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
            storeId: currentStoreId, // ✅ Placeholder ürün için store ID
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
    final tomorrow = DateTime(now.year, now.month, now.day + 1);

    final todaysSales = _sales.where((sale) {
      // Önce tedarikçi alışverişlerini çıkar (sadece müşteri satışları)
      if (sale.supplierId != null) return false;

      // Sadece bugünün satışlarını al (00:00:00 - 23:59:59)
      return sale.createdAt.isAtSameMomentAs(today) ||
          sale.createdAt.isAfter(today) && sale.createdAt.isBefore(tomorrow);
    }).toList();

    return todaysSales.fold(0.0, (total, sale) => total + sale.finalAmount);
  }
}
