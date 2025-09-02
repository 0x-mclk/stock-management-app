import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:syncfusion_flutter_charts/charts.dart';
import '../providers/sales_provider.dart';
import '../providers/product_provider.dart';
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
  DateTime _startDate = DateTime.now().subtract(const Duration(days: 30));
  DateTime _endDate = DateTime.now();

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

  // Türk Lirası formatı - güvenli fallback
  String formatCurrency(double amount) {
    try {
      return NumberFormat.currency(
        locale: 'tr_TR',
        symbol: '₺',
        decimalDigits: 2,
      ).format(amount);
    } catch (e) {
      // Fallback formatı: 1.234,50 ₺
      String amountStr = amount.toStringAsFixed(2);
      String integerPart = amountStr.split('.')[0];
      String decimalPart = amountStr.split('.')[1];

      // Binlik ayırıcı ekle
      String formattedInteger = '';
      for (int i = 0; i < integerPart.length; i++) {
        if (i > 0 && (integerPart.length - i) % 3 == 0) {
          formattedInteger += '.';
        }
        formattedInteger += integerPart[i];
      }

      return '$formattedInteger,$decimalPart ₺';
    }
  }

  // Güvenli tarih formatları
  String safeDayFormat(DateTime date) {
    try {
      return DateFormat('EEEE', 'tr').format(date);
    } catch (e) {
      const days = [
        'Pazartesi',
        'Salı',
        'Çarşamba',
        'Perşembe',
        'Cuma',
        'Cumartesi',
        'Pazar'
      ];
      return days[date.weekday - 1];
    }
  }

  String safeMonthFormat(DateTime date) {
    try {
      return DateFormat('MMM yyyy', 'tr').format(date);
    } catch (e) {
      const months = [
        'Oca',
        'Şub',
        'Mar',
        'Nis',
        'May',
        'Haz',
        'Tem',
        'Ağu',
        'Eyl',
        'Eki',
        'Kas',
        'Ara'
      ];
      return '${months[date.month - 1]} ${date.year}';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Raporlar'),
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: Colors.white,
          tabs: const [
            Tab(text: 'Satış & Kâr'),
            Tab(text: 'Ürün Analizi'),
            Tab(text: 'Stok Analizi'),
            Tab(text: 'Satış Listesi'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildSalesAnalysis(),
          _buildProductAnalysis(),
          _buildStockAnalysis(),
          _buildSalesList(),
        ],
      ),
    );
  }

  // 1. Satış ve Kârlılık Analizi
  Widget _buildSalesAnalysis() {
    return Consumer<SalesProvider>(
      builder: (context, salesProvider, child) {
        return SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildDateRangeSelector(),
              const SizedBox(height: 20),
              _buildSalesKPICards(salesProvider),
              const SizedBox(height: 20),
              _buildWeeklySalesChart(salesProvider),
              const SizedBox(height: 20),
              _buildMonthlySalesChart(salesProvider),
            ],
          ),
        );
      },
    );
  }

  // Tarih aralığı seçici
  Widget _buildDateRangeSelector() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Başlangıç Tarihi',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  GestureDetector(
                    onTap: () async {
                      final date = await showDatePicker(
                        context: context,
                        initialDate: _startDate,
                        firstDate: DateTime(2020),
                        lastDate: DateTime.now(),
                      );
                      if (date != null) {
                        setState(() {
                          _startDate = date;
                        });
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(DateFormat('dd/MM/yyyy').format(_startDate)),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Bitiş Tarihi',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  GestureDetector(
                    onTap: () async {
                      final date = await showDatePicker(
                        context: context,
                        initialDate: _endDate,
                        firstDate: DateTime(2020),
                        lastDate: DateTime.now(),
                      );
                      if (date != null) {
                        setState(() {
                          _endDate = date;
                        });
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(DateFormat('dd/MM/yyyy').format(_endDate)),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Satış KPI kartları
  Widget _buildSalesKPICards(SalesProvider salesProvider) {
    final filteredSales = _getFilteredSales(salesProvider.sales);
    final totalRevenue =
        filteredSales.fold<double>(0, (sum, sale) => sum + sale.totalAmount);
    final totalCost = filteredSales.fold<double>(
        0,
        (sum, sale) =>
            sum +
            sale.items.fold<double>(
                0,
                (itemSum, item) =>
                    itemSum +
                    (item.unitPrice *
                        0.7 *
                        item.quantity))); // Assuming 70% of unit price as cost
    final totalProfit = totalRevenue - totalCost;
    final profitMargin =
        totalRevenue > 0 ? (totalProfit / totalRevenue) * 100 : 0;

    return Row(
      children: [
        Expanded(
          child: _buildKPICard('Toplam Ciro', formatCurrency(totalRevenue),
              Icons.monetization_on, Colors.blue),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _buildKPICard('Toplam Kâr', formatCurrency(totalProfit),
              Icons.trending_up, Colors.green),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _buildKPICard(
              'Kâr Marjı',
              '${profitMargin.toStringAsFixed(1)}%',
              Icons.percent,
              Colors.orange),
        ),
      ],
    );
  }

  Widget _buildKPICard(String title, String value, IconData icon, Color color) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Icon(icon, color: color, size: 32),
            const SizedBox(height: 8),
            Text(
              title,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: TextStyle(
                  fontSize: 14, fontWeight: FontWeight.bold, color: color),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  // Haftalık satış grafiği
  Widget _buildWeeklySalesChart(SalesProvider salesProvider) {
    final weeklyData = _getWeeklySalesData(salesProvider.sales);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Haftalık Ciro & Kâr',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 250,
              child: SfCartesianChart(
                primaryXAxis: const CategoryAxis(),
                primaryYAxis: NumericAxis(
                  numberFormat: NumberFormat.compact(),
                ),
                legend: const Legend(isVisible: true),
                tooltipBehavior: TooltipBehavior(enable: true),
                series: <CartesianSeries>[
                  ColumnSeries<WeeklySalesData, String>(
                    name: 'Ciro',
                    dataSource: weeklyData,
                    xValueMapper: (WeeklySalesData data, _) => data.day,
                    yValueMapper: (WeeklySalesData data, _) => data.revenue,
                    color: Colors.blue,
                  ),
                  ColumnSeries<WeeklySalesData, String>(
                    name: 'Kâr',
                    dataSource: weeklyData,
                    xValueMapper: (WeeklySalesData data, _) => data.day,
                    yValueMapper: (WeeklySalesData data, _) => data.profit,
                    color: Colors.green,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Aylık satış grafiği
  Widget _buildMonthlySalesChart(SalesProvider salesProvider) {
    final monthlyData = _getMonthlySalesData(salesProvider.sales);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Aylık Ciro & Kâr',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 250,
              child: SfCartesianChart(
                primaryXAxis: const CategoryAxis(),
                primaryYAxis: NumericAxis(
                  numberFormat: NumberFormat.compact(),
                ),
                legend: const Legend(isVisible: true),
                tooltipBehavior: TooltipBehavior(enable: true),
                series: <CartesianSeries>[
                  ColumnSeries<MonthlySalesData, String>(
                    name: 'Ciro',
                    dataSource: monthlyData,
                    xValueMapper: (MonthlySalesData data, _) => data.month,
                    yValueMapper: (MonthlySalesData data, _) => data.revenue,
                    color: Colors.blue,
                  ),
                  ColumnSeries<MonthlySalesData, String>(
                    name: 'Kâr',
                    dataSource: monthlyData,
                    xValueMapper: (MonthlySalesData data, _) => data.month,
                    yValueMapper: (MonthlySalesData data, _) => data.profit,
                    color: Colors.green,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 2. Ürün Analizi
  Widget _buildProductAnalysis() {
    return Consumer2<SalesProvider, ProductProvider>(
      builder: (context, salesProvider, productProvider, child) {
        return SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildTopSellingProducts(salesProvider, productProvider),
              const SizedBox(height: 20),
              _buildMostProfitableProducts(salesProvider, productProvider),
              const SizedBox(height: 20),
              _buildLeastSellingProducts(salesProvider, productProvider),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTopSellingProducts(
      SalesProvider salesProvider, ProductProvider productProvider) {
    final topProducts =
        _getTopSellingProducts(salesProvider.sales, productProvider.products);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'En Çok Satan Ürünler',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            ...topProducts.take(10).map(
                  (productData) => ListTile(
                    title: Text(productData.productName),
                    subtitle: Text(
                        '${productData.quantitySold.toInt()} adet satıldı'),
                    trailing: Text(formatCurrency(productData.totalRevenue)),
                  ),
                ),
          ],
        ),
      ),
    );
  }

  Widget _buildMostProfitableProducts(
      SalesProvider salesProvider, ProductProvider productProvider) {
    final profitableProducts = _getMostProfitableProducts(
        salesProvider.sales, productProvider.products);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'En Karlı Ürünler',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            ...profitableProducts.take(10).map(
                  (productData) => ListTile(
                    title: Text(productData.productName),
                    subtitle: Text(
                        '${productData.quantitySold.toInt()} adet - Kâr: ${formatCurrency(productData.totalProfit)}'),
                    trailing: Text(formatCurrency(productData.totalRevenue)),
                  ),
                ),
          ],
        ),
      ),
    );
  }

  Widget _buildLeastSellingProducts(
      SalesProvider salesProvider, ProductProvider productProvider) {
    final leastProducts =
        _getLeastSellingProducts(salesProvider.sales, productProvider.products);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Az Satan Ürünler',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            ...leastProducts.take(10).map(
                  (productData) => ListTile(
                    title: Text(productData.productName),
                    subtitle: Text(
                        '${productData.quantitySold.toInt()} adet satıldı'),
                    trailing: Text(formatCurrency(productData.totalRevenue)),
                  ),
                ),
          ],
        ),
      ),
    );
  }

  // 3. Stok Analizi
  Widget _buildStockAnalysis() {
    return Consumer<ProductProvider>(
      builder: (context, productProvider, child) {
        return SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildStockKPICards(productProvider),
              const SizedBox(height: 20),
              _buildLowStockProducts(productProvider),
              const SizedBox(height: 20),
              _buildOutOfStockProducts(productProvider),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStockKPICards(ProductProvider productProvider) {
    final totalProducts = productProvider.products.length;
    final totalStock = productProvider.products
        .fold<int>(0, (sum, product) => sum + product.stock);
    final totalStockValue = productProvider.products.fold<double>(
        0,
        (sum, product) =>
            sum +
            ((product.purchasePrice ?? product.salePrice * 0.7) *
                product.stock));
    final lowStockCount =
        productProvider.products.where((p) => p.stock <= 10).length;

    return Row(
      children: [
        Expanded(
          child: _buildKPICard('Toplam Ürün', totalProducts.toString(),
              Icons.inventory, Colors.blue),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _buildKPICard('Toplam Stok', totalStock.toString(),
              Icons.storage, Colors.green),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _buildKPICard('Stok Değeri', formatCurrency(totalStockValue),
              Icons.monetization_on, Colors.orange),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _buildKPICard('Düşük Stok', lowStockCount.toString(),
              Icons.warning, Colors.red),
        ),
      ],
    );
  }

  Widget _buildLowStockProducts(ProductProvider productProvider) {
    final lowStockProducts = productProvider.products
        .where((p) => p.stock > 0 && p.stock <= 10)
        .toList();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.warning, color: Colors.orange),
                SizedBox(width: 8),
                Text(
                  'Düşük Stok Ürünler',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (lowStockProducts.isEmpty)
              const Text('Düşük stoklu ürün bulunmuyor.')
            else
              ...lowStockProducts.map(
                (product) => ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Colors.orange,
                    child: Text(product.stock.toString()),
                  ),
                  title: Text(product.name),
                  subtitle: Text('Stok: ${product.stock} adet'),
                  trailing: Text(formatCurrency(product.salePrice)),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildOutOfStockProducts(ProductProvider productProvider) {
    final outOfStockProducts =
        productProvider.products.where((p) => p.stock == 0).toList();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.error, color: Colors.red),
                SizedBox(width: 8),
                Text(
                  'Tükenen Ürünler',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (outOfStockProducts.isEmpty)
              const Text('Tükenen ürün bulunmuyor.')
            else
              ...outOfStockProducts.map(
                (product) => ListTile(
                  leading: const CircleAvatar(
                    backgroundColor: Colors.red,
                    child: Icon(Icons.close, color: Colors.white),
                  ),
                  title: Text(product.name),
                  subtitle: const Text('Stok: 0 adet'),
                  trailing: Text(formatCurrency(product.salePrice)),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // 4. Satış Listesi
  Widget _buildSalesList() {
    return Consumer<SalesProvider>(
      builder: (context, salesProvider, child) {
        final filteredSales = _getFilteredSales(salesProvider.sales);

        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: _buildDateRangeSelector(),
            ),
            Expanded(
              child: filteredSales.isEmpty
                  ? const Center(
                      child: Text('Bu tarih aralığında satış bulunmuyor.'))
                  : ListView.builder(
                      itemCount: filteredSales.length,
                      itemBuilder: (context, index) {
                        final sale = filteredSales[index];
                        return Card(
                          margin: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 4),
                          child: ExpansionTile(
                            title: Text('Satış #${sale.id}'),
                            subtitle: Text(
                                '${DateFormat('dd/MM/yyyy HH:mm').format(sale.createdAt)} - ${formatCurrency(sale.totalAmount)}'),
                            children: [
                              ...sale.items.map(
                                (item) => ListTile(
                                  title: Text(item.productName),
                                  subtitle: Text(
                                      '${item.quantity} adet x ${formatCurrency(item.unitPrice)}'),
                                  trailing: Text(formatCurrency(
                                      item.quantity * item.unitPrice)),
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.all(16.0),
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text('Ödeme: ${sale.paymentMethod}'),
                                    Text(
                                      'Toplam: ${formatCurrency(sale.totalAmount)}',
                                      style: const TextStyle(
                                          fontWeight: FontWeight.bold),
                                    ),
                                  ],
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

  // Yardımcı fonksiyonlar
  List<Sale> _getFilteredSales(List<Sale> sales) {
    return sales
        .where((sale) =>
            sale.createdAt
                .isAfter(_startDate.subtract(const Duration(days: 1))) &&
            sale.createdAt.isBefore(_endDate.add(const Duration(days: 1))))
        .toList();
  }

  List<WeeklySalesData> _getWeeklySalesData(List<Sale> sales) {
    final Map<String, double> weeklyRevenue = {};
    final Map<String, double> weeklyProfit = {};
    final filteredSales = _getFilteredSales(sales);

    for (var sale in filteredSales) {
      final dayName = safeDayFormat(sale.createdAt);
      weeklyRevenue[dayName] = (weeklyRevenue[dayName] ?? 0) + sale.totalAmount;

      final saleProfit = sale.items.fold<double>(
          0,
          (sum, item) =>
              sum + ((item.unitPrice - item.unitPrice * 0.7) * item.quantity));
      weeklyProfit[dayName] = (weeklyProfit[dayName] ?? 0) + saleProfit;
    }

    const days = [
      'Pazartesi',
      'Salı',
      'Çarşamba',
      'Perşembe',
      'Cuma',
      'Cumartesi',
      'Pazar'
    ];
    return days
        .map((day) => WeeklySalesData(
            day, weeklyRevenue[day] ?? 0, weeklyProfit[day] ?? 0))
        .toList();
  }

  List<MonthlySalesData> _getMonthlySalesData(List<Sale> sales) {
    final Map<String, double> monthlyRevenue = {};
    final Map<String, double> monthlyProfit = {};

    for (var sale in sales) {
      final monthName = safeMonthFormat(sale.createdAt);
      monthlyRevenue[monthName] =
          (monthlyRevenue[monthName] ?? 0) + sale.totalAmount;

      final saleProfit = sale.items.fold<double>(
          0,
          (sum, item) =>
              sum + ((item.unitPrice - item.unitPrice * 0.7) * item.quantity));
      monthlyProfit[monthName] = (monthlyProfit[monthName] ?? 0) + saleProfit;
    }

    return monthlyRevenue.entries
        .map((entry) => MonthlySalesData(
            entry.key, entry.value, monthlyProfit[entry.key] ?? 0))
        .toList();
  }

  List<ProductAnalysisData> _getTopSellingProducts(
      List<Sale> sales, List<Product> products) {
    final Map<String, ProductAnalysisData> productMap = {};
    final filteredSales = _getFilteredSales(sales);

    for (var sale in filteredSales) {
      for (var item in sale.items) {
        if (productMap.containsKey(item.productId)) {
          productMap[item.productId]!.quantitySold += item.quantity.toDouble();
          productMap[item.productId]!.totalRevenue +=
              item.quantity * item.unitPrice;
        } else {
          productMap[item.productId] = ProductAnalysisData(
            productId: item.productId,
            productName: item.productName,
            quantitySold: item.quantity.toDouble(),
            totalRevenue: item.quantity * item.unitPrice,
            totalProfit: 0,
          );
        }
      }
    }

    final result = productMap.values.toList();
    result.sort((a, b) => b.quantitySold.compareTo(a.quantitySold));
    return result;
  }

  List<ProductAnalysisData> _getMostProfitableProducts(
      List<Sale> sales, List<Product> products) {
    final Map<String, ProductAnalysisData> productMap = {};
    final filteredSales = _getFilteredSales(sales);

    for (var sale in filteredSales) {
      for (var item in sale.items) {
        final profit = (item.unitPrice - item.unitPrice * 0.7) * item.quantity;

        if (productMap.containsKey(item.productId)) {
          productMap[item.productId]!.quantitySold += item.quantity.toDouble();
          productMap[item.productId]!.totalRevenue +=
              item.quantity * item.unitPrice;
          productMap[item.productId]!.totalProfit += profit;
        } else {
          productMap[item.productId] = ProductAnalysisData(
            productId: item.productId,
            productName: item.productName,
            quantitySold: item.quantity.toDouble(),
            totalRevenue: item.quantity * item.unitPrice,
            totalProfit: profit,
          );
        }
      }
    }

    final result = productMap.values.toList();
    result.sort((a, b) => b.totalProfit.compareTo(a.totalProfit));
    return result;
  }

  List<ProductAnalysisData> _getLeastSellingProducts(
      List<Sale> sales, List<Product> products) {
    final topProducts = _getTopSellingProducts(sales, products);
    topProducts.sort((a, b) => a.quantitySold.compareTo(b.quantitySold));
    return topProducts;
  }
}

// Veri modelleri
class WeeklySalesData {
  final String day;
  final double revenue;
  final double profit;

  WeeklySalesData(this.day, this.revenue, this.profit);
}

class MonthlySalesData {
  final String month;
  final double revenue;
  final double profit;

  MonthlySalesData(this.month, this.revenue, this.profit);
}

class ProductAnalysisData {
  final String productId;
  final String productName;
  double quantitySold;
  double totalRevenue;
  double totalProfit;

  ProductAnalysisData({
    required this.productId,
    required this.productName,
    required this.quantitySold,
    required this.totalRevenue,
    required this.totalProfit,
  });
}




