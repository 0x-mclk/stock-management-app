import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:syncfusion_flutter_charts/charts.dart';
import '../providers/sales_provider.dart';
import '../providers/product_provider.dart';
import '../providers/supplier_provider.dart';
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
    
    // Ensure all data is loaded for accurate reports
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final productProvider = Provider.of<ProductProvider>(context, listen: false);
      final salesProvider = Provider.of<SalesProvider>(context, listen: false);
      final supplierProvider = Provider.of<SupplierProvider>(context, listen: false);
      
      productProvider.loadProducts();
      salesProvider.loadSales();
      supplierProvider.loadSuppliers();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  String _formatCurrency(double amount) {
    final formatter = NumberFormat.currency(
      locale: 'tr_TR',
      symbol: '₺',
      decimalDigits: 2,
    );
    return formatter.format(amount);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Detaylı Raporlar'),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabs: const [
            Tab(text: 'Satış & Kâr'),
            Tab(text: 'Ürün Analizi'),
            Tab(text: 'Stok Analizi'),
            Tab(text: 'Satış Listesi'),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.date_range),
            onPressed: _showDateRangePicker,
          ),
        ],
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

  void _showDateRangePicker() async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: DateTimeRange(start: _startDate, end: _endDate),
    );
    if (picked != null) {
      setState(() {
        _startDate = picked.start;
        _endDate = picked.end;
      });
    }
  }

  Widget _buildSalesAndProfitTab() {
    return Consumer2<SalesProvider, ProductProvider>(
      builder: (context, salesProvider, productProvider, child) {
        final sales = salesProvider.sales.where((sale) {
          return sale.createdAt.isAfter(_startDate) && 
                 sale.createdAt.isBefore(_endDate.add(const Duration(days: 1)));
        }).toList();

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildDateRangeInfo(),
              const SizedBox(height: 16),
              _buildDailySalesChart(sales, productProvider.products),
              const SizedBox(height: 24),
              _buildMonthlySalesChart(sales, productProvider.products),
              const SizedBox(height: 24),
              _buildYearlySalesChart(sales, productProvider.products),
              const SizedBox(height: 24),
              _buildProfitMarginCard(sales, productProvider.products),
              const SizedBox(height: 24),
              _buildHourlySalesChart(sales),
              const SizedBox(height: 24),
              _buildPaymentMethodChart(sales),
            ],
          ),
        );
      },
    );
  }

  Widget _buildProductAnalysisTab() {
    return Consumer2<SalesProvider, ProductProvider>(
      builder: (context, salesProvider, productProvider, child) {
        final sales = salesProvider.sales.where((sale) {
          return sale.createdAt.isAfter(_startDate) && 
                 sale.createdAt.isBefore(_endDate.add(const Duration(days: 1)));
        }).toList();

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildDateRangeInfo(),
              const SizedBox(height: 16),
              _buildTopSellingProducts(sales, productProvider.products),
              const SizedBox(height: 24),
              _buildMostProfitableProducts(sales, productProvider.products),
              const SizedBox(height: 24),
              _buildLeastSellingProducts(sales, productProvider.products),
              const SizedBox(height: 24),
              _buildDeadStockAnalysis(sales, productProvider.products),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStockAnalysisTab() {
    return Consumer<ProductProvider>(
      builder: (context, productProvider, child) {
        return SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildStockSummaryCards(productProvider.products),
              const SizedBox(height: 24),
              _buildLowStockProducts(productProvider.products),
              const SizedBox(height: 24),
              _buildOutOfStockProducts(productProvider.products),
              const SizedBox(height: 24),
              _buildStockValueChart(productProvider.products),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSalesListTab() {
    return Consumer2<SalesProvider, ProductProvider>(
      builder: (context, salesProvider, productProvider, child) {
        final sales = salesProvider.sales.where((sale) {
          return sale.createdAt.isAfter(_startDate) && 
                 sale.createdAt.isBefore(_endDate.add(const Duration(days: 1)));
        }).toList()..sort((a, b) => b.createdAt.compareTo(a.createdAt));

        return Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              child: _buildDateRangeInfo(),
            ),
            Expanded(
              child: sales.isEmpty
                  ? const Center(
                      child: Text(
                        'Seçilen tarih aralığında satış bulunamadı',
                        style: TextStyle(fontSize: 16),
                      ),
                    )
                  : ListView.builder(
                      itemCount: sales.length,
                      itemBuilder: (context, index) {
                        final sale = sales[index];
                        return _buildSaleListItem(sale, productProvider.products);
                      },
                    ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildDateRangeInfo() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).primaryColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          const Icon(Icons.date_range),
          const SizedBox(width: 8),
          Text(
            '${DateFormat('dd.MM.yyyy').format(_startDate)} - ${DateFormat('dd.MM.yyyy').format(_endDate)}',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _buildDailySalesChart(List<Sale> sales, List<Product> products) {
    final Map<DateTime, double> dailyRevenue = {};
    final Map<DateTime, double> dailyProfit = {};

    for (final sale in sales) {
      final date = DateTime(sale.timestamp.year, sale.timestamp.month, sale.timestamp.day);
      dailyRevenue[date] = (dailyRevenue[date] ?? 0) + sale.totalAmount;
      
      double saleProfit = 0;
      for (final item in sale.items) {
        final product = products.firstWhere(
          (p) => p.id == item.productId,
          orElse: () => Product(
            id: '',
            name: '',
            barcode: '',
            buyingPrice: 0,
            sellingPrice: 0,
            stock: 0,
            minStock: 0,
            category: '',
            description: '',
          ),
        );
        saleProfit += (item.unitPrice - product.buyingPrice) * item.quantity;
      }
      dailyProfit[date] = (dailyProfit[date] ?? 0) + saleProfit;
    }

    final revenueData = dailyRevenue.entries
        .map((e) => ChartData(DateFormat('dd/MM').format(e.key), e.value))
        .toList()..sort((a, b) => a.x.compareTo(b.x));

    final profitData = dailyProfit.entries
        .map((e) => ChartData(DateFormat('dd/MM').format(e.key), e.value))
        .toList()..sort((a, b) => a.x.compareTo(b.x));

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Günlük Ciro & Kâr',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 300,
              child: SfCartesianChart(
                primaryXAxis: CategoryAxis(
                  labelRotation: -45,
                  majorGridLines: const MajorGridLines(width: 0),
                ),
                primaryYAxis: NumericAxis(
                  numberFormat: NumberFormat.compact(locale: 'tr_TR'),
                ),
                legend: const Legend(isVisible: true),
                tooltipBehavior: TooltipBehavior(enable: true),
                series: <ChartSeries>[
                  ColumnSeries<ChartData, String>(
                    dataSource: revenueData,
                    xValueMapper: (ChartData data, _) => data.x,
                    yValueMapper: (ChartData data, _) => data.y,
                    name: 'Ciro',
                    color: Colors.blue,
                  ),
                  ColumnSeries<ChartData, String>(
                    dataSource: profitData,
                    xValueMapper: (ChartData data, _) => data.x,
                    yValueMapper: (ChartData data, _) => data.y,
                    name: 'Kâr',
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

  Widget _buildMonthlySalesChart(List<Sale> sales, List<Product> products) {
    final Map<String, double> monthlyRevenue = {};
    final Map<String, double> monthlyProfit = {};

    for (final sale in sales) {
      final monthKey = DateFormat('MM/yyyy').format(sale.timestamp);
      monthlyRevenue[monthKey] = (monthlyRevenue[monthKey] ?? 0) + sale.totalAmount;
      
      double saleProfit = 0;
      for (final item in sale.items) {
        final product = products.firstWhere(
          (p) => p.id == item.productId,
          orElse: () => Product(
            id: '',
            name: '',
            barcode: '',
            buyingPrice: 0,
            sellingPrice: 0,
            stock: 0,
            minStock: 0,
            category: '',
            description: '',
          ),
        );
        saleProfit += (item.unitPrice - product.buyingPrice) * item.quantity;
      }
      monthlyProfit[monthKey] = (monthlyProfit[monthKey] ?? 0) + saleProfit;
    }

    final revenueData = monthlyRevenue.entries
        .map((e) => ChartData(e.key, e.value))
        .toList()..sort((a, b) => a.x.compareTo(b.x));

    final profitData = monthlyProfit.entries
        .map((e) => ChartData(e.key, e.value))
        .toList()..sort((a, b) => a.x.compareTo(b.x));

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
              height: 300,
              child: SfCartesianChart(
                primaryXAxis: CategoryAxis(
                  labelRotation: -45,
                  majorGridLines: const MajorGridLines(width: 0),
                ),
                primaryYAxis: NumericAxis(
                  numberFormat: NumberFormat.compact(locale: 'tr_TR'),
                ),
                legend: const Legend(isVisible: true),
                tooltipBehavior: TooltipBehavior(enable: true),
                series: <ChartSeries>[
                  ColumnSeries<ChartData, String>(
                    dataSource: revenueData,
                    xValueMapper: (ChartData data, _) => data.x,
                    yValueMapper: (ChartData data, _) => data.y,
                    name: 'Ciro',
                    color: Colors.blue,
                  ),
                  ColumnSeries<ChartData, String>(
                    dataSource: profitData,
                    xValueMapper: (ChartData data, _) => data.x,
                    yValueMapper: (ChartData data, _) => data.y,
                    name: 'Kâr',
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

  Widget _buildYearlySalesChart(List<Sale> sales, List<Product> products) {
    final Map<String, double> yearlyRevenue = {};
    final Map<String, double> yearlyProfit = {};

    for (final sale in sales) {
      final yearKey = sale.timestamp.year.toString();
      yearlyRevenue[yearKey] = (yearlyRevenue[yearKey] ?? 0) + sale.totalAmount;
      
      double saleProfit = 0;
      for (final item in sale.items) {
        final product = products.firstWhere(
          (p) => p.id == item.productId,
          orElse: () => Product(
            id: '',
            name: '',
            barcode: '',
            buyingPrice: 0,
            sellingPrice: 0,
            stock: 0,
            minStock: 0,
            category: '',
            description: '',
          ),
        );
        saleProfit += (item.unitPrice - product.buyingPrice) * item.quantity;
      }
      yearlyProfit[yearKey] = (yearlyProfit[yearKey] ?? 0) + saleProfit;
    }

    final revenueData = yearlyRevenue.entries
        .map((e) => ChartData(e.key, e.value))
        .toList()..sort((a, b) => a.x.compareTo(b.x));

    final profitData = yearlyProfit.entries
        .map((e) => ChartData(e.key, e.value))
        .toList()..sort((a, b) => a.x.compareTo(b.x));

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Yıllık Ciro & Kâr',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 300,
              child: SfCartesianChart(
                primaryXAxis: CategoryAxis(
                  majorGridLines: const MajorGridLines(width: 0),
                ),
                primaryYAxis: NumericAxis(
                  numberFormat: NumberFormat.compact(locale: 'tr_TR'),
                ),
                legend: const Legend(isVisible: true),
                tooltipBehavior: TooltipBehavior(enable: true),
                series: <ChartSeries>[
                  ColumnSeries<ChartData, String>(
                    dataSource: revenueData,
                    xValueMapper: (ChartData data, _) => data.x,
                    yValueMapper: (ChartData data, _) => data.y,
                    name: 'Ciro',
                    color: Colors.blue,
                  ),
                  ColumnSeries<ChartData, String>(
                    dataSource: profitData,
                    xValueMapper: (ChartData data, _) => data.x,
                    yValueMapper: (ChartData data, _) => data.y,
                    name: 'Kâr',
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

  Widget _buildProfitMarginCard(List<Sale> sales, List<Product> products) {
    double totalRevenue = 0;
    double totalProfit = 0;

    for (final sale in sales) {
      totalRevenue += sale.totalAmount;
      
      for (final item in sale.items) {
        final product = products.firstWhere(
          (p) => p.id == item.productId,
          orElse: () => Product(
            id: '',
            name: '',
            barcode: '',
            buyingPrice: 0,
            sellingPrice: 0,
            stock: 0,
            minStock: 0,
            category: '',
            description: '',
          ),
        );
        totalProfit += (item.unitPrice - product.buyingPrice) * item.quantity;
      }
    }

    final profitMargin = totalRevenue > 0 ? (totalProfit / totalRevenue) * 100 : 0;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Brüt Kâr Marjı',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                Expanded(
                  child: Column(
                    children: [
                      Text(
                        'Toplam Ciro',
                        style: Theme.of(context).textTheme.titleSmall,
                        textAlign: TextAlign.center,
                      ),
                      Text(
                        _formatCurrency(totalRevenue),
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Column(
                    children: [
                      Text(
                        'Toplam Kâr',
                        style: Theme.of(context).textTheme.titleSmall,
                        textAlign: TextAlign.center,
                      ),
                      Text(
                        _formatCurrency(totalProfit),
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.green,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Column(
                    children: [
                      Text(
                        'Kâr Marjı',
                        style: Theme.of(context).textTheme.titleSmall,
                        textAlign: TextAlign.center,
                      ),
                      Text(
                        '%${profitMargin.toStringAsFixed(1)}',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.orange,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHourlySalesChart(List<Sale> sales) {
    final Map<int, double> hourlySales = {};
    
    for (final sale in sales) {
      final hour = sale.timestamp.hour;
      hourlySales[hour] = (hourlySales[hour] ?? 0) + sale.totalAmount;
    }

    final chartData = List.generate(24, (index) {
      return ChartData('${index.toString().padLeft(2, '0')}:00', hourlySales[index] ?? 0);
    });

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Saatlik Satış Yoğunluğu',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 300,
              child: SfCartesianChart(
                primaryXAxis: CategoryAxis(
                  interval: 2,
                  majorGridLines: const MajorGridLines(width: 0),
                ),
                primaryYAxis: NumericAxis(
                  numberFormat: NumberFormat.compact(locale: 'tr_TR'),
                ),
                tooltipBehavior: TooltipBehavior(enable: true),
                series: <ChartSeries>[
                  LineSeries<ChartData, String>(
                    dataSource: chartData,
                    xValueMapper: (ChartData data, _) => data.x,
                    yValueMapper: (ChartData data, _) => data.y,
                    name: 'Satış',
                    color: Colors.purple,
                    markerSettings: const MarkerSettings(isVisible: true),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPaymentMethodChart(List<Sale> sales) {
    final Map<String, double> paymentMethods = {};
    
    for (final sale in sales) {
      final method = sale.paymentMethod.toString().split('.').last;
      String methodName;
      switch (method) {
        case 'cash':
          methodName = 'Nakit';
          break;
        case 'credit':
          methodName = 'Kredi Kartı';
          break;
        case 'debit':
          methodName = 'Banka Kartı';
          break;
        default:
          methodName = 'Diğer';
      }
      paymentMethods[methodName] = (paymentMethods[methodName] ?? 0) + sale.totalAmount;
    }

    final chartData = paymentMethods.entries
        .map((e) => PieChartData(e.key, e.value))
        .toList();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Ödeme Türlerine Göre Satış Dağılımı',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 300,
              child: SfCircularChart(
                legend: const Legend(isVisible: true),
                tooltipBehavior: TooltipBehavior(enable: true),
                series: <CircularSeries>[
                  PieSeries<PieChartData, String>(
                    dataSource: chartData,
                    xValueMapper: (PieChartData data, _) => data.x,
                    yValueMapper: (PieChartData data, _) => data.y,
                    dataLabelSettings: const DataLabelSettings(isVisible: true),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopSellingProducts(List<Sale> sales, List<Product> products) {
    final Map<String, int> productQuantities = {};
    
    for (final sale in sales) {
      for (final item in sale.items) {
        productQuantities[item.productId] = 
            (productQuantities[item.productId] ?? 0) + item.quantity;
      }
    }

    final sortedProducts = productQuantities.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

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
            if (sortedProducts.isEmpty)
              const Text('Seçilen dönemde satış bulunamadı.')
            else
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: sortedProducts.take(10).length,
                itemBuilder: (context, index) {
                  final entry = sortedProducts[index];
                  final product = products.firstWhere(
                    (p) => p.id == entry.key,
                    orElse: () => Product(
                      id: '',
                      name: 'Bilinmeyen Ürün',
                      barcode: '',
                      buyingPrice: 0,
                      sellingPrice: 0,
                      stock: 0,
                      minStock: 0,
                      category: '',
                      description: '',
                    ),
                  );
                  
                  return ListTile(
                    leading: CircleAvatar(
                      child: Text('${index + 1}'),
                    ),
                    title: Text(product.name),
                    subtitle: Text('Kategori: ${product.category}'),
                    trailing: Text(
                      '${entry.value} adet',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildMostProfitableProducts(List<Sale> sales, List<Product> products) {
    final Map<String, double> productProfits = {};
    
    for (final sale in sales) {
      for (final item in sale.items) {
        final product = products.firstWhere(
          (p) => p.id == item.productId,
          orElse: () => Product(
            id: '',
            name: '',
            barcode: '',
            buyingPrice: 0,
            sellingPrice: 0,
            stock: 0,
            minStock: 0,
            category: '',
            description: '',
          ),
        );
        final profit = (item.unitPrice - product.buyingPrice) * item.quantity;
        productProfits[item.productId] = (productProfits[item.productId] ?? 0) + profit;
      }
    }

    final sortedProducts = productProfits.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

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
            if (sortedProducts.isEmpty)
              const Text('Seçilen dönemde satış bulunamadı.')
            else
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: sortedProducts.take(10).length,
                itemBuilder: (context, index) {
                  final entry = sortedProducts[index];
                  final product = products.firstWhere(
                    (p) => p.id == entry.key,
                    orElse: () => Product(
                      id: '',
                      name: 'Bilinmeyen Ürün',
                      barcode: '',
                      buyingPrice: 0,
                      sellingPrice: 0,
                      stock: 0,
                      minStock: 0,
                      category: '',
                      description: '',
                    ),
                  );
                  
                  return ListTile(
                    leading: CircleAvatar(
                      backgroundColor: Colors.green,
                      child: Text('${index + 1}'),
                    ),
                    title: Text(product.name),
                    subtitle: Text('Kategori: ${product.category}'),
                    trailing: Text(
                      _formatCurrency(entry.value),
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.green,
                      ),
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildLeastSellingProducts(List<Sale> sales, List<Product> products) {
    final Map<String, int> productQuantities = {};
    
    for (final sale in sales) {
      for (final item in sale.items) {
        productQuantities[item.productId] = 
            (productQuantities[item.productId] ?? 0) + item.quantity;
      }
    }

    // Add products with zero sales
    for (final product in products) {
      if (!productQuantities.containsKey(product.id)) {
        productQuantities[product.id] = 0;
      }
    }

    final sortedProducts = productQuantities.entries.toList()
      ..sort((a, b) => a.value.compareTo(b.value));

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
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: sortedProducts.take(10).length,
              itemBuilder: (context, index) {
                final entry = sortedProducts[index];
                final product = products.firstWhere(
                  (p) => p.id == entry.key,
                  orElse: () => Product(
                    id: '',
                    name: 'Bilinmeyen Ürün',
                    barcode: '',
                    buyingPrice: 0,
                    sellingPrice: 0,
                    stock: 0,
                    minStock: 0,
                    category: '',
                    description: '',
                  ),
                );
                
                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Colors.orange,
                    child: Text('${index + 1}'),
                  ),
                  title: Text(product.name),
                  subtitle: Text('Kategori: ${product.category}'),
                  trailing: Text(
                    '${entry.value} adet',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDeadStockAnalysis(List<Sale> sales, List<Product> products) {
    final cutoffDate = DateTime.now().subtract(const Duration(days: 30));
    final recentSales = sales.where((sale) => sale.timestamp.isAfter(cutoffDate)).toList();
    
    final soldProductIds = <String>{};
    for (final sale in recentSales) {
      for (final item in sale.items) {
        soldProductIds.add(item.productId);
      }
    }

    final deadStockProducts = products.where((product) => 
        !soldProductIds.contains(product.id) && product.stock > 0).toList();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Ölü Stok Analizi (Son 30 Gün)',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            if (deadStockProducts.isEmpty)
              const Text('Ölü stok bulunamadı.')
            else
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: deadStockProducts.take(10).length,
                itemBuilder: (context, index) {
                  final product = deadStockProducts[index];
                  
                  return ListTile(
                    leading: const CircleAvatar(
                      backgroundColor: Colors.red,
                      child: Icon(Icons.warning, color: Colors.white),
                    ),
                    title: Text(product.name),
                    subtitle: Text('Kategori: ${product.category}'),
                    trailing: Text(
                      '${product.stock} adet',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildStockSummaryCards(List<Product> products) {
    final totalProducts = products.length;
    final totalStock = products.fold<int>(0, (sum, product) => sum + product.stock);
    final totalStockValue = products.fold<double>(
        0, (sum, product) => sum + (product.stock * product.buyingPrice));

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      const Icon(Icons.inventory, size: 32, color: Colors.blue),
                      const SizedBox(height: 8),
                      Text(
                        totalProducts.toString(),
                        style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                      ),
                      const Text('Toplam Ürün', textAlign: TextAlign.center),
                    ],
                  ),
                ),
              ),
            ),
            Expanded(
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      const Icon(Icons.numbers, size: 32, color: Colors.green),
                      const SizedBox(height: 8),
                      Text(
                        totalStock.toString(),
                        style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                      ),
                      const Text('Toplam Stok', textAlign: TextAlign.center),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                const Icon(Icons.attach_money, size: 32, color: Colors.orange),
                const SizedBox(height: 8),
                Text(
                  _formatCurrency(totalStockValue),
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
                const Text('Toplam Stok Değeri', textAlign: TextAlign.center),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLowStockProducts(List<Product> products) {
    final lowStockProducts = products.where((p) => p.stock <= p.minStock && p.stock > 0).toList()
      ..sort((a, b) => a.stock.compareTo(b.stock));

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Düşük Stoklu Ürünler',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            if (lowStockProducts.isEmpty)
              const Text('Düşük stoklu ürün bulunamadı.')
            else
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: lowStockProducts.length,
                itemBuilder: (context, index) {
                  final product = lowStockProducts[index];
                  
                  return ListTile(
                    leading: const CircleAvatar(
                      backgroundColor: Colors.orange,
                      child: Icon(Icons.warning_amber, color: Colors.white),
                    ),
                    title: Text(product.name),
                    subtitle: Text('Min: ${product.minStock} | Mevcut: ${product.stock}'),
                    trailing: Text(
                      _formatCurrency(product.sellingPrice),
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildOutOfStockProducts(List<Product> products) {
    final outOfStockProducts = products.where((p) => p.stock == 0).toList();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Tükenen Ürünler',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            if (outOfStockProducts.isEmpty)
              const Text('Tükenen ürün bulunamadı.')
            else
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: outOfStockProducts.length,
                itemBuilder: (context, index) {
                  final product = outOfStockProducts[index];
                  
                  return ListTile(
                    leading: const CircleAvatar(
                      backgroundColor: Colors.red,
                      child: Icon(Icons.error, color: Colors.white),
                    ),
                    title: Text(product.name),
                    subtitle: Text('Kategori: ${product.category}'),
                    trailing: Text(
                      _formatCurrency(product.sellingPrice),
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildStockValueChart(List<Product> products) {
    final Map<String, double> categoryValues = {};
    
    for (final product in products) {
      final value = product.stock * product.buyingPrice;
      categoryValues[product.category] = (categoryValues[product.category] ?? 0) + value;
    }

    final chartData = categoryValues.entries
        .map((e) => PieChartData(e.key, e.value))
        .toList()
        ..sort((a, b) => b.y.compareTo(a.y));

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Kategorilere Göre Stok Değeri',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 300,
              child: SfCircularChart(
                legend: const Legend(isVisible: true),
                tooltipBehavior: TooltipBehavior(enable: true),
                series: <CircularSeries>[
                  PieSeries<PieChartData, String>(
                    dataSource: chartData,
                    xValueMapper: (PieChartData data, _) => data.x,
                    yValueMapper: (PieChartData data, _) => data.y,
                    dataLabelSettings: const DataLabelSettings(isVisible: true),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSaleListItem(Sale sale, List<Product> products) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: ExpansionTile(
        leading: CircleAvatar(
          backgroundColor: Theme.of(context).primaryColor,
          child: Text(
            DateFormat('dd').format(sale.timestamp),
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
        ),
        title: Text(
          _formatCurrency(sale.totalAmount),
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(
          DateFormat('dd.MM.yyyy HH:mm').format(sale.timestamp),
        ),
        trailing: Text(
          '${sale.items.length} ürün',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        children: sale.items.map((item) {
          final product = products.firstWhere(
            (p) => p.id == item.productId,
            orElse: () => Product(
              id: '',
              name: 'Bilinmeyen Ürün',
              barcode: '',
              buyingPrice: 0,
              sellingPrice: 0,
              stock: 0,
              minStock: 0,
              category: '',
              description: '',
            ),
          );

          return ListTile(
            title: Text(product.name),
            subtitle: Text('${item.quantity} adet × ${_formatCurrency(item.unitPrice)}'),
            trailing: Text(
              _formatCurrency(item.quantity * item.unitPrice),
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class ChartData {
  ChartData(this.x, this.y);
  final String x;
  final double y;
}

class PieChartData {
  PieChartData(this.x, this.y);
  final String x;
  final double y;
}
