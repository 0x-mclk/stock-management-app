import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
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
        limit: limit ?? 50, // Default limit 50 items to save memory
      );
      return maps.map((map) => Product.fromMap(map)).toList();
    } catch (e) {
      // // Debug print removed // Removed for production
      return [];
    }
  }

  Future<void> saveProduct(Product product) async {
    try {
      if (product.id?.isEmpty ?? true) {
        final productMap = product.toMap();
        productMap.remove(
            'id'); // Yeni ürünlerde ID çıkarılır, veritabanı otomatik oluşturur
        await _databaseService.insert('products', productMap);
      } else {
        await _databaseService.update(
          'products',
          product.toMap(),
          where: 'id = ?',
          whereArgs: [product.id],
        );
      }
    } catch (e) {
      // // Debug print removed // Removed for production
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

  Future<void> saveSale(Sale sale) async {
    try {
      // // Debug print removed // Removed for production
      // // Debug print removed // Removed for production
      if (sale.items.isNotEmpty) {
        for (int i = 0; i < sale.items.length; i++) {
          final item = sale.items[i];
          // // Debug print removed // Removed for production
        }
      }

      if (sale.id?.isEmpty ?? true) {
        // Items'ları korumak için listeyi önceden kopyalayalım
        final itemsToSave = List<SaleItem>.from(sale.items);
        // // Debug print removed // Removed for production

        // Insert new sale
        final saleMap = sale.toMap();
        // // Debug print removed // Removed for production

        saleMap.remove('id'); // Yeni satışlarda ID çıkarılır
        final saleId = await _databaseService.insert('sales', saleMap);

        // // Debug print removed // Removed for production
        // // Debug print removed // Removed for production

        // Insert sale items
        for (final item in itemsToSave) {
          final itemMap = item.toMap();
          itemMap['sale_id'] = saleId.toString();
          itemMap.remove('id'); // SaleItem ID'si de çıkarılır
          await _databaseService.insert('sale_items', itemMap);
          // Debug print removed
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
      // // Debug print removed // Removed for production
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

  Future<void> saveSupplier(Supplier supplier) async {
    try {
      if (supplier.id?.isEmpty ?? true) {
        final supplierMap = supplier.toMap();
        supplierMap.remove('id'); // Yeni tedarikçilerde ID çıkarılır
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
      // // Debug print removed // Removed for production
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
      final hasSupplierColumn =
          salesColumns.any((col) => col['name'] == 'supplier_id');
      // // Debug print removed // Removed for production

      // Check all sales data
      final sales = await _databaseService.query('sales');
      // // Debug print removed // Removed for production
      for (final sale in sales) {
        // // Debug print removed // Removed for production
      }

      // Check sale items
      final saleItems = await _databaseService.query('sale_items');
      // // Debug print removed // Removed for production
      for (final item in saleItems) {
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




