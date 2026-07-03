import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart'; // ✅ UUID generation için
import '../models/product.dart';
import '../models/sale.dart';
import '../models/supplier.dart';
import 'database_service.dart';

class DataService {
  static final DataService _instance = DataService._internal();
  factory DataService() => _instance;
  DataService._internal();

  final DatabaseService _databaseService = DatabaseService.instance;

  // Product CRUD operations
  Future<List<Product>> loadProducts({int? limit}) async {
    try {
      final maps = await _databaseService.query(
        'products',
        orderBy: 'created_at DESC',
        limit: limit, // No default limit - use exactly what's passed
      );
      return maps.map((map) => Product.fromMap(map)).toList();
    } catch (e) {
      // // Debug print removed // Removed for production
      return [];
    }
  }

  // ✅ Store ID ile filtrelenmiş ürünleri yükle
  Future<List<Product>> loadProductsByStore(String storeId,
      {int? limit}) async {
    try {
      final maps = await _databaseService.query(
        'products',
        where: 'store_id = ?',
        whereArgs: [storeId],
        orderBy: 'created_at DESC',
        limit: limit, // No default limit - use exactly what's passed
      );
      return maps.map((map) => Product.fromMap(map)).toList();
    } catch (e) {
      // // Debug print removed // Removed for production
      return [];
    }
  }

