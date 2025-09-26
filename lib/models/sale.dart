import 'package:cloud_firestore/cloud_firestore.dart';

enum PaymentMethod {
  cash,
  creditCard,
  debit,
  installment,
}

class Sale {
  final String? id;
  final String storeId; // ✅ Store isolation için eklendi
  final String? supplierId;
  final double totalAmount;
  final double discount;
  final double finalAmount;
  final PaymentMethod paymentMethod;
  final List<SaleItem> items;
  final DateTime createdAt;
  final bool isPrinted;

  Sale({
    this.id,
    required this.storeId, // ✅ Zorunlu alan
    this.supplierId,
    required this.totalAmount,
    this.discount = 0.0,
    double? finalAmount,
    required this.paymentMethod,
    required this.items,
    DateTime? createdAt,
    this.isPrinted = false,
  })  : finalAmount =
            finalAmount ?? (totalAmount - (totalAmount * discount / 100)),
        createdAt = createdAt ?? DateTime.now();

  // SQLite için (items hariç)
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'store_id': storeId,
      'supplier_id': supplierId,
      'total_amount': totalAmount,
      'discount': discount,
      'final_amount': finalAmount,
      'payment_method': paymentMethod.name,
      'created_at': createdAt.toIso8601String(),
      'is_printed': isPrinted ? 1 : 0,
      // 'items' field'ı SQLite için çıkarıldı - sale_items tablosunda tutuluyor
    };
  }

  // Firebase için (items dahil)
  Map<String, dynamic> toMapForFirebase() {
    final map = toMap();
    map['items'] = items.map((item) => item.toMap()).toList();
    return map;
  }

  factory Sale.fromMap(Map<String, dynamic> map) {
    return Sale(
      id: map['id']?.toString(),
      storeId: map['store_id'] ??
          map['storeId'] ??
          '', // ✅ Hem SQLite hem Firebase uyumlu
      supplierId: map['supplier_id']?.toString(),
      totalAmount: (map['total_amount'] ?? map['totalAmount'] ?? 0).toDouble(),
      discount: (map['discount'] ?? 0).toDouble(),
      finalAmount: (map['final_amount'] ?? map['finalAmount'] ?? 0).toDouble(),
      paymentMethod: PaymentMethod.values.firstWhere(
        (e) => e.name == (map['payment_method'] ?? map['paymentMethod']),
        orElse: () => PaymentMethod.cash,
      ),
      items: (map['items'] as List<dynamic>?)
              ?.map((item) => SaleItem.fromMap(item as Map<String, dynamic>))
              .toList() ??
          [], // ✅ Items mapping eklendi
      createdAt: map['created_at'] != null
          ? DateTime.parse(map['created_at'])
          : (map['createdAt'] != null
              ? (map['createdAt'] as Timestamp).toDate()
              : (map['saleDate'] != null
                  ? (map['saleDate'] as Timestamp).toDate()
                  : DateTime.now())),
      isPrinted: (map['is_printed'] ?? map['isPrinted'] ?? 0) == 1,
    );
  }

  Sale copyWith({
    String? id,
    String? storeId,
    String? supplierId,
    double? totalAmount,
    double? discount,
    double? finalAmount,
    PaymentMethod? paymentMethod,
    List<SaleItem>? items,
    DateTime? createdAt,
    bool? isPrinted,
  }) {
    return Sale(
      id: id ?? this.id,
      storeId: storeId ?? this.storeId, // ✅ Store ID eklendi
      supplierId: supplierId ?? this.supplierId,
      totalAmount: totalAmount ?? this.totalAmount,
      discount: discount ?? this.discount,
      finalAmount: finalAmount ?? this.finalAmount,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      items: items ?? this.items,
      createdAt: createdAt ?? this.createdAt,
      isPrinted: isPrinted ?? this.isPrinted,
    );
  }
}

class SaleItem {
  final String? id;
  final String saleId;
  final String productId;
  final String productName;
  final String productBarcode;
  final int quantity;
  final double unitPrice;

  SaleItem({
    this.id,
    this.saleId = '',
    required this.productId,
    required this.productName,
    this.productBarcode = '',
    required this.quantity,
    required this.unitPrice,
  });

  double get totalPrice => quantity * unitPrice;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'sale_id': saleId,
      'product_id': productId,
      'product_name': productName,
      'product_barcode': productBarcode,
      'quantity': quantity,
      'unit_price': unitPrice,
      'total_price': totalPrice,
    };
  }

  factory SaleItem.fromMap(Map<String, dynamic> map) {
    return SaleItem(
      id: map['id']?.toString(),
      saleId: map['sale_id']?.toString() ?? '',
      productId: map['product_id']?.toString() ?? '',
      productName: map['product_name']?.toString() ?? '',
      productBarcode: map['product_barcode']?.toString() ?? '',
      quantity: (map['quantity'] ?? 0).toInt(),
      unitPrice: (map['unit_price'] ?? 0).toDouble(),
    );
  }

  SaleItem copyWith({
    String? id,
    String? saleId,
    String? productId,
    String? productName,
    String? productBarcode,
    int? quantity,
    double? unitPrice,
  }) {
    return SaleItem(
      id: id ?? this.id,
      saleId: saleId ?? this.saleId,
      productId: productId ?? this.productId,
      productName: productName ?? this.productName,
      productBarcode: productBarcode ?? this.productBarcode,
      quantity: quantity ?? this.quantity,
      unitPrice: unitPrice ?? this.unitPrice,
    );
  }
}
