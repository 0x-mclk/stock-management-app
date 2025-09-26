import 'package:flutter/material.dart';
import 'dart:async';
import '../models/product.dart';
import '../services/data_service.dart';
import '../services/store_selection_service.dart';
import '../services/firebase_sync_service.dart';
import '../services/firestore_service.dart';
import '../services/connectivity_service.dart';
import '../services/offline_service.dart';
import 'notification_provider.dart';

// ✅ Add these imports for Firestore document changes
import 'package:cloud_firestore/cloud_firestore.dart';

class ProductProvider extends ChangeNotifier {
  List<Product> _products = [];
  List<Product> _filteredProducts = [];
  String _searchQuery = '';
  bool _isLoading = false;
  bool _isInitialized = false;
  String? _currentStoreId;

  final DataService _dataService = DataService();
  final FirebaseSyncService _syncService = FirebaseSyncService();
  final FirestoreService _firestoreService = FirestoreService.instance;
  final ConnectivityService _connectivityService = ConnectivityService();
  final OfflineService _offlineService = OfflineService();
  NotificationProvider? _notificationProvider;

  // 🔥 Firebase Real-Time Stream
  StreamSubscription? _firebaseSubscription;
  bool _firebaseListenerStarted = false;

  // Constructor
  ProductProvider() {
    print('🏗️ ProductProvider constructor called');
  }

  // Getters
  List<Product> get products {
    if (_searchQuery.isNotEmpty) {
      return _filteredProducts;
    }
    return _products;
  }

  bool get isLoading => _isLoading;
  String get searchQuery => _searchQuery;
  String get currentStoreId => _currentStoreId ?? '';
  bool get isInitialized => _isInitialized;

  // Set notification provider
  void setNotificationProvider(NotificationProvider notificationProvider) {
    _notificationProvider = notificationProvider;
  }

  // Initialize store ID
  Future<void> _initializeStoreId() async {
    final storeId = await StoreSelectionService.instance.getCurrentStoreId();
    _currentStoreId = storeId;
    print('🆔 Store ID initialized: $_currentStoreId');
  }

  // Load products from local database
  Future<void> _loadProductsFromDatabase() async {
    final storeId = _currentStoreId ?? '';
    if (storeId.isNotEmpty) {
      _products = await _dataService.loadProductsByStore(storeId, limit: null);
      _filterProducts();
      notifyListeners();
    }
  }

  // Main load products method
  Future<void> loadProducts() async {
    print('🚀 LOAD PRODUCTS CALLED! Starting entire process...');
    setLoading(true);
    try {
      // Initialize store ID first
      await _initializeStoreId();
      print('🆔 Store ID initialized: $_currentStoreId');

      final storeId = _currentStoreId ?? '';
      if (storeId.isEmpty) {
        print('❌ EMPTY STORE ID - User not logged in');
        throw Exception('Kullanıcı giriş yapmamış');
      }

      print('✅ Store ID is valid: $storeId, starting product loading...');

      // First load from local database
      _products = await _dataService.loadProductsByStore(storeId, limit: null);
      _isInitialized = true;
      _filterProducts();
      notifyListeners(); // Show local data first

      // Then sync with Firebase
      print('🔄 Starting Firebase sync for products...');
      await _syncService.syncFromFirebase();

      // Reload after Firebase sync
      _products = await _dataService.loadProductsByStore(storeId, limit: null);
      _filterProducts();

      print('🔍 LOADED PRODUCTS COUNT: ${_products.length}');

      // Start Firebase real-time updates
      _startFirebaseRealTimeStream(storeId);

      // Check low stock and update notifications
      _notificationProvider?.checkLowStockProducts(_products);

      notifyListeners();
      print('🔔 notifyListeners() called after Firebase sync');
    } catch (e) {
      print('❌ Error loading products: $e');
    } finally {
      setLoading(false);
    }
  }

  // 🔥 Firebase Real-Time Stream
  void _startFirebaseRealTimeStream(String storeId) {
    if (_firebaseListenerStarted) {
      print('🔥 Firebase listener already started, skipping...');
      return;
    }

    print('🔥 Starting Firebase Real-Time Stream for store: $storeId');

    // Cancel previous subscription
    _firebaseSubscription?.cancel();

    // Start Firebase stream
    _firebaseSubscription =
        _firestoreService.getStoreProductsStream(storeId).listen(
      (snapshot) {
        print('🔥 Real-time update received: ${snapshot.docs.length} products');

        // Process each document change individually
        snapshot.docChanges.forEach((change) {
          final doc = change.doc;
          final data = doc.data() as Map<String, dynamic>;
          final product = Product.fromMap({...data, 'id': doc.id});

          switch (change.type) {
            case DocumentChangeType.added:
              print(
                  '🆕 NEW product added: ${product.name} (ID: ${product.id})');
              _handleProductAdded(product);
            case DocumentChangeType.modified:
              print('🔄 Product modified: ${product.name} (ID: ${product.id})');
              _handleProductModified(product);
            case DocumentChangeType.removed:
              print('🗑️ Product removed: ${product.name} (ID: ${product.id})');
              _handleProductRemoved(product);
          }
        });

        // Reload products to update UI
        _loadProductsFromDatabase();
        notifyListeners();
      },
      onError: (error) {
        print('❌ Firebase stream error: $error');
      },
    );

    _firebaseListenerStarted = true;
    print('🔥 Firebase listener started successfully');
  }

