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
      print('Error loading products: $e');
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
      print('Error saving product: $e');
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
      print('Error deleting product: $e');
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
      print('Error loading sales: $e');
      return [];
    }
  }

  Future<void> saveSale(Sale sale) async {
    try {
      print('🔍 DataService.saveSale çağrıldı');
      print('📦 Alınan Sale objesi items sayısı: ${sale.items.length}');
      if (sale.items.isNotEmpty) {
        for (int i = 0; i < sale.items.length; i++) {
          final item = sale.items[i];
          print('  ${i + 1}. ${item.productName} x${item.quantity}');
        }
      }

      if (sale.id?.isEmpty ?? true) {
        // Items'ları korumak için listeyi önceden kopyalayalım
        final itemsToSave = List<SaleItem>.from(sale.items);
        print('� Items korundu, sayı: ${itemsToSave.length}');

        // Insert new sale
        final saleMap = sale.toMap();
        print('�️ saleMap oluşturuldu');

        saleMap.remove('id'); // Yeni satışlarda ID çıkarılır
        final saleId = await _databaseService.insert('sales', saleMap);

        print('🆕 YENİ SATIŞ KAYDI: ID=$saleId');
        print('📦 Kaydedilecek ürün sayısı: ${itemsToSave.length}');

        // Insert sale items
        for (final item in itemsToSave) {
          final itemMap = item.toMap();
          itemMap['sale_id'] = saleId.toString();
          itemMap.remove('id'); // SaleItem ID'si de çıkarılır
          await _databaseService.insert('sale_items', itemMap);
          print(
              '  ✅ SaleItem kaydedildi: ${item.productName} x${item.quantity}');
        }

        print('🎉 Tüm SaleItem\'lar başarıyla kaydedildi!');
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
      print('Error saving sale: $e');
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
      print('Error updating sale: $e');
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
      print('Error deleting sale: $e');
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
      print('Error loading suppliers: $e');
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
      print('Error saving supplier: $e');
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
      print('Error deleting supplier: $e');
      rethrow;
    }
  }

  // Settings and preferences
  Future<void> saveSettings(Map<String, dynamic> settings) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('app_settings', jsonEncode(settings));
    } catch (e) {
      print('Error saving settings: $e');
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
      print('Error loading settings: $e');
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
      print('Error marking data as synced: $e');
    }
  }

  Future<void> markDataAsUnsynced() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('has_unsynced_data', true);
    } catch (e) {
      print('Error marking data as unsynced: $e');
    }
  }

  // Debug method to check database content
  Future<void> debugDatabaseContent() async {
    try {
      print('=== DATABASE DEBUG START ===');

      // Check sales table structure
      final salesColumns =
          await _databaseService.rawQuery('PRAGMA table_info(sales)');
      print('Sales table columns: $salesColumns');

      // Check if supplier_id column exists
      final hasSupplierColumn =
          salesColumns.any((col) => col['name'] == 'supplier_id');
      print('Has supplier_id column: $hasSupplierColumn');

      // Check all sales data
      final sales = await _databaseService.query('sales');
      print('Sales count: ${sales.length}');
      for (final sale in sales) {
        print('Sale: $sale');
      }

      // Check sale items
      final saleItems = await _databaseService.query('sale_items');
      print('Sale items count: ${saleItems.length}');
      for (final item in saleItems) {
        print('Sale item: $item');
      }

      print('=== DATABASE DEBUG END ===');
    } catch (e) {
      print('Error debugging database: $e');
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
