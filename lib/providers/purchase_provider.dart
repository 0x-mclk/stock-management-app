import 'dart:async';
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
  StreamSubscription? _firebaseListener;

  List<Purchase> get purchases => _purchases;
  bool get isLoading => _isLoading;
  String? get error => _error;

  PurchaseProvider({
    DatabaseService? databaseService,
    FirestoreService? firestoreService,
  })  : _databaseService = databaseService ?? DatabaseService.instance,
        _firestoreService = firestoreService ?? FirestoreService.instance;

  /// Load purchases for a specific supplier with Firebase sync
  Future<void> loadPurchasesBySupplier(String supplierId,
      {String? storeId}) async {
    _setLoading(true);
    _error = null;

    try {
      // İlk olarak SQLite'dan yükle
      final purchaseData =
          await _databaseService.getPurchasesBySupplier(supplierId);
      _purchases = purchaseData.map((data) => Purchase.fromMap(data)).toList();
      print(
          '✅ Loaded ${_purchases.length} purchases from SQLite for supplier: $supplierId');

      // UI'ı güncelle
      _setLoading(false);

      // Store ID'yi belirle
      String? finalStoreId = storeId;
      if (finalStoreId == null || finalStoreId.isEmpty) {
        // SQLite'dan store ID çekmeye çalış
        if (_purchases.isNotEmpty) {
          finalStoreId = _purchases.first.storeId;
        } else {
          // Eğer purchase yoksa, tedarikçi bilgisinden al
          final supplierData =
              await _databaseService.getSupplierData(supplierId);
          if (supplierData != null) {
            finalStoreId = supplierData['store_id'];
          }
        }
      }

      // Şimdi Firebase listener başlat
      if (finalStoreId != null && finalStoreId.isNotEmpty) {
        _startFirebaseSupplierListener(supplierId, finalStoreId);
      } else {
        print('❌ Store ID bulunamadı, Firebase listener başlatılamıyor');
      }
    } catch (e) {
      _error = 'Failed to load purchases: $e';
      print('❌ Error loading purchases: $e');
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
      print(' updating purchase: $e');
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

  /// Start Firebase real-time listener for specific supplier purchases
  void _startFirebaseSupplierListener(String supplierId, String storeId) {
    _firebaseListener?.cancel(); // Önceki listener'ı iptal et

    try {
      print(
          '🔄 Starting Firebase listener for supplier: $supplierId, store: $storeId');

      _firebaseListener =
          _firestoreService.getPurchasesStream(storeId, supplierId).listen(
        (snapshot) {
          print(
              '🔄 Firebase purchase update received: ${snapshot.docs.length} documents for supplier: $supplierId');
          _handleFirebaseSupplierPurchaseUpdate(
              snapshot.docs, supplierId, storeId);
        },
        onError: (error) {
          print('❌ Firebase supplier purchases stream error: $error');
          _error = 'Firebase sync error: $error';
          notifyListeners();
        },
      );
    } catch (e) {
      print('❌ Error starting Firebase supplier purchase listener: $e');
    }
  }

  /// Handle Firebase purchase updates for specific supplier
  void _handleFirebaseSupplierPurchaseUpdate(
      List<dynamic> docs, String supplierId, String storeId) async {
    try {
      final firebasePurchases = docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        data['id'] = doc.id; // Firebase document ID
        // Store ID'yi garantile
        data['store_id'] = storeId;
        data['supplier_id'] = supplierId;
        return Purchase.fromMap(data);
      }).toList();

      // Firebase'den gelen verileri SQLite'a senkronize et
      await _syncFirebasePurchasesToSQLite(firebasePurchases, supplierId);

      // UI'ı güncelle
      _purchases = firebasePurchases;
      notifyListeners();

      print(
          '✅ Supplier purchases synced from Firebase: ${firebasePurchases.length} items');
    } catch (e) {
      print('❌ Error handling Firebase supplier purchase update: $e');
    }
  }

  /// Firebase verilerini SQLite'a senkronize et
  Future<void> _syncFirebasePurchasesToSQLite(
      List<Purchase> firebasePurchases, String supplierId) async {
    try {
      // Mevcut SQLite verilerini temizle (sadece bu supplier için)
      await _databaseService.deletePurchasesBySupplier(supplierId);

      // Firebase verilerini SQLite'a ekle - fromFirebase parametresi ile sync döngüsünü önle
      for (final purchase in firebasePurchases) {
        final purchaseData = purchase.toMap();

        try {
          // Update mevcut purchase'ı (fromFirebase=true ile sync döngüsü önlenir)
          await _databaseService.updatePurchase(purchaseData,
              fromFirebase: true);
          print('🔄 Attempt 1: Updating existing purchase: ${purchase.id}');
        } catch (e) {
          // Purchase yoksa create et - fromFirebase=true ile sync döngüsü önlenir
          await _databaseService.createPurchase(purchaseData,
              fromFirebase: true);
          print('✅ Purchase created in SQLite: ${purchase.id}');
        }
      }

      // Firebase sync sonrası supplier totals'ı doğru hesapla
      await _recalculateSupplierTotals(supplierId, firebasePurchases);

      print(
          '✅ ${firebasePurchases.length} purchases synced to SQLite for supplier: $supplierId');
    } catch (e) {
      print('❌ Error syncing purchases to SQLite: $e');
    }
  }

  /// Firebase sync sonrası supplier totals'ını yeniden hesapla
  Future<void> _recalculateSupplierTotals(
      String supplierId, List<Purchase> purchases) async {
    try {
      final totalAmount =
          purchases.fold(0.0, (sum, purchase) => sum + purchase.amount);

      // Supplier'ı doğru totals ile güncelle
      await _databaseService.recalculateSupplierTotals(supplierId, totalAmount);

      print(
          '🔄 Recalculated supplier totals for: $supplierId -> Total: $totalAmount');
    } catch (e) {
      print('❌ Error recalculating supplier totals: $e');
    }
  }

  /// Stop Firebase listener
  void stopFirebaseListener() {
    _firebaseListener?.cancel();
    _firebaseListener = null;
  }

  /// Clear all purchases
  void clearPurchases() {
    _purchases.clear();
    _error = null;
    stopFirebaseListener();
    notifyListeners();
  }

  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  @override
  void dispose() {
    stopFirebaseListener();
    super.dispose();
  }
}
