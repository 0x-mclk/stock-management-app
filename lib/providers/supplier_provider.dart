import 'package:flutter/material.dart';
import '../models/supplier.dart';
import '../services/data_service.dart';

class SupplierProvider extends ChangeNotifier {
  List<Supplier> _suppliers = [];
  bool _isLoading = false;
  final DataService _dataService = DataService();

  List<Supplier> get suppliers => _suppliers;
  bool get isLoading => _isLoading;

  // Initialize and load data from database
  Future<void> loadSuppliers() async {
    setLoading(true);
    try {
      _suppliers = await _dataService.loadSuppliers();
      notifyListeners();
    } catch (e) {
      print('Error loading suppliers: $e');
    } finally {
      setLoading(false);
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
      await _dataService.saveSupplier(supplier);
      // Veritabanından güncel veriyi yükle
      await loadSuppliers();
    } catch (e) {
      print('Error adding supplier: $e');
      rethrow;
    }
  }

  Future<void> updateSupplier(Supplier supplier) async {
    try {
      await _dataService.saveSupplier(supplier);
      final index = _suppliers.indexWhere((s) => s.id == supplier.id);
      if (index != -1) {
        _suppliers[index] = supplier;
        notifyListeners();
      }
    } catch (e) {
      print('Error updating supplier: $e');
      rethrow;
    }
  }

  Future<void> removeSupplier(String supplierId) async {
    try {
      await _dataService.deleteSupplier(supplierId);
      _suppliers.removeWhere((s) => s.id == supplierId);
      notifyListeners();
    } catch (e) {
      print('Error removing supplier: $e');
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

        await _dataService.saveSupplier(updatedSupplier);
        _suppliers[supplierIndex] = updatedSupplier;

        // Payment history'e kaydet
        await _savePaymentHistory(supplierId, 'payment', amount,
            'Ödeme yapıldı', previousDebt, newDebt < 0 ? 0 : newDebt);

        notifyListeners();
      }
    } catch (e) {
      print('Error making payment: $e');
      rethrow;
    }
  }

  Future<void> addPurchase(String supplierId, double amount) async {
    try {
      final supplierIndex = _suppliers.indexWhere((s) => s.id == supplierId);
      if (supplierIndex != -1) {
        final supplier = _suppliers[supplierIndex];
        final updatedSupplier = supplier.copyWith(
          // debt: supplier.debt + amount,  // HATALI: Alışveriş tutarı borç değildir!
          totalPurchases: supplier.totalPurchases + amount,
          updatedAt: DateTime.now(),
        );

        await _dataService.saveSupplier(updatedSupplier);
        _suppliers[supplierIndex] = updatedSupplier;

        notifyListeners();
      }
    } catch (e) {
      print('Error adding purchase: $e');
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

        await _dataService.saveSupplier(updatedSupplier);
        _suppliers[supplierIndex] = updatedSupplier;

        // Payment history'e kaydet
        await _savePaymentHistory(
            supplierId, 'debt', amount, 'Borç eklendi', previousDebt, newDebt);

        notifyListeners();
      }
    } catch (e) {
      print('Error adding debt: $e');
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
      final paymentData = {
        'supplier_id': supplierId,
        'type': type,
        'amount': amount,
        'description': description,
        'previous_debt': previousDebt,
        'new_debt': newDebt,
        'created_at': DateTime.now().toIso8601String(),
      };

      await _dataService.insert('payment_history', paymentData);
    } catch (e) {
      print('Error saving payment history: $e');
    }
  }

  // Ödeme geçmişini getirme metodu (eski)
  Future<List<Map<String, dynamic>>> getPaymentHistory(
      String supplierId) async {
    try {
      return await _dataService.query(
        'payment_history',
        where: 'supplier_id = ?',
        whereArgs: [supplierId],
        orderBy: 'created_at DESC',
      );
    } catch (e) {
      print('Error getting payment history: $e');
      return [];
    }
  }
}
