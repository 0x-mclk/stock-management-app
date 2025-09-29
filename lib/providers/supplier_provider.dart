import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart'; // ✅ UUID generation için
import 'dart:async';
import '../models/supplier.dart';
import '../services/database_service.dart';
import '../services/store_selection_service.dart';
import '../services/firestore_service.dart';

class SupplierProvider extends ChangeNotifier {
  List<Supplier> _suppliers = [];
  bool _isLoading = false;
  final DatabaseService _databaseService = DatabaseService.instance;
  StreamSubscription? _firebaseListener;
  StreamSubscription? _paymentHistoryListener;

  List<Supplier> get suppliers => _suppliers;
  bool get isLoading => _isLoading;

  // ✅ Store ID getter - Store Selection Service kullanarak
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

  // Initialize and load data from database
  Future<void> loadSuppliers() async {
    setLoading(true);
    try {
      // Initialize store ID first
      await _initializeStoreId();

      // ✅ Store ID ile filtrelenmiş tedarikçileri yükle
      final storeId = _currentStoreId ?? '';
      if (storeId.isEmpty) {
        throw Exception('Kullanıcı giriş yapmamış');
      }

      _suppliers = await _databaseService.getSuppliers(storeId);

      // Start Firebase listener for real-time updates
      _startFirebaseListener(storeId);

      // 🔄 Sync payment history from Firebase for all suppliers
      _syncAllSupplierPaymentHistories(storeId);

      notifyListeners();
    } catch (e) {
      // // Debug print removed // Removed for production
    } finally {
      setLoading(false);
    }
  }

  // Start Firebase real-time listener
  void _startFirebaseListener(String storeId) {
    _firebaseListener?.cancel(); // Cancel existing listener
    _paymentHistoryListener
        ?.cancel(); // Cancel existing payment history listener

    try {
      // Start suppliers listener
      _firebaseListener = FirestoreService.instance
          .getSuppliersStream(storeId)
          .listen((snapshot) {
        _handleFirebaseUpdate(snapshot.docs);
      }, onError: (error) {
        print('❌ Firebase supplier listener error: $error');
      });

      // Payment history listeners will be started per supplier as needed
      // New schema structure doesn't support global payment history listening
      print('ℹ️  Payment history listeners will be managed per supplier');

      print('✅ Firebase listeners started for store: $storeId');
    } catch (e) {
      print('❌ Failed to start Firebase listeners: $e');
    }
  }

  // Handle Firebase updates
  void _handleFirebaseUpdate(List docs) async {
    try {
      print('🔍 DEBUG: Firebase docs received: ${docs.length}');

      final firebaseSuppliers = docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        print('🔍 DEBUG: Firebase doc data: $data');
        data['id'] = doc.id; // Firebase document ID'yi ekle
        return Supplier.fromMap(data);
      }).toList();

      print('🔍 DEBUG: Parsed suppliers: ${firebaseSuppliers.length}');

      // Update UI DIRECTLY from Firebase data
      _suppliers = firebaseSuppliers;
      notifyListeners();

