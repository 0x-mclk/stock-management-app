import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:syncfusion_flutter_charts/charts.dart';
import '../providers/product_provider.dart';
import '../providers/sales_provider.dart';
import '../models/sale.dart';
import '../models/product.dart';
import 'qr_product_analysis_screen.dart';

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

  // Satış listesi tarih filtreleme için
  DateTimeRange? _salesDateRange;
  String _selectedDateFilter =
      'Tümü'; // 'Tümü', 'Bugün', 'Bu Hafta', 'Bu Ay', 'Özel Aralık'

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

        return DefaultTabController(
          length: 4,
          child: Column(
            children: [
              Container(
                color: Colors.grey[100],
                child: const TabBar(
                  labelColor: Colors.blue,
                  unselectedLabelColor: Colors.grey,
                  indicatorColor: Colors.blue,
                  isScrollable: true,
                  tabs: [
                    Tab(text: 'Günlük'),
                    Tab(text: 'Haftalık'),
                    Tab(text: 'Aylık'),
                    Tab(text: 'Yıllık'),
                  ],
                ),
              ),
              Expanded(
                child: TabBarView(
                  children: [
                    _buildDailyAnalysis(sales, productProvider),
                    _buildWeeklyAnalysis(sales, productProvider),
                    _buildMonthlyAnalysis(sales, productProvider),
                    _buildYearlyAnalysis(sales, productProvider),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // Haftalık Ciro & Kâr Analizi
  Widget _buildWeeklyAnalysis(
      List<Sale> sales, ProductProvider productProvider) {
    // Son haftanın verilerini hesapla
    final now = DateTime.now();
    final startOfWeek = now.subtract(Duration(days: now.weekday - 1));

    Map<String, double> weeklyRevenue = {};
    Map<String, double> weeklyProfit = {};

    // Haftanın günlerini hazırla
    final weekDays = [
      'Pazartesi',
      'Salı',
      'Çarşamba',
      'Perşembe',
      'Cuma',
      'Cumartesi',
      'Pazar'
    ];
    for (int i = 0; i < 7; i++) {
      final dayName = weekDays[i];
      weeklyRevenue[dayName] = 0;
      weeklyProfit[dayName] = 0;
    }

    // Satış verilerini analiz et
    for (var sale in sales) {
      final saleDate = sale.createdAt;
      if (saleDate.isAfter(startOfWeek.subtract(const Duration(days: 1))) &&
          saleDate.isBefore(startOfWeek.add(const Duration(days: 7)))) {
        final dayName = weekDays[saleDate.weekday - 1];
        weeklyRevenue[dayName] =
            (weeklyRevenue[dayName] ?? 0) + sale.finalAmount;

        // Kâr hesapla
        double saleProfit = _calculateSaleProfit(sale, productProvider);
        weeklyProfit[dayName] = (weeklyProfit[dayName] ?? 0) + saleProfit;
      }
    }

    final totalWeeklyRevenue =
        weeklyRevenue.values.fold<double>(0, (sum, value) => sum + value);
    final totalWeeklyProfit =
        weeklyProfit.values.fold<double>(0, (sum, value) => sum + value);
    final profitMargin = totalWeeklyRevenue > 0
        ? (totalWeeklyProfit / totalWeeklyRevenue * 100)
        : 0;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Özet Kartları
          Row(
            children: [
              Expanded(
                child: _buildSummaryCard(
                  'Haftalık Ciro',
                  _currencyFormat.format(totalWeeklyRevenue),
                  Icons.attach_money,
                  Colors.green,
                ),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: _buildSummaryCard(
                  'Haftalık Kâr',
                  _currencyFormat.format(totalWeeklyProfit),
                  Icons.trending_up,
                  Colors.blue,
                ),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: _buildSummaryCard(
                  'Kâr Marjı',
                  '%${profitMargin.toStringAsFixed(1)}',
                  Icons.percent,
                  Colors.orange,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Haftalık Grafik
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Haftalık Ciro & Kâr Analizi',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    height: 300,
                    child: SfCartesianChart(
                      primaryXAxis: const CategoryAxis(
                        labelRotation: 45,
                      ),
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
                          dataSource: weeklyRevenue.entries.toList(),
                          xValueMapper: (entry, _) => entry.key,
                          yValueMapper: (entry, _) => entry.value,
                          name: 'Ciro',
                          color: Colors.blue,
                          width: 0.6,
                        ),
                        LineSeries<MapEntry<String, double>, String>(
                          dataSource: weeklyProfit.entries.toList(),
                          xValueMapper: (entry, _) => entry.key,
                          yValueMapper: (entry, _) => entry.value,
                          name: 'Kâr',
                          color: Colors.green,
                          markerSettings: const MarkerSettings(isVisible: true),
                          width: 3,
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
  }

  // Aylık Ciro & Kâr Analizi
  Widget _buildMonthlyAnalysis(
      List<Sale> sales, ProductProvider productProvider) {
    Map<String, double> monthlyRevenue = {};
    Map<String, double> monthlyProfit = {};

    // Son 12 ayı hazırla
    final now = DateTime.now();
    final months = [
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
    for (int i = 11; i >= 0; i--) {
      final targetYear = now.month - i <= 0 ? now.year - 1 : now.year;
      final targetMonth =
          now.month - i <= 0 ? 12 + (now.month - i) : now.month - i;
      final monthKey = '${months[targetMonth - 1]} $targetYear';
      monthlyRevenue[monthKey] = 0;
      monthlyProfit[monthKey] = 0;
    }

    // Satış verilerini analiz et
    for (var sale in sales) {
      final saleMonth = sale.createdAt;
      final monthKey = '${months[saleMonth.month - 1]} ${saleMonth.year}';
      if (monthlyRevenue.containsKey(monthKey)) {
        monthlyRevenue[monthKey] =
            (monthlyRevenue[monthKey] ?? 0) + sale.finalAmount;

        double saleProfit = _calculateSaleProfit(sale, productProvider);
        monthlyProfit[monthKey] = (monthlyProfit[monthKey] ?? 0) + saleProfit;
      }
    }

    final totalRevenue =
        monthlyRevenue.values.fold<double>(0, (sum, value) => sum + value);
    final totalProfit =
        monthlyProfit.values.fold<double>(0, (sum, value) => sum + value);
    final profitMargin =
        totalRevenue > 0 ? (totalProfit / totalRevenue * 100) : 0;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Özet Kartları
          Row(
            children: [
              Expanded(
                child: _buildSummaryCard(
                  'Yıllık Ciro',
                  _currencyFormat.format(totalRevenue),
                  Icons.attach_money,
                  Colors.green,
                ),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: _buildSummaryCard(
                  'Yıllık Kâr',
                  _currencyFormat.format(totalProfit),
                  Icons.trending_up,
                  Colors.blue,
                ),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: _buildSummaryCard(
                  'Brüt Kâr Marjı',
                  '%${profitMargin.toStringAsFixed(1)}',
                  Icons.percent,
                  Colors.orange,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Aylık Grafik
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Aylık Ciro & Kâr Trendi (Son 12 Ay)',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    height: 300,
                    child: SfCartesianChart(
                      primaryXAxis: const CategoryAxis(
                        labelRotation: 45,
                      ),
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
                          xValueMapper: (entry, _) => entry.key,
                          yValueMapper: (entry, _) => entry.value,
                          name: 'Ciro',
                          color: Colors.blue,
                          width: 0.6,
                        ),
                        LineSeries<MapEntry<String, double>, String>(
                          dataSource: monthlyProfit.entries.toList(),
                          xValueMapper: (entry, _) => entry.key,
                          yValueMapper: (entry, _) => entry.value,
                          name: 'Kâr',
                          color: Colors.green,
                          markerSettings: const MarkerSettings(isVisible: true),
                          width: 3,
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
  }

  // Yıllık Ciro & Kâr Analizi
  Widget _buildYearlyAnalysis(
      List<Sale> sales, ProductProvider productProvider) {
    Map<String, double> yearlyRevenue = {};
    Map<String, double> yearlyProfit = {};

    // Son birkaç yılı hazırla
    final now = DateTime.now();
    for (int i = 3; i >= 0; i--) {
      final year = (now.year - i).toString();
      yearlyRevenue[year] = 0;
      yearlyProfit[year] = 0;
    }

    // Satış verilerini analiz et
    for (var sale in sales) {
      final year = sale.createdAt.year.toString();
      if (yearlyRevenue.containsKey(year)) {
        yearlyRevenue[year] = (yearlyRevenue[year] ?? 0) + sale.finalAmount;

        double saleProfit = _calculateSaleProfit(sale, productProvider);
        yearlyProfit[year] = (yearlyProfit[year] ?? 0) + saleProfit;
      }
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Yıllık Grafik
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Yıllık Ciro & Kâr Karşılaştırması',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
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
                          dataSource: yearlyRevenue.entries.toList(),
                          xValueMapper: (entry, _) => entry.key,
                          yValueMapper: (entry, _) => entry.value,
                          name: 'Ciro',
                          color: Colors.blue,
                          width: 0.6,
                        ),
                        LineSeries<MapEntry<String, double>, String>(
                          dataSource: yearlyProfit.entries.toList(),
                          xValueMapper: (entry, _) => entry.key,
                          yValueMapper: (entry, _) => entry.value,
                          name: 'Kâr',
                          color: Colors.green,
                          markerSettings: const MarkerSettings(isVisible: true),
                          width: 3,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Yıllık Özet Tablosu
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Yıllık Performans Özeti',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  Table(
                    border: TableBorder.all(color: Colors.grey[300]!),
                    children: [
                      const TableRow(
                        decoration: BoxDecoration(color: Colors.grey),
                        children: [
                          Padding(
                            padding: EdgeInsets.all(8),
                            child: Text('Yıl',
                                style: TextStyle(fontWeight: FontWeight.bold)),
                          ),
                          Padding(
                            padding: EdgeInsets.all(8),
                            child: Text('Ciro',
                                style: TextStyle(fontWeight: FontWeight.bold)),
                          ),
                          Padding(
                            padding: EdgeInsets.all(8),
                            child: Text('Kâr',
                                style: TextStyle(fontWeight: FontWeight.bold)),
                          ),
                          Padding(
                            padding: EdgeInsets.all(8),
                            child: Text('Marj %',
                                style: TextStyle(fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ),
                      // Yılları azalan sırada sırala (2025 en üstte)
                      ...(() {
                        final sortedEntries = yearlyRevenue.entries.toList()
                          ..sort((a, b) =>
                              int.parse(b.key).compareTo(int.parse(a.key)));

                        return sortedEntries.map((entry) {
                          final year = entry.key;
                          final revenue = entry.value;
                          final profit = yearlyProfit[year] ?? 0;
                          final margin =
                              revenue > 0 ? (profit / revenue * 100) : 0;

                          return TableRow(
                            children: [
                              Padding(
                                padding: const EdgeInsets.all(8),
                                child: Text(year),
                              ),
                              Padding(
                                padding: const EdgeInsets.all(8),
                                child: Text(_currencyFormat.format(revenue)),
                              ),
                              Padding(
                                padding: const EdgeInsets.all(8),
                                child: Text(_currencyFormat.format(profit)),
                              ),
                              Padding(
                                padding: const EdgeInsets.all(8),
                                child: Text('%${margin.toStringAsFixed(1)}'),
                              ),
                            ],
                          );
                        });
                      })(),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Seçili Gün Analizi
  Widget _buildDailyAnalysis(
      List<Sale> sales, ProductProvider productProvider) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Tarih Seçici
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Gün Seçin',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: () => _selectDate(context),
                    icon: const Icon(Icons.calendar_today),
                    label: Text(
                      'Seçilen Tarih: ${DateFormat('dd/MM/yyyy').format(_selectedDate)}',
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Seçili gün analizi
          _buildSelectedDayAnalysis(sales, productProvider),
        ],
      ),
    );
  }

  DateTime _selectedDate = DateTime.now();

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  Widget _buildSelectedDayAnalysis(
      List<Sale> sales, ProductProvider productProvider) {
    // Seçili güne ait satışları filtrele
    final selectedDaySales = sales.where((sale) {
      final saleDate = sale.createdAt;
      return saleDate.year == _selectedDate.year &&
          saleDate.month == _selectedDate.month &&
          saleDate.day == _selectedDate.day;
    }).toList();

    if (selectedDaySales.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(40),
          child: Center(
            child: Column(
              children: [
                Icon(Icons.info_outline, size: 48, color: Colors.grey[600]),
                const SizedBox(height: 16),
                Text(
                  'Seçilen tarihte satış bulunmuyor',
                  style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // Günlük hesaplamalar
    double dailyRevenue = 0;
    double dailyProfit = 0;
    Map<String, int> productSales = {};

    for (var sale in selectedDaySales) {
      dailyRevenue += sale.finalAmount;
      dailyProfit += _calculateSaleProfit(sale, productProvider);

      for (var item in sale.items) {
        productSales[item.productName] =
            (productSales[item.productName] ?? 0) + item.quantity;
      }
    }

    final profitMargin =
        dailyRevenue > 0 ? (dailyProfit / dailyRevenue * 100) : 0;

    // En çok satılan ürünler
    final topProducts = productSales.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Column(
      children: [
        // Günlük Özet
        Row(
          children: [
            Expanded(
              child: _buildSummaryCard(
                'Günlük Ciro',
                _currencyFormat.format(dailyRevenue),
                Icons.attach_money,
                Colors.green,
              ),
            ),
            const SizedBox(width: 4),
            Expanded(
              child: _buildSummaryCard(
                'Günlük Kâr',
                _currencyFormat.format(dailyProfit),
                Icons.trending_up,
                Colors.blue,
              ),
            ),
            const SizedBox(width: 4),
            Expanded(
              child: _buildSummaryCard(
                'Satış Sayısı',
                '${selectedDaySales.length}',
                Icons.receipt,
                Colors.orange,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // Günlük Detay Tablosu
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Günlük Satış Detayları - ${DateFormat('dd/MM/yyyy').format(_selectedDate)}',
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                Table(
                  border: TableBorder.all(color: Colors.grey[300]!),
                  children: [
                    const TableRow(
                      decoration: BoxDecoration(color: Colors.grey),
                      children: [
                        Padding(
                          padding: EdgeInsets.all(8),
                          child: Text('Saat',
                              style: TextStyle(fontWeight: FontWeight.bold)),
                        ),
                        Padding(
                          padding: EdgeInsets.all(8),
                          child: Text('Tutar',
                              style: TextStyle(fontWeight: FontWeight.bold)),
                        ),
                        Padding(
                          padding: EdgeInsets.all(8),
                          child: Text('Ürün Sayısı',
                              style: TextStyle(fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                    ...selectedDaySales.map((sale) {
                      return TableRow(
                        children: [
                          Padding(
                            padding: const EdgeInsets.all(8),
                            child: Text(
                                DateFormat('HH:mm').format(sale.createdAt)),
                          ),
                          Padding(
                            padding: const EdgeInsets.all(8),
                            child:
                                Text(_currencyFormat.format(sale.finalAmount)),
                          ),
                          Padding(
                            padding: const EdgeInsets.all(8),
                            child: Text('${sale.items.length}'),
                          ),
                        ],
                      );
                    }),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    Column(
                      children: [
                        const Text('Brüt Kâr Marjı:',
                            style: TextStyle(fontWeight: FontWeight.bold)),
                        Text(
                          '%${profitMargin.toStringAsFixed(1)}',
                          style: const TextStyle(
                              fontSize: 18,
                              color: Colors.green,
                              fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    Column(
                      children: [
                        const Text('Toplam İşlem:',
                            style: TextStyle(fontWeight: FontWeight.bold)),
                        Text(
                          '${selectedDaySales.length}',
                          style: const TextStyle(
                              fontSize: 18,
                              color: Colors.blue,
                              fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),

        // En Çok Satılan Ürünler (o gün için)
        if (topProducts.isNotEmpty) ...[
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'En Çok Satılan Ürünler (Bu Gün)',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  ...topProducts.take(5).map((entry) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(entry.key),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.blue[100],
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              '${entry.value} adet',
                              style:
                                  const TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }

  // Kâr hesaplama yardımcı fonksiyonu
  double _calculateSaleProfit(Sale sale, ProductProvider productProvider) {
    double totalProfit = 0;

    // Eğer items boşsa 0 döndür (eski satışlar için)
    if (sale.items.isEmpty) {
      return 0.0;
    }

    for (var item in sale.items) {
      // Ürünü listeden bul
      Product? foundProduct;

      // ID ile ara
      try {
        foundProduct = productProvider.products.firstWhere(
          (p) => p.id == item.productId,
        );
      } catch (e) {
        // ID ile bulunamadı
      }

      // Bulunamadıysa barcode ile ara
      if (foundProduct == null) {
        try {
          foundProduct = productProvider.products.firstWhere(
            (p) => p.barcode == item.productBarcode,
          );
        } catch (e) {
          // Barcode ile bulunamadı
        }
      }

      // Hala bulunamadıysa isim ile ara
      if (foundProduct == null) {
        try {
          foundProduct = productProvider.products.firstWhere(
            (p) => p.name == item.productName,
          );
        } catch (e) {
          // İsim ile bulunamadı
        }
      }

      // Kar hesapla
      double salePrice = item.unitPrice;
      double purchasePrice;
      double unitProfit;

      if (foundProduct != null) {
        purchasePrice = foundProduct.purchasePrice ?? 0;
        if (purchasePrice > 0) {
          unitProfit = salePrice - purchasePrice;
        } else {
          // Alış fiyatı 0 ise, satış fiyatının %30'u kâr kabul et
          unitProfit = salePrice * 0.3;
        }
      } else {
        // Ürün bulunamadıysa satış fiyatının %30'u kâr kabul et
        unitProfit = salePrice * 0.3;
      }

      double itemProfit = unitProfit * item.quantity;
      totalProfit += itemProfit;
    }

    return totalProfit;
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

        return DefaultTabController(
          length: 6,
          child: Column(
            children: [
              Container(
                color: Colors.grey[100],
                child: const TabBar(
                  labelColor: Colors.blue,
                  unselectedLabelColor: Colors.grey,
                  indicatorColor: Colors.blue,
                  isScrollable: true,
                  tabs: [
                    Tab(text: 'En Çok Satan'),
                    Tab(text: 'En Karlı'),
                    Tab(text: 'Az Satan'),
                    Tab(text: 'Ölü Stok'),
                    Tab(text: 'Saat Bazlı'),
                    Tab(text: 'Ödeme Türü'),
                  ],
                ),
              ),
              Expanded(
                child: TabBarView(
                  children: [
                    _buildTopSellingProducts(sales, products),
                    _buildMostProfitableProducts(sales, products),
                    _buildLeastSellingProducts(sales, products),
                    _buildDeadStockAnalysis(sales, products),
                    _buildHourlySalesAnalysis(sales),
                    _buildPaymentMethodAnalysis(sales),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // En Çok Satan Ürünler Sekmesi
  Widget _buildTopSellingProducts(List<Sale> sales, List<Product> products) {
    Map<String, int> productSales = {};
    Map<String, String> productIds = {};

    // Satış verilerini analiz et
    for (var sale in sales) {
      for (var item in sale.items) {
        final product = products.firstWhere(
          (p) => p.id == item.productId,
          orElse: () => Product(
            id: item.productId,
            barcode: '',
            name: item.productName,
            salePrice: 0,
            stock: 0,
            category: 'Diğer',
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
        );

        productSales[product.name] =
            (productSales[product.name] ?? 0) + item.quantity;
        productIds[product.name] = product.id ?? item.productId;
      }
    }

    // Sıralama: En çok satandan en aza
    final sortedProducts = productSales.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Grafik
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'En Çok Satan Ürünler (İlk 10)',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    height: 300,
                    child: SfCartesianChart(
                      primaryXAxis: const CategoryAxis(
                        labelRotation: 45,
                        maximumLabelWidth: 80,
                      ),
                      primaryYAxis: const NumericAxis(),
                      tooltipBehavior: TooltipBehavior(enable: true),
                      series: <CartesianSeries>[
                        ColumnSeries<MapEntry<String, int>, String>(
                          dataSource: sortedProducts.take(10).toList(),
                          xValueMapper: (entry, _) => entry.key.length > 12
                              ? '${entry.key.substring(0, 12)}...'
                              : entry.key,
                          yValueMapper: (entry, _) => entry.value,
                          name: 'Satış Adedi',
                          color: Colors.blue,
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

          // Liste
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Detaylı Liste',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      Text(
                        'Toplam ${sortedProducts.length} ürün',
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: sortedProducts.length,
                    itemBuilder: (context, index) {
                      final entry = sortedProducts[index];
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor:
                              index < 3 ? Colors.orange : Colors.grey[300],
                          child: Text(
                            '${index + 1}',
                            style: TextStyle(
                              color: index < 3 ? Colors.white : Colors.black87,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        title: Text(
                          entry.key,
                          style: const TextStyle(fontWeight: FontWeight.w500),
                        ),
                        subtitle: const Text('Satış Adedi'),
                        trailing: Text(
                          '${entry.value} adet',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.blue,
                          ),
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
  }

  // 3. Stok Analizi Sekmesi
  Widget _buildStockAnalysisTab() {
    return Consumer2<ProductProvider, SalesProvider>(
      builder: (context, productProvider, salesProvider, child) {
        final products = productProvider.products;
        final sales = salesProvider.sales;

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

        return DefaultTabController(
          length: 4,
          child: Column(
            children: [
              Container(
                color: Colors.grey[100],
                child: const TabBar(
                  labelColor: Colors.blue,
                  unselectedLabelColor: Colors.grey,
                  indicatorColor: Colors.blue,
                  isScrollable: true,
                  tabs: [
                    Tab(text: 'Stok Durumu'),
                    Tab(text: 'Stok Değeri'),
                    Tab(text: 'Stok İstatistik'),
                    Tab(text: 'QR Analiz'),
                  ],
                ),
              ),
              Expanded(
                child: TabBarView(
                  children: [
                    _buildStockStatusTab(products),
                    _buildStockValueTab(products),
                    _buildStockStatisticsTab(products, sales),
                    _buildQRAnalysisTab(products, sales),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // Stok Durumu Sekmesi
  Widget _buildStockStatusTab(List<Product> products) {
    // Asgari stok seviyesi (varsayılan: 10)
    const minStockLevel = 10;
    final lowStockProducts =
        products.where((p) => p.stock > 0 && p.stock <= minStockLevel).toList();
    final outOfStockProducts = products.where((p) => p.stock == 0).toList();
    final normalStockProducts =
        products.where((p) => p.stock > minStockLevel).toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Özet Kartları
          Row(
            children: [
              Expanded(
                child: _buildSummaryCard(
                  'Normal Stok',
                  '${normalStockProducts.length}',
                  Icons.check_circle,
                  Colors.green,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildSummaryCard(
                  'Düşük Stok',
                  '${lowStockProducts.length}',
                  Icons.warning,
                  Colors.orange,
                ),
              ),
              const SizedBox(width: 8),
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
          const SizedBox(height: 16),

          // Stok Durumu Dağılımı Grafiği
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Stok Durumu Dağılımı',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    height: 250,
                    child: SfCircularChart(
                      legend: const Legend(
                        isVisible: true,
                        position: LegendPosition.bottom,
                      ),
                      tooltipBehavior: TooltipBehavior(enable: true),
                      series: <CircularSeries>[
                        PieSeries<Map<String, dynamic>, String>(
                          dataSource: [
                            {
                              'category': 'Normal Stok',
                              'count': normalStockProducts.length,
                              'color': Colors.green
                            },
                            {
                              'category': 'Düşük Stok',
                              'count': lowStockProducts.length,
                              'color': Colors.orange
                            },
                            {
                              'category': 'Stokta Yok',
                              'count': outOfStockProducts.length,
                              'color': Colors.red
                            },
                          ]
                              .where((item) =>
                                  (item['count'] as int?) != null &&
                                  (item['count'] as int) > 0)
                              .toList(),
                          xValueMapper: (data, _) => data['category'],
                          yValueMapper: (data, _) => data['count'],
                          pointColorMapper: (data, _) => data['color'],
                          dataLabelSettings: const DataLabelSettings(
                            isVisible: true,
                            labelPosition: ChartDataLabelPosition.outside,
                          ),
                          explode: true,
                          explodeIndex: 1, // Düşük stok vurgusu
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Stokta Yok Ürünler
          if (outOfStockProducts.isNotEmpty)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.error, color: Colors.red),
                        SizedBox(width: 8),
                        Text(
                          'Stokta Yok - Acil Tedarik Gerekli',
                          style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.red),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: outOfStockProducts.length,
                      itemBuilder: (context, index) {
                        final product = outOfStockProducts[index];
                        return ListTile(
                          leading: const CircleAvatar(
                            backgroundColor: Colors.red,
                            child: Text('0',
                                style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold)),
                          ),
                          title: Text(product.name,
                              style:
                                  const TextStyle(fontWeight: FontWeight.w500)),
                          subtitle: Text(product.category ?? 'Kategori yok'),
                          trailing: Text(
                            _currencyFormat.format(product.salePrice),
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),

          // Düşük Stoklu Ürünler
          if (lowStockProducts.isNotEmpty) ...[
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.warning, color: Colors.orange),
                        const SizedBox(width: 8),
                        Text(
                          'Düşük Stok (≤$minStockLevel adet)',
                          style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.orange),
                        ),
                      ],
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
                            backgroundColor: Colors.orange,
                            child: Text(
                              '${product.stock}',
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold),
                            ),
                          ),
                          title: Text(product.name,
                              style:
                                  const TextStyle(fontWeight: FontWeight.w500)),
                          subtitle: Text(product.category ?? 'Kategori yok'),
                          trailing: Text(
                            _currencyFormat.format(product.salePrice),
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          ],

          // Hepsi Normal ise
          if (outOfStockProducts.isEmpty && lowStockProducts.isEmpty)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  children: [
                    const Icon(Icons.check_circle,
                        size: 64, color: Colors.green),
                    const SizedBox(height: 16),
                    const Text(
                      'Mükemmel Stok Durumu!',
                      style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.green),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Tüm ürünlerinizin stoku yeterli seviyede',
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  // Stok Değeri Sekmesi
  Widget _buildStockValueTab(List<Product> products) {
    // Toplam stok değeri hesaplama
    double totalPurchaseValue = 0;
    double totalSaleValue = 0;
    Map<String, double> categoryValues = {};

    for (var product in products) {
      final purchaseValue = (product.purchasePrice ?? 0) * product.stock;
      final saleValue = product.salePrice * product.stock;

      totalPurchaseValue += purchaseValue;
      totalSaleValue += saleValue;

      final category = product.category ?? 'Diğer';
      categoryValues[category] = (categoryValues[category] ?? 0) + saleValue;
    }

    final potentialProfit = totalSaleValue - totalPurchaseValue;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Değer Özet Kartları
          Row(
            children: [
              Expanded(
                child: _buildSummaryCard(
                  'Alış Değeri',
                  _currencyFormat.format(totalPurchaseValue),
                  Icons.shopping_cart,
                  Colors.blue,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildSummaryCard(
                  'Satış Değeri',
                  _currencyFormat.format(totalSaleValue),
                  Icons.sell,
                  Colors.green,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _buildSummaryCard(
                  'Potansiyel Kâr',
                  _currencyFormat.format(potentialProfit),
                  Icons.trending_up,
                  potentialProfit >= 0 ? Colors.green : Colors.red,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildSummaryCard(
                  'Kâr Oranı',
                  totalPurchaseValue > 0
                      ? '%${((potentialProfit / totalPurchaseValue) * 100).toStringAsFixed(1)}'
                      : '%0,0',
                  Icons.percent,
                  Colors.purple,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Kategori Bazında Stok Değeri Grafiği
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Kategori Bazında Stok Değeri (Satış Fiyatı)',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    height: 300,
                    child: SfCartesianChart(
                      primaryXAxis: const CategoryAxis(),
                      primaryYAxis: NumericAxis(
                        numberFormat:
                            NumberFormat.currency(locale: 'tr_TR', symbol: '₺'),
                      ),
                      tooltipBehavior: TooltipBehavior(enable: true),
                      series: <CartesianSeries>[
                        ColumnSeries<MapEntry<String, double>, String>(
                          dataSource: categoryValues.entries.toList(),
                          xValueMapper: (MapEntry<String, double> data, _) =>
                              data.key,
                          yValueMapper: (MapEntry<String, double> data, _) =>
                              data.value,
                          name: 'Stok Değeri',
                          color: Colors.teal,
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
          const SizedBox(height: 16),

          // En Değerli Ürünler
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'En Değerli Stoklar (Top 10)',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  Builder(
                    builder: (context) {
                      final sortedProducts = products
                          .map((p) => MapEntry(p, p.salePrice * p.stock))
                          .toList()
                        ..sort((a, b) => b.value.compareTo(a.value));

                      final topProducts = sortedProducts.take(10).toList();

                      return ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: topProducts.length,
                        itemBuilder: (context, index) {
                          final entry = topProducts[index];
                          final product = entry.key;
                          final value = entry.value;

                          return ListTile(
                            leading: CircleAvatar(
                              backgroundColor: Colors.teal,
                              child: Text(
                                '${index + 1}',
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold),
                              ),
                            ),
                            title: Text(product.name,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w500)),
                            subtitle: Text(
                                '${product.stock} adet × ${_currencyFormat.format(product.salePrice)}'),
                            trailing: Text(
                              _currencyFormat.format(value),
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 16),
                            ),
                          );
                        },
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
  }

  // Stok İstatistikleri Sekmesi
  Widget _buildStockStatisticsTab(List<Product> products, List<Sale> sales) {
    // Temel istatistikler
    final totalProducts = products.length;
    final totalStock = products.fold(0, (sum, p) => sum + p.stock);
    final totalCategories =
        products.map((p) => p.category ?? 'Diğer').toSet().length;
    final averageStock =
        totalProducts > 0 ? (totalStock / totalProducts).round() : 0;

    // Kategori istatistikleri
    Map<String, Map<String, dynamic>> categoryStats = {};
    for (var product in products) {
      final category = product.category ?? 'Diğer';
      if (!categoryStats.containsKey(category)) {
        categoryStats[category] = {
          'count': 0,
          'stock': 0,
          'value': 0.0,
        };
      }
      categoryStats[category]!['count'] += 1;
      categoryStats[category]!['stock'] += product.stock;
      categoryStats[category]!['value'] += product.salePrice * product.stock;
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Genel İstatistikler
          Row(
            children: [
              Expanded(
                child: _buildSummaryCard(
                  'Toplam Ürün',
                  '$totalProducts',
                  Icons.inventory,
                  Colors.blue,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildSummaryCard(
                  'Toplam Adet',
                  '$totalStock',
                  Icons.format_list_numbered,
                  Colors.green,
                ),
              ),
            ],
          ),
          const SizedBox(width: 8),
          Row(
            children: [
              Expanded(
                child: _buildSummaryCard(
                  'Kategori Sayısı',
                  '$totalCategories',
                  Icons.category,
                  Colors.orange,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildSummaryCard(
                  'Ortalama Stok',
                  '$averageStock',
                  Icons.balance,
                  Colors.purple,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Kategori Dağılımı Pasta Grafiği
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Ürün Kategorileri Dağılımı',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    height: 250,
                    child: SfCircularChart(
                      legend: const Legend(
                        isVisible: true,
                        position: LegendPosition.bottom,
                      ),
                      tooltipBehavior: TooltipBehavior(enable: true),
                      series: <CircularSeries>[
                        PieSeries<MapEntry<String, Map<String, dynamic>>,
                            String>(
                          dataSource: categoryStats.entries.toList(),
                          xValueMapper: (data, _) => data.key,
                          yValueMapper: (data, _) => data.value['count'],
                          dataLabelSettings: const DataLabelSettings(
                            isVisible: true,
                            labelPosition: ChartDataLabelPosition.outside,
                          ),
                          explode: true,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Kategori Detayları
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Kategori Detayları',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: categoryStats.length,
                    itemBuilder: (context, index) {
                      final entry = categoryStats.entries.toList()[index];
                      final category = entry.key;
                      final stats = entry.value;

                      return Card(
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        child: ListTile(
                          title: Text(
                            category,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Text(
                            '${stats['count']} ürün • ${stats['stock']} adet',
                          ),
                          trailing: Text(
                            _currencyFormat.format(stats['value']),
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
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
  }

  // QR Analiz Sekmesi
  Widget _buildQRAnalysisTab(List<Product> products, List<Sale> sales) {
    // Ürün bazında satış istatistikleri
    Map<String, Map<String, dynamic>> productSalesStats = {};

    for (var sale in sales) {
      for (var item in sale.items) {
        final productName = item.productName;
        if (!productSalesStats.containsKey(productName)) {
          productSalesStats[productName] = {
            'totalSales': 0,
            'totalQuantity': 0,
            'totalRevenue': 0.0,
            'lastSaleDate': sale.createdAt,
            'barcode': products
                .firstWhere((p) => p.name == productName,
                    orElse: () => Product(
                          id: '',
                          name: productName,
                          salePrice: 0,
                          stock: 0,
                          barcode: '',
                        ))
                .barcode,
          };
        }

        productSalesStats[productName]!['totalSales'] += 1;
        productSalesStats[productName]!['totalQuantity'] += item.quantity;
        productSalesStats[productName]!['totalRevenue'] += item.totalPrice;

        // En son satış tarihini güncelle
        if (sale.createdAt
            .isAfter(productSalesStats[productName]!['lastSaleDate'])) {
          productSalesStats[productName]!['lastSaleDate'] = sale.createdAt;
        }
      }
    }

    // En çok satılan ürünler
    final topSellingProducts = productSalesStats.entries.toList()
      ..sort((a, b) => (b.value['totalQuantity'] as int)
          .compareTo(a.value['totalQuantity'] as int));

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // QR Okuma Butonu
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  const Icon(
                    Icons.qr_code_scanner,
                    size: 64,
                    color: Colors.blue,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'QR Kod ile Ürün Analizi',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'QR kodu tarayarak ürün bazlı satış analizi yapabilirsiniz',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: () async {
                      // QR kod tarama sayfasına yönlendir
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const QRProductAnalysisScreen(),
                        ),
                      );
                    },
                    icon: const Icon(Icons.qr_code_scanner),
                    label: const Text('QR Kod Tara'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 24, vertical: 12),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // En Çok Satılan Ürünler
          if (topSellingProducts.isNotEmpty)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'En Çok Satılan Ürünler',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 16),
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: topSellingProducts.take(10).length,
                      itemBuilder: (context, index) {
                        final entry = topSellingProducts[index];
                        final productName = entry.key;
                        final stats = entry.value;
                        final barcode = stats['barcode'];

                        return Card(
                          margin: const EdgeInsets.symmetric(vertical: 4),
                          child: ExpansionTile(
                            leading: CircleAvatar(
                              backgroundColor: Colors.blue,
                              child: Text(
                                '${index + 1}',
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold),
                              ),
                            ),
                            title: Text(
                              productName,
                              style:
                                  const TextStyle(fontWeight: FontWeight.w500),
                            ),
                            subtitle: Text(
                              '${stats['totalQuantity']} adet satıldı • ${_currencyFormat.format(stats['totalRevenue'])}',
                            ),
                            children: [
                              Padding(
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    if (barcode != null && barcode.isNotEmpty)
                                      Row(
                                        children: [
                                          const Icon(Icons.qr_code, size: 20),
                                          const SizedBox(width: 8),
                                          Text('Barkod: $barcode'),
                                        ],
                                      ),
                                    const SizedBox(height: 8),
                                    Row(
                                      children: [
                                        const Icon(Icons.shopping_cart,
                                            size: 20),
                                        const SizedBox(width: 8),
                                        Text(
                                            'Toplam Satış: ${stats['totalSales']} işlem'),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    Row(
                                      children: [
                                        const Icon(Icons.calendar_today,
                                            size: 20),
                                        const SizedBox(width: 8),
                                        Text(
                                            'Son Satış: ${DateFormat('dd.MM.yyyy').format(stats['lastSaleDate'])}'),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),

          // Barkod Bulunamayan Ürünler
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Barkod Bilgisi Eksik Ürünler',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount:
                        products.where((p) => p.barcode.isEmpty).take(5).length,
                    itemBuilder: (context, index) {
                      final productsWithoutBarcode =
                          products.where((p) => p.barcode.isEmpty).toList();
                      if (index >= productsWithoutBarcode.length) {
                        return const SizedBox.shrink();
                      }

                      final product = productsWithoutBarcode[index];

                      return ListTile(
                        leading:
                            const Icon(Icons.warning, color: Colors.orange),
                        title: Text(product.name),
                        subtitle: const Text('Barkod bilgisi eksik'),
                        trailing: const Icon(Icons.edit),
                        onTap: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                  '${product.name} ürününe barkod ekleyebilirsiniz'),
                            ),
                          );
                        },
                      );
                    },
                  ),
                  if (products.where((p) => p.barcode.isEmpty).isEmpty)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.all(16),
                        child: Text(
                          'Tüm ürünlerin barkod bilgisi mevcut!',
                          style: TextStyle(
                              color: Colors.green, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // 4. Satış Listesi Sekmesi
  Widget _buildSalesListTab() {
    return Consumer2<SalesProvider, ProductProvider>(
      builder: (context, salesProvider, productProvider, child) {
        final allSales = salesProvider.sales;

        // Tarih aralığına göre filtreleme
        final filteredSales = _filterSalesByDateRange(allSales);

        if (filteredSales.isEmpty) {
          return Column(
            children: [
              // Tarih Seçici
              _buildDateRangeSelector(),

              const Expanded(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.receipt_long, size: 64, color: Colors.grey),
                      SizedBox(height: 16),
                      Text('Seçili tarih aralığında satış verisi bulunmuyor'),
                    ],
                  ),
                ),
              ),
            ],
          );
        }

        // Satışları tarihe göre sırala (en yeni önce)
        final sortedSales = filteredSales.toList()
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

        // Toplam satış tutarı
        final totalSalesAmount = filteredSales.fold<double>(
            0, (sum, sale) => sum + sale.finalAmount);

        return Column(
          children: [
            // Tarih Seçici
            _buildDateRangeSelector(),

            // Filtre ve Sıralama Seçenekleri
            Container(
              padding: const EdgeInsets.all(16),
              color: Colors.grey[100],
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Toplam ${filteredSales.length} satış',
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
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 24, color: color),
            const SizedBox(height: 4),
            Text(
              title,
              style: const TextStyle(
                fontSize: 11,
                color: Colors.grey,
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            Text(
              value,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: color,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  // En Karlı Ürünler Sekmesi
  Widget _buildMostProfitableProducts(
      List<Sale> sales, List<Product> products) {
    Map<String, double> productProfits = {};

    // Kâr verilerini analiz et
    for (var sale in sales) {
      for (var item in sale.items) {
        final product = products.firstWhere(
          (p) => p.id == item.productId,
          orElse: () => Product(
            id: item.productId,
            barcode: '',
            name: item.productName,
            salePrice: item.unitPrice,
            stock: 0,
            category: 'Diğer',
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
        );

        // Kâr hesapla
        double unitProfit;
        if (product.purchasePrice != null && product.purchasePrice! > 0) {
          unitProfit = item.unitPrice - product.purchasePrice!;
        } else {
          unitProfit = item.unitPrice * 0.3; // %30 varsayılan kâr
        }

        double totalItemProfit = unitProfit * item.quantity;
        productProfits[product.name] =
            (productProfits[product.name] ?? 0) + totalItemProfit;
      }
    }

    // Sıralama: En karlıdan en aza
    final sortedProducts = productProfits.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Grafik
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'En Karlı Ürünler (İlk 10)',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    height: 300,
                    child: SfCartesianChart(
                      primaryXAxis: const CategoryAxis(
                        labelRotation: 45,
                        maximumLabelWidth: 80,
                      ),
                      primaryYAxis: NumericAxis(
                        numberFormat: NumberFormat.currency(
                          locale: 'tr_TR',
                          symbol: '₺',
                          decimalDigits: 0,
                        ),
                      ),
                      tooltipBehavior: TooltipBehavior(enable: true),
                      series: <CartesianSeries>[
                        ColumnSeries<MapEntry<String, double>, String>(
                          dataSource: sortedProducts.take(10).toList(),
                          xValueMapper: (entry, _) => entry.key.length > 12
                              ? '${entry.key.substring(0, 12)}...'
                              : entry.key,
                          yValueMapper: (entry, _) => entry.value,
                          name: 'Toplam Kâr',
                          color: Colors.green,
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

          // Liste
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Detaylı Liste',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      Text(
                        'Toplam ${sortedProducts.length} ürün',
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: sortedProducts.length,
                    itemBuilder: (context, index) {
                      final entry = sortedProducts[index];
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor:
                              index < 3 ? Colors.green : Colors.grey[300],
                          child: Text(
                            '${index + 1}',
                            style: TextStyle(
                              color: index < 3 ? Colors.white : Colors.black87,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        title: Text(
                          entry.key,
                          style: const TextStyle(fontWeight: FontWeight.w500),
                        ),
                        subtitle: const Text('Toplam Kâr'),
                        trailing: Text(
                          _currencyFormat.format(entry.value),
                          style: const TextStyle(
                            fontSize: 16,
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
          ),
        ],
      ),
    );
  }

  // Az Satan Ürünler Sekmesi
  Widget _buildLeastSellingProducts(List<Sale> sales, List<Product> products) {
    Map<String, int> productSales = {};

    // Satış verilerini analiz et
    for (var sale in sales) {
      for (var item in sale.items) {
        final product = products.firstWhere(
          (p) => p.id == item.productId,
          orElse: () => Product(
            id: item.productId,
            barcode: '',
            name: item.productName,
            salePrice: 0,
            stock: 0,
            category: 'Diğer',
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
        );

        productSales[product.name] =
            (productSales[product.name] ?? 0) + item.quantity;
      }
    }

    // Tüm ürünleri al (satışı olmayan ürünler de dahil)
    for (var product in products) {
      productSales[product.name] = productSales[product.name] ?? 0;
    }

    // Sıralama: En az satandan en çoğa
    final sortedProducts = productSales.entries.toList()
      ..sort((a, b) => a.value.compareTo(b.value));

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Grafik
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'En Az Satan Ürünler (İlk 10)',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    height: 300,
                    child: SfCartesianChart(
                      primaryXAxis: const CategoryAxis(
                        labelRotation: 45,
                        maximumLabelWidth: 80,
                      ),
                      primaryYAxis: const NumericAxis(),
                      tooltipBehavior: TooltipBehavior(enable: true),
                      series: <CartesianSeries>[
                        ColumnSeries<MapEntry<String, int>, String>(
                          dataSource: sortedProducts.take(10).toList(),
                          xValueMapper: (entry, _) => entry.key.length > 12
                              ? '${entry.key.substring(0, 12)}...'
                              : entry.key,
                          yValueMapper: (entry, _) => entry.value,
                          name: 'Satış Adedi',
                          color: Colors.red,
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

          // Liste
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Detaylı Liste',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      Text(
                        'Toplam ${sortedProducts.length} ürün',
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: sortedProducts.length,
                    itemBuilder: (context, index) {
                      final entry = sortedProducts[index];
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor:
                              entry.value == 0 ? Colors.red : Colors.orange,
                          child: Text(
                            '${index + 1}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        title: Text(
                          entry.key,
                          style: const TextStyle(fontWeight: FontWeight.w500),
                        ),
                        subtitle: Text(entry.value == 0
                            ? 'Hiç satılmamış'
                            : 'Düşük satış'),
                        trailing: Text(
                          '${entry.value} adet',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color:
                                entry.value == 0 ? Colors.red : Colors.orange,
                          ),
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
  }

  // Ölü Stok Analizi Sekmesi
  Widget _buildDeadStockAnalysis(List<Sale> sales, List<Product> products) {
    Map<String, DateTime?> lastSaleDate = {};
    Map<String, int> productSales = {};

    // Son satış tarihlerini bul
    for (var sale in sales) {
      for (var item in sale.items) {
        final product = products.firstWhere(
          (p) => p.id == item.productId,
          orElse: () => Product(
            id: item.productId,
            barcode: '',
            name: item.productName,
            salePrice: 0,
            stock: 0,
            category: 'Diğer',
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
        );

        if (lastSaleDate[product.name] == null ||
            sale.createdAt.isAfter(lastSaleDate[product.name]!)) {
          lastSaleDate[product.name] = sale.createdAt;
        }
        productSales[product.name] =
            (productSales[product.name] ?? 0) + item.quantity;
      }
    }

    // Ölü stok kriterini belirle (30 gün)
    final now = DateTime.now();
    final deadStockThreshold = now.subtract(const Duration(days: 30));

    List<Map<String, dynamic>> deadStockProducts = [];

    for (var product in products) {
      final lastSale = lastSaleDate[product.name];
      final totalSales = productSales[product.name] ?? 0;

      bool isDeadStock = false;
      String reason = '';

      if (lastSale == null) {
        isDeadStock = true;
        reason = 'Hiç satılmamış';
      } else if (lastSale.isBefore(deadStockThreshold)) {
        isDeadStock = true;
        final daysSinceLastSale = now.difference(lastSale).inDays;
        reason = '$daysSinceLastSale gün önce satıldı';
      }

      if (isDeadStock) {
        deadStockProducts.add({
          'name': product.name,
          'lastSale': lastSale,
          'totalSales': totalSales,
          'stock': product.stock,
          'reason': reason,
          'daysSinceLastSale':
              lastSale != null ? now.difference(lastSale).inDays : null,
        });
      }
    }

    // Sıralama: En uzun süredir satılmayandan başla
    deadStockProducts.sort((a, b) {
      if (a['lastSale'] == null && b['lastSale'] == null) return 0;
      if (a['lastSale'] == null) return -1;
      if (b['lastSale'] == null) return 1;
      return (a['lastSale'] as DateTime).compareTo(b['lastSale'] as DateTime);
    });

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Özet kartları
          Row(
            children: [
              Expanded(
                child: _buildSummaryCard(
                  'Ölü Stok',
                  '${deadStockProducts.length}',
                  Icons.inventory_2,
                  Colors.red,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildSummaryCard(
                  'Aktif Ürün',
                  '${products.length - deadStockProducts.length}',
                  Icons.trending_up,
                  Colors.green,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Liste
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Ölü Stok Ürünleri',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  if (deadStockProducts.isEmpty)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.all(32),
                        child: Column(
                          children: [
                            Icon(Icons.check_circle,
                                size: 64, color: Colors.green),
                            SizedBox(height: 16),
                            Text(
                              'Harika! Ölü stokunuz yok',
                              style: TextStyle(
                                  fontSize: 16, fontWeight: FontWeight.w500),
                            ),
                            Text(
                              'Tüm ürünleriniz son 30 gün içinde satılmış',
                              style: TextStyle(color: Colors.grey),
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: deadStockProducts.length,
                      itemBuilder: (context, index) {
                        final product = deadStockProducts[index];
                        return ListTile(
                          leading: CircleAvatar(
                            backgroundColor: product['lastSale'] == null
                                ? Colors.red
                                : Colors.orange,
                            child: Icon(
                              product['lastSale'] == null
                                  ? Icons.block
                                  : Icons.schedule,
                              color: Colors.white,
                            ),
                          ),
                          title: Text(
                            product['name'],
                            style: const TextStyle(fontWeight: FontWeight.w500),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(product['reason']),
                              Text('Stok: ${product['stock']} adet'),
                            ],
                          ),
                          trailing: Text(
                            'Toplam satış:\n${product['totalSales']} adet',
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontSize: 12),
                          ),
                          isThreeLine: true,
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
  }

  // Saat Bazlı Satış Analizi Sekmesi
  Widget _buildHourlySalesAnalysis(List<Sale> sales) {
    Map<int, int> hourlySales = {};
    Map<int, double> hourlyRevenue = {};

    // 24 saati başlat
    for (int i = 0; i < 24; i++) {
      hourlySales[i] = 0;
      hourlyRevenue[i] = 0;
    }

    // Satış verilerini analiz et
    for (var sale in sales) {
      final hour = sale.createdAt.hour;
      hourlySales[hour] = hourlySales[hour]! + 1;
      hourlyRevenue[hour] = hourlyRevenue[hour]! + sale.finalAmount;
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Satış sayısı grafiği
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Saat Bazlı Satış Sayısı',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    height: 300,
                    child: SfCartesianChart(
                      primaryXAxis: const NumericAxis(
                        minimum: 0,
                        maximum: 23,
                        interval: 2,
                      ),
                      primaryYAxis: const NumericAxis(),
                      tooltipBehavior: TooltipBehavior(enable: true),
                      series: <CartesianSeries>[
                        LineSeries<MapEntry<int, int>, int>(
                          dataSource: hourlySales.entries.toList(),
                          xValueMapper: (entry, _) => entry.key,
                          yValueMapper: (entry, _) => entry.value,
                          name: 'Satış Sayısı',
                          color: Colors.blue,
                          markerSettings: const MarkerSettings(isVisible: true),
                          width: 3,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Ciro grafiği
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Saat Bazlı Ciro',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    height: 300,
                    child: SfCartesianChart(
                      primaryXAxis: const NumericAxis(
                        minimum: 0,
                        maximum: 23,
                        interval: 2,
                      ),
                      primaryYAxis: NumericAxis(
                        numberFormat: NumberFormat.currency(
                          locale: 'tr_TR',
                          symbol: '₺',
                          decimalDigits: 0,
                        ),
                      ),
                      tooltipBehavior: TooltipBehavior(enable: true),
                      series: <CartesianSeries>[
                        AreaSeries<MapEntry<int, double>, int>(
                          dataSource: hourlyRevenue.entries.toList(),
                          xValueMapper: (entry, _) => entry.key,
                          yValueMapper: (entry, _) => entry.value,
                          name: 'Ciro',
                          color: Colors.green.withOpacity(0.3),
                          borderColor: Colors.green,
                          borderWidth: 2,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // En yoğun saatler
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'En Yoğun Saatler',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  ...(() {
                    final sortedHours = hourlySales.entries
                        .where((entry) => entry.value > 0)
                        .toList()
                      ..sort((a, b) => b.value.compareTo(a.value));

                    return sortedHours.take(5).map((entry) => ListTile(
                          leading: CircleAvatar(
                            backgroundColor: Colors.blue,
                            child: Text(
                              '${entry.key}',
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold),
                            ),
                          ),
                          title: Text('${entry.key}:00 - ${entry.key + 1}:00'),
                          trailing: Text(
                            '${entry.value} satış',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ));
                  })(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Ödeme Yöntemi Analizi Sekmesi
  Widget _buildPaymentMethodAnalysis(List<Sale> sales) {
    Map<String, int> paymentCounts = {};
    Map<String, double> paymentRevenue = {};

    // Payment method'ları string'e çevir
    final paymentNames = {
      'cash': 'Nakit',
      'creditCard': 'Kredi Kartı',
      'debit': 'Banka Kartı',
      'installment': 'Taksit',
    };

    // Başlangıç değerleri
    for (var method in paymentNames.values) {
      paymentCounts[method] = 0;
      paymentRevenue[method] = 0;
    }

    // Satış verilerini analiz et
    for (var sale in sales) {
      final methodName = paymentNames[sale.paymentMethod.name] ?? 'Diğer';
      paymentCounts[methodName] = paymentCounts[methodName]! + 1;
      paymentRevenue[methodName] =
          paymentRevenue[methodName]! + sale.finalAmount;
    }

    // Sıfır olmayan değerleri filtrele
    final activePayments =
        paymentCounts.entries.where((e) => e.value > 0).toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Ödeme sayısı pasta grafiği
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Ödeme Yöntemi Dağılımı (Adet)',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
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
                          dataSource: activePayments,
                          xValueMapper: (entry, _) => entry.key,
                          yValueMapper: (entry, _) => entry.value,
                          dataLabelSettings: const DataLabelSettings(
                            isVisible: true,
                            labelPosition: ChartDataLabelPosition.outside,
                          ),
                          explode: true,
                          explodeIndex: 0,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Ödeme cirosu pasta grafiği
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Ödeme Yöntemi Dağılımı (Ciro)',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
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
                        DoughnutSeries<MapEntry<String, double>, String>(
                          dataSource: paymentRevenue.entries
                              .where((e) => e.value > 0)
                              .toList(),
                          xValueMapper: (entry, _) => entry.key,
                          yValueMapper: (entry, _) => entry.value,
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
          const SizedBox(height: 16),

          // Detaylı liste
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Detaylı Ödeme Analizi',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  ...activePayments.map((entry) {
                    final revenue = paymentRevenue[entry.key] ?? 0;
                    final percentage = sales.isNotEmpty
                        ? (entry.value / sales.length * 100)
                        : 0;

                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: entry.key == 'Nakit'
                            ? Colors.green
                            : entry.key == 'Kredi Kartı'
                                ? Colors.blue
                                : Colors.orange,
                        child: Icon(
                          entry.key == 'Nakit'
                              ? Icons.money
                              : Icons.credit_card,
                          color: Colors.white,
                        ),
                      ),
                      title: Text(
                        entry.key,
                        style: const TextStyle(fontWeight: FontWeight.w500),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                              '${entry.value} işlem (%${percentage.toStringAsFixed(1)})'),
                          Text(_currencyFormat.format(revenue)),
                        ],
                      ),
                      isThreeLine: true,
                    );
                  }),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Tarih aralığı seçici widget'ı
  Widget _buildDateRangeSelector() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        border: Border(bottom: BorderSide(color: Colors.grey.shade300)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Icon(Icons.filter_list, color: Colors.blue),
              const SizedBox(width: 8),
              const Text(
                'Tarih Filtresi:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              DropdownButton<String>(
                value: _selectedDateFilter,
                items: const [
                  DropdownMenuItem(value: 'Tümü', child: Text('Tümü')),
                  DropdownMenuItem(value: 'Bugün', child: Text('Bugün')),
                  DropdownMenuItem(value: 'Bu Hafta', child: Text('Bu Hafta')),
                  DropdownMenuItem(value: 'Bu Ay', child: Text('Bu Ay')),
                  DropdownMenuItem(
                      value: 'Özel Aralık', child: Text('Özel Aralık')),
                ],
                onChanged: (value) {
                  setState(() {
                    _selectedDateFilter = value!;
                    if (value != 'Özel Aralık') {
                      _salesDateRange = null;
                    }
                  });
                },
              ),
            ],
          ),
          if (_selectedDateFilter == 'Özel Aralık') ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _selectSalesDateRange,
                    icon: const Icon(Icons.date_range),
                    label: Text(
                      _salesDateRange == null
                          ? 'Tarih Aralığı Seç'
                          : '${DateFormat('dd.MM.yyyy').format(_salesDateRange!.start)} - ${DateFormat('dd.MM.yyyy').format(_salesDateRange!.end)}',
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
                if (_salesDateRange != null) ...[
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: () {
                      setState(() {
                        _salesDateRange = null;
                      });
                    },
                    icon: const Icon(Icons.clear),
                    tooltip: 'Temizle',
                  ),
                ],
              ],
            ),
          ],
        ],
      ),
    );
  }

  // Tarih aralığı seçme
  Future<void> _selectSalesDateRange() async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: _salesDateRange,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _salesDateRange = picked;
      });
    }
  }

  // Satışları tarih aralığına göre filtrele
  List<Sale> _filterSalesByDateRange(List<Sale> sales) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    switch (_selectedDateFilter) {
      case 'Bugün':
        final tomorrow = today.add(const Duration(days: 1));
        return sales.where((sale) {
          return sale.createdAt
                  .isAfter(today.subtract(const Duration(milliseconds: 1))) &&
              sale.createdAt.isBefore(tomorrow);
        }).toList();

      case 'Bu Hafta':
        final weekStart = today.subtract(Duration(days: today.weekday - 1));
        final weekEnd = weekStart.add(const Duration(days: 7));
        return sales.where((sale) {
          return sale.createdAt.isAfter(
                  weekStart.subtract(const Duration(milliseconds: 1))) &&
              sale.createdAt.isBefore(weekEnd);
        }).toList();

      case 'Bu Ay':
        final monthStart = DateTime(now.year, now.month, 1);
        final monthEnd = DateTime(now.year, now.month + 1, 1);
        return sales.where((sale) {
          return sale.createdAt.isAfter(
                  monthStart.subtract(const Duration(milliseconds: 1))) &&
              sale.createdAt.isBefore(monthEnd);
        }).toList();

      case 'Özel Aralık':
        if (_salesDateRange == null) return sales;
        final startDate = DateTime(
          _salesDateRange!.start.year,
          _salesDateRange!.start.month,
          _salesDateRange!.start.day,
        );
        final endDate = DateTime(
          _salesDateRange!.end.year,
          _salesDateRange!.end.month,
          _salesDateRange!.end.day,
          23,
          59,
          59,
        );
        return sales.where((sale) {
          return sale.createdAt.isAfter(
                  startDate.subtract(const Duration(milliseconds: 1))) &&
              sale.createdAt
                  .isBefore(endDate.add(const Duration(milliseconds: 1)));
        }).toList();

      default: // 'Tümü'
        return sales;
    }
  }
}
