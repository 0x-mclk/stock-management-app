class Product {
  final String? id;
  final String storeId; // ✅ Store isolation için eklendi
  final String barcode;
  final String name;
  final String? description;
  final double salePrice;
  final double? purchasePrice;
  final int stock;
  final int minStock;
  final double? taxRate;
  final String? category;
  final DateTime createdAt;
  final DateTime updatedAt;

  Product({
    this.id,
    required this.storeId, // ✅ Zorunlu alan
    required this.barcode,
    required this.name,
    this.description,
    required this.salePrice,
    this.purchasePrice,
    required this.stock,
    this.minStock = 5,
    this.taxRate,
    this.category,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  // minStockLevel getter ekleme
  int get minStockLevel => minStock;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'store_id': storeId, // ✅ Store ID eklendi
      'barcode': barcode,
      'name': name,
      'description': description,
      'sale_price': salePrice,
      'purchase_price': purchasePrice,
      'stock': stock,
      'min_stock': minStock,
      'tax_rate': taxRate,
      'category': category,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  factory Product.fromMap(Map<String, dynamic> map) {
    return Product(
      id: map['id']?.toString(),
      storeId: map['store_id'] ?? '', // ✅ Store ID eklendi
      barcode: map['barcode'] ?? '',
      name: map['name'] ?? '',
      description: map['description'],
      salePrice: (map['sale_price'] ?? 0).toDouble(),
      purchasePrice: map['purchase_price']?.toDouble(),
      stock: map['stock'] ?? 0,
      minStock: map['min_stock'] ?? 5,
      taxRate: map['tax_rate']?.toDouble(),
      category: map['category'],
      createdAt: DateTime.parse(map['created_at']),
      updatedAt: DateTime.parse(map['updated_at']),
    );
  }

  Product copyWith({
    String? id,
    String? storeId,
    String? barcode,
    String? name,
    String? description,
    double? salePrice,
    double? purchasePrice,
    int? stock,
    int? minStock,
    double? taxRate,
    String? category,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? forceNullId, // ⚠️ NEW: Force ID to be null when needed
  }) {
    return Product(
      id: forceNullId == true
          ? null
          : (id ?? this.id), // ⚠️ NEW: Handle null ID properly
      storeId: storeId ?? this.storeId, // ✅ Store ID eklendi
      barcode: barcode ?? this.barcode,
      name: name ?? this.name,
      description: description ?? this.description,
      salePrice: salePrice ?? this.salePrice,
      purchasePrice: purchasePrice ?? this.purchasePrice,
      stock: stock ?? this.stock,
      minStock: minStock ?? this.minStock,
      taxRate: taxRate ?? this.taxRate,
      category: category ?? this.category,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  bool get isLowStock => stock <= minStock;
}