  void _handleProductAdded(Product product) async {
    final storeId = _currentStoreId ?? '';
    if (storeId.isEmpty) return;

    // Check if product already exists locally
    if (product.id == null) {
      print('❌ Product ID is null');
      return;
    }

    // ✅ Store ID doğrulaması
    if (product.storeId != storeId) {
      print(
          '⚠️ Product ${product.id} belongs to different store: ${product.storeId} vs current: $storeId');
      return; // Farklı mağazaya ait ürünü işleme
    }

    final localProduct = await _dataService.getProductById(product.id!);
    if (localProduct == null) {
      // Product doesn't exist locally, add it
      await _dataService.saveProduct(product);
      print('✅ Product saved to local DB: ${product.name} (ID: ${product.id})');
    } else if (localProduct.updatedAt.isBefore(product.updatedAt)) {
      // Product exists but Firebase has newer version
      await _dataService.saveProduct(product);
      print(
          '🔄 Product updated in local DB: ${product.name} (ID: ${product.id})');
    }
  }

  void _handleProductModified(Product firebaseProduct) async {
    final storeId = _currentStoreId ?? '';
    if (storeId.isEmpty) return;

    // ✅ Store ID doğrulaması
    if (firebaseProduct.storeId != storeId) {
      print(
          '⚠️ Modified product ${firebaseProduct.id} belongs to different store: ${firebaseProduct.storeId} vs current: $storeId');
      return; // Farklı mağazaya ait ürünü işleme
    }

    if (firebaseProduct.id == null) return;

    // 🔥 YENİ: CONFLICT RESOLUTION - Timestamp bazlı çakışma çözümü
    try {
      final localProduct =
          await _dataService.getProductById(firebaseProduct.id!);

      if (localProduct != null) {
        print('🔍 Conflict check: Firebase vs Local timestamps');
        print('   Firebase: ${firebaseProduct.updatedAt}');
        print('   Local: ${localProduct.updatedAt}');

        // Timestamp karşılaştırması
        if (firebaseProduct.updatedAt.isAfter(localProduct.updatedAt)) {
          // Firebase daha yeni - Firebase'i kabul et
          print('✅ Firebase version is newer - accepting Firebase data');
          await _dataService.saveProduct(firebaseProduct);
          print(
              '🔄 Firebase product saved to local DB: ${firebaseProduct.name}');
        } else if (localProduct.updatedAt.isAfter(firebaseProduct.updatedAt)) {
          // Local daha yeni - Local'i Firebase'e gönder
          print('⚠️ Local version is newer - syncing local to Firebase');
          final success = await _firestoreService.saveProduct(
              storeId, localProduct.id, localProduct.toMap());

          if (success) {
            print('✅ Local product synced to Firebase: ${localProduct.name}');
          } else {
            print('❌ Failed to sync local product to Firebase');
          }
        } else {
          // Aynı timestamp - Firebase'i kabul et (server timestamp'e güven)
          print(
              '🔄 Same timestamp - accepting Firebase version (server timestamp)');
          await _dataService.saveProduct(firebaseProduct);
        }
      } else {
        // Yerel ürün yok - Firebase'i kabul et
        print('🆕 Local product not found - accepting Firebase data');
        await _dataService.saveProduct(firebaseProduct);
        print('✅ Firebase product saved to local DB: ${firebaseProduct.name}');
      }
    } catch (e) {
      print('❌ Conflict resolution error: $e');
      // Hata durumunda Firebase'i kabul et
      await _dataService.saveProduct(firebaseProduct);
    }
  }

  void _handleProductRemoved(Product product) async {
    final storeId = _currentStoreId ?? '';
    if (storeId.isEmpty) return;

    if (product.id == null) {
      print('❌ Product ID is null');
      return;
    }

    // Delete product from local database
    await _dataService.deleteProduct(product.id!);
    print(
        '🗑️ Product deleted from local DB: ${product.name} (ID: ${product.id})');
  }

