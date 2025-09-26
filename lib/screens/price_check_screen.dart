import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/realtime_product_provider.dart';
import '../models/product.dart';
import 'barcode_scanner_screen.dart';

class PriceCheckScreen extends StatefulWidget {
  const PriceCheckScreen({super.key});

  @override
  State<PriceCheckScreen> createState() => _PriceCheckScreenState();
}

class _PriceCheckScreenState extends State<PriceCheckScreen> {
  final TextEditingController _barcodeController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();
  Product? _foundProduct;
  bool _isSearching = false;
  String _searchQuery = '';

  @override
  void dispose() {
    _barcodeController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _scanBarcode() async {
    try {
      final String? barcode = await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => const BarcodeScannerScreen(
            title: 'Fiyat Kontrol',
            isPriceCheckMode: true,
          ),
        ),
      );

      if (barcode != null && barcode.isNotEmpty) {
        _barcodeController.text = barcode;
        _searchProductByBarcode(barcode);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Barkod okuyucu hatası: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _searchProductByBarcode(String barcode) {
    if (barcode.trim().isEmpty) return;

    setState(() {
      _isSearching = true;
      _foundProduct = null;
    });

    final realtimeProductProvider = context.read<RealtimeProductProvider>();
    final product = realtimeProductProvider.products
        .where((p) => p.barcode == barcode)
        .firstOrNull;

    setState(() {
      _isSearching = false;
      _foundProduct = product;
    });

    if (product == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Bu barkoda sahip ürün bulunamadı'),
          backgroundColor: Colors.orange,
        ),
      );
    }
  }

  void _searchProductByName() {
    setState(() {
      _searchQuery = _searchController.text.toLowerCase();
    });
  }

  void _selectProduct(Product product) {
    setState(() {
      _foundProduct = product;
      _barcodeController.text = product.barcode;
      _searchController.clear();
      _searchQuery = '';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Fiyat Kontrol'),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Açıklama
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: Column(
                children: [
                  Icon(
                    Icons.info_outline,
                    color: Colors.blue.shade700,
                    size: 32,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Ürün Fiyatı Öğrenme',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue.shade800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Herhangi bir ürünün fiyatını öğrenmek için barkodunu okutun veya ürün adını arayın.',
                    style: TextStyle(
                      color: Colors.blue.shade700,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Barkod Girişi
            const Text(
              'Barkod ile Arama',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _barcodeController,
                    decoration: InputDecoration(
                      labelText: 'Barkod',
                      hintText: 'Barkod girin veya okutun',
                      prefixIcon: const Icon(Icons.qr_code),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onSubmitted: _searchProductByBarcode,
                  ),
                ),
                const SizedBox(width: 12),
                ElevatedButton.icon(
                  onPressed: _scanBarcode,
                  icon: const Icon(Icons.qr_code_scanner),
                  label: const Text('Okut'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 24),

            // İsim ile Arama
            const Text(
              'Ürün Adı ile Arama',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _searchController,
              decoration: InputDecoration(
                labelText: 'Ürün Adı',
                hintText: 'Ürün adını yazın',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          setState(() {
                            _searchQuery = '';
                          });
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onChanged: (value) => _searchProductByName(),
            ),

            const SizedBox(height: 24),

            // Arama Sonuçları
            if (_searchQuery.isNotEmpty) ...[
              const Text(
                'Arama Sonuçları',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              Consumer<RealtimeProductProvider>(
                builder: (context, realtimeProductProvider, child) {
                  final filteredProducts = realtimeProductProvider.products
                      .where((product) =>
                          product.name.toLowerCase().contains(_searchQuery))
                      .toList();

                  if (filteredProducts.isEmpty) {
                    return Container(
                      padding: const EdgeInsets.all(20),
                      child: const Text(
                        'Aranan kriterlere uygun ürün bulunamadı',
                        style: TextStyle(color: Colors.grey),
                        textAlign: TextAlign.center,
                      ),
                    );
                  }

                  return ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: filteredProducts.length,
                    itemBuilder: (context, index) {
                      final product = filteredProducts[index];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: Colors.blue.shade100,
                            child: Text(
                              '₺',
                              style: TextStyle(
                                color: Colors.blue.shade800,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          title: Text(product.name),
                          subtitle: Text('Barkod: ${product.barcode}'),
                          trailing: Text(
                            '₺${product.salePrice.toStringAsFixed(2)}',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.green,
                            ),
                          ),
                          onTap: () => _selectProduct(product),
                        ),
                      );
                    },
                  );
                },
              ),
            ],

            // Yükleniyor göstergesi
            if (_isSearching)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(20),
                  child: CircularProgressIndicator(),
                ),
              ),

            // Bulunan Ürün
            if (_foundProduct != null) ...[
              const Text(
                'Ürün Bilgileri',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.green.shade50,
                      Colors.green.shade100,
                    ],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.green.shade200),
                ),
                child: Column(
                  children: [
                    Icon(
                      Icons.check_circle,
                      color: Colors.green.shade600,
                      size: 48,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      _foundProduct!.name,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Barkod: ${_foundProduct!.barcode}',
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.green.shade600,
                        borderRadius: BorderRadius.circular(25),
                      ),
                      child: Text(
                        '₺${_foundProduct!.salePrice.toStringAsFixed(2)}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (_foundProduct!.stock > 0)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade100,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          'Stokta var (${_foundProduct!.stock} adet)',
                          style: TextStyle(
                            color: Colors.blue.shade800,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      )
                    else
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.red.shade100,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          'Stokta yok',
                          style: TextStyle(
                            color: Colors.red.shade800,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 32),

            // Temizle Butonu
            if (_foundProduct != null || _searchQuery.isNotEmpty)
              Center(
                child: ElevatedButton.icon(
                  onPressed: () {
                    setState(() {
                      _foundProduct = null;
                      _searchQuery = '';
                    });
                    _barcodeController.clear();
                    _searchController.clear();
                  },
                  icon: const Icon(Icons.refresh),
                  label: const Text('Yeni Arama'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 12,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
