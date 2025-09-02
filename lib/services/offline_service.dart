import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class OfflineService extends ChangeNotifier {
  static final OfflineService _instance = OfflineService._internal();
  factory OfflineService() => _instance;
  OfflineService._internal();

  List<Map<String, dynamic>> _pendingOperations = [];
  List<Map<String, dynamic>> get pendingOperations => _pendingOperations;

  bool get hasPendingOperations => _pendingOperations.isNotEmpty;
  int get pendingOperationsCount => _pendingOperations.length;

  Future<void> loadPendingOperations() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? operationsJson = prefs.getString('pending_operations');

      if (operationsJson != null) {
        final List<dynamic> operationsList = json.decode(operationsJson);
        _pendingOperations = operationsList.cast<Map<String, dynamic>>();
        notifyListeners();
      }
    } catch (e) {
      // Debug print removed
    }
  }

  Future<void> _savePendingOperations() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String operationsJson = json.encode(_pendingOperations);
      await prefs.setString('pending_operations', operationsJson);
      notifyListeners();
    } catch (e) {
      // Debug print removed
    }
  }

  // Offline operasyon ekleme
  Future<void> addPendingOperation({
    required String type, // 'product_add', 'sale_add', 'customer_add', etc.
    required Map<String, dynamic> data,
    String? description,
  }) async {
    final operation = {
      'id': DateTime.now().millisecondsSinceEpoch.toString(),
      'type': type,
      'data': data,
      'description': description ?? _getOperationDescription(type, data),
      'timestamp': DateTime.now().toIso8601String(),
    };

    _pendingOperations.add(operation);
    await _savePendingOperations();
  }

  String _getOperationDescription(String type, Map<String, dynamic> data) {
    switch (type) {
      case 'product_add':
        return 'Ürün eklendi: ${data['name'] ?? 'Bilinmeyen'}';
      case 'product_update':
        return 'Ürün güncellendi: ${data['name'] ?? 'Bilinmeyen'}';
      case 'product_delete':
        return 'Ürün silindi';
      case 'sale_add':
        return 'Satış kaydedildi: ₺${data['totalAmount']?.toStringAsFixed(2) ?? '0.00'}';
      case 'supplier_add':
        return 'Tedarikçi eklendi: ${data['name'] ?? 'Bilinmeyen'}';
      case 'supplier_update':
        return 'Tedarikçi güncellendi: ${data['name'] ?? 'Bilinmeyen'}';
      default:
        return 'Bilinmeyen işlem';
    }
  }

  // Belirli bir operasyonu kaldır
  Future<void> removePendingOperation(String operationId) async {
    _pendingOperations.removeWhere((op) => op['id'] == operationId);
    await _savePendingOperations();
  }

  // Tüm bekleyen operasyonları temizle
  Future<void> clearPendingOperations() async {
    _pendingOperations.clear();
    await _savePendingOperations();
  }

  // Senkronizasyon simülasyonu (gerçek API entegrasyonunda kullanılacak)
  Future<bool> syncPendingOperations() async {
    if (_pendingOperations.isEmpty) return true;

    try {
      // Burada gerçek API'ye gönderim yapılacak
      // Şimdilik başarılı olduğunu varsayıyoruz

      await Future.delayed(const Duration(seconds: 2)); // Simülasyon

      // Tüm operasyonlar başarıyla senkronize edildi
      await clearPendingOperations();

      return true;
    } catch (e) {
      // Debug print removed
      return false;
    }
  }

  // Operasyon detaylarını al
  Map<String, dynamic>? getOperationById(String operationId) {
    try {
      return _pendingOperations.firstWhere((op) => op['id'] == operationId);
    } catch (e) {
      return null;
    }
  }

  // Operasyon türüne göre filtrele
  List<Map<String, dynamic>> getOperationsByType(String type) {
    return _pendingOperations.where((op) => op['type'] == type).toList();
  }

  // Son operasyon zamanını al
  DateTime? getLastOperationTime() {
    if (_pendingOperations.isEmpty) return null;

    try {
      final lastOp = _pendingOperations.last;
      return DateTime.parse(lastOp['timestamp']);
    } catch (e) {
      return null;
    }
  }

  // Operasyon istatistikleri
  Map<String, int> getOperationStats() {
    final stats = <String, int>{};

    for (final operation in _pendingOperations) {
      final type = operation['type'] as String;
      stats[type] = (stats[type] ?? 0) + 1;
    }

    return stats;
  }

  // Operasyon özetini al (kullanıcı dostu formatta)
  Map<String, int> getPendingOperationsSummary() {
    final summary = <String, int>{};

    for (final operation in _pendingOperations) {
      final type = operation['type'] as String;
      String displayType;

      // Operasyon türlerini kullanıcı dostu isimlere çevir
      switch (type) {
        case 'product_add':
        case 'product_update':
        case 'product_delete':
          displayType = 'Ürün İşlemleri';
          break;
        case 'sale_add':
        case 'sale_update':
        case 'sale_delete':
          displayType = 'Satış İşlemleri';
          break;
        case 'supplier_add':
        case 'supplier_update':
        case 'supplier_delete':
          displayType = 'Tedarikçi İşlemleri';
          break;
        case 'transaction_add':
        case 'transaction_update':
        case 'transaction_delete':
          displayType = 'İşlem Kayıtları';
          break;
        default:
          displayType = 'Diğer İşlemler';
      }

      summary[displayType] = (summary[displayType] ?? 0) + 1;
    }

    return summary;
  }

  // Offline mod mesajları
  String getOfflineModeMessage() {
    if (_pendingOperations.isEmpty) {
      return 'Offline moddasınız. Yaptığınız değişiklikler internet bağlandığında senkronize edilecek.';
    } else {
      return '${_pendingOperations.length} bekleyen işlem var. Internet bağlandığında otomatik senkronize edilecek.';
    }
  }

  // Veri boyutu tahmini
  String getDataSizeEstimate() {
    try {
      final jsonString = json.encode(_pendingOperations);
      final bytes = utf8.encode(jsonString).length;

      if (bytes < 1024) {
        return '$bytes B';
      } else if (bytes < 1024 * 1024) {
        return '${(bytes / 1024).toStringAsFixed(1)} KB';
      } else {
        return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
      }
    } catch (e) {
      return 'Bilinmiyor';
    }
  }
}