  // Force reload products
  Future<void> refreshProducts() async {
    _isInitialized = false;
    await loadProducts();
  }

  void setLoading(bool loading) {
    if (_isLoading != loading) {
      _isLoading = loading;
      notifyListeners();
    }
  }

  Future<void> addProduct(Product product) async {
    try {
      final storeId = _currentStoreId ?? '';
      if (storeId.isEmpty) {
        throw Exception('Kullanıcı giriş yapmamış');
      }

      final productWithStore = product.copyWith(storeId: storeId);

      // 🌐 CONNECTION CHECK
      if (_connectivityService.isOffline) {
        print('� Offline mode - adding to queue: ${productWithStore.name}');

        // Offline queue'ya ekle
        await _offlineService.addPendingOperation(
          type: 'product_add',
          data: productWithStore.toMap(),
          description: 'Ürün eklendi: ${productWithStore.name}',
        );

        // Yerel veritabanına kaydet
        await _dataService.saveProduct(productWithStore);
        print('✅ Ürün offline modda yerel veritabanına kaydedildi');

        // UI'yı güncelle
        await refreshProducts();
        return;
      }

      // �🔥 ONLINE MODE: ÖNCELİKLE FİREBASE'E DİREKT KAYDET
      print(
          '🔄 Online mode - Ürün Firebase\'e direkt kaydediliyor: ${productWithStore.name}');

      final firebaseSuccess = await _firestoreService.saveProduct(
          storeId,
          null, // New product - Firebase will generate ID
          productWithStore.toMap());

      if (!firebaseSuccess) {
        // Firebase başarısız - offline queue'ya ekle
        print('⚠️ Firebase kayıt başarısız - offline queue\'ya ekleniyor');
        await _offlineService.addPendingOperation(
          type: 'product_add',
          data: productWithStore.toMap(),
          description:
              'Ürün eklendi (Firebase hatası): ${productWithStore.name}',
        );
      }

      print(
          '✅ Ürün Firebase\'e başarıyla kaydedildi: ${productWithStore.name}');

      // 🔄 Firebase başarılı olursa local backup kaydet
      try {
        await _dataService.saveProduct(productWithStore);
        print('✅ Ürün yerel veritabanına backup olarak kaydedildi');
      } catch (e) {
        print('⚠️ Yerel backup hatası (Firebase\'de kayıtlı): $e');
        // Firebase'de kayıtlı olduğu için devam et
      }

      // 🔄 Real-time stream Firebase'den güncelleyecek, manuel refresh gereksiz
      print('🔥 Ürün eklendi - Firebase stream otomatik güncelleyecek');
    } catch (e) {
      print('❌ Error adding product: $e');
      rethrow;
    }
  }

  Future<void> updateProduct(Product product) async {
    try {
      final storeId = _currentStoreId ?? '';
      if (storeId.isEmpty) {
        throw Exception('Kullanıcı giriş yapmamış');
      }

      if (product.storeId != storeId && product.storeId.isNotEmpty) {
        throw Exception('Bu ürünü düzenleme yetkiniz yok');
      }

      if (product.id == null) {
        throw Exception('Ürün ID\'si bulunamadı - güncelleme yapılamaz');
      }

      // 🌐 CONNECTION CHECK
      if (_connectivityService.isOffline) {
        print('📱 Offline mode - adding update to queue: ${product.name}');

        // Offline queue'ya ekle
        await _offlineService.addPendingOperation(
          type: 'product_update',
          data: product.toMap(),
          description: 'Ürün güncellendi: ${product.name}',
        );

        // Yerel veritabanında güncelle
        await _dataService.saveProduct(product);
        print('✅ Ürün offline modda yerel veritabanında güncellendi');

        // UI'yı güncelle
        final index = _products.indexWhere((p) => p.id == product.id);
        if (index != -1) {
          _products[index] = product;
          _filterProducts();
          notifyListeners();
        }
        return;
      }

      // 🔥 ONLINE MODE: ÖNCELİKLE FİREBASE'E DİREKT GÜNCELLE
      print(
          '🔄 Online mode - Ürün Firebase\'de direkt güncelleniyor: ${product.name}');

      final firebaseSuccess = await _firestoreService.saveProduct(
          storeId,
          product.id, // Existing product - use existing ID
          product.toMap());

      if (!firebaseSuccess) {
        // Firebase başarısız - offline queue'ya ekle
        print('⚠️ Firebase güncelleme başarısız - offline queue\'ya ekleniyor');
        await _offlineService.addPendingOperation(
          type: 'product_update',
          data: product.toMap(),
          description: 'Ürün güncellendi (Firebase hatası): ${product.name}',
        );
      }

      print('✅ Ürün Firebase\'de başarıyla güncellendi: ${product.name}');

      // 🔄 Firebase başarılı olursa local backup güncelle
      try {
        await _dataService.saveProduct(product);
        print('✅ Ürün yerel veritabanında backup olarak güncellendi');
      } catch (e) {
        print('⚠️ Yerel backup hatası (Firebase\'de güncel): $e');
        // Firebase'de güncel olduğu için devam et
      }

      // 🔄 Real-time stream Firebase'den güncelleyecek
      print(
          '🔥 Ürün güncellendi - Firebase stream otomatik senkronizasyonu sağlayacak');
    } catch (e) {
      print('❌ Error updating product: $e');
      rethrow;
    }
  }

