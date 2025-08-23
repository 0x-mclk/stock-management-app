import 'dart:io' as io;
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
// path_provider sadece web dışı platformlarda kullanılacak
import 'package:path_provider/path_provider.dart';

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
      version: 8,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    // Products table
    await db.execute('''
      CREATE TABLE products (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        barcode TEXT UNIQUE NOT NULL,
        name TEXT NOT NULL,
        description TEXT,
        sale_price REAL NOT NULL,
        purchase_price REAL,
        stock INTEGER NOT NULL DEFAULT 0,
        min_stock INTEGER,
        tax_rate REAL,
        category TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');

    // Sales table
    await db.execute('''
      CREATE TABLE sales (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        supplier_id TEXT,
        total_amount REAL NOT NULL,
        discount REAL DEFAULT 0,
        final_amount REAL NOT NULL,
        payment_method TEXT NOT NULL,
        created_at TEXT NOT NULL,
        is_printed INTEGER DEFAULT 0
      )
    ''');

    // Sale items table
    await db.execute('''
      CREATE TABLE sale_items (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        sale_id INTEGER NOT NULL,
        product_id TEXT NOT NULL,
        product_name TEXT NOT NULL,
        product_barcode TEXT,
        quantity INTEGER NOT NULL,
        unit_price REAL NOT NULL,
        total_price REAL NOT NULL,
        FOREIGN KEY (sale_id) REFERENCES sales (id) ON DELETE CASCADE
      )
    ''');

    // Suppliers table
    await db.execute('''
      CREATE TABLE suppliers (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        phone TEXT,
        email TEXT,
        address TEXT,
        debt REAL DEFAULT 0,
        total_purchases REAL DEFAULT 0,
        monthly_purchases REAL DEFAULT 0,
        yearly_purchases REAL DEFAULT 0,
        notes TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');

    // Payment history table
    await db.execute('''
      CREATE TABLE payment_history (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
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

    // Transaction history table
    await db.execute('''
      CREATE TABLE transaction_history (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
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

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    // Handle database upgrades here
    if (oldVersion < 2) {
      // Add supplier_id column to sales table
      await db.execute('ALTER TABLE sales ADD COLUMN supplier_id TEXT');
    }
    if (oldVersion < 3) {
      // Add payment history table
      await db.execute('''
        CREATE TABLE payment_history (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
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
      // Add transaction history table
      await db.execute('''
        CREATE TABLE transaction_history (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
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
      print(
          'All existing sample data cleared - fresh start for user data only');
    }
    if (oldVersion < 7) {
      // Add missing supplier columns
      await db.execute(
          'ALTER TABLE suppliers ADD COLUMN total_purchases REAL DEFAULT 0');
      await db.execute(
          'ALTER TABLE suppliers ADD COLUMN monthly_purchases REAL DEFAULT 0');
      await db.execute(
          'ALTER TABLE suppliers ADD COLUMN yearly_purchases REAL DEFAULT 0');
      print('Added missing supplier purchase tracking columns');
    }
    if (oldVersion < 8) {
      // Clear all data due to schema inconsistencies and data contamination
      await db.delete('payment_history');
      await db.delete('transaction_history');
      await db.delete('sale_items');
      await db.delete('sales');
      await db.delete('suppliers');
      await db.delete('products');
      print('Database cleared to fix data contamination issues - fresh start');
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

    print('All user data cleared from database');
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
      print('Database file deleted');
    }

    // Reinitialize database
    _database = await _initDatabase();
    print('Database recreated');
  }
}
