import 'package:flutter/material.dart';
import 'dart:async';
import '../models/product.dart';
import '../services/firestore_service.dart';
import '../services/store_selection_service.dart';

class RealtimeProductProvider extends ChangeNotifier {
  List<Product> _products = [];
  bool _isLoading = false;
  StreamSubscription? _firebaseSubscription;
  final FirestoreService _firestoreService = FirestoreService.instance;
  String? _currentStoreId;

  List<Product> get products => _products;
  bool get isLoading => _isLoading;
  String get currentStoreId => _currentStoreId ?? '';

  // Firebase Real-Time Stream ile ürünleri dinle
  Future<void> startRealtimeUpdates() async {
    print('🚀 Starting Firebase real-time updates...');

    // Store ID'yi al
    _currentStoreId = await StoreSelectionService.instance.getCurrentStoreId();

    if (_currentStoreId == null || _currentStoreId!.isEmpty) {
      print('❌ Store ID bulunamadı');
      return;
    }

    print('🔥 Store ID: $_currentStoreId');

    // Önceki subscription'ı iptal et
    _firebaseSubscription?.cancel();

    // Loading state'i aktifleştir
    _isLoading = true;
    notifyListeners();

    try {
      // Firebase stream'i başlat
      _firebaseSubscription =
          _firestoreService.getStoreProductsStream(_currentStoreId!).listen(
        (snapshot) {
          print('🔥 Firebase snapshot alındı: ${snapshot.docs.length} ürün');

          try {
            // Firebase verilerini Product modeline çevir
            final firebaseProducts = snapshot.docs.map((doc) {
              final data = doc.data() as Map<String, dynamic>;
              data['id'] = doc.id; // Firestore document ID'sini ekle
              return Product.fromMap(data);
            }).toList();

            // Ürün listesini güncelle
            _products = firebaseProducts;

            print('✅ Ürünler güncellendi: ${_products.length} adet');

            // Loading'i kapat
            _isLoading = false;

            // UI'ı güncelle
            notifyListeners();

            print('⚡ REAL-TIME UPDATE TAMAMLANDI!');
          } catch (e) {
            print('❌ Firebase snapshot işleme hatası: $e');
            _isLoading = false;
            notifyListeners();
          }
        },
        onError: (error) {
          print('❌ Firebase stream hatası: $error');
          _isLoading = false;
          notifyListeners();
        },
      );

      print('✅ Firebase real-time stream başlatıldı');
    } catch (e) {
      print('❌ Stream başlatma hatası: $e');
      _isLoading = false;
      notifyListeners();
    }
  }

  // Real-time güncellemeleri durdur
  void stopRealtimeUpdates() {
    print('🛑 Firebase real-time updates durduruluyor');
    _firebaseSubscription?.cancel();
    _firebaseSubscription = null;
  }

  // Ürün ekle ve Firebase'e senkronize et
  Future<bool> addProduct(Product product) async {
    if (_currentStoreId == null || _currentStoreId!.isEmpty) {
      print('❌ Store ID bulunamadı');
      return false;
    }

    try {
      _isLoading = true;
      notifyListeners();

      // Firebase'e ekle
      final success = await _firestoreService.saveProduct(
        _currentStoreId!,
        null, // null = yeni ürün
        product.toMap(),
      );

      if (success) {
        print('✅ Ürün Firebase\'e eklendi');
        // Real-time stream otomatik olarak güncellemeyi alacak
        return true;
      } else {
        print('❌ Ürün Firebase\'e eklenemedi');
        return false;
      }
    } catch (e) {
      print('❌ Ürün ekleme hatası: $e');
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Ürün güncelle
  Future<bool> updateProduct(Product product) async {
    if (_currentStoreId == null || _currentStoreId!.isEmpty) {
      print('❌ Store ID bulunamadı');
      return false;
    }

    try {
      _isLoading = true;
      notifyListeners();

      // Firebase'de güncelle
      final success = await _firestoreService.saveProduct(
        _currentStoreId!,
        product.id.toString(),
        product.toMap(),
      );

      if (success) {
        print('✅ Ürün Firebase\'de güncellendi');
        // Real-time stream otomatik olarak güncellemeyi alacak
        return true;
      } else {
        print('❌ Ürün Firebase\'de güncellenemedi');
        return false;
      }
    } catch (e) {
      print('❌ Ürün güncelleme hatası: $e');
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Ürün sil
  Future<bool> deleteProduct(String productId) async {
    if (_currentStoreId == null || _currentStoreId!.isEmpty) {
      print('❌ Store ID bulunamadı');
      return false;
    }

    try {
      _isLoading = true;
      notifyListeners();

      // Firebase'den sil
      final success =
          await _firestoreService.deleteProduct(_currentStoreId!, productId);

      if (success) {
        print('✅ Ürün Firebase\'den silindi');
        // Real-time stream otomatik olarak güncellemeyi alacak
        return true;
      } else {
        print('❌ Ürün Firebase\'den silinemedi');
        return false;
      }
    } catch (e) {
      print('❌ Ürün silme hatası: $e');
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _firebaseSubscription?.cancel();
    super.dispose();
  }
}
