import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/sales_provider.dart';
import '../providers/product_provider.dart';
import '../models/sale.dart';
import '../models/product                            color: product.stock < 5 
                                ? Colors.red 
                                : Colors.orange,rt';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Raporlar'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Satış'),
            Tab(text: 'Ürünler'),
            Tab(text: 'Stok'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildSalesReport(),
          _buildProductsReport(),
          _buildStockReport(),
        ],
      ),
    );
  }

  Widget _buildSalesReport() {
    return Consumer<SalesProvider>(
      builder: (context, salesProvider, child) {
        if (salesProvider.isLoading) {
          return const Center(child: CircularProgressIndicator());
        }

        final sales = salesProvider.sales;
        final totalSales = sales.length;
        final totalRevenue = sales.fold<double>(
          0.0,
          (sum, sale) => sum + sale.totalAmount,
        );

        return Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      Text(
                        'Toplam Satış Özeti',
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          Column(
                            children: [
                              Text(
                                '$totalSales',
                                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                                  color: Theme.of(context).primaryColor,
                                ),
                              ),
                              const Text('Toplam Satış'),
                            ],
                          ),
                          Column(
                            children: [
                              Text(
                                '₺${totalRevenue.toStringAsFixed(2)}',
                                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                                  color: Colors.green,
                                ),
                              ),
                              const Text('Toplam Gelir'),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Son Satışlar',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              Expanded(
                child: ListView.builder(
                  itemCount: sales.take(10).length,
                  itemBuilder: (context, index) {
                    final sale = sales[index];
                    return Card(
                      child: ListTile(
                        title: Text('Satış #${sale.id}'),
                        subtitle: Text(
                          '${sale.items.length} ürün - ${sale.paymentMethod}',
                        ),
                        trailing: Text(
                          '₺${sale.totalAmount.toStringAsFixed(2)}',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.green,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildProductsReport() {
    return Consumer<ProductProvider>(
      builder: (context, productProvider, child) {
        if (productProvider.isLoading) {
          return const Center(child: CircularProgressIndicator());
        }

        final products = productProvider.products;
        final lowStockProducts = products.where((p) => p.stock < 10).toList();

        return Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      Text(
                        'Ürün Özeti',
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          Column(
                            children: [
                              Text(
                                '${products.length}',
                                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                                  color: Theme.of(context).primaryColor,
                                ),
                              ),
                              const Text('Toplam Ürün'),
                            ],
                          ),
                          Column(
                            children: [
                              Text(
                                '${lowStockProducts.length}',
                                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                                  color: Colors.orange,
                                ),
                              ),
                              const Text('Düşük Stok'),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              if (lowStockProducts.isNotEmpty) ...[
                Text(
                  'Düşük Stoklu Ürünler',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: ListView.builder(
                    itemCount: lowStockProducts.length,
                    itemBuilder: (context, index) {
                      final product = lowStockProducts[index];
                      return Card(
                        child: ListTile(
                          title: Text(product.name),
                          subtitle: Text('Kategori: ${product.category}'),
                          trailing: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: product.stockQuantity < 5 
                                  ? Colors.red 
                                  : Colors.orange,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              '${product.stockQuantity}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ] else ...[
                const Expanded(
                  child: Center(
                    child: Text('Tüm ürünler yeterli stokta'),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildStockReport() {
    return Consumer<ProductProvider>(
      builder: (context, productProvider, child) {
        if (productProvider.isLoading) {
          return const Center(child: CircularProgressIndicator());
        }

        final products = productProvider.products;
        final totalStock = products.fold<int>(
          0,
          (sum, product) => sum + product.stockQuantity,
        );
        final totalValue = products.fold<double>(
          0.0,
          (sum, product) => sum + (product.purchasePrice * product.stockQuantity),
        );

        return Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      Text(
                        'Stok Özeti',
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          Column(
                            children: [
                              Text(
                                '$totalStock',
                                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                                  color: Theme.of(context).primaryColor,
                                ),
                              ),
                              const Text('Toplam Stok'),
                            ],
                          ),
                          Column(
                            children: [
                              Text(
                                '₺${totalValue.toStringAsFixed(2)}',
                                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                                  color: Colors.green,
                                ),
                              ),
                              const Text('Stok Değeri'),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Tüm Ürünler',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              Expanded(
                child: ListView.builder(
                  itemCount: products.length,
                  itemBuilder: (context, index) {
                    final product = products[index];
                    final stockValue = product.purchasePrice * product.stockQuantity;
                    
                    return Card(
                      child: ListTile(
                        title: Text(product.name),
                        subtitle: Text(
                          'Alış: ₺${product.purchasePrice.toStringAsFixed(2)} - '
                          'Satış: ₺${product.salePrice.toStringAsFixed(2)}',
                        ),
                        trailing: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              'Stok: ${product.stockQuantity}',
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                            Text(
                              '₺${stockValue.toStringAsFixed(2)}',
                              style: const TextStyle(
                                color: Colors.green,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
