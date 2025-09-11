import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/realtime_product_provider.dart';
import '../models/product.dart';

class RealtimeTestScreen extends StatefulWidget {
  @override
  _RealtimeTestScreenState createState() => _RealtimeTestScreenState();
}

class _RealtimeTestScreenState extends State<RealtimeTestScreen> {
  RealtimeProductProvider? _provider;

  @override
  void initState() {
    super.initState();
    // Real-time güncellemeleri başlat
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _provider = Provider.of<RealtimeProductProvider>(context, listen: false);
      _provider?.startRealtimeUpdates();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Firebase Real-Time Test'),
        backgroundColor: Colors.blue,
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: () {
              // Manual refresh
              Provider.of<RealtimeProductProvider>(context, listen: false)
                  .startRealtimeUpdates();
            },
          ),
          IconButton(
            icon: Icon(Icons.add),
            onPressed: () => _addTestProduct(),
          ),
        ],
      ),
      body: Consumer<RealtimeProductProvider>(
        builder: (context, provider, child) {
          if (provider.isLoading && provider.products.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Firebase\'den ürünler yükleniyor...'),
                ],
              ),
            );
          }

          if (provider.products.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.inventory_2, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text(
                    'Henüz ürün bulunmuyor',
                    style: TextStyle(fontSize: 18, color: Colors.grey),
                  ),
                  SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _addTestProduct,
                    child: Text('Test Ürünü Ekle'),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Store ID: ${provider.currentStoreId}',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),
            );
          }

          return Column(
            children: [
              // Status bar
              Container(
                width: double.infinity,
                padding: EdgeInsets.all(16),
                color:
                    provider.isLoading ? Colors.orange[100] : Colors.green[100],
                child: Row(
                  children: [
                    Icon(
                      provider.isLoading ? Icons.sync : Icons.check_circle,
                      color: provider.isLoading ? Colors.orange : Colors.green,
                    ),
                    SizedBox(width: 8),
                    Text(
                      provider.isLoading
                          ? 'Firebase senkronizasyonu...'
                          : 'Firebase Real-Time Aktif',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    Spacer(),
                    Text('${provider.products.length} ürün'),
                  ],
                ),
              ),

              // Product list
              Expanded(
                child: ListView.builder(
                  itemCount: provider.products.length,
                  itemBuilder: (context, index) {
                    final product = provider.products[index];
                    return Card(
                      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      child: ListTile(
                        leading: CircleAvatar(
                          child: Text(product.stock.toString()),
                          backgroundColor:
                              product.stock > 0 ? Colors.green : Colors.red,
                          foregroundColor: Colors.white,
                        ),
                        title: Text(
                          product.name,
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                                'Fiyat: ${product.salePrice.toStringAsFixed(2)} TL'),
                            Text('Barkod: ${product.barcode}'),
                          ],
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: Icon(Icons.remove, color: Colors.red),
                              onPressed: () =>
                                  _updateStock(product, product.stock - 1),
                            ),
                            IconButton(
                              icon: Icon(Icons.add, color: Colors.green),
                              onPressed: () =>
                                  _updateStock(product, product.stock + 1),
                            ),
                            IconButton(
                              icon: Icon(Icons.delete, color: Colors.red),
                              onPressed: () => _deleteProduct(product),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addTestProduct,
        icon: Icon(Icons.add),
        label: Text('Test Ürünü Ekle'),
        tooltip: 'Firebase\'e yeni test ürünü ekle',
      ),
    );
  }

  void _addTestProduct() async {
    final provider =
        Provider.of<RealtimeProductProvider>(context, listen: false);

    if (provider.currentStoreId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Store ID bulunamadı!')),
      );
      return;
    }

    final testProduct = Product(
      id: null, // Firebase will assign ID
      name: 'Test Ürün ${DateTime.now().millisecondsSinceEpoch}',
      barcode: '${DateTime.now().millisecondsSinceEpoch}',
      salePrice: 10.99,
      purchasePrice: 8.99,
      stock: 50,
      minStock: 10,
      category: 'Test',
      storeId: provider.currentStoreId,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    final success = await provider.addProduct(testProduct);

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✅ Test ürünü Firebase\'e eklendi!'),
          backgroundColor: Colors.green,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Ürün eklenemedi!'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _updateStock(Product product, int newStock) async {
    if (newStock < 0) newStock = 0;

    final provider =
        Provider.of<RealtimeProductProvider>(context, listen: false);

    final updatedProduct = product.copyWith(
      stock: newStock,
      updatedAt: DateTime.now(),
    );

    final success = await provider.updateProduct(updatedProduct);

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✅ Stok güncellendi: ${product.name}'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 1),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Stok güncellenemedi!'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _deleteProduct(Product product) async {
    // Onay dialog'u göster
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Ürün Sil'),
        content: Text('${product.name} ürünü silinsin mi?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text('İptal'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text('Sil'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final provider =
          Provider.of<RealtimeProductProvider>(context, listen: false);
      final success = await provider.deleteProduct(product.id.toString());

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ Ürün silindi: ${product.name}'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Ürün silinemedi!'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    // Real-time updates'i güvenli şekilde durdur
    _provider?.stopRealtimeUpdates();
    super.dispose();
  }
}
