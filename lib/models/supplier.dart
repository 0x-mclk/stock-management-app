class Supplier {
  final String? id;
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

  factory Supplier.fromMap(Map<String, dynamic> map) {
    return Supplier(
      id: map['id']?.toString(),
      name: map['name'] ?? '',
      phone: map['phone'],
      email: map['email'],
      address: map['address'],
      notes: map['notes'],
      debt: (map['debt'] ?? 0).toDouble(),
      totalPurchases: (map['total_purchases'] ?? 0).toDouble(),
      monthlyPurchases: (map['monthly_purchases'] ?? 0).toDouble(),
      yearlyPurchases: (map['yearly_purchases'] ?? 0).toDouble(),
      createdAt: DateTime.parse(map['created_at']),
      updatedAt: DateTime.parse(map['updated_at']),
    );
  }

  Supplier copyWith({
    String? id,
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