  Future<void> removeProduct(String productId) async {
    try {
      final storeId = _currentStoreId ?? '';
      if (storeId.isEmpty) {
        throw Exception('Kullanıcı giriş yapmamış');
      }

      final product = _products.firstWhere((p) => p.id == productId,
          orElse: () => throw Exception('Ürün bulunamadı'));
      if (product.storeId != storeId) {
        throw Exception('Bu ürünü silme yetkiniz yok');
      }

      // 🔥 YENİ: ÖNCELİKLE FİREBASE'DEN DİREKT SİL
      print(
          '🗑️ Ürün Firebase\'den direkt siliniyor: ${product.name} (ID: $productId)');

      final firebaseSuccess =
          await _firestoreService.deleteProduct(storeId, productId);

      if (!firebaseSuccess) {
        throw Exception('Firebase\'den silme başarısız - işlem iptal edildi');
      }

      print('✅ Ürün Firebase\'den başarıyla silindi: ${product.name}');

      // 🔄 Firebase başarılı olursa local'den de sil
      try {
        await _dataService.deleteProduct(productId);
        print('✅ Ürün yerel veritabanından da silindi');
      } catch (e) {
        print('⚠️ Yerel silme hatası (Firebase\'den silindi): $e');
        // Firebase'den silindiği için devam et
      }

      // 🔄 Real-time stream Firebase'den güncelleyecek
      print(
          '🔥 Ürün silindi - Firebase stream otomatik senkronizasyonu sağlayacak');
    } catch (e) {
      rethrow;
    }
  }

  void setProducts(List<Product> products) {
    _products = products;
    _filterProducts();
    notifyListeners();
  }

  void searchProducts(String query) {
    _searchQuery = query;
    _filterProducts();
    notifyListeners();
  }

  void _filterProducts() {
    if (_searchQuery.isEmpty) {
      _filteredProducts = [];
    } else {
      _filteredProducts = _products.where((product) {
        return product.name
                .toLowerCase()
                .contains(_searchQuery.toLowerCase()) ||
            product.barcode.contains(_searchQuery) ||
            (product.description
                    ?.toLowerCase()
                    .contains(_searchQuery.toLowerCase()) ??
                false);
      }).toList();
    }
  }

  void clearSearch() {
    _searchQuery = '';
    _filteredProducts = [];
    notifyListeners();
  }

  Product? getProductByBarcode(String barcode) {
    try {
      return _products.firstWhere((product) => product.barcode == barcode);
    } catch (e) {
      return null;
    }
  }

  List<Product> getLowStockProducts() {
    return _products.where((product) => product.isLowStock).toList();
  }

  void updateStock(String productId, int newStock) {
    final index = _products.indexWhere((p) => p.id == productId);
    if (index != -1) {
      _products[index] = _products[index].copyWith(
        stock: newStock,
        updatedAt: DateTime.now(),
      );
      _filterProducts();
      notifyListeners();
    }
  }

  // Migration methods for Firestore
  Future<Map<String, dynamic>> getMigrationStatus() async {
    try {
      return {
        'sqliteCount': _products.length,
        'firestoreCount': 0,
        'needsMigration': _products.isNotEmpty,
        'hasStore': true,
        'storeId': 'default_store',
      };
    } catch (e) {
      return {
        'sqliteCount': 0,
        'firestoreCount': 0,
        'needsMigration': false,
        'hasStore': false,
        'storeId': null,
      };
    }
  }

  Future<bool> migrateProductsToFirestore() async {
    try {
      setLoading(true);
      await refreshProducts();
      return true;
    } catch (e) {
      return false;
    } finally {
      setLoading(false);
    }
  }

  // Clean up resources when provider is disposed
  @override
  void dispose() {
    _firebaseSubscription?.cancel();
    _firebaseListenerStarted = false;
    print('🧹 ProductProvider disposed - Firebase listener cancelled');
    super.dispose();
  }
}
