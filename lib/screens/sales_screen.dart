import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/realtime_product_provider.dart';
import '../providers/sales_provider.dart';
import '../models/product.dart';
import '../models/sale.dart';
import 'barcode_scanner_screen.dart';
import 'price_check_screen.dart';

class SalesScreen extends StatefulWidget {
  const SalesScreen({super.key});

  @override
  State<SalesScreen> createState() => _SalesScreenState();
}

class _SalesScreenState extends State<SalesScreen> {
  final TextEditingController _barcodeController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _discountController = TextEditingController();

  List<SaleItem> cartItems = [];
  double discount = 0.0;
  PaymentMethod selectedPaymentMethod = PaymentMethod.cash;

  @override
  void initState() {
    super.initState();
    // Ensure products and sales are loaded when screen opens
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final realtimeProductProvider =
          Provider.of<RealtimeProductProvider>(context, listen: false);
      final salesProvider = Provider.of<SalesProvider>(context, listen: false);
      realtimeProductProvider.startRealtimeUpdates(); // Real-time başlat
      salesProvider.loadSales();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: false,
      appBar: AppBar(
        title: const Text('Satış İşlemi'),
        actions: [
          IconButton(
            icon: const Icon(Icons.qr_code_scanner),
            onPressed: () => _scanBarcode(),
          ),
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () => _showProductSearch(),
          ),
          IconButton(
            icon: const Icon(Icons.price_check),
            tooltip: 'Fiyat Kontrol',
            onPressed: () => _openPriceCheck(),
          ),
        ],
      ),
      body: Column(
        children: [
          // Üstteki kaydırılabilir alan
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  // Ürün Ekleme Alanı
                  _buildProductAddSection(),

                  // Sepet Listesi
                  _buildCartSection(),

                  const SizedBox(height: 60), // 80'den 60'a düşürüldü
                ],
              ),
            ),
          ),
        ],
      ),
      // Alttaki sabit ödeme bölümü
      bottomSheet: Container(
        margin: const EdgeInsets.only(bottom: 0), // Margin kaldırıldı
        width: double.infinity,
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border(
            top: BorderSide(
              color: Colors.grey.shade300,
              width: 1,
            ),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 4,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
              12.0, 12.0, 12.0, 8.0), // Alt padding azaltıldı
          child: _buildPaymentSection(),
        ),
      ),
    );
  }

  Widget _buildProductAddSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withValues(alpha: 0.2),
            spreadRadius: 1,
            blurRadius: 5,
          ),
        ],
      ),
      child: Column(
        children: [
          // Barkod Girişi
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
                  onSubmitted: (value) => _addProductByBarcode(value),
                ),
              ),
              const SizedBox(width: 12),
              ElevatedButton.icon(
                onPressed: () => _scanBarcode(),
                icon: const Icon(Icons.qr_code_scanner),
                label: const Text('Oku'),
              ),
            ],
          ),
          // Hızlı satış butonları kaldırıldı
        ],
      ),
    );
  }

  Widget _buildCartSection() {
    if (cartItems.isEmpty) {
      return Container(
        height: 200,
        child: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.shopping_cart_outlined, size: 64, color: Colors.grey),
              SizedBox(height: 16),
              Text(
                'Sepet Boş',
                style: TextStyle(fontSize: 18, color: Colors.grey),
              ),
              SizedBox(height: 8),
              Text(
                'Ürün eklemek için barkod okutun veya arama yapın',
                style: TextStyle(color: Colors.grey),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Sepet Başlığı
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          color: Theme.of(context).primaryColor.withValues(alpha: 0.1),
          child: Row(
            children: [
              const Text(
                'Sepet',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              Text(
                '${cartItems.length} ürün',
                style: TextStyle(color: Colors.grey[600]),
              ),
            ],
          ),
        ),

        // Sepet Öğeleri - Maksimum yükseklik ile sınırlandırılmış
        Container(
          constraints: const BoxConstraints(
            maxHeight: 400, // 300'den 400'e artırıldı
          ),
          child: ListView.builder(
            shrinkWrap: true,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            itemCount: cartItems.length,
            itemBuilder: (context, index) {
              final item = cartItems[index];
              return _buildCartItem(item, index);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildCartItem(SaleItem item, int index) {
    return Card(
      margin: const EdgeInsets.only(bottom: 4), // Margin azaltıldı
      child: Padding(
        padding: const EdgeInsets.all(8), // Padding azaltıldı
        child: Row(
          children: [
            // Ürün Bilgileri
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.productName,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14, // Font boyutu azaltıldı
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    '₺${item.unitPrice.toStringAsFixed(2)}',
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 12, // Font boyutu azaltıldı
                    ),
                  ),
                ],
              ),
            ),

            // Miktar Kontrolü
            Row(
              children: [
                IconButton(
                  onPressed: () => _decreaseQuantity(index),
                  icon: const Icon(Icons.remove_circle_outline,
                      size: 20), // Icon boyutu azaltıldı
                  color: Colors.red,
                  padding: EdgeInsets.zero, // Padding kaldırıldı
                  constraints: const BoxConstraints(
                      minWidth: 32, minHeight: 32), // Boyut kısıtlaması
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 4), // Padding azaltıldı
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    item.quantity.toString(),
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14, // Font boyutu azaltıldı
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => _increaseQuantity(index),
                  icon: const Icon(Icons.add_circle_outline,
                      size: 20), // Icon boyutu azaltıldı
                  color: Colors.green,
                  padding: EdgeInsets.zero, // Padding kaldırıldı
                  constraints: const BoxConstraints(
                      minWidth: 32, minHeight: 32), // Boyut kısıtlaması
                ),
              ],
            ),

            // Toplam Fiyat ve Sil Butonu
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '₺${item.totalPrice.toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14, // Font boyutu azaltıldı
                  ),
                ),
                IconButton(
                  onPressed: () => _removeFromCart(index),
                  icon: const Icon(Icons.delete,
                      size: 18), // Icon boyutu azaltıldı
                  color: Colors.red,
                  padding: EdgeInsets.zero, // Padding kaldırıldı
                  constraints: const BoxConstraints(
                      minWidth: 24, minHeight: 24), // Boyut kısıtlaması
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPaymentSection() {
    final subtotal = cartItems.fold<double>(
      0.0,
      (sum, item) => sum + item.totalPrice,
    );
    final discountAmount = subtotal * (discount / 100);
    final total = subtotal - discountAmount;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Fiyat Özeti (tek satırda kompakt)
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Ara Toplam: ₺${subtotal.toStringAsFixed(2)}'),
            if (discount > 0)
              Text('-₺${discountAmount.toStringAsFixed(2)}',
                  style: const TextStyle(color: Colors.red)),
          ],
        ),

        const SizedBox(height: 4), // 8'den 4'e düşürüldü

        // İndirim ve Toplam tek satırda
        Row(
          children: [
            // İndirim girişi
            const Text('İndirim: '),
            SizedBox(
              width: 50,
              child: TextField(
                controller: _discountController,
                decoration: const InputDecoration(
                  hintText: '0',
                  suffixText: '%',
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(
                      horizontal: 4,
                      vertical: 2), // vertical 4'ten 2'ye düşürüldü
                  isDense: true,
                ),
                keyboardType: TextInputType.number,
                style: const TextStyle(fontSize: 12),
                onChanged: (value) {
                  setState(() {
                    discount = double.tryParse(value) ?? 0.0;
                  });
                },
              ),
            ),
            const Spacer(),
            // Toplam
            Text(
              'TOPLAM: ₺${total.toStringAsFixed(2)}',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.green,
              ),
            ),
          ],
        ),

        const SizedBox(height: 4), // 8'den 4'e düşürüldü

        // Ödeme Yöntemi Seçimi (Taksitli kaldırıldı)
        Wrap(
          spacing: 4, // 6'dan 4'e düşürüldü
          children: PaymentMethod.values
              .where((method) =>
                  method != PaymentMethod.installment) // Taksitli kaldırıldı
              .map((method) {
            return ChoiceChip(
              label: Text(
                _getPaymentMethodName(method),
                style: const TextStyle(fontSize: 11), // 12'den 11'e düşürüldü
              ),
              selected: selectedPaymentMethod == method,
              onSelected: (selected) {
                if (selected) {
                  setState(() {
                    selectedPaymentMethod = method;
                  });
                }
              },
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            );
          }).toList(),
        ),

        const SizedBox(height: 4), // 8'den 4'e düşürüldü

        // Satış Tamamla Butonu
        ElevatedButton(
          onPressed:
              cartItems.isEmpty ? null : () async => await _completeSale(total),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.green,
            foregroundColor: Colors.white,
            padding:
                const EdgeInsets.symmetric(vertical: 8), // 12'den 8'e düşürüldü
          ),
          child: const Text(
            'SATIŞ TAMAMLA',
            style: TextStyle(
              fontSize: 15, // 16'dan 15'e düşürüldü
              fontWeight: FontWeight.bold,
            ),
          ),
        ),

        // Butonun altındaki boşluk kaldırıldı
      ],
    );
  }

  void _scanBarcode() async {
    try {
      final String? barcode = await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => const BarcodeScannerScreen(
            title: 'Satış - Barkod Okuyucu',
          ),
        ),
      );

      if (barcode != null && barcode.isNotEmpty) {
        _barcodeController.text = barcode;
        _addProductByBarcode(barcode);
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

  void _openPriceCheck() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const PriceCheckScreen(),
      ),
    );
  }

  void _showProductSearch() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Ürün Ara'),
        content: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _searchController,
                decoration: const InputDecoration(
                  labelText: 'Ürün adı',
                  prefixIcon: Icon(Icons.search),
                  border: OutlineInputBorder(),
                ),
                onChanged: (value) => setState(() {}),
              ),
              const SizedBox(height: 16),
              SizedBox(
                height: 300,
                child: Consumer<RealtimeProductProvider>(
                  builder: (context, productProvider, child) {
                    final filteredProducts = productProvider.products
                        .where((product) => product.name
                            .toLowerCase()
                            .contains(_searchController.text.toLowerCase()))
                        .toList();

                    return ListView.builder(
                      itemCount: filteredProducts.length,
                      itemBuilder: (context, index) {
                        final product = filteredProducts[index];
                        return ListTile(
                          title: Text(product.name),
                          subtitle:
                              Text('₺${product.salePrice.toStringAsFixed(2)}'),
                          trailing: Text('Stok: ${product.stock}'),
                          onTap: () {
                            _addProductToCart(product);
                            Navigator.pop(context);
                          },
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Kapat'),
          ),
        ],
      ),
    );
  }

  void _addProductByBarcode(String barcode) {
    if (barcode.trim().isEmpty) return;

    final productProvider = context.read<RealtimeProductProvider>();
    final product =
        productProvider.products.where((p) => p.barcode == barcode).firstOrNull;

    if (product != null) {
      _addProductToCart(product);
      _barcodeController.clear();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Ürün bulunamadı'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _addProductToCart(Product product) {
    if (product.stock <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Bu ürün stokta yok'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final existingIndex = cartItems.indexWhere(
      (item) => item.productId == product.id,
    );

    setState(() {
      if (existingIndex >= 0) {
        final newQuantity = cartItems[existingIndex].quantity + 1;

        // ✅ Stok kontrolü
        if (newQuantity > product.stock) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                '⚠️ Stok yetersiz! ${product.name} için mevcut stok: ${product.stock}',
              ),
              backgroundColor: Colors.orange,
            ),
          );
          return;
        }

        cartItems[existingIndex] = cartItems[existingIndex].copyWith(
          quantity: newQuantity,
        );
      } else {
        // ✅ İlk ekleme için de stok kontrolü
        if (product.stock <= 0) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('⚠️ ${product.name} stokta yok!'),
              backgroundColor: Colors.red,
            ),
          );
          return;
        }

        cartItems.add(SaleItem(
          productId: product.id!,
          productName: product.name,
          quantity: 1,
          unitPrice: product.salePrice,
        ));
      }
    });
  }

  void _increaseQuantity(int index) {
    final cartItem = cartItems[index];
    final productProvider = context.read<RealtimeProductProvider>();
    final product = productProvider.products
        .where((p) => p.id == cartItem.productId)
        .firstOrNull;

    if (product != null) {
      final newQuantity = cartItem.quantity + 1;

      // ✅ Stok kontrolü
      if (newQuantity > product.stock) {
        // Stok yetersiz uyarısı
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '⚠️ Stok yetersiz! ${product.name} için mevcut stok: ${product.stock}',
            ),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 3),
          ),
        );
        return; // Artırma işlemini iptal et
      }

      setState(() {
        cartItems[index] = cartItems[index].copyWith(quantity: newQuantity);
      });
    }
  }

  void _decreaseQuantity(int index) {
    setState(() {
      if (cartItems[index].quantity > 1) {
        cartItems[index] = cartItems[index].copyWith(
          quantity: cartItems[index].quantity - 1,
        );
      }
    });
  }

  void _removeFromCart(int index) {
    setState(() {
      cartItems.removeAt(index);
    });
  }

  String _getPaymentMethodName(PaymentMethod method) {
    switch (method) {
      case PaymentMethod.cash:
        return 'Nakit';
      case PaymentMethod.creditCard:
        return 'Kredi Kartı';
      case PaymentMethod.debit:
        return 'Veresiye';
      case PaymentMethod.installment:
        return 'Taksitli';
    }
  }

  Future<void> _completeSale(double total) async {
    // // Debug print removed // Removed for production
    // // Debug print removed // Removed for production

    if (cartItems.isEmpty) {
      // // Debug print removed // Removed for production
      return;
    }

    // // Debug print removed // Removed for production
    for (int i = 0; i < cartItems.length; i++) {
      // Debug print removed
    }

    final sale = Sale(
      id: null, // Yeni satış için null, veritabanı otomatik ID oluşturacak
      items: cartItems,
      totalAmount: total,
      paymentMethod: selectedPaymentMethod,
      discount: discount,
      createdAt: DateTime.now(),
      storeId: '', // ✅ Provider otomatik atayacak
    );

    // // Debug print removed // Removed for production

    try {
      // Satış işlemini kaydet
      await context.read<SalesProvider>().addSale(sale);

      print('✅ Satış başarıyla tamamlandı!');

      // Stokları güncelle - RealtimeProductProvider kullan
      final productProvider = context.read<RealtimeProductProvider>();
      for (final item in cartItems) {
        final product = productProvider.products
            .where((p) => p.id == item.productId)
            .firstOrNull;
        if (product != null) {
          final newStock = product.stock - item.quantity;

          // ✅ Stok sıfır olsa bile ürünü silme, sadece 0 yap
          final finalStock =
              newStock < 0 ? 0 : newStock; // Negatif olmasını engelle
          final updatedProduct = product.copyWith(stock: finalStock);
          await productProvider.updateProduct(updatedProduct);

          if (finalStock == 0) {
            print('⚠️ ${product.name} ürününün stoku sıfırlandı');
          }
        }
      }

      // Sepeti temizle
      setState(() {
        cartItems.clear();
        discount = 0.0;
        _discountController.clear();
      });

      // Başarı mesajı göster
      _showSaleCompleteDialog(sale);
    } catch (e) {
      print('❌ Satış tamamlama hatası: $e');

      // Kullanıcıya hata mesajı göster
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Satış kaydedilemedi: $e'),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 5),
          action: SnackBarAction(
            label: 'Tekrar Dene',
            textColor: Colors.white,
            onPressed: () => _completeSale(total),
          ),
        ),
      );
    }
  }

  void _showSaleCompleteDialog(Sale sale) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Satış Tamamlandı'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Toplam Tutar: ₺${sale.totalAmount.toStringAsFixed(2)}'),
            Text('Ödeme: ${_getPaymentMethodName(sale.paymentMethod)}'),
            if (sale.discount > 0)
              Text('İndirim: %${sale.discount.toStringAsFixed(1)}'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Tamam'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _printReceipt(sale);
            },
            child: const Text('Fiş Yazdır'),
          ),
        ],
      ),
    );
  }

  void _printReceipt(Sale sale) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Fiş yazdırılıyor...')),
    );
    // Gerçek implementasyonda printing paketi kullanılacak
  }
}
