import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
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
  }

  Future<void> _ensureStoreId() async {
    if (_currentStoreId == null || _currentStoreId!.isEmpty) {
      await _initializeStoreId();
    }
  }

  /// Tedarikçiyi listeden veya Firestore'dan getir (detay ekranı için)
  Future<Supplier?> _resolveSupplier(String supplierId) async {
    final index = _suppliers.indexWhere((s) => s.id == supplierId);
    if (index != -1) return _suppliers[index];

    if (kIsWeb) {
      await _ensureStoreId();
      final storeId = _currentStoreId ?? '';
      if (storeId.isEmpty) return null;
      final doc =
          await FirestoreService.instance.getSupplier(storeId, supplierId);
      if (doc != null && doc.exists) {
        final data = doc.data() as Map<String, dynamic>;
        data['id'] = doc.id;
        return Supplier.fromMap(data);
      }
    }
    return null;
  }

  void _upsertSupplierInList(Supplier supplier) {
    final index = _suppliers.indexWhere((s) => s.id == supplier.id);
    if (index != -1) {
      _suppliers[index] = supplier;
    } else {
      _suppliers = [..._suppliers, supplier];
    }
  }

  Future<void> _persistSupplier(Supplier supplier) async {
    await _ensureStoreId();
    final storeId = _currentStoreId ?? '';
    if (storeId.isEmpty) {
      throw Exception('Mağaza bulunamadı');
    }

    if (kIsWeb) {
      final result = await FirestoreService.instance.saveSupplier(
        storeId,
        supplier.id,
        supplier.toFirebaseMap(),
      );
      if (result == null) {
        throw Exception('Tedarikçi Firestore\'a kaydedilemedi');
      }
      _upsertSupplierInList(supplier);
      notifyListeners();
    } else {
      await _databaseService.updateSupplier(supplier);
      _upsertSupplierInList(supplier);
      notifyListeners();
    }
  }

  // Initialize and load data from database
  Future<void> loadSuppliers() async {
    setLoading(true);
    try {
      await _initializeStoreId();

      final storeId = _currentStoreId ?? '';
      if (storeId.isEmpty) {
        throw Exception('Kullanıcı giriş yapmamış');
      }

      if (kIsWeb) {
        // Web: SQLite yok — Firebase stream başlat, veriler _handleFirebaseUpdate ile gelir
        _startFirebaseListener(storeId);
      } else {
        _suppliers = await _databaseService.getSuppliers(storeId);
        _startFirebaseListener(storeId);
        _syncAllSupplierPaymentHistories(storeId);
        notifyListeners();
      }
    } catch (e) {
      // hata görmezden gel
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
      });

      // Payment history listeners will be started per supplier as needed
      // New schema structure doesn't support global payment history listening
    } catch (e) {
    }
  }

  // Handle Firebase updates — tek kaynak: Firestore (mobil + web aynı listeyi görür)
  void _handleFirebaseUpdate(List docs) {
    final firebaseSuppliers = <Supplier>[];
    for (final doc in docs) {
      try {
        final data = doc.data() as Map<String, dynamic>;
        // Silinmiş / pasif kayıtları atla
        if (data['isActive'] == false) continue;
        data['id'] = doc.id;
        firebaseSuppliers.add(Supplier.fromMap(data));
      } catch (_) {
        // Tek hatalı kayıt tüm listeyi bozmasın
      }
    }
    _suppliers = firebaseSuppliers;
    notifyListeners();
  }

  void setLoading(bool loading) {
    if (_isLoading != loading) {
      _isLoading = loading;
      notifyListeners();
    }
  }

  Future<void> addSupplier(Supplier supplier) async {
    try {
      final storeId = _currentStoreId ?? '';
      if (storeId.isEmpty) {
        throw Exception('Kullanıcı giriş yapmamış');
      }

      final supplierId = supplier.id ?? const Uuid().v4();
      final supplierWithStore =
          supplier.copyWith(id: supplierId, storeId: storeId);

      if (kIsWeb) {
        // Web: Firestore'a kaydet, dönen ID ile anında listeye ekle (stream gecikmesini beklemeden)
        final docId = await FirestoreService.instance
            .saveSupplier(storeId, null, supplierWithStore.toFirebaseMap());
        if (docId == null) {
          throw Exception('Tedarikçi Firestore\'a kaydedilemedi');
        }
        final saved = supplierWithStore.copyWith(id: docId);
        _suppliers = [..._suppliers, saved];
        notifyListeners();
      } else {
        await _databaseService.createSupplier(supplierWithStore);
        await loadSuppliers();
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<void> updateSupplier(Supplier supplier) async {
    try {
      final storeId = _currentStoreId ?? '';
      if (storeId.isEmpty) {
        throw Exception('Kullanıcı giriş yapmamış');
      }

      final updatedSupplier = supplier.copyWith(
        storeId: storeId,
        updatedAt: DateTime.now(),
      );

      if (kIsWeb) {
        // Web: Firestore'da güncelle ve listeyi anında yansıt
        final result = await FirestoreService.instance.saveSupplier(
            storeId, updatedSupplier.id, updatedSupplier.toFirebaseMap());
        if (result == null) {
          throw Exception('Tedarikçi güncellenemedi');
        }
        final index = _suppliers.indexWhere((s) => s.id == updatedSupplier.id);
        if (index != -1) {
          _suppliers[index] = updatedSupplier;
        }
        notifyListeners();
      } else {
        await _databaseService.updateSupplier(updatedSupplier);
        final index =
            _suppliers.indexWhere((s) => s.id == updatedSupplier.id);
        if (index != -1) {
          _suppliers[index] = updatedSupplier;
          notifyListeners();
        }
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<void> removeSupplier(String supplierId) async {
    try {
      final storeId = _currentStoreId ?? '';
      if (storeId.isEmpty) {
        throw Exception('Kullanıcı giriş yapmamış');
      }

      if (kIsWeb) {
        // Web: Firestore'dan sil ve listeyi anında güncelle
        final success =
            await FirestoreService.instance.deleteSupplier(storeId, supplierId);
        if (!success) {
          throw Exception('Tedarikçi silinemedi');
        }
        _suppliers.removeWhere((s) => s.id == supplierId);
        notifyListeners();
      } else {
        _suppliers.firstWhere((s) => s.id == supplierId,
            orElse: () => throw Exception('Tedarikçi bulunamadı'));
        await _databaseService.deleteSupplier(supplierId, storeId);
        _suppliers.removeWhere((s) => s.id == supplierId);
        notifyListeners();
      }
    } catch (e) {
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
      final supplier = await _resolveSupplier(supplierId);
      if (supplier == null) {
        throw Exception('Tedarikçi bulunamadı');
      }

      final previousDebt = supplier.debt;
      final newDebt = supplier.debt - amount;
      final updatedSupplier = supplier.copyWith(
        debt: newDebt < 0 ? 0 : newDebt,
        updatedAt: DateTime.now(),
      );

      await _persistSupplier(updatedSupplier);
      await _savePaymentHistory(
        supplierId,
        'payment',
        amount,
        'Ödeme yapıldı',
        previousDebt,
        newDebt < 0 ? 0 : newDebt,
      );
    } catch (e) {
      rethrow;
    }
  }

  Future<void> addPurchase(String supplierId, double amount) async {
    try {
      final supplier = await _resolveSupplier(supplierId);
      if (supplier == null) {
        throw Exception('Tedarikçi bulunamadı');
      }

      final updatedSupplier = supplier.copyWith(
        totalPurchases: supplier.totalPurchases + amount,
        monthlyPurchases: supplier.monthlyPurchases + amount,
        yearlyPurchases: supplier.yearlyPurchases + amount,
        updatedAt: DateTime.now(),
      );

      await _persistSupplier(updatedSupplier);
    } catch (e) {
      rethrow;
    }
  }

  // Borç ekleme metodu
  Future<void> addDebt(String supplierId, double amount) async {
    try {
      final supplier = await _resolveSupplier(supplierId);
      if (supplier == null) {
        throw Exception('Tedarikçi bulunamadı');
      }

      final previousDebt = supplier.debt;
      final newDebt = supplier.debt + amount;
      final updatedSupplier = supplier.copyWith(
        debt: newDebt,
        updatedAt: DateTime.now(),
      );

      await _persistSupplier(updatedSupplier);
      await _savePaymentHistory(
        supplierId,
        'debt',
        amount,
        'Borç eklendi',
        previousDebt,
        newDebt,
      );
    } catch (e) {
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
    await _ensureStoreId();
    final storeId = _currentStoreId ?? '';
    if (storeId.isEmpty) return;

    final paymentId = const Uuid().v4();
    final createdAt = DateTime.now().toIso8601String();

    final firebaseData = {
      'id': paymentId,
      'supplierId': supplierId,
      'type': type,
      'amount': amount,
      'description': description,
      'previousDebt': previousDebt,
      'newDebt': newDebt,
      'created_at': createdAt,
      'storeId': storeId,
    };

    if (kIsWeb) {
      final success = await FirestoreService.instance.savePaymentHistory(
        storeId,
        supplierId,
        paymentId,
        firebaseData,
      );
      if (!success) {
        throw Exception('Ödeme geçmişi kaydedilemedi');
      }
      notifyListeners();
      return;
    }

    final paymentData = {
      'id': paymentId,
      'supplier_id': supplierId,
      'type': type,
      'amount': amount,
      'description': description,
      'previous_debt': previousDebt,
      'new_debt': newDebt,
      'created_at': createdAt,
    };

    await _databaseService.insert('payment_history', paymentData);
    _syncPaymentHistoryToFirebase(supplierId, paymentId, paymentData);
  }

  /// Sync payment history to Firebase (private method)
  void _syncPaymentHistoryToFirebase(String supplierId, String paymentId,
      Map<String, dynamic> paymentData) async {
    try {
      final storeId = _currentStoreId; // Use cached store ID

      if (storeId == null) {
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
      } else {
        // TODO: Mark for pending sync retry
      }
    } catch (e) {
      // TODO: Mark for pending sync retry
    }
  }

  // ✅ Ödeme geçmişini getirme metodu - Firebase senkronizasyonu ile
  Future<List<Map<String, dynamic>>> getPaymentHistory(
      String supplierId) async {
    try {
      await _ensureStoreId();
      final storeId = _currentStoreId ?? '';
      if (storeId.isEmpty) return [];

      if (kIsWeb) {
        final snapshot = await FirestoreService.instance
            .getPaymentHistory(storeId, supplierId);
        if (snapshot == null || snapshot.docs.isEmpty) return [];

        return snapshot.docs.map((doc) {
          final data = doc.data() as Map<String, dynamic>;
          return {
            'id': doc.id,
            'supplier_id': supplierId,
            'type': data['type']?.toString() ?? '',
            'amount': (data['amount'] ?? 0).toDouble(),
            'description': data['description']?.toString() ?? '',
            'previous_debt':
                (data['previousDebt'] ?? data['previous_debt'] ?? 0).toDouble(),
            'new_debt': (data['newDebt'] ?? data['new_debt'] ?? 0).toDouble(),
            'created_at': _paymentCreatedAtString(data['created_at']),
          };
        }).toList();
      }

      await _syncPaymentHistoryFromFirebase(supplierId, storeId);
      return await _databaseService.query(
        'payment_history',
        where: 'supplier_id = ?',
        whereArgs: [supplierId],
        orderBy: 'created_at DESC',
      );
    } catch (e) {
      return [];
    }
  }

  static String _paymentCreatedAtString(dynamic value) {
    if (value == null) return DateTime.now().toIso8601String();
    if (value is String) return value;
    try {
      return (value as dynamic).toDate().toIso8601String();
    } catch (_) {
      return DateTime.now().toIso8601String();
    }
  }

  /// Firebase'den payment history'yi çek ve SQLite'e senkronize et
  Future<void> _syncPaymentHistoryFromFirebase(
      String supplierId, String storeId) async {
    try {

      final querySnapshot = await FirestoreService.instance
          .getPaymentHistory(storeId, supplierId);

      if (querySnapshot != null && querySnapshot.docs.isNotEmpty) {

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
          } else {
            // Update existing transaction if needed
            await _databaseService.update(
              'payment_history',
              sqliteData,
              where: 'id = ?',
              whereArgs: [data['id']],
            );
          }
        }
      } else {
      }
    } catch (e) {
    }
  }

  // ==========================================
  // PAYMENT HISTORY REAL-TIME SYNC
  // ==========================================

  /// Start payment history listener for specific supplier
  StreamSubscription? startSupplierPaymentHistoryListener(String supplierId) {
    final storeId = currentStoreId;
    if (storeId.isEmpty) {
      return null;
    }

    try {
      return FirestoreService.instance
          .getPaymentHistoryStream(storeId, supplierId)
          .listen((snapshot) {
        _handleSupplierPaymentHistoryUpdate(supplierId, snapshot.docs);
      }, onError: (error) {
      });
    } catch (e) {
      return null;
    }
  }

  /// Handle payment history updates for specific supplier
  void _handleSupplierPaymentHistoryUpdate(String supplierId, List docs) async {
    if (kIsWeb) {
      notifyListeners();
      return;
    }
    try {
      for (final doc in docs) {
        final data = doc.data() as Map<String, dynamic>;
        data['id'] = doc.id;

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

        final existing = await _databaseService.query(
          'payment_history',
          where: 'id = ?',
          whereArgs: [data['id']],
        );

        if (existing.isEmpty) {
          await _databaseService.insert('payment_history', sqliteData);
        } else {
          await _databaseService.update(
            'payment_history',
            sqliteData,
            where: 'id = ?',
            whereArgs: [data['id']],
          );
        }
      }
      notifyListeners();
    } catch (e) {
      // ignore
    }
  }

  /// Sync payment history from Firebase for all suppliers (background task)
  void _syncAllSupplierPaymentHistories(String storeId) async {
    try {

      for (final supplier in _suppliers) {
        if (supplier.id != null) {
          // Background sync - don't await to avoid blocking UI
          _syncPaymentHistoryFromFirebase(supplier.id!, storeId)
              .catchError((e) {
          });

          // Small delay to avoid overwhelming Firebase
          await Future.delayed(const Duration(milliseconds: 100));
        }
      }
    } catch (e) {
    }
  }

  @override
  void dispose() {
    _firebaseListener?.cancel();
    _paymentHistoryListener?.cancel();
    super.dispose();
  }
}
