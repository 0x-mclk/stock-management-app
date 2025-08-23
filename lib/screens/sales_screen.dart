import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/product_provider.dart';
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
      final productProvider =
          Provider.of<ProductProvider>(context, listen: false);
      final salesProvider = Provider.of<SalesProvider>(context, listen: false);
      productProvider.loadProducts();
      salesProvider.loadSales();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset:
          false, // Klavye açıldığında alt tarafın taşmasını engelle
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
      body: SingleChildScrollView(
        child: SizedBox(
          height: MediaQuery.of(context).size.height -
              kToolbarHeight -
              MediaQuery.of(context).padding.top,
          child: Column(
            children: [
              // Ürün Ekleme Alanı (Daha kompakt)
              _buildProductAddSection(),

              // Sepet Listesi (Daha büyük alan)
              Expanded(
                flex: 3, // Sepet alanını büyüttük
                child: _buildCartSection(),
              ),

              // Ödeme Bölümü (Kompakt)
              _buildPaymentSection(),
            ],
          ),
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
            color: Colors.grey.withOpacity(0.2),
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
      return const Center(
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
      );
    }

    return Column(
      children: [
        // Sepet Başlığı
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          color: Theme.of(context).primaryColor.withOpacity(0.1),
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

        // Sepet Öğeleri
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(
                horizontal: 12, vertical: 8), // Padding azaltıldı
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

    return Container(
      padding: const EdgeInsets.all(12), // Padding azaltıldı
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.2),
            spreadRadius: 1,
            blurRadius: 5,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Fiyat Özeti (tek satırda kompakt)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Ara Toplam: ₺${subtotal.toStringAsFixed(2)}'),
              if (discount > 0)
                Text('-₺${discountAmount.toStringAsFixed(2)}',
                    style: TextStyle(color: Colors.red)),
            ],
          ),

          // İndirim ve Toplam tek satırda
          Row(
            children: [
              // İndirim girişi
              const Text('İndirim: '),
              SizedBox(
                width: 50, // Width azaltıldı
                child: TextField(
                  controller: _discountController,
                  decoration: const InputDecoration(
                    hintText: '0',
                    suffixText: '%',
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(
                        horizontal: 4, vertical: 4), // Padding azaltıldı
                    isDense: true, // Compact görünüm
                  ),
                  keyboardType: TextInputType.number,
                  style: const TextStyle(fontSize: 12), // Font boyutu azaltıldı
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
                  fontSize: 16, // Font boyutu azaltıldı
                  fontWeight: FontWeight.bold,
                  color: Colors.green,
                ),
              ),
            ],
          ),

          const SizedBox(height: 8), // Boşluk azaltıldı

          // Ödeme Yöntemi Seçimi (Taksitli kaldırıldı)
          Wrap(
            spacing: 6, // Spacing azaltıldı
            children: PaymentMethod.values
                .where((method) =>
                    method != PaymentMethod.installment) // Taksitli kaldırıldı
                .map((method) {
              return ChoiceChip(
                label: Text(
                  _getPaymentMethodName(method),
                  style: const TextStyle(fontSize: 12), // Font boyutu azaltıldı
                ),
                selected: selectedPaymentMethod == method,
                onSelected: (selected) {
                  if (selected) {
                    setState(() {
                      selectedPaymentMethod = method;
                    });
                  }
                },
                materialTapTargetSize:
                    MaterialTapTargetSize.shrinkWrap, // Kompakt tap target
              );
            }).toList(),
          ),

          const SizedBox(height: 8), // Boşluk azaltıldı

          // Satış Tamamla Butonu
          ElevatedButton(
            onPressed: cartItems.isEmpty ? null : () => _completeSale(total),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
              padding:
                  const EdgeInsets.symmetric(vertical: 12), // Padding azaltıldı
            ),
            child: const Text(
              'SATIŞ TAMAMLA',
              style: TextStyle(
                fontSize: 16, // Font boyutu azaltıldı
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
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
                child: Consumer<ProductProvider>(
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

    final productProvider = context.read<ProductProvider>();
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
        cartItems[existingIndex] = cartItems[existingIndex].copyWith(
          quantity: cartItems[existingIndex].quantity + 1,
        );
      } else {
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
    setState(() {
      cartItems[index] = cartItems[index].copyWith(
        quantity: cartItems[index].quantity + 1,
      );
    });
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

  void _completeSale(double total) {
    print('🔍 SATIŞ TAMAMLAMA DEBUG:');
    print('CartItems sayısı: ${cartItems.length}');

    if (cartItems.isEmpty) {
      print('❌ Sepet boş, satış yapılamaz!');
      return;
    }

    print('📦 Sepetteki ürünler:');
    for (int i = 0; i < cartItems.length; i++) {
      final item = cartItems[i];
      print(
          '  ${i + 1}. ${item.productName} x${item.quantity} - ${item.unitPrice}₺');
    }

    final sale = Sale(
      id: null, // Yeni satış için null, veritabanı otomatik ID oluşturacak
      items: cartItems,
      totalAmount: total,
      paymentMethod: selectedPaymentMethod,
      discount: discount,
      createdAt: DateTime.now(),
    );

    print('💾 Sale nesnesi oluşturuldu, items sayısı: ${sale.items.length}');

    // Satış işlemini kaydet
    context.read<SalesProvider>().addSale(sale);

    // Stokları güncelle
    final productProvider = context.read<ProductProvider>();
    for (final item in cartItems) {
      final product = productProvider.products
          .where((p) => p.id == item.productId)
          .firstOrNull;
      if (product != null) {
        final updatedProduct = product.copyWith(
          stock: product.stock - item.quantity,
        );
        productProvider.updateProduct(updatedProduct);
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