      print(
          '✅ Suppliers synced from Firebase: ${firebaseSuppliers.length} items');
    } catch (e) {
      print('❌ Error handling Firebase supplier update: $e');
    }
  }

  void setLoading(bool loading) {
    if (_isLoading != loading) {
      _isLoading = loading;
      notifyListeners();
    }
  }

  Future<void> addSupplier(Supplier supplier) async {
    try {
      // ✅ Store ID'sini otomatik ata
      final storeId = _currentStoreId ?? '';
      if (storeId.isEmpty) {
        throw Exception('Kullanıcı giriş yapmamış');
      }

      final supplierWithStore = supplier.copyWith(storeId: storeId);
      await _databaseService.createSupplier(supplierWithStore);
      // Veritabanından güncel veriyi yükle
      await loadSuppliers();
    } catch (e) {
      // // Debug print removed // Removed for production
      rethrow;
    }
  }

  Future<void> updateSupplier(Supplier supplier) async {
    try {
      // ✅ Store ID kontrolü - güvenlik için
      final storeId = _currentStoreId ?? '';
      if (storeId.isEmpty) {
        throw Exception('Kullanıcı giriş yapmamış');
      }
      if (supplier.storeId != storeId) {
        throw Exception('Bu tedarikçiyi düzenleme yetkiniz yok');
      }

      await _databaseService.updateSupplier(supplier);
      final index = _suppliers.indexWhere((s) => s.id == supplier.id);
      if (index != -1) {
        _suppliers[index] = supplier;
        notifyListeners();
      }
    } catch (e) {
      // // Debug print removed // Removed for production
      rethrow;
    }
  }

  Future<void> removeSupplier(String supplierId) async {
    try {
      // ✅ Store ID kontrolü - güvenlik için
      final storeId = _currentStoreId ?? '';
      if (storeId.isEmpty) {
        throw Exception('Kullanıcı giriş yapmamış');
      }

      // Tedarikçinin bu store'a ait olduğunu kontrol et
      final supplier = _suppliers.firstWhere((s) => s.id == supplierId,
          orElse: () => throw Exception('Tedarikçi bulunamadı'));
      if (supplier.storeId != storeId) {
        throw Exception('Bu tedarikçiyi silme yetkiniz yok');
      }

      await _databaseService.deleteSupplier(supplierId, _currentStoreId ?? '');
      _suppliers.removeWhere((s) => s.id == supplierId);
      notifyListeners();
    } catch (e) {
      // // Debug print removed // Removed for production
      rethrow;
    }
  }

  void setSuppliers(List<Supplier> suppliers) {
    _suppliers = suppliers;
    notifyListeners();
  }

  List<Supplier> getSuppliersWithDebt() {
    return _suppliers.where((supplier) => supplier.debt > 0).toList();
  }

  double getTotalDebt() {
    return _suppliers.fold(0.0, (total, supplier) => total + supplier.debt);
  }

  Future<void> makePayment(String supplierId, double amount) async {
    try {
      final supplierIndex = _suppliers.indexWhere((s) => s.id == supplierId);
      if (supplierIndex != -1) {
        final supplier = _suppliers[supplierIndex];
        final previousDebt = supplier.debt;
        final newDebt = supplier.debt - amount;
        final updatedSupplier = supplier.copyWith(
          debt: newDebt < 0 ? 0 : newDebt,
          updatedAt: DateTime.now(),
        );

        await _databaseService.updateSupplier(updatedSupplier);
        _suppliers[supplierIndex] = updatedSupplier;

        // Payment history'e kaydet
        await _savePaymentHistory(supplierId, 'payment', amount,
            'Ödeme yapıldı', previousDebt, newDebt < 0 ? 0 : newDebt);

        notifyListeners();
      }
    } catch (e) {
      // // Debug print removed // Removed for production
      rethrow;
    }
  }

  Future<void> addPurchase(String supplierId, double amount) async {
    try {
      final supplierIndex = _suppliers.indexWhere((s) => s.id == supplierId);
      if (supplierIndex != -1) {
        final supplier = _suppliers[supplierIndex];
        final now = DateTime.now();

        // Aylık ve yıllık alışverişleri basit toplama ile hesapla
        // NOT: Gerçek uygulama için sales tablosundan tarih bazlı sorgu yapılmalı
        // Şimdilik basit toplama yapıyoruz
        double newMonthlyPurchases = supplier.monthlyPurchases + amount;
        double newYearlyPurchases = supplier.yearlyPurchases + amount;

        final updatedSupplier = supplier.copyWith(
          totalPurchases: supplier.totalPurchases + amount,
          monthlyPurchases: newMonthlyPurchases,
          yearlyPurchases: newYearlyPurchases,
          updatedAt: now,
        );

        await _databaseService.updateSupplier(updatedSupplier);
        _suppliers[supplierIndex] = updatedSupplier;

        print(
            '✅ Purchase added: Total=${updatedSupplier.totalPurchases}, Monthly=${updatedSupplier.monthlyPurchases}, Yearly=${updatedSupplier.yearlyPurchases}');
        notifyListeners();
      }
    } catch (e) {
      print('❌ Error in addPurchase: $e');
      rethrow;
    }
  }

  // Borç ekleme metodu
  Future<void> addDebt(String supplierId, double amount) async {
    try {
      final supplierIndex = _suppliers.indexWhere((s) => s.id == supplierId);
      if (supplierIndex != -1) {
        final supplier = _suppliers[supplierIndex];
        final previousDebt = supplier.debt;
        final newDebt = supplier.debt + amount;
        final updatedSupplier = supplier.copyWith(
          debt: newDebt,
          updatedAt: DateTime.now(),
        );

        await _databaseService.updateSupplier(updatedSupplier);
        _suppliers[supplierIndex] = updatedSupplier;

        // Payment history'e kaydet
        await _savePaymentHistory(
            supplierId, 'debt', amount, 'Borç eklendi', previousDebt, newDebt);

        notifyListeners();
      }
    } catch (e) {
      // // Debug print removed // Removed for production
      rethrow;
    }
  }

  // Payment history kaydetme metodu
  Future<void> _savePaymentHistory(
      String supplierId,
      String type,
      double amount,
      String description,
      double previousDebt,
      double newDebt) async {
    try {
      // ✅ Firebase uyumlu STRING ID generate et
      final uuid = Uuid();
      final paymentId = uuid.v4();

      final paymentData = {
        'id': paymentId, // ✅ STRING ID eklendi
        'supplier_id': supplierId,
        'type': type,
        'amount': amount,
        'description': description,
        'previous_debt': previousDebt,
        'new_debt': newDebt,
        'created_at': DateTime.now().toIso8601String(),
      };

      // ✅ Save to SQLite first (offline-first approach)
      await _databaseService.insert('payment_history', paymentData);
      print('✅ Payment history saved to SQLite with STRING ID: $paymentId');

      // ✅ Sync to Firebase (non-blocking)
      _syncPaymentHistoryToFirebase(supplierId, paymentId, paymentData);
    } catch (e) {
      print('❌ Error saving payment history: $e');
    }
  }

  /// Sync payment history to Firebase (private method)
  void _syncPaymentHistoryToFirebase(String supplierId, String paymentId,
      Map<String, dynamic> paymentData) async {
    try {
      final storeId = _currentStoreId; // Use cached store ID

      if (storeId == null) {
        print('❌ Cannot sync payment history: Store ID not available');
        return;
      }

      // Convert SQLite format to Firebase format
      final firebaseData = {
        'id': paymentData['id'],
        'supplierId': supplierId,
        'type': paymentData['type'],
        'amount': paymentData['amount'],
        'description': paymentData['description'],
        'previousDebt': paymentData['previous_debt'],
        'newDebt': paymentData['new_debt'],
        'created_at': paymentData['created_at'],
        'storeId': storeId,
      };

      final success = await FirestoreService.instance.savePaymentHistory(
        storeId,
        supplierId,
        paymentId,
        firebaseData,
      );

      if (success) {
        print('✅ Payment history synced to Firebase: $paymentId');
      } else {
        print('❌ Failed to sync payment history to Firebase: $paymentId');
        // TODO: Mark for pending sync retry
      }
    } catch (e) {
      print('❌ Error syncing payment history to Firebase: $e');
      // TODO: Mark for pending sync retry
    }
  }

  // ✅ Ödeme geçmişini getirme metodu - Firebase senkronizasyonu ile
  Future<List<Map<String, dynamic>>> getPaymentHistory(
      String supplierId) async {
    try {
      final storeId = currentStoreId;
      if (storeId.isEmpty) {
        print('❌ Store ID not available for payment history');
        return [];
      }

      // 🔄 İlk olarak Firebase'den verileri al ve SQLite'e senkronize et
      await _syncPaymentHistoryFromFirebase(supplierId, storeId);

      // 📱 SQLite'den güncel verileri döndür
      return await _databaseService.query(
        'payment_history',
        where: 'supplier_id = ?',
        whereArgs: [supplierId],
        orderBy: 'created_at DESC',
      );
    } catch (e) {
      print('❌ Error getting payment history: $e');
      return [];
    }
  }

  /// Firebase'den payment history'yi çek ve SQLite'e senkronize et
  Future<void> _syncPaymentHistoryFromFirebase(
      String supplierId, String storeId) async {
    try {
      print(
          '🔄 Syncing payment history from Firebase for supplier: $supplierId');

      final querySnapshot = await FirestoreService.instance
          .getPaymentHistory(storeId, supplierId);

      if (querySnapshot != null && querySnapshot.docs.isNotEmpty) {
        print(
            '✅ Found ${querySnapshot.docs.length} payment transactions in Firebase');

        for (final doc in querySnapshot.docs) {
          final data = doc.data() as Map<String, dynamic>;
          data['id'] = doc.id; // Firebase document ID'yi ekle

          // Convert Firebase format to SQLite format
          final sqliteData = {
            'id': data['id'],
            'supplier_id': supplierId,
            'type': data['type'],
            'amount': data['amount'],
            'description': data['description'] ?? '',
            'previous_debt': data['previousDebt'] ?? 0.0,
            'new_debt': data['newDebt'] ?? 0.0,
            'created_at': data['created_at'],
          };

          // Check if transaction exists in SQLite
          final existing = await _databaseService.query(
            'payment_history',
            where: 'id = ?',
            whereArgs: [data['id']],
          );

          if (existing.isEmpty) {
            // Insert new transaction to SQLite
            await _databaseService.insert('payment_history', sqliteData);
            print('✅ Payment transaction synced to SQLite: ${data['id']}');
          } else {
            // Update existing transaction if needed
            await _databaseService.update(
              'payment_history',
              sqliteData,
              where: 'id = ?',
              whereArgs: [data['id']],
            );
            print('✅ Payment transaction updated in SQLite: ${data['id']}');
          }
        }
      } else {
        print(
            'ℹ️  No payment history found in Firebase for supplier: $supplierId');
      }
    } catch (e) {
      print('❌ Error syncing payment history from Firebase: $e');
    }
  }

  // ==========================================
  // PAYMENT HISTORY REAL-TIME SYNC
  // ==========================================

  /// Start payment history listener for specific supplier
  StreamSubscription? startSupplierPaymentHistoryListener(String supplierId) {
    final storeId = currentStoreId;
    if (storeId.isEmpty) {
      print('❌ Cannot start payment history listener: Store ID not available');
      return null;
    }

    try {
      return FirestoreService.instance
          .getPaymentHistoryStream(storeId, supplierId)
          .listen((snapshot) {
        _handleSupplierPaymentHistoryUpdate(supplierId, snapshot.docs);
      }, onError: (error) {
        print(
            '❌ Payment history listener error for supplier $supplierId: $error');
      });
    } catch (e) {
      print(
          '❌ Failed to start payment history listener for supplier $supplierId: $e');
      return null;
    }
  }

  /// Handle payment history updates for specific supplier
  void _handleSupplierPaymentHistoryUpdate(String supplierId, List docs) async {
    try {
      print(
          '🔍 Payment history update for supplier $supplierId: ${docs.length} transactions');

      for (final doc in docs) {
        final data = doc.data() as Map<String, dynamic>;
        data['id'] = doc.id; // Firebase document ID'yi ekle

        // Convert Firebase format to SQLite format
        final sqliteData = {
          'id': data['id'],
          'supplier_id': supplierId,
          'type': data['type'],
          'amount': data['amount'],
          'description': data['description'] ?? '',
          'previous_debt': data['previousDebt'] ?? 0.0,
          'new_debt': data['newDebt'] ?? 0.0,
          'created_at': data['created_at'],
        };

        // Check if transaction exists in SQLite
        final existing = await _databaseService.query(
          'payment_history',
          where: 'id = ?',
          whereArgs: [data['id']],
        );

        if (existing.isEmpty) {
          // Insert new transaction to SQLite
          await _databaseService.insert('payment_history', sqliteData);
          print('✅ Payment transaction synced to SQLite: ${data['id']}');
        } else {
          // Update existing transaction if needed
          await _databaseService.update(
            'payment_history',
            sqliteData,
            where: 'id = ?',
            whereArgs: [data['id']],
          );
          print('✅ Payment transaction updated in SQLite: ${data['id']}');
        }
      }

      // Notify listeners to update UI
      notifyListeners();
    } catch (e) {
      print(
          '❌ Error handling payment history update for supplier $supplierId: $e');
    }
  }

  /// Sync payment history from Firebase for all suppliers (background task)
  void _syncAllSupplierPaymentHistories(String storeId) async {
    try {
      print(
          '🔄 Starting background sync of payment histories for all suppliers');

      for (final supplier in _suppliers) {
        if (supplier.id != null) {
          // Background sync - don't await to avoid blocking UI
          _syncPaymentHistoryFromFirebase(supplier.id!, storeId)
              .catchError((e) {
            print('❌ Background sync error for supplier ${supplier.id}: $e');
          });

          // Small delay to avoid overwhelming Firebase
          await Future.delayed(const Duration(milliseconds: 100));
        }
      }

      print(
          '✅ Background payment history sync initiated for ${_suppliers.length} suppliers');
    } catch (e) {
      print('❌ Error in background payment history sync: $e');
    }
  }

  @override
  void dispose() {
    _firebaseListener?.cancel();
    _paymentHistoryListener?.cancel();
    super.dispose();
  }
}