  Future<void> saveProduct(Product product) async {
    try {

      if (product.id == null) {
        // ✅ Firebase uyumlu STRING ID generate et
        final uuid = Uuid();
        final newId = uuid.v4();

        final productWithId = product.copyWith(id: newId);
        final productMap = productWithId.toMap();

        try {
          await _databaseService.insert('products', productMap);
        } catch (e) {
          if (e
              .toString()
              .contains('UNIQUE constraint failed: products.barcode')) {

            // Find existing product with same barcode and update it instead
            final existingProducts = await loadProducts();
            final existingProduct = existingProducts
                .where((p) => p.barcode == product.barcode)
                .firstOrNull;

            if (existingProduct != null) {
              final updatedProduct = product.copyWith(
                id: existingProduct.id, // Use existing product's ID
              );
              await saveProduct(updatedProduct); // Recursive call with ID
              return;
            } else {
              rethrow;
            }
          } else {
            rethrow;
          }
        }
      } else {
        // Existing product - update
        final result = await _databaseService.update(
          'products',
          product.toMap(),
          where: 'id = ?',
          whereArgs: [product.id],
        );
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<void> deleteProduct(String productId) async {
    try {
      await _databaseService.delete(
        'products',
        where: 'id = ?',
        whereArgs: [productId],
      );
    } catch (e) {
      // // Debug print removed // Removed for production
      rethrow;
    }
  }

  // Get product by ID
  Future<Product?> getProductById(String productId) async {
    try {
      final maps = await _databaseService.query(
        'products',
        where: 'id = ?',
        whereArgs: [productId],
      );

      if (maps.isEmpty) {
        return null;
      }

      return Product.fromMap(maps.first);
    } catch (e) {
      // // Debug print removed // Removed for production
      return null;
    }
  }

  // Sales CRUD operations
  Future<List<Sale>> loadSales({int? limit}) async {
    try {
      final maps = await _databaseService.query(
        'sales',
        orderBy: 'created_at DESC',
        limit: limit, // limit null ise tüm kayıtları getir
      );

      List<Sale> sales = [];

      for (final map in maps) {
        // Load sale items for each sale
        final itemMaps = await _databaseService.query(
          'sale_items',
          where: 'sale_id = ?',
          whereArgs: [map['id']],
        );

        final items =
            itemMaps.map((itemMap) => SaleItem.fromMap(itemMap)).toList();
        final sale = Sale.fromMap(map).copyWith(items: items);
        sales.add(sale);
      }

      return sales;
    } catch (e) {
      // // Debug print removed // Removed for production
      return [];
    }
  }

  // ✅ Store ID ile filtrelenmiş satışları yükle
  Future<List<Sale>> loadSalesByStore(String storeId, {int? limit}) async {
    try {
      if (storeId.isEmpty) {
        return [];
      }

      final maps = await _databaseService.query(
        'sales',
        where: 'store_id = ?',
        whereArgs: [storeId],
        orderBy: 'created_at DESC',
        limit: limit, // limit null ise tüm kayıtları getir
      );

      List<Sale> sales = [];

      for (final map in maps) {
        // Load sale items for each sale
        final itemMaps = await _databaseService.query(
          'sale_items',
          where: 'sale_id = ?',
          whereArgs: [map['id']],
        );

        final items =
            itemMaps.map((itemMap) => SaleItem.fromMap(itemMap)).toList();
        final sale = Sale.fromMap(map).copyWith(items: items);

        // ✅ Store ID doğrulaması
        if (sale.storeId != storeId) {
          continue; // Bu satışı atla
        }

        sales.add(sale);
      }
      return sales;
    } catch (e) {
      return [];
    }
  }

  Future<void> saveSale(Sale sale) async {
    try {
      // // Debug print removed // Removed for production
      // // Debug print removed // Removed for production
      if (sale.items.isNotEmpty) {
        for (int i = 0; i < sale.items.length; i++) {
          // // Debug print removed // Removed for production
        }
      }

      if (sale.id?.isEmpty ?? true) {
        // Items'ları korumak için listeyi önceden kopyalayalım
        final itemsToSave = List<SaleItem>.from(sale.items);
        // // Debug print removed // Removed for production

        // ✅ Firebase uyumlu STRING ID generate et
        final uuid = Uuid();
        final newSaleId = uuid.v4();

        final saleWithId = sale.copyWith(id: newSaleId);
        final saleMap = saleWithId.toMap();

        await _databaseService.insert('sales', saleMap);

        // Insert sale items with STRING IDs
        for (final item in itemsToSave) {
          final itemId = uuid.v4();
          final itemWithId = item.copyWith(id: itemId);
          final itemMap = itemWithId.toMap();
          itemMap['sale_id'] = newSaleId;
          await _databaseService.insert('sale_items', itemMap);
        }

        // // Debug print removed // Removed for production
      } else {
        // Update existing sale
        await _databaseService.update(
          'sales',
          sale.toMap(),
          where: 'id = ?',
          whereArgs: [sale.id],
        );

        // Delete old items and insert new ones
        await _databaseService.delete(
          'sale_items',
          where: 'sale_id = ?',
          whereArgs: [sale.id],
        );

        for (final item in sale.items) {
          final itemMap = item.toMap();
          itemMap['sale_id'] = sale.id;
          await _databaseService.insert('sale_items', itemMap);
        }
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<void> updateSale(Sale sale) async {
    try {
      // Update sale in database
      await _databaseService.update(
        'sales',
        sale.toMap(),
        where: 'id = ?',
        whereArgs: [sale.id],
      );

      // Delete old items and insert new ones
      await _databaseService.delete(
        'sale_items',
        where: 'sale_id = ?',
        whereArgs: [sale.id],
      );

      for (final item in sale.items) {
        final itemMap = item.toMap();
        itemMap['sale_id'] = sale.id;
        itemMap.remove('id'); // SaleItem ID'si çıkarılır
        await _databaseService.insert('sale_items', itemMap);
      }
    } catch (e) {
      // // Debug print removed // Removed for production
      rethrow;
    }
  }

  Future<void> deleteSale(String saleId) async {
    try {
      // Delete sale items first
      await _databaseService.delete(
        'sale_items',
        where: 'sale_id = ?',
        whereArgs: [saleId],
      );

      // Delete sale
      await _databaseService.delete(
        'sales',
        where: 'id = ?',
        whereArgs: [saleId],
      );
    } catch (e) {
      // // Debug print removed // Removed for production
      rethrow;
    }
  }

  // Supplier CRUD operations
  Future<List<Supplier>> loadSuppliers() async {
    try {
      final maps =
          await _databaseService.query('suppliers', orderBy: 'created_at DESC');
      return maps.map((map) => Supplier.fromMap(map)).toList();
    } catch (e) {
      // // Debug print removed // Removed for production
      return [];
    }
  }

  // ✅ Store ID ile filtrelenmiş tedarikçileri yükle
  Future<List<Supplier>> loadSuppliersByStore(String storeId) async {
    try {
      final maps = await _databaseService.query(
        'suppliers',
        where: 'store_id = ?',
        whereArgs: [storeId],
        orderBy: 'created_at DESC',
      );
      return maps.map((map) => Supplier.fromMap(map)).toList();
    } catch (e) {
      // // Debug print removed // Removed for production
      return [];
    }
  }

  Future<void> saveSupplier(Supplier supplier) async {
    try {
      if (supplier.id?.isEmpty ?? true) {
        // ✅ Firebase uyumlu STRING ID generate et
        final uuid = Uuid();
        final newId = uuid.v4();

        final supplierWithId = supplier.copyWith(id: newId);
        final supplierMap = supplierWithId.toMap();
        await _databaseService.insert('suppliers', supplierMap);
      } else {
        await _databaseService.update(
          'suppliers',
          supplier.toMap(),
          where: 'id = ?',
          whereArgs: [supplier.id],
        );
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<void> deleteSupplier(String supplierId) async {
    try {
      await _databaseService.delete(
        'suppliers',
        where: 'id = ?',
        whereArgs: [supplierId],
      );
    } catch (e) {
      // // Debug print removed // Removed for production
      rethrow;
    }
  }

  // Settings and preferences
  Future<void> saveSettings(Map<String, dynamic> settings) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('app_settings', jsonEncode(settings));
    } catch (e) {
      // // Debug print removed // Removed for production
      rethrow;
    }
  }

  Future<Map<String, dynamic>> loadSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final settingsJson = prefs.getString('app_settings');
      if (settingsJson != null) {
        return jsonDecode(settingsJson);
      }
      return {};
    } catch (e) {
      // // Debug print removed // Removed for production
      return {};
    }
  }

  // Data synchronization check
  Future<bool> hasUnsyncedData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool('has_unsynced_data') ?? false;
    } catch (e) {
      return false;
    }
  }

  Future<void> markDataAsSynced() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('has_unsynced_data', false);
    } catch (e) {
      // // Debug print removed // Removed for production
    }
  }

  Future<void> markDataAsUnsynced() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('has_unsynced_data', true);
    } catch (e) {
      // // Debug print removed // Removed for production
    }
  }

  // Debug method to check database content
  Future<void> debugDatabaseContent() async {
    try {
      // // Debug print removed // Removed for production

      // Check sales table structure
      final salesColumns =
          await _databaseService.rawQuery('PRAGMA table_info(sales)');
      // // Debug print removed // Removed for production

      // Check if supplier_id column exists
      salesColumns.any((col) => col['name'] == 'supplier_id');
      // // Debug print removed // Removed for production

      // Check all sales data
      final sales = await _databaseService.query('sales');
      // // Debug print removed // Removed for production
      for (int i = 0; i < sales.length; i++) {
        // // Debug print removed // Removed for production
      }

      // Check sale items
      final saleItems = await _databaseService.query('sale_items');
      // // Debug print removed // Removed for production
      for (int i = 0; i < saleItems.length; i++) {
        // // Debug print removed // Removed for production
      }

      // // Debug print removed // Removed for production
    } catch (e) {
      // // Debug print removed // Removed for production
    }
  }

  // Generic CRUD operations
  Future<int> insert(String table, Map<String, dynamic> data) async {
    return await _databaseService.insert(table, data);
  }

  Future<List<Map<String, dynamic>>> query(
    String table, {
    String? where,
    List<dynamic>? whereArgs,
    String? orderBy,
    int? limit,
  }) async {
    return await _databaseService.query(
      table,
      where: where,
      whereArgs: whereArgs,
      orderBy: orderBy,
      limit: limit,
    );
  }

  Future<int> update(
    String table,
    Map<String, dynamic> data, {
    required String where,
    required List<dynamic> whereArgs,
  }) async {
    return await _databaseService.update(table, data,
        where: where, whereArgs: whereArgs);
  }

  Future<int> delete(
    String table, {
    required String where,
    required List<dynamic> whereArgs,
  }) async {
    return await _databaseService.delete(table,
        where: where, whereArgs: whereArgs);
  }
}
