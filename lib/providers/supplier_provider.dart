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

    try {
      _firebaseListener = FirestoreService.instance
          .getSuppliersStream(storeId)
          .listen((snapshot) {
        _handleFirebaseUpdate(snapshot.docs);
      }, onError: (error) {
        print('❌ Firebase supplier listener error: $error');
      });

      print('✅ Firebase supplier listener started for store: $storeId');
    } catch (e) {
      print('❌ Failed to start Firebase supplier listener: $e');
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

      await _databaseService.insert('payment_history', paymentData);
      print('✅ Payment history saved with STRING ID: $paymentId');
    } catch (e) {
      // // Debug print removed // Removed for production
    }
  }

  // Ödeme geçmişini getirme metodu (eski)
  Future<List<Map<String, dynamic>>> getPaymentHistory(
      String supplierId) async {
    try {
      return await _databaseService.query(
        'payment_history',
        where: 'supplier_id = ?',
        whereArgs: [supplierId],
        orderBy: 'created_at DESC',
      );
    } catch (e) {
      // // Debug print removed // Removed for production
      return [];
    }
  }

  @override
  void dispose() {
    _firebaseListener?.cancel();
    super.dispose();
  }
}
