import 'package:flutter/material.dart';
import '../models/product.dart';
import '../screens/qr_product_analysis_screen.dart';
import 'web_utils.dart';

/// Merkezi navigation yönetimi için utility sınıfı
class NavigationHelper {
  /// Ürün analizi sayfasını açar.
  /// Masaüstünde sağdan kayan panel, mobilde tam ekran route.
  static Future<void> openProductAnalysis(
    BuildContext context, {
    Product? product,
    String? source,
  }) {
    return showWebPanel(
      context: context,
      child: QRProductAnalysisScreen(preSelectedProduct: product),
      panelWidth: 900,
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
