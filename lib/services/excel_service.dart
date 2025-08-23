import 'dart:io' as io;
import 'package:excel/excel.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../models/product.dart';
import '../models/sale.dart';
import '../models/supplier.dart';
// path_provider sadece web dışı platformlarda kullanılacak
import 'package:path_provider/path_provider.dart';

class ExcelService {
  static final ExcelService _instance = ExcelService._internal();
  factory ExcelService() => _instance;
  ExcelService._internal();

  Future<bool> _requestStoragePermission() async {
    if (kIsWeb) {
      // Web'de depolama izni gerekmiyor
      return true;
    }
    final status = await Permission.storage.request();
    return status.isGranted;
  }

  Future<String> _getDownloadsDirectory() async {
    if (kIsWeb) {
      // Web'de gerçek bir dosya sistemi yok, path_provider çağrısı yapılmaz
      return '/downloads';
    } else if (io.Platform.isAndroid) {
      return '/storage/emulated/0/Download';
    } else {
      final directory = await getApplicationDocumentsDirectory();
      return directory.path;
    }
  }

  Future<String?> exportProducts(List<Product> products) async {
    try {
      if (kIsWeb) {
        // Web'de dosya sistemi işlemleri desteklenmiyor
        return null;
      }

      if (!await _requestStoragePermission()) {
        throw Exception('Depolama izni gereklidir');
      }

      final excel = Excel.createExcel();
      final sheet = excel['Ürünler'];

      // Başlık satırı
      sheet.cell(CellIndex.indexByString('A1')).value = TextCellValue('Barkod');
      sheet.cell(CellIndex.indexByString('B1')).value =
          TextCellValue('Ürün Adı');
      sheet.cell(CellIndex.indexByString('C1')).value =
          TextCellValue('Kategori');
      sheet.cell(CellIndex.indexByString('D1')).value =
          TextCellValue('Alış Fiyatı');
      sheet.cell(CellIndex.indexByString('E1')).value =
          TextCellValue('Satış Fiyatı');
      sheet.cell(CellIndex.indexByString('F1')).value = TextCellValue('Stok');
      sheet.cell(CellIndex.indexByString('G1')).value =
          TextCellValue('Min. Stok');
      sheet.cell(CellIndex.indexByString('H1')).value = TextCellValue('Marka');
      sheet.cell(CellIndex.indexByString('I1')).value = TextCellValue('Birim');
      sheet.cell(CellIndex.indexByString('J1')).value =
          TextCellValue('Oluşturma Tarihi');

      // Veri satırları
      for (int i = 0; i < products.length; i++) {
        final product = products[i];
        final row = i + 2;

        sheet.cell(CellIndex.indexByString('A$row')).value =
            TextCellValue(product.barcode);
        sheet.cell(CellIndex.indexByString('B$row')).value =
            TextCellValue(product.name);
        sheet.cell(CellIndex.indexByString('C$row')).value =
            TextCellValue(product.category ?? '');
        sheet.cell(CellIndex.indexByString('D$row')).value =
            DoubleCellValue(product.purchasePrice ?? 0.0);
        sheet.cell(CellIndex.indexByString('E$row')).value =
            DoubleCellValue(product.salePrice);
        sheet.cell(CellIndex.indexByString('F$row')).value =
            IntCellValue(product.stock);
        sheet.cell(CellIndex.indexByString('G$row')).value =
            IntCellValue(product.minStock);
        sheet.cell(CellIndex.indexByString('H$row')).value =
            TextCellValue(product.description ?? '');
        sheet.cell(CellIndex.indexByString('I$row')).value =
            TextCellValue('adet'); // Default unit
        sheet.cell(CellIndex.indexByString('J$row')).value =
            TextCellValue(product.createdAt.toString());
      }

      final directory = await _getDownloadsDirectory();
      final fileName = 'urunler_${DateTime.now().millisecondsSinceEpoch}.xlsx';
      final filePath = '$directory/$fileName';

      final bytes = excel.save();
      if (bytes != null) {
        if (kIsWeb) {
          // Web'de dosya yazılamaz, null döndürülür veya farklı bir çözüm uygulanabilir
          return null;
        } else {
          final file = io.File(filePath);
          await file.writeAsBytes(bytes);
          return filePath;
        }
      }
      return null;
    } catch (e) {
      throw Exception('Excel dışa aktarma hatası: $e');
    }
  }

