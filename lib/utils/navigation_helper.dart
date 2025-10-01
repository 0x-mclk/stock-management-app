import 'package:flutter/material.dart';
import '../models/product.dart';
import '../screens/qr_product_analysis_screen.dart';

/// Merkezi navigation yönetimi için utility sınıfı
class NavigationHelper {
  /// Ürün analizi sayfasını açar
  ///
  /// [context] - BuildContext
  /// [product] - Önceden seçilmiş ürün (opsiyonel)
  /// [source] - Hangi sayfadan geldiği bilgisi (analytics için)
  static Future<void> openProductAnalysis(
    BuildContext context, {
    Product? product,
    String? source,
  }) {
    return Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => QRProductAnalysisScreen(
          preSelectedProduct: product,
        ),
      ),
    );
  }

  /// Ürün analizi sayfasını modalBottom olarak açar
  static Future<void> openProductAnalysisModal(
    BuildContext context, {
    Product? product,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.9,
        child: QRProductAnalysisScreen(
          preSelectedProduct: product,
        ),
      ),
    );
  }

  /// Ürün analizi sayfasını tam ekran dialog olarak açar
  static Future<void> openProductAnalysisDialog(
    BuildContext context, {
    Product? product,
  }) {
    return showDialog(
      context: context,
      useSafeArea: true,
      builder: (context) => Dialog.fullscreen(
        child: QRProductAnalysisScreen(
          preSelectedProduct: product,
        ),
      ),
    );
  }
}
