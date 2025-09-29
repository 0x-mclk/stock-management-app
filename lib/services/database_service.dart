import 'dart:io' as io;
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
// path_provider sadece web dışı platformlarda kullanılacak
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';
import '../models/supplier.dart';
import '../models/purchase.dart';
import 'firestore_service.dart';

class DatabaseService {
  static final DatabaseService _instance = DatabaseService._internal();
  static DatabaseService get instance => _instance;
  DatabaseService._internal();

  Database? _database;

  Future<Database> get database async {
    _database ??= await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    if (kIsWeb) {
      throw Exception('Web platformunda yerel veritabanı desteklenmiyor.');
    }
    io.Directory documentsDirectory = await getApplicationDocumentsDirectory();
    String path = join(documentsDirectory.path, 'stock_management.db');

    return await openDatabase(
      path,
      version: 14, // ✅ purchases tablosu eklendi
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    // Products table - Firebase uyumlu ID formatı
    await db.execute('''
      CREATE TABLE products (
        id TEXT PRIMARY KEY,
        barcode TEXT UNIQUE NOT NULL,
        name TEXT NOT NULL,
        description TEXT,
        sale_price REAL NOT NULL,
        purchase_price REAL,
        stock INTEGER NOT NULL DEFAULT 0,
        min_stock INTEGER,
        tax_rate REAL,
        category TEXT,
        store_id TEXT NOT NULL DEFAULT "default_store",
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');

    // Sales table - Firebase uyumlu ID formatı
    await db.execute('''
      CREATE TABLE sales (
        id TEXT PRIMARY KEY,
        supplier_id TEXT,
        total_amount REAL NOT NULL,
        discount REAL DEFAULT 0,
        final_amount REAL NOT NULL,
        payment_method TEXT NOT NULL,
        store_id TEXT NOT NULL DEFAULT "default_store",
        created_at TEXT NOT NULL,
        is_printed INTEGER DEFAULT 0
      )
    ''');

    // Sale items table - Firebase uyumlu ID formatı
    await db.execute('''
      CREATE TABLE sale_items (
        id TEXT PRIMARY KEY,
        sale_id TEXT NOT NULL,
        product_id TEXT NOT NULL,
        product_name TEXT NOT NULL,
        product_barcode TEXT,
        quantity INTEGER NOT NULL,
        unit_price REAL NOT NULL,
        total_price REAL NOT NULL,
        FOREIGN KEY (sale_id) REFERENCES sales (id) ON DELETE CASCADE
      )
    ''');

    // Suppliers table - Firebase uyumlu ID formatı
    await db.execute('''
      CREATE TABLE suppliers (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        phone TEXT,
        email TEXT,
        address TEXT,
        debt REAL DEFAULT 0,
        total_purchases REAL DEFAULT 0,
        monthly_purchases REAL DEFAULT 0,
        yearly_purchases REAL DEFAULT 0,
        notes TEXT,
        store_id TEXT NOT NULL DEFAULT "default_store",
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        is_active INTEGER DEFAULT 1,
        pending_sync INTEGER DEFAULT 0,
        sync_operation TEXT,
        last_sync_attempt TEXT
      )
    ''');

    // Payment history table - Firebase uyumlu ID formatı
    await db.execute('''
      CREATE TABLE payment_history (
        id TEXT PRIMARY KEY,
        supplier_id TEXT NOT NULL,
        type TEXT NOT NULL,
        amount REAL NOT NULL,
        description TEXT,
        previous_debt REAL NOT NULL DEFAULT 0,
        new_debt REAL NOT NULL DEFAULT 0,
        created_at TEXT NOT NULL,
        FOREIGN KEY (supplier_id) REFERENCES suppliers (id) ON DELETE CASCADE
      )
    ''');

    // Transaction history table - Firebase uyumlu ID formatı
    await db.execute('''
      CREATE TABLE transaction_history (
        id TEXT PRIMARY KEY,
        supplier_id TEXT NOT NULL,
        type TEXT NOT NULL,
        amount REAL NOT NULL,
        description TEXT,
        previous_debt REAL NOT NULL,
        new_debt REAL NOT NULL,
        created_at TEXT NOT NULL,
        FOREIGN KEY (supplier_id) REFERENCES suppliers (id) ON DELETE CASCADE
      )
    ''');

    // ✅ Purchases table - Tedarikçi alımları için
    await db.execute('''
      CREATE TABLE purchases (
        id TEXT PRIMARY KEY,
        supplier_id TEXT NOT NULL,
        store_id TEXT NOT NULL,
        product_name TEXT NOT NULL,
        amount REAL NOT NULL,
        payment_method TEXT DEFAULT 'cash',
        notes TEXT,
        purchase_date TEXT NOT NULL,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        pending_sync INTEGER DEFAULT 0,
        sync_operation TEXT,
        last_sync_attempt TEXT,
        FOREIGN KEY (supplier_id) REFERENCES suppliers (id) ON DELETE CASCADE
      )
    ''');

    // ✅ Create indexes for better performance
    await db
        .execute('CREATE INDEX idx_products_store_id ON products(store_id)');
    await db.execute('CREATE INDEX idx_sales_store_id ON sales(store_id)');
    await db
        .execute('CREATE INDEX idx_suppliers_store_id ON suppliers(store_id)');
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    // Handle database upgrades here
    if (oldVersion < 2) {
      // Add supplier_id column to sales table
      await db.execute('ALTER TABLE sales ADD COLUMN supplier_id TEXT');
    }
    if (oldVersion < 3) {
      // Add payment history table - Firebase uyumlu ID formatı
      await db.execute('''
        CREATE TABLE payment_history (
          id TEXT PRIMARY KEY,
          supplier_id TEXT NOT NULL,
          type TEXT NOT NULL,
          amount REAL NOT NULL,
          description TEXT,
          created_at TEXT NOT NULL,
          FOREIGN KEY (supplier_id) REFERENCES suppliers (id) ON DELETE CASCADE
        )
      ''');
    }
    if (oldVersion < 4) {
      // Add transaction history table - Firebase uyumlu ID formatı
      await db.execute('''
        CREATE TABLE transaction_history (
          id TEXT PRIMARY KEY,
          supplier_id TEXT NOT NULL,
          type TEXT NOT NULL,
          amount REAL NOT NULL,
          description TEXT,
          previous_debt REAL NOT NULL,
          new_debt REAL NOT NULL,
          created_at TEXT NOT NULL,
          FOREIGN KEY (supplier_id) REFERENCES suppliers (id) ON DELETE CASCADE
        )
      ''');
    }
    if (oldVersion < 5) {
      // Add previous_debt and new_debt columns to payment_history table
      await db.execute(
          'ALTER TABLE payment_history ADD COLUMN previous_debt REAL NOT NULL DEFAULT 0');
      await db.execute(
          'ALTER TABLE payment_history ADD COLUMN new_debt REAL NOT NULL DEFAULT 0');
    }
    if (oldVersion < 6) {
      // Clear all existing sample/demo data to have a clean start
      await db.delete('payment_history');
      await db.delete('transaction_history');
      await db.delete('sale_items');
      await db.delete('sales');
      await db.delete('customers');
      await db.delete('suppliers');
      await db.delete('products');
      // Debug print removed
    }
    if (oldVersion < 7) {
      // Add missing supplier columns
      await db.execute(
          'ALTER TABLE suppliers ADD COLUMN total_purchases REAL DEFAULT 0');
      await db.execute(
          'ALTER TABLE suppliers ADD COLUMN monthly_purchases REAL DEFAULT 0');
      await db.execute(
          'ALTER TABLE suppliers ADD COLUMN yearly_purchases REAL DEFAULT 0');
      // // Debug print removed // Removed for production
    }
    if (oldVersion < 8) {
      // Clear all data due to schema inconsistencies and data contamination
      await db.delete('payment_history');
      await db.delete('transaction_history');
      await db.delete('sale_items');
      await db.delete('sales');
      await db.delete('suppliers');
      await db.delete('products');
      // // Debug print removed // Removed for production
    }
    if (oldVersion < 9) {
      // ✅ Add store_id columns for multi-tenant support
      await db.execute(
          'ALTER TABLE products ADD COLUMN store_id TEXT NOT NULL DEFAULT "default_store"');
      await db.execute(
          'ALTER TABLE sales ADD COLUMN store_id TEXT NOT NULL DEFAULT "default_store"');
      await db.execute(
          'ALTER TABLE suppliers ADD COLUMN store_id TEXT NOT NULL DEFAULT "default_store"');

      // Create indexes for better performance
      await db
          .execute('CREATE INDEX idx_products_store_id ON products(store_id)');
      await db.execute('CREATE INDEX idx_sales_store_id ON sales(store_id)');
      await db.execute(
          'CREATE INDEX idx_suppliers_store_id ON suppliers(store_id)');

      // // Debug print removed // Removed for production
    }
    if (oldVersion < 10) {
      // ✅ Migration to Firebase-compatible ID format
      // Bu migration mevcut verileri temizler ve yeni formatla başlar
      await db.delete('payment_history');
      await db.delete('transaction_history');
      await db.delete('sale_items');
      await db.delete('sales');
      await db.delete('suppliers');
      await db.delete('products');

      print('🔄 SQLite tabloları Firebase uyumlu ID formatına geçirildi');
    }
    if (oldVersion < 11) {
      // ✅ Complete migration to STRING ID format for all tables
      print('🔄 Migrating to STRING ID format for all tables...');

      // Drop and recreate tables to ensure proper STRING ID format
      await db.execute('DROP TABLE IF EXISTS suppliers');
      await db.execute('DROP TABLE IF EXISTS payment_history');
      await db.execute('DROP TABLE IF EXISTS transaction_history');

      // Recreate with STRING IDs
      await db.execute('''
        CREATE TABLE suppliers (
          id TEXT PRIMARY KEY,
          name TEXT NOT NULL,
          phone TEXT,
          email TEXT,
          address TEXT,
          debt REAL DEFAULT 0,
          total_purchases REAL DEFAULT 0,
          monthly_purchases REAL DEFAULT 0,
          yearly_purchases REAL DEFAULT 0,
          notes TEXT,
          store_id TEXT NOT NULL DEFAULT "default_store",
          created_at TEXT NOT NULL,
          updated_at TEXT NOT NULL
        )
      ''');

      await db.execute('''
        CREATE TABLE payment_history (
          id TEXT PRIMARY KEY,
          supplier_id TEXT NOT NULL,
          type TEXT NOT NULL,
          amount REAL NOT NULL,
          description TEXT,
          previous_debt REAL NOT NULL DEFAULT 0,
          new_debt REAL NOT NULL DEFAULT 0,
          created_at TEXT NOT NULL,
          FOREIGN KEY (supplier_id) REFERENCES suppliers (id) ON DELETE CASCADE
        )
      ''');

      await db.execute('''
        CREATE TABLE transaction_history (
          id TEXT PRIMARY KEY,
          supplier_id TEXT NOT NULL,
          type TEXT NOT NULL,
          amount REAL NOT NULL,
          description TEXT,
          previous_debt REAL NOT NULL,
          new_debt REAL NOT NULL,
          created_at TEXT NOT NULL,
          FOREIGN KEY (supplier_id) REFERENCES suppliers (id) ON DELETE CASCADE
        )
      ''');

      // Recreate indexes
      await db.execute(
          'CREATE INDEX idx_suppliers_store_id ON suppliers(store_id)');

      print('✅ All tables successfully migrated to STRING ID format');
    }

    if (oldVersion < 12) {
      // ✅ Add missing columns to suppliers table
      print('🔄 Adding missing columns to suppliers table...');

      try {
        // Add is_active column
        await db.execute('''
          ALTER TABLE suppliers ADD COLUMN is_active INTEGER DEFAULT 1
        ''');

        // Add pending sync columns
        await db.execute('''
          ALTER TABLE suppliers ADD COLUMN pending_sync INTEGER DEFAULT 0
        ''');

        await db.execute('''
          ALTER TABLE suppliers ADD COLUMN sync_operation TEXT
        ''');

        await db.execute('''
          ALTER TABLE suppliers ADD COLUMN last_sync_attempt TEXT
        ''');

        print('✅ Missing columns added to suppliers table');
      } catch (e) {
        print('⚠️ Some columns may already exist: $e');
      }
    }

    if (oldVersion < 13) {
      // ✅ Ensure is_active column exists
      print('🔄 Ensuring is_active column exists in suppliers table...');

      try {
        await db.execute('''
          ALTER TABLE suppliers ADD COLUMN is_active INTEGER DEFAULT 1
        ''');
        print('✅ is_active column added to suppliers table');
      } catch (e) {
        print('⚠️ is_active column may already exist: $e');
      }
    }

    if (oldVersion < 14) {
      // ✅ Add purchases table - Tedarikçi alımları için ayrı tablo
      print('🔄 Creating purchases table...');

      try {
        await db.execute('''
          CREATE TABLE purchases (
            id TEXT PRIMARY KEY,
            supplier_id TEXT NOT NULL,
            store_id TEXT NOT NULL,
            product_name TEXT NOT NULL,
            amount REAL NOT NULL,
            payment_method TEXT DEFAULT 'cash',
            notes TEXT,
            purchase_date TEXT NOT NULL,
            created_at TEXT NOT NULL,
            updated_at TEXT NOT NULL,
            pending_sync INTEGER DEFAULT 0,
            sync_operation TEXT,
            last_sync_attempt TEXT,
            FOREIGN KEY (supplier_id) REFERENCES suppliers (id) ON DELETE CASCADE
          )
        ''');
        print('✅ purchases table created successfully');
      } catch (e) {
        print('❌ Error creating purchases table: $e');
      }
    }
  }

  Future<void> close() async {
    final db = await database;
    await db.close();
  }

  // Generic CRUD operations
  Future<int> insert(String table, Map<String, dynamic> data) async {
    final db = await database;
    return await db.insert(table, data);
  }

  Future<List<Map<String, dynamic>>> query(
    String table, {
    String? where,
    List<dynamic>? whereArgs,
    String? orderBy,
    int? limit,
  }) async {
    final db = await database;
    return await db.query(
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
    final db = await database;
    return await db.update(table, data, where: where, whereArgs: whereArgs);
  }

  Future<int> delete(
    String table, {
    required String where,
    required List<dynamic> whereArgs,
  }) async {
    final db = await database;
    return await db.delete(table, where: where, whereArgs: whereArgs);
  }

  Future<List<Map<String, dynamic>>> rawQuery(String sql,
      [List<dynamic>? arguments]) async {
    final db = await database;
    return await db.rawQuery(sql, arguments);
  }

  // Clear all user data from database
  Future<void> clearAllUserData() async {
    final db = await database;

    // Clear all tables
    await db.delete('payment_history');
    await db.delete('transaction_history');
    await db.delete('sale_items');
    await db.delete('sales');
    await db.delete('suppliers');
    await db.delete('products');

    // // Debug print removed // Removed for production
  }

  // Reset database completely (including structure)
  Future<void> resetDatabase() async {
    if (kIsWeb) {
      throw Exception('Web platformunda veritabanı sıfırlama desteklenmiyor.');
    }

    // Close current database connection
    if (_database != null) {
      await _database!.close();
      _database = null;
    }

    // Delete database file
    io.Directory documentsDirectory = await getApplicationDocumentsDirectory();
    String path = join(documentsDirectory.path, 'stock_management.db');

    final file = io.File(path);
    if (await file.exists()) {
      await file.delete();
      // // Debug print removed // Removed for production
    }

    // Reinitialize database
    _database = await _initDatabase();
    // // Debug print removed // Removed for production
  }

  // ==========================================
  // SUPPLIER CRUD OPERATIONS WITH FIREBASE SYNC
  // ==========================================

  /// Create new supplier with Firebase sync
  Future<String> createSupplier(Supplier supplier) async {
    final db = await database;

    // Generate UUID if not provided
    final supplierId = supplier.id ?? const Uuid().v4();

    final supplierData = supplier.copyWith(id: supplierId).toMap();

    try {
      // Save to SQLite first (offline-first approach)
      await db.insert('suppliers', supplierData);
      print('✅ New supplier saved to SQLite: $supplierId');

      // Attempt Firebase sync (non-blocking) - mark as new supplier
      _syncSupplierToFirebase(supplierData, isNewSupplier: true);

      return supplierId;
    } catch (e) {
      print('❌ Error creating supplier: $e');
      rethrow;
    }
  }

  /// Update existing supplier with Firebase sync - Auto-create if not exists
  Future<void> updateSupplier(Supplier supplier) async {
    if (supplier.id == null) {
      throw ArgumentError('Supplier ID cannot be null for update');
    }

    final db = await database;
    final supplierData = supplier.toMap();

    try {
      // First try to update
      final rowsAffected = await db.update(
        'suppliers',
        supplierData,
        where: 'id = ?',
        whereArgs: [supplier.id],
      );

      if (rowsAffected > 0) {
        print('✅ Supplier updated in SQLite: ${supplier.id}');
        // Attempt Firebase sync (non-blocking)
        _syncSupplierToFirebase(supplierData);
      } else {
        // Supplier not found in SQLite, try to insert it
        print('⚠️ Supplier not found in SQLite, creating: ${supplier.id}');

        try {
          await db.insert('suppliers', supplierData);
          print('✅ Supplier created in SQLite: ${supplier.id}');

          // Sync to Firebase
          _syncSupplierToFirebase(supplierData);
        } catch (insertError) {
          print('❌ Error creating supplier: $insertError');
          throw Exception(
              'Supplier not found and could not be created: ${supplier.id}');
        }
      }
    } catch (e) {
      print('❌ Error updating supplier: $e');
      rethrow;
    }
  }

  /// Delete supplier with Firebase sync
  Future<void> deleteSupplier(String supplierId, String storeId) async {
    final db = await database;

    try {
      // Delete from SQLite first
      final rowsAffected = await db.delete(
        'suppliers',
        where: 'id = ?',
        whereArgs: [supplierId],
      );

      if (rowsAffected > 0) {
        print('✅ Supplier deleted from SQLite: $supplierId');

        // Attempt Firebase sync (non-blocking)
        _deleteSupplierFromFirebase(supplierId, storeId);
      } else {
        throw Exception('Supplier not found: $supplierId');
      }
    } catch (e) {
      print('❌ Error deleting supplier: $e');
      rethrow;
    }
  }

  /// Get all suppliers for a store
  Future<List<Supplier>> getSuppliers(String storeId) async {
    final db = await database;

    try {
      final maps = await db.query(
        'suppliers',
        where: 'store_id = ? AND is_active = ?',
        whereArgs: [storeId, 1],
        orderBy: 'name ASC',
      );

      return maps.map((map) => Supplier.fromMap(map)).toList();
    } catch (e) {
      print('❌ Error getting suppliers: $e');
      return [];
    }
  }

  /// Get specific supplier by ID
  Future<Supplier?> getSupplier(String supplierId) async {
    final db = await database;

    try {
      final maps = await db.query(
        'suppliers',
        where: 'id = ?',
        whereArgs: [supplierId],
        limit: 1,
      );

      if (maps.isNotEmpty) {
        return Supplier.fromMap(maps.first);
      }
      return null;
    } catch (e) {
      print('❌ Error getting supplier: $e');
      return null;
    }
  }

  /// Get specific supplier data as Map by ID
  Future<Map<String, dynamic>?> getSupplierData(String supplierId) async {
    final db = await database;

    try {
      final maps = await db.query(
        'suppliers',
        where: 'id = ?',
        whereArgs: [supplierId],
        limit: 1,
      );

      if (maps.isNotEmpty) {
        return maps.first;
      }
      return null;
    } catch (e) {
      print('❌ Error getting supplier data: $e');
      return null;
    }
  }

  // ==========================================
  // PRIVATE FIREBASE SYNC METHODS
  // ==========================================

  /// Sync supplier to Firebase (non-blocking) with retry and offline support
  void _syncSupplierToFirebase(Map<String, dynamic> supplierData,
      {bool isNewSupplier = false}) async {
    try {
      final storeId = supplierData['store_id'] as String?;
      final supplierId = supplierData['id'] as String?;

      if (storeId == null || supplierId == null) {
        print(
            '❌ Cannot sync supplier to Firebase: missing storeId or supplierId');
        return;
      }

      // Mark as pending sync in SQLite
      await _markSupplierPendingSync(
          supplierId, isNewSupplier ? 'create' : 'update');

      // Prepare Firebase data (add isActive field)
      final firebaseData = Map<String, dynamic>.from(supplierData);
      firebaseData['isActive'] = true; // Firebase query için

      // For new suppliers, pass null supplierId to trigger Firebase document creation
      final firebaseDocId = await FirestoreService.instance.saveSupplier(
        storeId,
        isNewSupplier ? null : supplierId,
        firebaseData,
      );

      if (firebaseDocId != null) {
        print(
            '✅ Supplier synced to Firebase: $supplierId -> Firebase ID: $firebaseDocId');

        // If this was a new supplier and we got a different Firebase ID, update SQLite
        if (isNewSupplier && firebaseDocId != supplierId) {
          print(
              '🔄 Updating SQLite with Firebase ID: $supplierId -> $firebaseDocId');
          await _updateSupplierIdInSQLite(supplierId, firebaseDocId);
        }

        // Clear pending sync flag
        await _clearSupplierPendingSync(firebaseDocId);
      } else {
        print(
            '⚠️ Failed to sync supplier to Firebase: $supplierId - will retry later');
        // Keep pending sync flag for retry
      }
    } catch (e) {
      print('❌ Firebase sync error for supplier: $e - will retry later');
      // Keep pending sync flag for retry
    }
  }

  /// Delete supplier from Firebase (non-blocking) with retry support
  void _deleteSupplierFromFirebase(String supplierId, String storeId) async {
    try {
      // Mark as pending delete
      await _markSupplierPendingSync(supplierId, 'delete');

      final success =
          await FirestoreService.instance.deleteSupplier(storeId, supplierId);

      if (success) {
        print('✅ Supplier deleted from Firebase: $supplierId');
        // Clear pending sync flag
        await _clearSupplierPendingSync(supplierId);
      } else {
        print(
            '⚠️ Failed to delete supplier from Firebase: $supplierId - will retry later');
      }
    } catch (e) {
      print('❌ Firebase delete error for supplier: $e - will retry later');
    }
  }

  // ==========================================
  // PENDING SYNC MANAGEMENT
  // ==========================================

  /// Mark supplier as pending Firebase sync
  Future<void> _markSupplierPendingSync(
      String supplierId, String operation) async {
    final db = await database;

    try {
      await db.update(
        'suppliers',
        {
          'pending_sync': 1,
          'sync_operation': operation,
          'last_sync_attempt': DateTime.now().toIso8601String(),
        },
        where: 'id = ?',
        whereArgs: [supplierId],
      );
    } catch (e) {
      print('❌ Error marking supplier pending sync: $e');
    }
  }

  /// Clear supplier pending sync flag
  Future<void> _clearSupplierPendingSync(String supplierId) async {
    final db = await database;

    try {
      await db.update(
        'suppliers',
        {
          'pending_sync': 0,
          'sync_operation': null,
          'last_sync_attempt': null,
        },
        where: 'id = ?',
        whereArgs: [supplierId],
      );
    } catch (e) {
      print('❌ Error clearing supplier pending sync: $e');
    }
  }

  // ==================== PURCHASE CRUD OPERATIONS ====================

  /// Create new purchase with Firebase sync
  Future<String?> createPurchase(Map<String, dynamic> purchaseData,
      {bool fromFirebase = false}) async {
    final db = await database;
    final purchaseId = purchaseData['id'] ??
        'purchase_${DateTime.now().millisecondsSinceEpoch}_${(DateTime.now().microsecond % 1000).toString().padLeft(3, '0')}';
    purchaseData['id'] = purchaseId;

    if (!fromFirebase) {
      purchaseData['created_at'] = DateTime.now().toIso8601String();
      purchaseData['updated_at'] = DateTime.now().toIso8601String();
    }

    try {
      await db.insert('purchases', purchaseData);
      print('✅ Purchase created in SQLite: $purchaseId');

      // Only sync to Firebase if not coming from Firebase
      if (!fromFirebase) {
        _syncPurchaseToFirebase(purchaseData, fromFirebase: fromFirebase);
      }

      // Update supplier totals - ONLY if NOT coming from Firebase (prevent double counting)
      if (!fromFirebase) {
        try {
          await _updateSupplierTotalsAfterPurchase(
              purchaseData['supplier_id'], purchaseData['amount'].toDouble(),
              add: true);
          print(
              '✅ Supplier totals update completed for: ${purchaseData['supplier_id']}');
        } catch (e) {
          print('❌ Error calling supplier totals update: $e');
        }
      } else {
        print(
            '🔄 Skipping supplier totals update - data from Firebase: ${purchaseData['supplier_id']}');
      }

      return purchaseId;
    } catch (e) {
      print('❌ Error creating purchase: $e');
      return null;
    }
  }

  /// Update existing purchase with Firebase sync
  Future<void> updatePurchase(Map<String, dynamic> purchaseData,
      {bool fromFirebase = false}) async {
    if (purchaseData['id'] == null) {
      throw ArgumentError('Purchase ID cannot be null for update');
    }

    final db = await database;
    if (!fromFirebase) {
      purchaseData['updated_at'] = DateTime.now().toIso8601String();
    }

    try {
      final rowsAffected = await db.update(
        'purchases',
        purchaseData,
        where: 'id = ?',
        whereArgs: [purchaseData['id']],
      );

      if (rowsAffected > 0) {
        print('✅ Purchase updated: ${purchaseData['id']}');
        // Only sync to Firebase if not coming from Firebase
        if (!fromFirebase) {
          _syncPurchaseToFirebase(purchaseData, fromFirebase: fromFirebase);
        }
      } else {
        throw Exception('Purchase not found: ${purchaseData['id']}');
      }
    } catch (e) {
      print(' updating purchase: $e');
      rethrow;
    }
  }

  /// Delete purchase with Firebase sync
  Future<void> deletePurchase(String purchaseId) async {
    final db = await database;

    try {
      // Get purchase details before deletion for supplier total update
      final purchases = await db.query(
        'purchases',
        where: 'id = ?',
        whereArgs: [purchaseId],
      );

      if (purchases.isNotEmpty) {
        final purchase = purchases.first;

        // Delete from SQLite
        final rowsAffected = await db.delete(
          'purchases',
          where: 'id = ?',
          whereArgs: [purchaseId],
        );

        if (rowsAffected > 0) {
          print('✅ Purchase deleted from SQLite: $purchaseId');

          // Update supplier totals (subtract the amount)
          _updateSupplierTotalsAfterPurchase(
              purchase['supplier_id'].toString(),
              (purchase['amount'] ?? 0.0) is num
                  ? (purchase['amount'] as num).toDouble()
                  : 0.0,
              add: false);

          // Attempt Firebase deletion (non-blocking)
          _deletePurchaseFromFirebase(purchase['store_id'].toString(),
              purchase['supplier_id'].toString(), purchaseId);
        }
      }
    } catch (e) {
      print('❌ Error deleting purchase: $e');
      rethrow;
    }
  }

  /// Get purchases for a supplier
  Future<List<Map<String, dynamic>>> getPurchasesBySupplier(
      String supplierId) async {
    final db = await database;
    return await db.query(
      'purchases',
      where: 'supplier_id = ?',
      whereArgs: [supplierId],
      orderBy: 'purchase_date DESC',
    );
  }

  /// Get all purchases for a store
  Future<List<Map<String, dynamic>>> getAllPurchases(String storeId) async {
    final db = await database;
    return await db.query(
      'purchases',
      where: 'store_id = ?',
      whereArgs: [storeId],
      orderBy: 'purchase_date DESC',
    );
  }

  /// Delete all purchases for a specific supplier
  Future<void> deletePurchasesBySupplier(String supplierId) async {
    try {
      final db = await database;
      await db.delete(
        'purchases',
        where: 'supplier_id = ?',
        whereArgs: [supplierId],
      );
      print('✅ Deleted all purchases for supplier: $supplierId');
    } catch (e) {
      print('❌ Error deleting purchases for supplier: $e');
      rethrow;
    }
  }

  /// Sync purchase to Firebase (private method)
  void _syncPurchaseToFirebase(Map<String, dynamic> purchaseData,
      {bool fromFirebase = false}) async {
    // Prevent sync loops - don't sync back to Firebase if data came from Firebase
    if (fromFirebase) {
      print(
          '🔄 Skipping Firebase sync - data originated from Firebase: ${purchaseData['id']}');
      return;
    }

    try {
      final firestoreService = FirestoreService.instance;

      // Convert SQLite format to Firebase format using Purchase model
      final purchase = Purchase.fromMap(purchaseData);
      final firebaseData = purchase.toFirebaseMap();

      final success = await firestoreService.savePurchase(
        purchaseData['store_id'],
        purchaseData['supplier_id'],
        purchaseData['id'],
        firebaseData, // Firebase formatında data gönder
      );

      if (success) {
        print('✅ Purchase synced to Firebase: ${purchaseData['id']}');
      } else {
        print('❌ Failed to sync purchase to Firebase: ${purchaseData['id']}');
        // Mark for pending sync
        _markPurchaseForPendingSync(purchaseData['id'], 'create');
      }
    } catch (e) {
      print('❌ Error syncing purchase to Firebase: $e');
      _markPurchaseForPendingSync(purchaseData['id'], 'create');
    }
  }

  /// Delete purchase from Firebase (private method)
  void _deletePurchaseFromFirebase(
      String storeId, String supplierId, String purchaseId) async {
    try {
      final firestoreService = FirestoreService.instance;
      final success = await firestoreService.deletePurchase(
          storeId, supplierId, purchaseId);

      if (success) {
        print('✅ Purchase deleted from Firebase: $purchaseId');
      } else {
        print('❌ Failed to delete purchase from Firebase: $purchaseId');
      }
    } catch (e) {
      print('❌ Error deleting purchase from Firebase: $e');
    }
  }

  /// Update supplier totals after purchase
  Future<void> _updateSupplierTotalsAfterPurchase(
      String supplierId, double amount,
      {required bool add}) async {
    print(
        '🔄 Starting supplier totals update for: $supplierId, amount: $amount, add: $add');
    try {
      final db = await database;
      final suppliers = await db.query(
        'suppliers',
        where: 'id = ?',
        whereArgs: [supplierId],
      );

      if (suppliers.isNotEmpty) {
        final supplier = suppliers.first;
        print(
            '✅ Supplier found in SQLite: ${supplier['id']} - ${supplier['name']}');
        // ✅ Tüm totals hesapla
        final currentTotal = (supplier['total_purchases'] ?? 0.0) is num
            ? (supplier['total_purchases'] as num).toDouble()
            : 0.0;
        final currentMonthly = (supplier['monthly_purchases'] ?? 0.0) is num
            ? (supplier['monthly_purchases'] as num).toDouble()
            : 0.0;
        final currentYearly = (supplier['yearly_purchases'] ?? 0.0) is num
            ? (supplier['yearly_purchases'] as num).toDouble()
            : 0.0;

        final newTotal = add ? currentTotal + amount : currentTotal - amount;
        final newMonthly =
            add ? currentMonthly + amount : currentMonthly - amount;
        final newYearly = add ? currentYearly + amount : currentYearly - amount;

        await db.update(
          'suppliers',
          {
            'total_purchases': newTotal,
            'monthly_purchases': newMonthly,
            'yearly_purchases': newYearly,
            'updated_at': DateTime.now().toIso8601String(),
          },
          where: 'id = ?',
          whereArgs: [supplierId],
        );

        // ✅ Firebase'e de sync et - READ-ONLY sorununu çözmek için kopyala
        final updatedSupplierData = Map<String, dynamic>.from(supplier);
        updatedSupplierData['total_purchases'] = newTotal;
        updatedSupplierData['monthly_purchases'] = newMonthly;
        updatedSupplierData['yearly_purchases'] = newYearly;
        updatedSupplierData['updated_at'] = DateTime.now().toIso8601String();
        _syncSupplierToFirebase(updatedSupplierData);

        print(
            '✅ Supplier purchases updated: $supplierId -> Total: $newTotal, Monthly: $newMonthly, Yearly: $newYearly');
      } else {
        print('❌ Supplier NOT found in SQLite: $supplierId');
        print('🔄 Attempting to create supplier from Firebase...');

        // Firebase'dan supplier bilgisini al ve SQLite'a ekle
        final firebaseSupplier = await _getSupplierFromFirebase(supplierId);
        if (firebaseSupplier != null) {
          print('✅ Found supplier in Firebase, syncing to SQLite...');
          await _insertSupplierFromFirebase(firebaseSupplier);

          // Şimdi manuel olarak totals güncelle (recursion önlemek için)
          await _updateSupplierTotalsDirectly(supplierId, amount, add: add);
        } else {
          print('❌ Supplier not found in Firebase either: $supplierId');
        }
      }
    } catch (e) {
      print('❌ Error updating supplier totals: $e');
      print('📍 Stack trace: ${StackTrace.current}');
    }
  }

  /// Get supplier from Firebase
  Future<Map<String, dynamic>?> _getSupplierFromFirebase(
      String supplierId) async {
    try {
      final firestoreService = FirestoreService.instance;
      // Store ID'yi cache'den al (SupplierProvider'dan)
      final storeId =
          'store_ho61LEL6IwVYprnt3F2b9SJlqiE3'; // TODO: Dynamic store ID

      final doc = await firestoreService.getSupplier(storeId, supplierId);
      if (doc != null && doc.exists) {
        final data = doc.data() as Map<String, dynamic>;
        data['id'] = doc.id;
        return data;
      }
      return null;
    } catch (e) {
      print('❌ Error getting supplier from Firebase: $e');
      return null;
    }
  }

  /// Insert supplier from Firebase data to SQLite
  Future<void> _insertSupplierFromFirebase(
      Map<String, dynamic> firebaseData) async {
    try {
      final db = await database;

      // Firebase data'yı SQLite formatına çevir
      final supplierData = {
        'id': firebaseData['id'],
        'store_id': firebaseData['storeId'] ?? firebaseData['store_id'],
        'name': firebaseData['name'],
        'phone': firebaseData['phone'],
        'email': firebaseData['email'],
        'address': firebaseData['address'],
        'notes': firebaseData['notes'],
        'debt': (firebaseData['debt'] ?? 0.0) is num
            ? (firebaseData['debt'] as num).toDouble()
            : 0.0,
        'total_purchases': (firebaseData['total_purchases'] ?? 0.0) is num
            ? (firebaseData['total_purchases'] as num).toDouble()
            : 0.0,
        'monthly_purchases': (firebaseData['monthly_purchases'] ?? 0.0) is num
            ? (firebaseData['monthly_purchases'] as num).toDouble()
            : 0.0,
        'yearly_purchases': (firebaseData['yearly_purchases'] ?? 0.0) is num
            ? (firebaseData['yearly_purchases'] as num).toDouble()
            : 0.0,
        'created_at':
            firebaseData['created_at'] ?? DateTime.now().toIso8601String(),
        'updated_at':
            firebaseData['updated_at'] ?? DateTime.now().toIso8601String(),
        'is_active': 1,
        'pending_sync': 0,
        'sync_operation': null,
        'last_sync_attempt': null,
      };

      await db.insert('suppliers', supplierData,
          conflictAlgorithm: ConflictAlgorithm.replace);
      print(
          '✅ Supplier synced from Firebase to SQLite: ${supplierData['id']} - ${supplierData['name']}');
    } catch (e) {
      print('❌ Error inserting supplier from Firebase: $e');
    }
  }

  /// Update supplier totals directly (without supplier existence check)
  Future<void> _updateSupplierTotalsDirectly(String supplierId, double amount,
      {required bool add}) async {
    try {
      final db = await database;
      final suppliers = await db.query(
        'suppliers',
        where: 'id = ?',
        whereArgs: [supplierId],
      );

      if (suppliers.isNotEmpty) {
        final supplier = suppliers.first;
        final currentTotal = (supplier['total_purchases'] ?? 0.0) is num
            ? (supplier['total_purchases'] as num).toDouble()
            : 0.0;
        final currentMonthly = (supplier['monthly_purchases'] ?? 0.0) is num
            ? (supplier['monthly_purchases'] as num).toDouble()
            : 0.0;
        final currentYearly = (supplier['yearly_purchases'] ?? 0.0) is num
            ? (supplier['yearly_purchases'] as num).toDouble()
            : 0.0;

        final newTotal = add ? currentTotal + amount : currentTotal - amount;
        final newMonthly =
            add ? currentMonthly + amount : currentMonthly - amount;
        final newYearly = add ? currentYearly + amount : currentYearly - amount;

        await db.update(
          'suppliers',
          {
            'total_purchases': newTotal,
            'monthly_purchases': newMonthly,
            'yearly_purchases': newYearly,
            'updated_at': DateTime.now().toIso8601String(),
          },
          where: 'id = ?',
          whereArgs: [supplierId],
        );

        // Firebase'e sync et
        final updatedSupplierData = Map<String, dynamic>.from(supplier);
        updatedSupplierData['total_purchases'] = newTotal;
        updatedSupplierData['monthly_purchases'] = newMonthly;
        updatedSupplierData['yearly_purchases'] = newYearly;
        updatedSupplierData['updated_at'] = DateTime.now().toIso8601String();
        _syncSupplierToFirebase(updatedSupplierData);

        print(
            '✅ Supplier purchases updated directly: $supplierId -> Total: $newTotal, Monthly: $newMonthly, Yearly: $newYearly');
      }
    } catch (e) {
      print('❌ Error updating supplier totals directly: $e');
    }
  }

  /// Recalculate supplier totals with exact amount (for Firebase sync)
  Future<void> recalculateSupplierTotals(
      String supplierId, double totalAmount) async {
    final db = await database;

    try {
      final suppliers = await db.query(
        'suppliers',
        where: 'id = ?',
        whereArgs: [supplierId],
      );

      if (suppliers.isNotEmpty) {
        await db.update(
          'suppliers',
          {
            'total_purchases': totalAmount,
            'monthly_purchases':
                totalAmount, // Basit hesaplama - ilerisi için geliştirilebilir
            'yearly_purchases': totalAmount,
            'updated_at': DateTime.now().toIso8601String(),
          },
          where: 'id = ?',
          whereArgs: [supplierId],
        );

        // Firebase'e sync et
        final supplierData = Map<String, dynamic>.from(suppliers.first);
        supplierData['total_purchases'] = totalAmount;
        supplierData['monthly_purchases'] = totalAmount;
        supplierData['yearly_purchases'] = totalAmount;
        supplierData['updated_at'] = DateTime.now().toIso8601String();
        _syncSupplierToFirebase(supplierData);

        print(
            '✅ Supplier totals recalculated: $supplierId -> Total: $totalAmount');
      }
    } catch (e) {
      print('❌ Error recalculating supplier totals: $e');
    }
  }

  /// Mark purchase for pending sync
  void _markPurchaseForPendingSync(String purchaseId, String operation) async {
    final db = await database;
    try {
      await db.update(
        'purchases',
        {
          'pending_sync': 1,
          'sync_operation': operation,
          'last_sync_attempt': DateTime.now().toIso8601String(),
        },
        where: 'id = ?',
        whereArgs: [purchaseId],
      );
    } catch (e) {
      print('❌ Error marking purchase for pending sync: $e');
    }
  }

  /// Retry pending supplier syncs (call when network is available)
  Future<void> retryPendingSupplierSyncs() async {
    final db = await database;

    try {
      final pendingSuppliers = await db.query(
        'suppliers',
        where: 'pending_sync = ?',
        whereArgs: [1],
      );

      print('🔄 Retrying ${pendingSuppliers.length} pending supplier syncs...');

      for (final supplierMap in pendingSuppliers) {
        final supplierId = supplierMap['id'] as String;
        final operation = supplierMap['sync_operation'] as String?;
        final storeId = supplierMap['store_id'] as String;

        if (operation == 'delete') {
          _deleteSupplierFromFirebase(supplierId, storeId);
        } else {
          // update or create
          _syncSupplierToFirebase(supplierMap);
        }

        // Add small delay between retries
        await Future.delayed(const Duration(milliseconds: 100));
      }
    } catch (e) {
      print('❌ Error retrying pending supplier syncs: $e');
    }
  }

  /// Update supplier ID in SQLite when Firebase assigns a different ID
  Future<void> _updateSupplierIdInSQLite(String oldId, String newId) async {
    final db = await database;

    try {
      // Get the supplier data first
      final suppliers = await db.query(
        'suppliers',
        where: 'id = ?',
        whereArgs: [oldId],
      );

      if (suppliers.isNotEmpty) {
        final supplierData = Map<String, dynamic>.from(suppliers.first);
        supplierData['id'] = newId; // Update with Firebase ID
        supplierData['updated_at'] = DateTime.now().toIso8601String();

        // Insert with new ID
        await db.insert('suppliers', supplierData,
            conflictAlgorithm: ConflictAlgorithm.replace);

        // Delete old record
        await db.delete(
          'suppliers',
          where: 'id = ?',
          whereArgs: [oldId],
        );

        // Update related records (payment_history, purchases, etc.)
        await db.update(
          'payment_history',
          {'supplier_id': newId},
          where: 'supplier_id = ?',
          whereArgs: [oldId],
        );

        await db.update(
          'purchases',
          {'supplier_id': newId},
          where: 'supplier_id = ?',
          whereArgs: [oldId],
        );

        print('✅ Supplier ID updated in SQLite: $oldId -> $newId');
      }
    } catch (e) {
      print('❌ Error updating supplier ID in SQLite: $e');
    }
  }
}
