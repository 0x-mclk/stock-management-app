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
  bool _isStarting = false; // guard: aynı anda iki kez başlatmayı önler

  List<Product> get products => _products;
  bool get isLoading => _isLoading;
  String get currentStoreId => _currentStoreId ?? '';

  void _setLoading(bool value) {
    if (_isLoading == value) return; // gereksiz rebuild'ı önle
    _isLoading = value;
    notifyListeners();
  }

  Future<void> startRealtimeUpdates() async {
    // Zaten çalışan bir stream varsa ve aynı mağaza ise yeniden başlatma
    if (_isStarting) return;
    _isStarting = true;

    final storeId = await StoreSelectionService.instance.getCurrentStoreId();

    if (storeId == null || storeId.isEmpty) {
      _isStarting = false;
      return;
    }

    // Aynı store için zaten aktif bir subscription varsa dokunma
    if (_firebaseSubscription != null && _currentStoreId == storeId) {
      _isStarting = false;
      return;
    }

    _currentStoreId = storeId;
    _firebaseSubscription?.cancel();
    _setLoading(true);

    try {
      _firebaseSubscription =
          _firestoreService.getStoreProductsStream(_currentStoreId!).listen(
        (snapshot) {
          try {
            final firebaseProducts = snapshot.docs.map((doc) {
              final data = doc.data() as Map<String, dynamic>;
              data['id'] = doc.id;
              return Product.fromMap(data);
            }).toList();
            _products = firebaseProducts;
          } catch (_) {
            // veri dönüşüm hatası — eski listeyi koru
          } finally {
            // loading bitti + UI'ı her durumda güncelle
            if (_isLoading) {
              _isLoading = false;
            }
            notifyListeners();
          }
        },
        onError: (_) => _setLoading(false),
      );
    } catch (_) {
      _setLoading(false);
    } finally {
      _isStarting = false;
    }
  }

  void stopRealtimeUpdates() {
    _firebaseSubscription?.cancel();
    _firebaseSubscription = null;
  }

  Future<bool> addProduct(Product product) async {
    if (_currentStoreId == null || _currentStoreId!.isEmpty) return false;
    try {
      return await _firestoreService.saveProduct(
            _currentStoreId!, null, product.toMap()) ??
          false;
    } catch (_) {
      return false;
    }
  }

  Future<bool> updateProduct(Product product) async {
    if (_currentStoreId == null || _currentStoreId!.isEmpty) return false;
    try {
      return await _firestoreService.saveProduct(
            _currentStoreId!, product.id.toString(), product.toMap()) ??
          false;
    } catch (_) {
      return false;
    }
  }

  Future<void> removeProduct(String productId) async {
    await deleteProduct(productId);
  }

  Future<bool> deleteProduct(String productId) async {
    if (_currentStoreId == null || _currentStoreId!.isEmpty) return false;
    try {
      return await _firestoreService.deleteProduct(
              _currentStoreId!, productId) ??
          false;
    } catch (_) {
      return false;
    }
  }

  @override
  void dispose() {
    _firebaseSubscription?.cancel();
    super.dispose();
  }
}
