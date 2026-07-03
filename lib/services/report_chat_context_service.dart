import 'dart:convert';

import '../models/product.dart';
import '../models/sale.dart';

/// Satış/ürün özeti — Gemini prompt'una gider (7 veya 30 gün).
class ReportChatContextService {
  static const int defaultPeriodDays = 30;

  static const _calisanStripKeys = {
    'totalRevenueTRY',
    'totalProfitTRY',
    'transactionCount',
    'revenue',
    'profit',
    'dailyRevenue',
  };

  Map<String, dynamic> build({
    required List<Sale> sales,
    required List<Product> products,
    required bool includeFinancials,
    int periodDays = defaultPeriodDays,
  }) {
    final end = DateTime.now();
    final start = end.subtract(Duration(days: periodDays));

    final customerSales = sales.where((s) {
      if (s.supplierId != null) return false;
      return !s.createdAt.isBefore(start);
    }).toList();

    final qtyByProductId = <String, int>{};
    final nameByProductId = <String, String>{};

    for (final sale in customerSales) {
      for (final item in sale.items) {
        final id = item.productId;
        qtyByProductId[id] = (qtyByProductId[id] ?? 0) + item.quantity;
        nameByProductId[id] = item.productName;
      }
    }

    final ranked = qtyByProductId.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    List<Map<String, dynamic>> mapRanked(List<MapEntry<String, int>> list) {
      return list
          .map((e) => {
                'name': nameByProductId[e.key] ?? e.key,
                'quantity': e.value,
              })
          .toList();
    }

    final top = mapRanked(ranked.take(5).toList());
    final withSales = ranked.where((e) => e.value > 0).toList();
    final bottom = mapRanked(
      (withSales.length > 5 ? withSales.sublist(withSales.length - 5) : withSales)
          .reversed
          .toList(),
    );

    final soldIds = qtyByProductId.keys.toSet();
    final zeroSales = products
        .where((p) => p.id != null && !soldIds.contains(p.id))
        .take(15)
        .map((p) => p.name)
        .toList();

    final lowStock = products
        .where((p) => p.stock <= p.minStock)
        .take(10)
        .map((p) => {'name': p.name, 'stock': p.stock, 'minStock': p.minStock})
        .toList();

    final summary = <String, dynamic>{
      'period': 'son_$periodDays gun',
      'topProductsByQuantity': top,
      'slowProductsByQuantity': bottom,
      'noSalesInPeriod': zeroSales,
      'lowStockProducts': lowStock,
    };

    if (includeFinancials) {
      summary['transactionCount'] = customerSales.length;
      final totalRevenue =
          customerSales.fold(0.0, (t, s) => t + s.finalAmount);
      summary['totalRevenueTRY'] =
          double.parse(totalRevenue.toStringAsFixed(2));
      summary['note'] =
          'Tutarlar TRY, müşteri satışları (tedarikçi hareketleri hariç).';
    } else {
      summary['financialDataHidden'] = true;
      summary['note'] =
          'Kullanıcı çalışan rolünde; ciro ve kâr paylaşılmamalı.';
    }

    return summary;
  }

  /// Gemini'ye gidecek JSON; çalışanda finans alanları tamamen çıkarılır.
  static String toPromptJson(
    Map<String, dynamic> context, {
    required bool isYonetici,
  }) {
    if (isYonetici) {
      return const JsonEncoder.withIndent('  ').convert(context);
    }
    final safe = Map<String, dynamic>.from(context);
    for (final key in _calisanStripKeys) {
      safe.remove(key);
    }
    safe['financialDataHidden'] = true;
    return const JsonEncoder.withIndent('  ').convert(safe);
  }
}
