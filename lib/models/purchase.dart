class Purchase {
  final String? id;
  final String supplierId;
  final String storeId;
  final String productName;
  final double amount;
  final String paymentMethod;
  final String? notes;
  final DateTime purchaseDate;
  final DateTime createdAt;
  final DateTime updatedAt;

  Purchase({
    this.id,
    required this.supplierId,
    required this.storeId,
    required this.productName,
    required this.amount,
    this.paymentMethod = 'cash',
    this.notes,
    required this.purchaseDate,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'supplier_id': supplierId,
      'store_id': storeId,
      'product_name': productName,
      'amount': amount,
      'payment_method': paymentMethod,
      'notes': notes,
      'purchase_date': purchaseDate.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  // Firebase subcollection için
  Map<String, dynamic> toFirebaseMap() {
    return {
      'id': id,
      'supplierId': supplierId,
      'storeId': storeId,
      'productName': productName,
      'amount': amount,
      'paymentMethod': paymentMethod,
      'notes': notes,
      'purchaseDate': purchaseDate.toIso8601String(),
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory Purchase.fromMap(Map<String, dynamic> map) {
    return Purchase(
      id: map['id']?.toString(),
      supplierId: map['supplier_id'] ?? map['supplierId'] ?? '',
      storeId: map['store_id'] ?? map['storeId'] ?? '',
      productName: map['product_name'] ?? map['productName'] ?? '',
      amount: (map['amount'] ?? 0).toDouble(),
      paymentMethod: map['payment_method'] ?? map['paymentMethod'] ?? 'cash',
      notes: map['notes'],
      purchaseDate: DateTime.parse(map['purchase_date'] ?? map['purchaseDate']),
      createdAt: DateTime.parse(map['created_at'] ?? map['createdAt']),
      updatedAt: DateTime.parse(map['updated_at'] ?? map['updatedAt']),
    );
  }

  Purchase copyWith({
    String? id,
    String? supplierId,
    String? storeId,
    String? productName,
    double? amount,
    String? paymentMethod,
    String? notes,
    DateTime? purchaseDate,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Purchase(
      id: id ?? this.id,
      supplierId: supplierId ?? this.supplierId,
      storeId: storeId ?? this.storeId,
      productName: productName ?? this.productName,
      amount: amount ?? this.amount,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      notes: notes ?? this.notes,
      purchaseDate: purchaseDate ?? this.purchaseDate,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