  Future<String?> exportSales(List<Sale> sales) async {
    try {
      if (kIsWeb) {
        // Web'de dosya sistemi işlemleri desteklenmiyor
        return null;
      }

      if (!await _requestStoragePermission()) {
        throw Exception('Depolama izni gereklidir');
      }

      final excel = Excel.createExcel();
      final sheet = excel['Satışlar'];

      // Başlık satırı
      sheet.cell(CellIndex.indexByString('A1')).value =
          TextCellValue('Satış ID');
      sheet.cell(CellIndex.indexByString('B1')).value = TextCellValue('Tarih');
      sheet.cell(CellIndex.indexByString('C1')).value = TextCellValue('Toplam');
      sheet.cell(CellIndex.indexByString('D1')).value =
          TextCellValue('İndirim');
      sheet.cell(CellIndex.indexByString('E1')).value =
          TextCellValue('Net Toplam');
      sheet.cell(CellIndex.indexByString('F1')).value =
          TextCellValue('Ödeme Türü');
      sheet.cell(CellIndex.indexByString('G1')).value =
          TextCellValue('Yazdırıldı');

      // Veri satırları
      for (int i = 0; i < sales.length; i++) {
        final sale = sales[i];
        final row = i + 2;

        sheet.cell(CellIndex.indexByString('A$row')).value =
            TextCellValue(sale.id ?? '');
        sheet.cell(CellIndex.indexByString('B$row')).value =
            TextCellValue(sale.createdAt.toString());
        sheet.cell(CellIndex.indexByString('C$row')).value =
            DoubleCellValue(sale.totalAmount);
        sheet.cell(CellIndex.indexByString('D$row')).value =
            DoubleCellValue(sale.discount);
        sheet.cell(CellIndex.indexByString('E$row')).value =
            DoubleCellValue(sale.finalAmount);
        sheet.cell(CellIndex.indexByString('F$row')).value =
            TextCellValue(sale.paymentMethod.name);
        sheet.cell(CellIndex.indexByString('G$row')).value =
            TextCellValue(sale.isPrinted ? 'Evet' : 'Hayır');
      }

      final directory = await _getDownloadsDirectory();
      final fileName = 'satislar_${DateTime.now().millisecondsSinceEpoch}.xlsx';
      final filePath = '$directory/$fileName';

      final bytes = excel.save();
      if (bytes != null) {
        if (kIsWeb) {
          return null;
        } else {
          final file = io.File(filePath);
          await file.writeAsBytes(bytes);
          return filePath;
        }
      }
      return null;
    } catch (e) {
      throw Exception('Excel dışa aktarma hatası: $e');
    }
  }

  Future<String?> exportSuppliers(List<Supplier> suppliers) async {
    try {
      if (kIsWeb) {
        // Web'de dosya sistemi işlemleri desteklenmiyor
        return null;
      }

      if (!await _requestStoragePermission()) {
        throw Exception('Depolama izni gereklidir');
      }

      final excel = Excel.createExcel();
      final sheet = excel['Tedarikçiler'];

      // Başlık satırı
      sheet.cell(CellIndex.indexByString('A1')).value =
          TextCellValue('Şirket Adı');
      sheet.cell(CellIndex.indexByString('B1')).value =
          TextCellValue('Telefon');
      sheet.cell(CellIndex.indexByString('C1')).value = TextCellValue('Adres');
      sheet.cell(CellIndex.indexByString('D1')).value = TextCellValue('Notlar');
      sheet.cell(CellIndex.indexByString('E1')).value = TextCellValue('Borç');
      sheet.cell(CellIndex.indexByString('F1')).value =
          TextCellValue('Toplam Alışlar');
      sheet.cell(CellIndex.indexByString('G1')).value =
          TextCellValue('Oluşturma Tarihi');

      // Veri satırları
      for (int i = 0; i < suppliers.length; i++) {
        final supplier = suppliers[i];
        final row = i + 2;

        sheet.cell(CellIndex.indexByString('A$row')).value =
            TextCellValue(supplier.name);
        sheet.cell(CellIndex.indexByString('B$row')).value =
            TextCellValue(supplier.phone ?? '');
        sheet.cell(CellIndex.indexByString('C$row')).value =
            TextCellValue(supplier.address ?? '');
        sheet.cell(CellIndex.indexByString('D$row')).value =
            TextCellValue(supplier.notes ?? '');
        sheet.cell(CellIndex.indexByString('E$row')).value =
            DoubleCellValue(supplier.debt);
        sheet.cell(CellIndex.indexByString('F$row')).value =
            DoubleCellValue(supplier.totalPurchases);
        sheet.cell(CellIndex.indexByString('G$row')).value =
            TextCellValue(supplier.createdAt.toString());
      }

      final directory = await _getDownloadsDirectory();
      final fileName =
          'tedarikciler_${DateTime.now().millisecondsSinceEpoch}.xlsx';
      final filePath = '$directory/$fileName';

      final bytes = excel.save();
      if (bytes != null) {
        if (kIsWeb) {
          return null;
        } else {
          final file = io.File(filePath);
          await file.writeAsBytes(bytes);
          return filePath;
        }
      }
      return null;
    } catch (e) {
      throw Exception('Excel dışa aktarma hatası: $e');
    }
  }

  // Import functionality için gelecekte genişletilebilir
  Future<List<Product>?> importProducts(String filePath) async {
    // TODO: Excel dosyasından ürün import işlemi
    return null;
  }
}
