import 'package:cloud_firestore/cloud_firestore.dart';

class Supplier {
  final String? id;
  final String storeId; // ✅ Store isolation için eklendi
  final String name;
  final String? phone;
  final String? email;
  final String? address;
  final String? notes;
  final double debt;
  final double totalPurchases;
  final double monthlyPurchases;
  final double yearlyPurchases;
  final DateTime createdAt;
  final DateTime updatedAt;

  Supplier({
    this.id,
    required this.storeId, // ✅ Zorunlu alan
    required this.name,
    this.phone,
    this.email,
    this.address,
    this.notes,
    this.debt = 0.0,
    this.totalPurchases = 0.0,
    this.monthlyPurchases = 0.0,
    this.yearlyPurchases = 0.0,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'store_id': storeId, // ✅ Store ID eklendi
      'name': name,
      'phone': phone,
      'email': email,
      'address': address,
      'notes': notes,
      'debt': debt,
      'total_purchases': totalPurchases,
      'monthly_purchases': monthlyPurchases,
      'yearly_purchases': yearlyPurchases,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  // Firebase için ayrı toMap metodu - camelCase field adları ile
  Map<String, dynamic> toFirebaseMap() {
    return {
      'id': id,
      'storeId': storeId, // camelCase
      'store_id': storeId, // backward compatibility
      'name': name,
      'phone': phone,
      'email': email,
      'address': address,
      'notes': notes,
      'debt': debt,
      'total_purchases': totalPurchases, // underscore versiyonu
      'monthly_purchases': monthlyPurchases, // underscore versiyonu
      'yearly_purchases': yearlyPurchases, // underscore versiyonu
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'lastModified': updatedAt.toIso8601String(), // Firebase için
      'isActive': true, // Firebase query için
    };
  }

  factory Supplier.fromMap(Map<String, dynamic> map) {
    return Supplier(
      id: map['id']?.toString(),
      storeId: (map['store_id'] ?? map['storeId'] ?? '').toString(),
      name: map['name']?.toString() ?? '',
      phone: map['phone']?.toString(),
      email: map['email']?.toString(),
      address: map['address']?.toString(),
      notes: map['notes']?.toString(),
      debt: _toDouble(map['debt']),
      totalPurchases: _toDouble(map['total_purchases']),
      monthlyPurchases: _toDouble(map['monthly_purchases']),
      yearlyPurchases: _toDouble(map['yearly_purchases']),
      createdAt: _parseDateTime(map['created_at'] ?? map['createdAt']),
      updatedAt: _parseDateTime(
        map['updated_at'] ?? map['updatedAt'] ?? map['lastModified'],
      ),
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

  Supplier copyWith({
    String? id,
    String? storeId,
    String? name,
    String? phone,
    String? email,
    String? address,
    String? notes,
    double? debt,
    double? totalPurchases,
    double? monthlyPurchases,
    double? yearlyPurchases,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Supplier(
      id: id ?? this.id,
      storeId: storeId ?? this.storeId, // ✅ Store ID eklendi
      name: name ?? this.name,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      address: address ?? this.address,
      notes: notes ?? this.notes,
      debt: debt ?? this.debt,
      totalPurchases: totalPurchases ?? this.totalPurchases,
      monthlyPurchases: monthlyPurchases ?? this.monthlyPurchases,
      yearlyPurchases: yearlyPurchases ?? this.yearlyPurchases,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
