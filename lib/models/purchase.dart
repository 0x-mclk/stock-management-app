import 'package:cloud_firestore/cloud_firestore.dart';

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
      supplierId: (map['supplier_id'] ?? map['supplierId'] ?? '').toString(),
      storeId: (map['store_id'] ?? map['storeId'] ?? '').toString(),
      productName: (map['product_name'] ?? map['productName'] ?? '').toString(),
      amount: _toDouble(map['amount']),
      paymentMethod:
          (map['payment_method'] ?? map['paymentMethod'] ?? 'cash').toString(),
      notes: map['notes']?.toString(),
      purchaseDate: _parseDateTime(map['purchase_date'] ?? map['purchaseDate']),
      createdAt: _parseDateTime(map['created_at'] ?? map['createdAt']),
      updatedAt: _parseDateTime(map['updated_at'] ?? map['updatedAt']),
    );
  }

  static double _toDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString()) ?? 0.0;
  }

  static DateTime _parseDateTime(dynamic value) {
    if (value == null) return DateTime.now();
    if (value is DateTime) return value;
    if (value is Timestamp) return value.toDate();
    if (value is String && value.isNotEmpty) {
      return DateTime.tryParse(value) ?? DateTime.now();
    }
    return DateTime.now();
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
