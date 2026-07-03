import 'dart:async';
import 'package:flutter/foundation.dart' show kIsWeb, ChangeNotifier;
import 'package:uuid/uuid.dart';
import '../models/purchase.dart';
import '../models/supplier.dart';
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
      String? finalStoreId = storeId;

      if (kIsWeb) {
        // Web: SQLite yok — doğrudan Firestore stream
        if (finalStoreId == null || finalStoreId.isEmpty) {
          _error = 'Store ID bulunamadı';
          _setLoading(false);
          return;
        }
        _startFirebaseSupplierListener(supplierId, finalStoreId);
        _setLoading(false);
        return;
      }

      final purchaseData =
          await _databaseService.getPurchasesBySupplier(supplierId);
      _purchases = purchaseData.map((data) => Purchase.fromMap(data)).toList();
      _setLoading(false);

      if (finalStoreId == null || finalStoreId.isEmpty) {
        if (_purchases.isNotEmpty) {
          finalStoreId = _purchases.first.storeId;
        } else {
          final supplierData =
              await _databaseService.getSupplierData(supplierId);
          if (supplierData != null) {
            finalStoreId = supplierData['store_id'];
          }
        }
      }

      if (finalStoreId != null && finalStoreId.isNotEmpty) {
        _startFirebaseSupplierListener(supplierId, finalStoreId);
      }
    } catch (e) {
      _error = 'Failed to load purchases: $e';
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
    } catch (e) {
      _error = 'Failed to load purchases: $e';
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
      if (kIsWeb) {
        final purchaseId = const Uuid().v4();
        final purchase = Purchase(
          id: purchaseId,
          supplierId: supplierId,
          storeId: storeId,
          productName: productName,
          amount: amount,
          purchaseDate: purchaseDate,
          paymentMethod: paymentMethod,
          notes: notes,
        );

        // Mobil ile aynı: belirli purchaseId ile kaydet (.add() değil — çift kayıt önlenir)
        final success = await _firestoreService.savePurchase(
          storeId,
          supplierId,
          purchaseId,
          purchase.toFirebaseMap(),
        );
        if (!success) {
          throw Exception('Alışveriş Firestore\'a kaydedilemedi');
        }

        await _updateSupplierPurchaseTotalsWeb(
          storeId,
          supplierId,
          amount,
          add: true,
        );

        // Listeyi stream günceller; burada ekleme yapma (çift satır oluşuyordu)
        return purchaseId;
      }

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
        await loadPurchasesBySupplier(supplierId, storeId: storeId);
        return purchaseId;
      } else {
        throw Exception('Failed to create purchase');
      }
    } catch (e) {
      _error = 'Failed to create purchase: $e';
      notifyListeners();
      return null;
    }
  }

  Future<void> _updateSupplierPurchaseTotalsWeb(
    String storeId,
    String supplierId,
    double amount, {
    required bool add,
  }) async {
    final doc = await _firestoreService.getSupplier(storeId, supplierId);
    if (doc == null || !doc.exists) return;

    final data = doc.data() as Map<String, dynamic>;
    data['id'] = doc.id;
    final supplier = Supplier.fromMap(data);
    final delta = add ? amount : -amount;

    final updated = supplier.copyWith(
      totalPurchases:
          (supplier.totalPurchases + delta).clamp(0, double.infinity),
      monthlyPurchases:
          (supplier.monthlyPurchases + delta).clamp(0, double.infinity),
      yearlyPurchases:
          (supplier.yearlyPurchases + delta).clamp(0, double.infinity),
      updatedAt: DateTime.now(),
    );

    await _firestoreService.saveSupplier(
      storeId,
      updated.id,
      updated.toFirebaseMap(),
    );
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
      return true;
    } catch (e) {
      _error = 'Failed to update purchase: $e';
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
      return true;
    } catch (e) {
      _error = 'Failed to delete purchase: $e';
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
          _handleFirebasePurchaseUpdate(snapshot.docs);
        },
        onError: (error) {
          _error = 'Firebase sync error: $error';
          notifyListeners();
        },
      );
    } catch (e) {
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
    } catch (e) {
    }
  }

  /// Start Firebase real-time listener for specific supplier purchases
  void _startFirebaseSupplierListener(String supplierId, String storeId) {
    _firebaseListener?.cancel(); // Önceki listener'ı iptal et

    try {

      _firebaseListener =
          _firestoreService.getPurchasesStream(storeId, supplierId).listen(
        (snapshot) {
          _handleFirebaseSupplierPurchaseUpdate(
              snapshot.docs, supplierId, storeId);
        },
        onError: (error) {
          _error = 'Firebase sync error: $error';
          notifyListeners();
        },
      );
    } catch (e) {
    }
  }

  /// Handle Firebase purchase updates for specific supplier
  void _handleFirebaseSupplierPurchaseUpdate(
      List<dynamic> docs, String supplierId, String storeId) async {
    try {
      final firebasePurchases = <Purchase>[];
      final seenIds = <String>{};
      for (final doc in docs) {
        try {
          if (!seenIds.add(doc.id)) continue;
          final data = doc.data() as Map<String, dynamic>;
          data['id'] = doc.id;
          data['store_id'] = storeId;
          data['supplier_id'] = supplierId;
          firebasePurchases.add(Purchase.fromMap(data));
        } catch (_) {}
      }

      if (!kIsWeb) {
        await _syncFirebasePurchasesToSQLite(firebasePurchases, supplierId);
      }

      _purchases = _dedupePurchases(firebasePurchases);
      notifyListeners();
    } catch (e) {
      // ignore
    }
  }

  /// Aynı dakikada aynı ürün+tutar (eski web çift kayıt) tek satır göster
  List<Purchase> _dedupePurchases(List<Purchase> purchases) {
    final seen = <String>{};
    final result = <Purchase>[];
    for (final p in purchases) {
      final minuteKey =
          '${p.productName}|${p.amount}|${p.purchaseDate.year}-${p.purchaseDate.month}-${p.purchaseDate.day}-${p.purchaseDate.hour}-${p.purchaseDate.minute}';
      if (seen.add(minuteKey)) {
        result.add(p);
      }
    }
    result.sort((a, b) => b.purchaseDate.compareTo(a.purchaseDate));
    return result;
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
        } catch (e) {
          // Purchase yoksa create et - fromFirebase=true ile sync döngüsü önlenir
          await _databaseService.createPurchase(purchaseData,
              fromFirebase: true);
        }
      }

      // Firebase sync sonrası supplier totals'ı doğru hesapla
      await _recalculateSupplierTotals(supplierId, firebasePurchases);
    } catch (e) {
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
    } catch (e) {
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
