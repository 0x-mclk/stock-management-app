import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:syncfusion_flutter_charts/charts.dart';
import '../providers/product_provider.dart';
import '../providers/sales_provider.dart';
import '../models/sale.dart';
import '../models/product.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final NumberFormat _currencyFormat = NumberFormat.currency(
    locale: 'tr_TR',
    symbol: '₺',
    decimalDigits: 2,
  );

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
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
        backgroundColor: Colors.blue[600],
        foregroundColor: Colors.white,
        elevation: 2,
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.blue[200],
          indicatorColor: Colors.white,
          tabs: const [
            Tab(
              icon: Icon(Icons.trending_up),
              text: 'Satış & Kâr',
            ),
            Tab(
              icon: Icon(Icons.analytics),
              text: 'Ürün Analizi',
            ),
            Tab(
              icon: Icon(Icons.inventory),
              text: 'Stok Analizi',
            ),
            Tab(
              icon: Icon(Icons.list_alt),
              text: 'Satış Listesi',
            ),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildSalesAndProfitTab(),
          _buildProductAnalysisTab(),
          _buildStockAnalysisTab(),
          _buildSalesListTab(),
        ],
      ),
    );
  }

  // 1. Satış & Kâr Sekmesi
  Widget _buildSalesAndProfitTab() {
    return Consumer2<SalesProvider, ProductProvider>(
      builder: (context, salesProvider, productProvider, child) {
        final sales = salesProvider.sales;

        if (sales.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.assessment, size: 64, color: Colors.grey),
                SizedBox(height: 16),
                Text('Henüz satış verisi bulunmuyor'),
              ],
            ),
          );
        }

        // Satış verilerini analiz et - SaleItem'ları kullan
        double totalRevenue = 0;
        double totalProfit = 0;
        Map<String, double> monthlyRevenue = {};
        Map<String, double> monthlyProfit = {};

        for (var sale in sales) {
          totalRevenue += sale.finalAmount;

          final monthKey = DateFormat('MM/yyyy').format(sale.createdAt);
          monthlyRevenue[monthKey] =
              (monthlyRevenue[monthKey] ?? 0) + sale.finalAmount;

          // Her satış kaleminden kâr hesapla
          double saleProfit = 0;
          for (var item in sale.items) {
            final product = productProvider.products.firstWhere(
              (p) => p.id == item.productId,
              orElse: () => Product(
                id: '',
                barcode: '',
                name: 'Bilinmeyen',
                salePrice: 0,
                stock: 0,
                category: 'Diğer',
                createdAt: DateTime.now(),
                updatedAt: DateTime.now(),
                storeId: 'unknown', // ✅ Default store ID for missing products
              ),
            );

            double itemCost =
                (product.purchasePrice ?? product.salePrice * 0.7) *
                    item.quantity;
            double itemRevenue = item.totalPrice;
            saleProfit += itemRevenue - itemCost;
          }

          totalProfit += saleProfit;
          monthlyProfit[monthKey] = (monthlyProfit[monthKey] ?? 0) + saleProfit;
        }

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              // Özet Kartları
              Row(
                children: [
                  Expanded(
                    child: _buildSummaryCard(
                      'Toplam Satış',
                      _currencyFormat.format(totalRevenue),
                      Icons.attach_money,
                      Colors.green,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildSummaryCard(
                      'Toplam Kâr',
                      _currencyFormat.format(totalProfit),
                      Icons.trending_up,
                      Colors.blue,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Aylık Satış Grafiği
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Aylık Satış Trendi',
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        height: 300,
                        child: SfCartesianChart(
                          primaryXAxis: const CategoryAxis(),
                          primaryYAxis: NumericAxis(
                            numberFormat: NumberFormat.currency(
                              locale: 'tr_TR',
                              symbol: '₺',
                              decimalDigits: 0,
                            ),
                          ),
                          legend: const Legend(isVisible: true),
                          tooltipBehavior: TooltipBehavior(enable: true),
                          series: <CartesianSeries>[
                            ColumnSeries<MapEntry<String, double>, String>(
                              dataSource: monthlyRevenue.entries.toList(),
                              xValueMapper:
                                  (MapEntry<String, double> data, _) =>
                                      data.key,
                              yValueMapper:
                                  (MapEntry<String, double> data, _) =>
                                      data.value,
                              name: 'Satış',
                              color: Colors.blue,
                            ),
                            LineSeries<MapEntry<String, double>, String>(
                              dataSource: monthlyProfit.entries.toList(),
                              xValueMapper:
                                  (MapEntry<String, double> data, _) =>
                                      data.key,
                              yValueMapper:
                                  (MapEntry<String, double> data, _) =>
                                      data.value,
                              name: 'Kâr',
                              color: Colors.green,
                              markerSettings:
                                  const MarkerSettings(isVisible: true),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // 2. Ürün Analizi Sekmesi
  Widget _buildProductAnalysisTab() {
    return Consumer2<ProductProvider, SalesProvider>(
      builder: (context, productProvider, salesProvider, child) {
        final products = productProvider.products;
        final sales = salesProvider.sales;

        if (products.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.inventory_2, size: 64, color: Colors.grey),
                SizedBox(height: 16),
                Text('Henüz ürün verisi bulunmuyor'),
              ],
            ),
          );
        }

        // Ürün satış analizleri - SaleItem'ları kullan
        Map<String, int> productSales = {};
        Map<String, double> productRevenue = {};
        Map<String, int> categorySales = {};

        for (var sale in sales) {
          for (var item in sale.items) {
            final product = products.firstWhere(
              (p) => p.id == item.productId,
              orElse: () => Product(
                id: '',
                barcode: '',
                name: 'Bilinmeyen',
                salePrice: 0,
                stock: 0,
                category: 'Diğer',
                createdAt: DateTime.now(),
                updatedAt: DateTime.now(),
                storeId: 'unknown', // ✅ Default store ID for missing products
              ),
            );

            productSales[product.name] =
                (productSales[product.name] ?? 0) + item.quantity;
            productRevenue[product.name] =
                (productRevenue[product.name] ?? 0) + item.totalPrice;

            final category = product.category ?? 'Diğer';
            categorySales[category] =
                (categorySales[category] ?? 0) + item.quantity;
          }
        }

        // En çok satan ürünler (top 10)
        final topProducts = productSales.entries.toList()
          ..sort((a, b) => b.value.compareTo(a.value));
        final topProductsData = topProducts.take(10).toList();

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              // En Çok Satan Ürünler
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'En Çok Satan Ürünler',
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        height: 300,
                        child: SfCartesianChart(
                          primaryXAxis: const CategoryAxis(
                            labelRotation: 45,
                            maximumLabelWidth: 100,
                          ),
                          primaryYAxis: const NumericAxis(),
                          tooltipBehavior: TooltipBehavior(enable: true),
                          series: <CartesianSeries>[
                            ColumnSeries<MapEntry<String, int>, String>(
                              dataSource: topProductsData,
                              xValueMapper: (MapEntry<String, int> data, _) =>
                                  data.key.length > 15
                                      ? '${data.key.substring(0, 15)}...'
                                      : data.key,
                              yValueMapper: (MapEntry<String, int> data, _) =>
                                  data.value,
                              name: 'Satış Adedi',
                              color: Colors.orange,
                              dataLabelSettings:
                                  const DataLabelSettings(isVisible: true),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Kategori Dağılımı
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Kategori Bazında Satış Dağılımı',
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        height: 300,
                        child: SfCircularChart(
                          legend: const Legend(
                            isVisible: true,
                            position: LegendPosition.bottom,
                          ),
                          tooltipBehavior: TooltipBehavior(enable: true),
                          series: <CircularSeries>[
                            PieSeries<MapEntry<String, int>, String>(
                              dataSource: categorySales.entries.toList(),
                              xValueMapper: (MapEntry<String, int> data, _) =>
                                  data.key,
                              yValueMapper: (MapEntry<String, int> data, _) =>
                                  data.value,
                              dataLabelSettings: const DataLabelSettings(
                                isVisible: true,
                                labelPosition: ChartDataLabelPosition.outside,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // 3. Stok Analizi Sekmesi
  Widget _buildStockAnalysisTab() {
    return Consumer<ProductProvider>(
      builder: (context, productProvider, child) {
        final products = productProvider.products;

        if (products.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.inventory, size: 64, color: Colors.grey),
                SizedBox(height: 16),
                Text('Henüz ürün verisi bulunmuyor'),
              ],
            ),
          );
        }

        // Stok durumları - doğru alan adını kullan
        final lowStockProducts = products.where((p) => p.stock <= 10).toList();
        final outOfStockProducts = products.where((p) => p.stock == 0).toList();
        final categoryStock = <String, int>{};

        for (var product in products) {
          final category = product.category ?? 'Diğer';
          categoryStock[category] =
              (categoryStock[category] ?? 0) + product.stock;
        }

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              // Stok Özet Kartları
              Row(
                children: [
                  Expanded(
                    child: _buildSummaryCard(
                      'Düşük Stok',
                      '${lowStockProducts.length}',
                      Icons.warning,
                      Colors.orange,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildSummaryCard(
                      'Stokta Yok',
                      '${outOfStockProducts.length}',
                      Icons.error,
                      Colors.red,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Kategori Bazında Stok
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Kategori Bazında Stok Durumu',
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        height: 300,
                        child: SfCartesianChart(
                          primaryXAxis: const CategoryAxis(),
                          primaryYAxis: const NumericAxis(),
                          tooltipBehavior: TooltipBehavior(enable: true),
                          series: <CartesianSeries>[
                            ColumnSeries<MapEntry<String, int>, String>(
                              dataSource: categoryStock.entries.toList(),
                              xValueMapper: (MapEntry<String, int> data, _) =>
                                  data.key,
                              yValueMapper: (MapEntry<String, int> data, _) =>
                                  data.value,
                              name: 'Stok Adedi',
                              color: Colors.purple,
                              dataLabelSettings:
                                  const DataLabelSettings(isVisible: true),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Düşük Stoklu Ürünler Listesi
              if (lowStockProducts.isNotEmpty)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Düşük Stoklu Ürünler (≤10)',
                          style: TextStyle(
                              fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 16),
                        ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: lowStockProducts.length,
                          itemBuilder: (context, index) {
                            final product = lowStockProducts[index];
                            return ListTile(
                              leading: CircleAvatar(
                                backgroundColor: product.stock == 0
                                    ? Colors.red
                                    : Colors.orange,
                                child: Text(
                                  '${product.stock}',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              title: Text(product.name),
                              subtitle:
                                  Text(product.category ?? 'Kategori yok'),
                              trailing: Text(
                                _currencyFormat.format(product.salePrice),
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  // 4. Satış Listesi Sekmesi
  Widget _buildSalesListTab() {
    return Consumer2<SalesProvider, ProductProvider>(
      builder: (context, salesProvider, productProvider, child) {
        final sales = salesProvider.sales;

        if (sales.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.receipt_long, size: 64, color: Colors.grey),
                SizedBox(height: 16),
                Text('Henüz satış verisi bulunmuyor'),
              ],
            ),
          );
        }

        // Satışları tarihe göre sırala (en yeni önce)
        final sortedSales = sales.toList()
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

        // Toplam satış tutarı
        final totalSalesAmount =
            sales.fold<double>(0, (sum, sale) => sum + sale.finalAmount);

        return Column(
          children: [
            // Filtre ve Sıralama Seçenekleri
            Container(
              padding: const EdgeInsets.all(16),
              color: Colors.grey[100],
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Toplam ${sales.length} satış',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                  Text(
                    'Toplam: ${_currencyFormat.format(totalSalesAmount)}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.green,
                    ),
                  ),
                ],
              ),
            ),

            // Satış Listesi
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: sortedSales.length,
                itemBuilder: (context, index) {
                  final sale = sortedSales[index];

                  // Satıştaki toplam ürün adedi
                  final totalQuantity = sale.items
                      .fold<int>(0, (sum, item) => sum + item.quantity);

                  // İlk ürünü al (varsa)
                  final firstItem =
                      sale.items.isNotEmpty ? sale.items.first : null;
                  final productName =
                      firstItem?.productName ?? 'Bilinmeyen Ürün';
                  final itemCount = sale.items.length;

                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ExpansionTile(
                      leading: CircleAvatar(
                        backgroundColor: Colors.blue,
                        child: Text(
                          '$totalQuantity',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      title: Text(
                        itemCount == 1 ? productName : '$itemCount farklı ürün',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                              'Tarih: ${DateFormat('dd/MM/yyyy HH:mm').format(sale.createdAt)}'),
                          Text(
                              'Ödeme: ${_getPaymentMethodText(sale.paymentMethod)}'),
                          if (sale.discount > 0)
                            Text(
                                'İndirim: %${sale.discount.toStringAsFixed(1)}'),
                        ],
                      ),
                      trailing: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          if (sale.discount > 0) ...[
                            Text(
                              _currencyFormat.format(sale.totalAmount),
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[600],
                                decoration: TextDecoration.lineThrough,
                              ),
                            ),
                          ],
                          Text(
                            _currencyFormat.format(sale.finalAmount),
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: Colors.green,
                            ),
                          ),
                        ],
                      ),
                      children: [
                        // Satış detayları
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            children: sale.items.map((item) {
                              return Padding(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 4),
                                child: Row(
                                  children: [
                                    Expanded(
                                      flex: 2,
                                      child: Text(item.productName),
                                    ),
                                    Expanded(
                                      child: Text(
                                        '${item.quantity} adet',
                                        textAlign: TextAlign.center,
                                      ),
                                    ),
                                    Expanded(
                                      child: Text(
                                        _currencyFormat.format(item.unitPrice),
                                        textAlign: TextAlign.center,
                                      ),
                                    ),
                                    Expanded(
                                      child: Text(
                                        _currencyFormat.format(item.totalPrice),
                                        textAlign: TextAlign.right,
                                        style: const TextStyle(
                                            fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  String _getPaymentMethodText(PaymentMethod method) {
    switch (method) {
      case PaymentMethod.cash:
        return 'Nakit';
      case PaymentMethod.creditCard:
        return 'Kredi Kartı';
      case PaymentMethod.debit:
        return 'Banka Kartı';
      case PaymentMethod.installment:
        return 'Taksit';
    }
  }

  Widget _buildSummaryCard(
      String title, String value, IconData icon, Color color) {
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Icon(icon, size: 32, color: color),
            const SizedBox(height: 8),
            Text(
              title,
              style: const TextStyle(
                fontSize: 14,
                color: Colors.grey,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: color,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}




