import 'package:flutter/foundation.dart';
import '../models/purchase.dart';
import '../services/database_service.dart';
import '../services/firestore_service.dart';

class PurchaseProvider with ChangeNotifier {
  final DatabaseService _databaseService;
  final FirestoreService _firestoreService;

  List<Purchase> _purchases = [];
  bool _isLoading = false;
  String? _error;

  List<Purchase> get purchases => _purchases;
  bool get isLoading => _isLoading;
  String? get error => _error;

  PurchaseProvider({
    DatabaseService? databaseService,
    FirestoreService? firestoreService,
  })  : _databaseService = databaseService ?? DatabaseService.instance,
        _firestoreService = firestoreService ?? FirestoreService.instance;

  /// Load purchases for a specific supplier
  Future<void> loadPurchasesBySupplier(String supplierId) async {
    _setLoading(true);
    _error = null;

    try {
      final purchaseData =
          await _databaseService.getPurchasesBySupplier(supplierId);
      _purchases = purchaseData.map((data) => Purchase.fromMap(data)).toList();
      print(
          '✅ Loaded ${_purchases.length} purchases for supplier: $supplierId');
    } catch (e) {
      _error = 'Failed to load purchases: $e';
      print('❌ Error loading purchases: $e');
    } finally {
      _setLoading(false);
    }
  }

  /// Load all purchases for a store
  Future<void> loadAllPurchases(String storeId) async {
    _setLoading(true);
    _error = null;

    try {
      final purchaseData = await _databaseService.getAllPurchases(storeId);
      _purchases = purchaseData.map((data) => Purchase.fromMap(data)).toList();
      print('✅ Loaded ${_purchases.length} purchases for store: $storeId');
    } catch (e) {
      _error = 'Failed to load purchases: $e';
      print('❌ Error loading purchases: $e');
    } finally {
      _setLoading(false);
    }
  }

  /// Create new purchase
  Future<String?> createPurchase({
    required String supplierId,
    required String storeId,
    required String productName,
    required double amount,
    required DateTime purchaseDate,
    String paymentMethod = 'cash',
    String? notes,
  }) async {
    _error = null;

    try {
      final purchaseData = {
        'supplier_id': supplierId,
        'store_id': storeId,
        'product_name': productName,
        'amount': amount,
        'payment_method': paymentMethod,
        'notes': notes,
        'purchase_date': purchaseDate.toIso8601String(),
      };

      final purchaseId = await _databaseService.createPurchase(purchaseData);

      if (purchaseId != null) {
        // Reload purchases to reflect changes
        await loadPurchasesBySupplier(supplierId);
        print('✅ Purchase created successfully: $purchaseId');
        return purchaseId;
      } else {
        throw Exception('Failed to create purchase');
      }
    } catch (e) {
      _error = 'Failed to create purchase: $e';
      print('❌ Error creating purchase: $e');
      notifyListeners();
      return null;
    }
  }

  /// Update existing purchase
  Future<bool> updatePurchase(Purchase purchase) async {
    _error = null;

    try {
      await _databaseService.updatePurchase(purchase.toMap());

      // Update local list
      final index = _purchases.indexWhere((p) => p.id == purchase.id);
      if (index != -1) {
        _purchases[index] = purchase;
        notifyListeners();
      }

      print('✅ Purchase updated successfully: ${purchase.id}');
      return true;
    } catch (e) {
      _error = 'Failed to update purchase: $e';
      print('❌ Error updating purchase: $e');
      notifyListeners();
      return false;
    }
  }

  /// Delete purchase
  Future<bool> deletePurchase(String purchaseId, String supplierId) async {
    _error = null;

    try {
      await _databaseService.deletePurchase(purchaseId);

      // Remove from local list
      _purchases.removeWhere((p) => p.id == purchaseId);
      notifyListeners();

      print('✅ Purchase deleted successfully: $purchaseId');
      return true;
    } catch (e) {
      _error = 'Failed to delete purchase: $e';
      print('❌ Error deleting purchase: $e');
      notifyListeners();
      return false;
    }
  }

  /// Get total purchases amount for a supplier
  double getTotalPurchasesForSupplier(String supplierId) {
    return _purchases
        .where((p) => p.supplierId == supplierId)
        .fold(0.0, (sum, purchase) => sum + purchase.amount);
  }

  /// Get purchases for a date range
  List<Purchase> getPurchasesInDateRange(DateTime startDate, DateTime endDate) {
    return _purchases.where((purchase) {
      return purchase.purchaseDate
              .isAfter(startDate.subtract(const Duration(days: 1))) &&
          purchase.purchaseDate.isBefore(endDate.add(const Duration(days: 1)));
    }).toList();
  }

  /// Get total amount for date range
  double getTotalAmountInDateRange(DateTime startDate, DateTime endDate) {
    final purchasesInRange = getPurchasesInDateRange(startDate, endDate);
    return purchasesInRange.fold(0.0, (sum, purchase) => sum + purchase.amount);
  }

  /// Start Firebase real-time listener for all purchases in store
  void startFirebasePurchaseListener(String storeId) {
    try {
      _firestoreService.getAllPurchasesStream(storeId).listen(
        (snapshot) {
          print(
              '🔄 Firebase purchases update received: ${snapshot.docs.length} documents');
          _handleFirebasePurchaseUpdate(snapshot.docs);
        },
        onError: (error) {
          print('❌ Firebase purchases stream error: $error');
          _error = 'Firebase sync error: $error';
          notifyListeners();
        },
      );
    } catch (e) {
      print('❌ Error starting Firebase purchase listener: $e');
    }
  }

  /// Handle Firebase purchase updates
  void _handleFirebasePurchaseUpdate(List<dynamic> docs) {
    try {
      final firebasePurchases = docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        data['id'] = doc.id; // Firebase document ID
        return Purchase.fromMap(data);
      }).toList();

      // Update local list with Firebase data
      _purchases = firebasePurchases;
      notifyListeners();

      print(
          '✅ Purchases synced from Firebase: ${firebasePurchases.length} items');
    } catch (e) {
      print('❌ Error handling Firebase purchase update: $e');
    }
  }

  /// Clear all purchases
  void clearPurchases() {
    _purchases.clear();
    _error = null;
    notifyListeners();
  }

  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }
}
