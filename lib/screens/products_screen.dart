import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/realtime_product_provider.dart';
import '../models/product.dart';
import '../utils/currency_formatter.dart';
import '../utils/web_utils.dart';
import 'barcode_scanner_screen.dart';
import 'add_product_with_camera_screen.dart';
import '../utils/navigation_helper.dart';

// Excel import/export
import 'package:file_picker/file_picker.dart';
import 'package:excel/excel.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'package:flutter/services.dart';

class ProductsScreen extends StatefulWidget {
  const ProductsScreen({super.key});

  @override
  State<ProductsScreen> createState() => _ProductsScreenState();
}

class _ProductsScreenState extends State<ProductsScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    // Start real-time updates when screen opens
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final realtimeProvider =
          Provider.of<RealtimeProductProvider>(context, listen: false);
      realtimeProvider.startRealtimeUpdates();
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = WebBreakpoints.isDesktop(context);

    return Scaffold(
      appBar: isDesktop ? null : _buildMobileAppBar(),
      body: isDesktop ? _buildDesktopBody(context) : _buildMobileBody(),
      floatingActionButton: isDesktop
          ? null
          : FloatingActionButton.extended(
              heroTag: 'products_fab',
              onPressed: () => _showAddProductDialog(),
              icon: const Icon(Icons.camera_alt),
              label: const Text('Yeni Ürün'),
            ),
    );
  }

  PreferredSizeWidget _buildMobileAppBar() {
    return AppBar(
      title: const Text('Ürün Yönetimi'),
      actions: [
        IconButton(
          icon: const Icon(Icons.search),
          onPressed: () => _showSearchDialog(),
        ),
        IconButton(
          icon: const Icon(Icons.add),
          onPressed: () => _showAddProductDialog(),
        ),
        _buildExcelMenu(),
      ],
    );
  }

  Widget _buildExcelMenu() {
    return PopupMenuButton<String>(
      onSelected: (value) {
        if (value == 'import') _importFromExcel();
        if (value == 'export') _exportToExcel();
      },
      itemBuilder: (context) => [
        const PopupMenuItem(
          value: 'import',
          child: Row(children: [
            Icon(Icons.file_upload),
            SizedBox(width: 8),
            Text('Excel\'den İçe Aktar'),
          ]),
        ),
        const PopupMenuItem(
          value: 'export',
          child: Row(children: [
            Icon(Icons.file_download),
            SizedBox(width: 8),
            Text('Excel\'e Dışa Aktar'),
          ]),
        ),
      ],
    );
  }

  // ─── Desktop Body ───────────────────────────────────────────────────────────
  Widget _buildDesktopBody(BuildContext context) {
    return WebPageWrapper(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Page header + action buttons
          Row(
            children: [
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Ürün Yönetimi',
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.5,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Tüm ürünlerinizi yönetin, stok takibi yapın',
                      style: TextStyle(fontSize: 13, color: Colors.grey),
                    ),
                  ],
                ),
              ),
              // Action buttons in toolbar
              _buildExcelMenu(),
              const SizedBox(width: 8),
              FilledButton.icon(
                onPressed: () => _showAddProductDialog(),
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text('Yeni Ürün'),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Search bar
          SizedBox(
            width: 380,
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Ürün adı veya barkod ara...',
                prefixIcon: const Icon(Icons.search, size: 20),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 18),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _searchQuery = '');
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 12),
                isDense: true,
              ),
              onChanged: (v) => setState(() => _searchQuery = v),
            ),
          ),
          const SizedBox(height: 16),

          // DataTable
          Expanded(child: _buildProductDataTable()),
        ],
      ),
    );
  }

  Widget _buildProductDataTable() {
    return Consumer<RealtimeProductProvider>(
      builder: (context, provider, _) {
        final products = provider.products
            .where((p) =>
                p.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
                p.barcode.contains(_searchQuery))
            .toList();

        if (products.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.inventory_2_rounded,
                    size: 56, color: Colors.grey.shade300),
                const SizedBox(height: 16),
                Text(
                  _searchQuery.isEmpty
                      ? 'Henüz ürün eklenmemiş'
                      : '"$_searchQuery" için sonuç yok',
                  style:
                      const TextStyle(fontSize: 16, color: Colors.grey),
                ),
                if (_searchQuery.isEmpty) ...[
                  const SizedBox(height: 8),
                  const Text(
                    'Yeni Ürün butonuna tıklayarak ürün ekleyin',
                    style: TextStyle(fontSize: 13, color: Colors.grey),
                  ),
                ],
              ],
            ),
          );
        }

        return Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: Colors.grey.shade200),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: SingleChildScrollView(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  headingRowColor: WidgetStateProperty.all(
                      Colors.grey.shade50),
                  headingTextStyle: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                    color: Colors.black87,
                  ),
                  dataTextStyle: const TextStyle(fontSize: 13),
                  columnSpacing: 24,
                  horizontalMargin: 20,
                  columns: const [
                    DataColumn(label: Text('Ürün Adı')),
                    DataColumn(label: Text('Barkod')),
                    DataColumn(label: Text('Stok'), numeric: true),
                    DataColumn(
                        label: Text('Satış Fiyatı'), numeric: true),
                    DataColumn(
                        label: Text('Alış Fiyatı'), numeric: true),
                    DataColumn(label: Text('Kategori')),
                    DataColumn(label: Text('Durum')),
                    DataColumn(label: Text('İşlemler')),
                  ],
                  rows: products.map((p) {
                    final isLow = p.stock <= p.minStockLevel;
                    return DataRow(cells: [
                      DataCell(
                        Text(p.name,
                            style: const TextStyle(
                                fontWeight: FontWeight.w500)),
                      ),
                      DataCell(Text(p.barcode,
                          style: const TextStyle(
                              fontFamily: 'monospace',
                              fontSize: 12))),
                      DataCell(Text('${p.stock}',
                          style: TextStyle(
                              color: isLow ? Colors.red : null,
                              fontWeight: isLow
                                  ? FontWeight.w600
                                  : null))),
                      DataCell(Text(CurrencyFormatter.formatWithSymbol(
                          p.salePrice))),
                      DataCell(Text(p.purchasePrice != null
                          ? CurrencyFormatter.formatWithSymbol(
                              p.purchasePrice!)
                          : '—')),
                      DataCell(Text(p.category ?? '—')),
                      DataCell(_StockBadge(isLow: isLow)),
                      DataCell(Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.analytics_rounded,
                                size: 18, color: Colors.blue),
                            tooltip: 'Analiz',
                            onPressed: () =>
                                _navigateToProductAnalysis(p),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          ),
                          const SizedBox(width: 12),
                          IconButton(
                            icon: const Icon(Icons.edit_rounded,
                                size: 18, color: Colors.grey),
                            tooltip: 'Düzenle',
                            onPressed: () =>
                                _showEditProductDialog(p),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          ),
                          const SizedBox(width: 12),
                          IconButton(
                            icon: const Icon(Icons.add_box_rounded,
                                size: 18, color: Colors.green),
                            tooltip: 'Stok Ekle',
                            onPressed: () => _showAddStockDialog(p),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          ),
                          const SizedBox(width: 12),
                          IconButton(
                            icon: const Icon(Icons.delete_rounded,
                                size: 18, color: Colors.red),
                            tooltip: 'Sil',
                            onPressed: () =>
                                _showDeleteConfirmation(p),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          ),
                        ],
                      )),
                    ]);
                  }).toList(),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  // ─── Mobile Body ────────────────────────────────────────────────────────────
  Widget _buildMobileBody() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Ürün adı, barkod ara...',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        _searchController.clear();
                        setState(() => _searchQuery = '');
                      },
                    )
                  : null,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onChanged: (v) => setState(() => _searchQuery = v),
          ),
        ),
        Expanded(
          child: Consumer<RealtimeProductProvider>(
            builder: (context, productProvider, _) {
              final filtered = productProvider.products
                  .where((p) =>
                      p.name
                          .toLowerCase()
                          .contains(_searchQuery.toLowerCase()) ||
                      p.barcode.contains(_searchQuery))
                  .toList();

              if (filtered.isEmpty) {
                return const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.inventory_2,
                          size: 64, color: Colors.grey),
                      SizedBox(height: 16),
                      Text('Henüz ürün bulunmuyor',
                          style:
                              TextStyle(fontSize: 18, color: Colors.grey)),
                      SizedBox(height: 8),
                      Text('Yeni ürün eklemek için + butonuna dokunun',
                          style: TextStyle(color: Colors.grey)),
                    ],
                  ),
                );
              }

              return ListView.builder(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16),
                itemCount: filtered.length,
                itemBuilder: (context, i) =>
                    _buildProductCard(filtered[i]),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildProductCard(Product product) {
    final isLowStock = product.stock <= product.minStockLevel;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: isLowStock ? Colors.red : Colors.green,
          child: Text(
            product.stock.toString(),
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        title: Text(
          product.name,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Barkod: ${product.barcode}'),
            Text(
                'Satış Fiyatı: ${CurrencyFormatter.formatWithSymbol(product.salePrice)}'),
            if (isLowStock)
              Text(
                'Stok Azaldı! (Min: ${product.minStockLevel})',
                style: const TextStyle(
                    color: Colors.red, fontWeight: FontWeight.bold),
              ),
          ],
        ),
        onTap: () {
          _showProductOptionsDialog(product);
        },
      ),
    );
  }

  void _showProductOptionsDialog(Product product) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          product.name,
          style: const TextStyle(fontSize: 18),
        ),
        contentPadding: const EdgeInsets.symmetric(vertical: 4),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              dense: true,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
              leading:
                  const Icon(Icons.analytics, color: Colors.blue, size: 22),
              title: const Text('Ürün Analizi', style: TextStyle(fontSize: 16)),
              onTap: () {
                Navigator.pop(context);
                _navigateToProductAnalysis(product);
              },
            ),
            ListTile(
              dense: true,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
              leading: const Icon(Icons.edit, size: 22),
              title: const Text('Düzenle', style: TextStyle(fontSize: 16)),
              onTap: () {
                Navigator.pop(context);
                _showEditProductDialog(product);
              },
            ),
            ListTile(
              dense: true,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
              leading: const Icon(Icons.add_box, size: 22),
              title: const Text('Stok Ekle', style: TextStyle(fontSize: 16)),
              onTap: () {
                Navigator.pop(context);
                _showAddStockDialog(product);
              },
            ),
            ListTile(
              dense: true,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
              leading: const Icon(Icons.delete, color: Colors.red, size: 22),
              title: const Text('Sil',
                  style: TextStyle(color: Colors.red, fontSize: 16)),
              onTap: () {
                Navigator.pop(context);
                _showDeleteConfirmation(product);
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('İptal', style: TextStyle(fontSize: 16)),
          ),
        ],
      ),
    );
  }

  void _showSearchDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Gelişmiş Arama'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              decoration: InputDecoration(
                labelText: 'Ürün Adı',
                border: OutlineInputBorder(),
              ),
            ),
            SizedBox(height: 16),
            TextField(
              decoration: InputDecoration(
                labelText: 'Barkod',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('İptal'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              // Apply advanced search
            },
            child: const Text('Ara'),
          ),
        ],
      ),
    );
  }

  void _showAddProductDialog() {
    if (WebBreakpoints.isDesktop(context)) {
      // Web/masaüstü: kamera olmadan form dialog'u aç (mobilde zaten çalışan dialog)
      _showProductDialog();
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => const AddProductWithCameraScreen(),
        ),
      );
    }
  }

  void _showEditProductDialog(Product product) {
    _showProductDialog(product: product);
  }

  void _showProductDialog({Product? product}) {
    final isEditing = product != null;
    final nameController = TextEditingController(text: product?.name ?? '');
    final barcodeController =
        TextEditingController(text: product?.barcode ?? '');
    final salePriceController = TextEditingController(
      text: product?.salePrice.toString() ?? '',
    );
    final purchasePriceController = TextEditingController(
      text: product?.purchasePrice.toString() ?? '',
    );
    final stockController = TextEditingController(
      text: product?.stock.toString() ?? '0',
    );
    final minStockController = TextEditingController(
      text: product?.minStockLevel.toString() ?? '5',
    );

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(isEditing ? 'Ürün Düzenle' : 'Yeni Ürün Ekle'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'Ürün Adı *',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: barcodeController,
                      decoration: const InputDecoration(
                        labelText: 'Barkod *',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () async {
                      try {
                        final String? barcode =
                            await Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (context) => const BarcodeScannerScreen(
                              title: 'Ürün - Barkod Okuyucu',
                            ),
                          ),
                        );

                        if (barcode != null && barcode.isNotEmpty) {
                          barcodeController.text = barcode;
                        }
                      } catch (e) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Barkod okuyucu hatası: $e'),
                            backgroundColor: Colors.red,
                          ),
                        );
                      }
                    },
                    icon: const Icon(Icons.qr_code_scanner),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: salePriceController,
                      decoration: const InputDecoration(
                        labelText: 'Satış Fiyatı *',
                        border: OutlineInputBorder(),
                        prefixText: '₺',
                      ),
                      keyboardType: TextInputType.number,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextField(
                      controller: purchasePriceController,
                      decoration: const InputDecoration(
                        labelText: 'Alış Fiyatı',
                        border: OutlineInputBorder(),
                        prefixText: '₺',
                      ),
                      keyboardType: TextInputType.number,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: stockController,
                      decoration: const InputDecoration(
                        labelText: 'Stok Miktarı',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly, // Sadece rakam
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextField(
                      controller: minStockController,
                      decoration: const InputDecoration(
                        labelText: 'Min. Stok',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.number,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('İptal'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (nameController.text.trim().isEmpty ||
                  barcodeController.text.trim().isEmpty ||
                  salePriceController.text.trim().isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Zorunlu alanları doldurun'),
                    backgroundColor: Colors.red,
                  ),
                );
                return;
              }

              // ✅ Fiyat mantık kontrolü
              final salePrice = double.parse(salePriceController.text);
              final purchasePrice =
                  double.tryParse(purchasePriceController.text) ?? 0;

              if (purchasePrice > 0 && purchasePrice >= salePrice) {
                final shouldContinue = await showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: Text('⚠️ Fiyat Uyarısı'),
                    content: Text(
                        'Alış fiyatı (₺${purchasePrice.toStringAsFixed(2)}) '
                        'satış fiyatından (₺${salePrice.toStringAsFixed(2)}) '
                        'yüksek veya eşit!\n\n'
                        'Bu durumda zarar edeceksiniz. Devam etmek istiyor musunuz?'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: Text('İptal'),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(context, true),
                        child: Text('Devam Et'),
                        style:
                            TextButton.styleFrom(foregroundColor: Colors.red),
                      ),
                    ],
                  ),
                );

                if (shouldContinue != true) {
                  return; // İşlemi iptal et
                }
              }

              // ✅ Stok kontrolü - Negatif stok engelleme
              final stock = int.parse(stockController.text);
              final minStock = int.parse(minStockController.text);

              if (stock < 0) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('❌ Stok miktarı negatif olamaz!'),
                    backgroundColor: Colors.red,
                  ),
                );
                return;
              }

              if (minStock < 0) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('❌ Minimum stok miktarı negatif olamaz!'),
                    backgroundColor: Colors.red,
                  ),
                );
                return;
              }

              // ✅ Barkod çakışması kontrolü
              final barcodeToCheck = barcodeController.text.trim();
              final existingProducts = context
                  .read<RealtimeProductProvider>()
                  .products
                  .where((p) => p.barcode == barcodeToCheck)
                  .toList();

              if (isEditing) {
                // Güncelleme: Başka üründe aynı barkod var mı kontrol et (kendi hariç)
                final currentProductId = product.id;
                final otherProducts = existingProducts
                    .where((p) => p.id != currentProductId)
                    .toList();

                if (otherProducts.isNotEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        '❌ Bu barkod numarası başka bir ürün tarafından kullanılıyor!\n'
                        'Barkod: $barcodeToCheck\n'
                        'Diğer Ürün: ${otherProducts.first.name}',
                      ),
                      backgroundColor: Colors.red,
                      duration: const Duration(seconds: 4),
                      action: SnackBarAction(
                        label: 'Tamam',
                        textColor: Colors.white,
                        onPressed: () {},
                      ),
                    ),
                  );
                  return; // İşlemi sonlandır
                }
              } else {
                // Yeni ürün: Barkod hiç kullanılmamış olmalı
                if (existingProducts.isNotEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        '❌ Bu barkod numarası zaten kullanılıyor!\n'
                        'Barkod: $barcodeToCheck\n'
                        'Mevcut Ürün: ${existingProducts.first.name}',
                      ),
                      backgroundColor: Colors.red,
                      duration: const Duration(seconds: 4),
                      action: SnackBarAction(
                        label: 'Tamam',
                        textColor: Colors.white,
                        onPressed: () {},
                      ),
                    ),
                  );
                  return; // İşlemi sonlandır
                }
              }

              final newProduct = Product(
                id: product?.id, // Yeni ürün için null olacak
                name: nameController.text.trim(),
                barcode: barcodeController.text.trim(),
                salePrice: double.parse(salePriceController.text),
                purchasePrice:
                    double.tryParse(purchasePriceController.text) ?? 0,
                stock: stock,
                minStock: minStock,
                storeId: '', // ✅ Provider otomatik atayacak
              );

              bool success;
              if (isEditing) {
                success = await context
                    .read<RealtimeProductProvider>()
                    .updateProduct(newProduct);
              } else {
                success = await context
                    .read<RealtimeProductProvider>()
                    .addProduct(newProduct);
              }

              Navigator.pop(context);

              if (success) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(isEditing
                        ? 'Ürün başarıyla güncellendi'
                        : 'Ürün başarıyla eklendi'),
                    backgroundColor: Colors.green,
                  ),
                );
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(isEditing
                        ? 'Ürün güncellenirken hata oluştu'
                        : 'Ürün eklenirken hata oluştu'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            child: Text(isEditing ? 'Güncelle' : 'Ekle'),
          ),
        ],
      ),
    );
  }

  void _showDeleteConfirmation(Product product) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Ürün Sil'),
        content:
            Text('${product.name} ürününü silmek istediğinizden emin misiniz?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('İptal'),
          ),
          ElevatedButton(
            onPressed: () async {
              final success = await context
                  .read<RealtimeProductProvider>()
                  .deleteProduct(product.id!);
              Navigator.pop(context);
              if (success) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Ürün başarıyla silindi'),
                    backgroundColor: Colors.green,
                  ),
                );
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Ürün silinemedi'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Sil'),
          ),
        ],
      ),
    );
  }

  void _showAddStockDialog(Product product) {
    final stockController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('${product.name} - Stok Ekle'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Mevcut Stok: ${product.stock}'),
            const SizedBox(height: 16),
            TextField(
              controller: stockController,
              decoration: const InputDecoration(
                labelText: 'Eklenecek Miktar',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('İptal'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (stockController.text.trim().isEmpty) return;

              final addAmount = int.tryParse(stockController.text) ?? 0;
              if (addAmount <= 0) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('❌ Eklenecek miktar pozitif olmalıdır!'),
                    backgroundColor: Colors.red,
                  ),
                );
                return;
              }

              final updatedProduct = product.copyWith(
                stock: product.stock + addAmount,
              );

              final success = await context
                  .read<RealtimeProductProvider>()
                  .updateProduct(updatedProduct);
              Navigator.pop(context);
              if (success) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('$addAmount adet stok eklendi'),
                    backgroundColor: Colors.green,
                  ),
                );
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Stok güncellenemedi'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            child: const Text('Ekle'),
          ),
        ],
      ),
    );
  }

  Future<void> _importFromExcel() async {
    if (kIsWeb) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Excel içe aktarma web platformunda desteklenmemektedir'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }
    try {
      // Dosya seçici
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['xlsx', 'xls'],
      );

      if (result == null) return;

      File file = File(result.files.single.path!);
      var bytes = await file.readAsBytes();
      var excel = Excel.decodeBytes(bytes);

      // İlk sheet'i al
      Sheet sheet = excel.tables.values.first;

      final productProvider =
          Provider.of<RealtimeProductProvider>(context, listen: false);
      int importedCount = 0;
      int errorCount = 0;
      int priceErrorCount = 0; // ✅ Fiyat hatası sayacı
      List<String> priceErrorProducts = []; // ✅ Fiyat hatası olan ürünler

      // İlk satır başlık olduğu için 1'den başla
      for (int i = 1; i < sheet.rows.length; i++) {
        try {
          var row = sheet.rows[i];
          if (row.length < 5) continue; // En az 5 kolon olmalı

          String name = row[0]?.value?.toString() ?? '';
          String barcode = row[1]?.value?.toString() ?? '';
          String category = row[2]?.value?.toString() ?? '';
          double purchasePrice =
              double.tryParse(row[3]?.value?.toString() ?? '0') ?? 0;
          double salePrice =
              double.tryParse(row[4]?.value?.toString() ?? '0') ?? 0;
          int stock = int.tryParse(row[5]?.value?.toString() ?? '0') ?? 0;
          int minStock = int.tryParse(row[6]?.value?.toString() ?? '0') ?? 0;
          String description =
              row.length > 7 ? (row[7]?.value?.toString() ?? '') : '';

          if (name.isEmpty || salePrice <= 0) {
            errorCount++;
            continue;
          }

          // ✅ Fiyat mantık kontrolü - Excel import için
          if (purchasePrice > 0 && purchasePrice >= salePrice) {
            priceErrorCount++;
            priceErrorProducts.add(name);
            errorCount++;
            continue; // Bu ürünü atla
          }

          // ✅ Stok kontrolü - Excel import için negatif stok engelleme
          if (stock < 0 || minStock < 0) {
            errorCount++;
            continue; // Bu ürünü atla
          }

          // Ürün oluştur
          Product product = Product(
            // id'yi null bırak, veritabanı otomatik oluştursun
            name: name,
            barcode: barcode.isEmpty ? 'NO_BARCODE_$i' : barcode,
            category: category.isEmpty ? 'Genel' : category,
            purchasePrice: purchasePrice > 0 ? purchasePrice : null,
            salePrice: salePrice,
            stock: stock,
            minStock: minStock,
            description: description.isEmpty ? null : description,
            storeId: '', // ✅ Provider otomatik atayacak
          );

          final success = await productProvider.addProduct(product);
          if (success) {
            importedCount++;
          } else {
            errorCount++;
          }
        } catch (e) {
          errorCount++;
        }
      }

      // RealtimeProductProvider otomatik günceller, loadProducts() gereksiz

      // ✅ Detaylı sonuç mesajı
      String message = '✅ $importedCount ürün başarıyla içe aktarıldı';
      if (errorCount > 0) {
        message += '\n❌ $errorCount hata';
        if (priceErrorCount > 0) {
          message += '\n⚠️ $priceErrorCount fiyat hatası (alış ≥ satış)';
        }
      }

      if (priceErrorCount > 0) {
        // Fiyat hatası detayları için dialog göster
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: Text('⚠️ Import Sonucu'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(message),
                  if (priceErrorProducts.isNotEmpty) ...[
                    SizedBox(height: 10),
                    Text('Fiyat hatası olan ürünler:',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    ...priceErrorProducts.take(5).map((name) =>
                        Text('• $name', style: TextStyle(fontSize: 12))),
                    if (priceErrorProducts.length > 5)
                      Text(
                          '... ve ${priceErrorProducts.length - 5} diğer ürün'),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('Tamam'),
              ),
            ],
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Hata: $e')),
      );
    }
  }

  Future<void> _exportToExcel() async {
    if (kIsWeb) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Excel dışa aktarma web platformunda desteklenmemektedir'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }
    try {
      final productProvider =
          Provider.of<RealtimeProductProvider>(context, listen: false);
      final products = productProvider.products;

      // // Debug print removed // Removed for production // Debug

      if (products.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Dışa aktarılacak ürün bulunamadı')),
        );
        return;
      }

      // Excel dosyası oluştur
      var excel = Excel.createExcel();

      // Varsayılan Sheet'i Ürünler olarak yeniden adlandır
      excel.rename('Sheet1', 'Ürünler');
      Sheet sheetObject = excel['Ürünler'];

      // Başlık satırını manuel olarak set et
      sheetObject.cell(CellIndex.indexByString('A1')).value =
          TextCellValue('Ürün Adı');
      sheetObject.cell(CellIndex.indexByString('B1')).value =
          TextCellValue('Barkod');
      sheetObject.cell(CellIndex.indexByString('C1')).value =
          TextCellValue('Kategori');
      sheetObject.cell(CellIndex.indexByString('D1')).value =
          TextCellValue('Alış Fiyatı');
      sheetObject.cell(CellIndex.indexByString('E1')).value =
          TextCellValue('Satış Fiyatı');
      sheetObject.cell(CellIndex.indexByString('F1')).value =
          TextCellValue('Stok');
      sheetObject.cell(CellIndex.indexByString('G1')).value =
          TextCellValue('Minimum Stok');
      sheetObject.cell(CellIndex.indexByString('H1')).value =
          TextCellValue('Açıklama');

      // Ürün verilerini ekle
      for (int i = 0; i < products.length; i++) {
        final product = products[i];
        final rowIndex = i + 2; // 2'den başla (1. satır başlık)

        // // Debug print removed // Removed for production // Debug

        sheetObject.cell(CellIndex.indexByString('A$rowIndex')).value =
            TextCellValue(product.name);
        sheetObject.cell(CellIndex.indexByString('B$rowIndex')).value =
            TextCellValue(product.barcode);
        sheetObject.cell(CellIndex.indexByString('C$rowIndex')).value =
            TextCellValue(product.category ?? '');
        sheetObject.cell(CellIndex.indexByString('D$rowIndex')).value =
            TextCellValue(product.purchasePrice?.toString() ?? '0');
        sheetObject.cell(CellIndex.indexByString('E$rowIndex')).value =
            TextCellValue(product.salePrice.toString());
        sheetObject.cell(CellIndex.indexByString('F$rowIndex')).value =
            TextCellValue(product.stock.toString());
        sheetObject.cell(CellIndex.indexByString('G$rowIndex')).value =
            TextCellValue(product.minStock.toString());
        sheetObject.cell(CellIndex.indexByString('H$rowIndex')).value =
            TextCellValue(product.description ?? '');
      }

      // Downloads klasörüne kaydet
      Directory? directory;
      if (Platform.isAndroid) {
        // Android için Downloads klasörünü kullan
        directory = Directory('/storage/emulated/0/Download');
        if (!await directory.exists()) {
          directory = await getExternalStorageDirectory();
        }
      } else {
        directory = await getApplicationDocumentsDirectory();
      }

      String fileName = 'urunler_${DateTime.now().millisecondsSinceEpoch}.xlsx';
      String filePath = '${directory?.path}/$fileName';

      // // Debug print removed // Removed for production // Debug

      List<int>? fileBytes = excel.save();
      if (fileBytes != null) {
        File file = File(filePath);
        await file.writeAsBytes(fileBytes);

        // // Debug print removed // Removed for production // Debug

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'Excel dosyası kaydedildi:\n$filePath\n${products.length} ürün dışa aktarıldı'),
            duration: const Duration(seconds: 5),
            action: SnackBarAction(
              label: 'Tamam',
              onPressed: () {},
            ),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Excel dosyası oluşturulamadı')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Hata: $e')),
      );
    }
  }

  // Navigate to product analysis with selected product
  void _navigateToProductAnalysis(Product product) {
    NavigationHelper.openProductAnalysis(
      context,
      product: product,
      source: 'products',
    );
  }
}

// ─────────────────────────────────────────────
// Helpers
// ─────────────────────────────────────────────
class _StockBadge extends StatelessWidget {
  final bool isLow;
  const _StockBadge({required this.isLow});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: isLow
            ? Colors.red.withValues(alpha: 0.1)
            : Colors.green.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        isLow ? 'Stok Az' : 'Normal',
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: isLow ? Colors.red : Colors.green,
        ),
      ),
    );
  }
}
