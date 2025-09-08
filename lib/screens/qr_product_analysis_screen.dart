import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:syncfusion_flutter_charts/charts.dart';
import '../models/product.dart';
import '../models/sale.dart';
import '../providers/product_provider.dart';
import '../providers/sales_provider.dart';

class QRProductAnalysisScreen extends StatefulWidget {
  final Product? preSelectedProduct;

  const QRProductAnalysisScreen({super.key, this.preSelectedProduct});

  @override
  State<QRProductAnalysisScreen> createState() =>
      _QRProductAnalysisScreenState();
}

class _QRProductAnalysisScreenState extends State<QRProductAnalysisScreen>
    with TickerProviderStateMixin {
  MobileScannerController cameraController = MobileScannerController();
  bool _isScanning = false;
  bool _showSearchInput = false;
  bool _showSelectionScreen = true;
  Product? _scannedProduct;
  Map<String, dynamic>? _productAnalysis;
  late TabController _tabController;
  DateTimeRange? _customDateRange;

  final TextEditingController _searchController = TextEditingController();
  List<Product> _filteredProducts = [];

  final _currencyFormat = NumberFormat.currency(
    locale: 'tr_TR',
    symbol: '₺',
    decimalDigits: 2,
  );

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);

    // If a product is pre-selected, skip selection screen and show analysis
    if (widget.preSelectedProduct != null) {
      _showSelectionScreen = false;
      _scannedProduct = widget.preSelectedProduct;
      _generateAnalysis();
    }
  }

  @override
  void dispose() {
    cameraController.dispose();
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  // Generate analysis for pre-selected product
  void _generateAnalysis() {
    if (_scannedProduct == null) return;

    final salesProvider = Provider.of<SalesProvider>(context, listen: false);
    setState(() {
      _productAnalysis = _analyzeProduct(_scannedProduct!, salesProvider.sales);
    });
  }

  void _onDetect(BarcodeCapture capture) {
    if (!_isScanning) return;

    final List<Barcode> barcodes = capture.barcodes;
    if (barcodes.isNotEmpty) {
      final barcode = barcodes.first.rawValue;
      if (barcode != null && barcode.isNotEmpty) {
        _findProductByBarcode(barcode);
      }
    }
  }

  void _findProductByBarcode(String barcode) {
    final productProvider =
        Provider.of<ProductProvider>(context, listen: false);
    final salesProvider = Provider.of<SalesProvider>(context, listen: false);

    try {
      final product = productProvider.products.firstWhere(
        (p) => p.barcode.toLowerCase() == barcode.toLowerCase(),
      );

      setState(() {
        _isScanning = false;
        _showSelectionScreen = false;
        _showSearchInput = false;
        _scannedProduct = product;
        _productAnalysis = _analyzeProduct(product, salesProvider.sales);
      });

      cameraController.stop();
    } catch (e) {
      // Ürün bulunamadı
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Barkod "$barcode" ile eşleşen ürün bulunamadı'),
          backgroundColor: Colors.red,
          action: SnackBarAction(
            label: 'Tekrar Tara',
            textColor: Colors.white,
            onPressed: () {
              setState(() {
                _isScanning = true;
              });
              cameraController.start();
            },
          ),
        ),
      );
    }
  }

  void _searchProducts(String query) {
    if (query.isEmpty) {
      setState(() {
        _filteredProducts = [];
      });
      return;
    }

    final productProvider =
        Provider.of<ProductProvider>(context, listen: false);
    setState(() {
      _filteredProducts = productProvider.products
          .where((product) =>
              product.name.toLowerCase().contains(query.toLowerCase()) ||
              product.barcode.contains(query))
          .toList();
    });
  }

  void _selectProduct(Product product) {
    final salesProvider = Provider.of<SalesProvider>(context, listen: false);

    setState(() {
      _scannedProduct = product;
      _showSelectionScreen = false;
      _showSearchInput = false;
      _filteredProducts = [];
      _searchController.clear();
      _productAnalysis = _analyzeProduct(product, salesProvider.sales);
    });
  }

  void _startQRScanning() {
    setState(() {
      _isScanning = true;
      _showSelectionScreen = false;
      _showSearchInput = false;
    });
    cameraController.start();
  }

  void _startProductSearch() {
    setState(() {
      _showSearchInput = true;
      _showSelectionScreen = false;
      _isScanning = false;
    });
  }

  void _backToSelection() {
    setState(() {
      _showSelectionScreen = true;
      _showSearchInput = false;
      _isScanning = false;
      _scannedProduct = null;
      _productAnalysis = null;
      _filteredProducts = [];
      _searchController.clear();
    });
    cameraController.stop();
  }

  Map<String, dynamic> _analyzeProduct(Product product, List<Sale> sales) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final weekAgo = today.subtract(const Duration(days: 7));
    final monthAgo = DateTime(now.year, now.month - 1, now.day);

    Map<String, int> dailySales = {};
    Map<String, int> weeklySales = {};
    Map<String, int> monthlySales = {};
    Map<String, int> customRangeSales = {};

    int todaySales = 0;
    int weekSales = 0;
    int monthSales = 0;
    int customSales = 0;
    double totalRevenue = 0;
    int totalQuantity = 0;

    for (var sale in sales) {
      for (var item in sale.items) {
        if (item.productName == product.name) {
          final saleDate = DateTime(
            sale.createdAt.year,
            sale.createdAt.month,
            sale.createdAt.day,
          );

          totalQuantity += item.quantity;
          totalRevenue += item.totalPrice;

          // Günlük analiz
          if (saleDate.isAtSameMomentAs(today)) {
            todaySales += item.quantity;
          }

          // Haftalık analiz
          if (saleDate.isAfter(weekAgo) &&
              saleDate.isBefore(today.add(const Duration(days: 1)))) {
            weekSales += item.quantity;
            final weekKey = '${saleDate.day}.${saleDate.month}';
            weeklySales[weekKey] = (weeklySales[weekKey] ?? 0) + item.quantity;
          }

          // Aylık analiz
          if (saleDate.isAfter(monthAgo) &&
              saleDate.isBefore(today.add(const Duration(days: 1)))) {
            monthSales += item.quantity;
            final monthKey = '${saleDate.day}.${saleDate.month}';
            monthlySales[monthKey] =
                (monthlySales[monthKey] ?? 0) + item.quantity;
          }

          // Günlük detay
          final dayKey = DateFormat('dd.MM').format(saleDate);
          dailySales[dayKey] = (dailySales[dayKey] ?? 0) + item.quantity;

          // Özel tarih aralığı
          if (_customDateRange != null) {
            final startDate = DateTime(
              _customDateRange!.start.year,
              _customDateRange!.start.month,
              _customDateRange!.start.day,
            );
            final endDate = DateTime(
              _customDateRange!.end.year,
              _customDateRange!.end.month,
              _customDateRange!.end.day,
            );

            if (saleDate.isAfter(startDate.subtract(const Duration(days: 1))) &&
                saleDate.isBefore(endDate.add(const Duration(days: 1)))) {
              customSales += item.quantity;
              final customKey = DateFormat('dd.MM').format(saleDate);
              customRangeSales[customKey] =
                  (customRangeSales[customKey] ?? 0) + item.quantity;
            }
          }
        }
      }
    }

    return {
      'todaySales': todaySales,
      'weekSales': weekSales,
      'monthSales': monthSales,
      'customSales': customSales,
      'dailySales': dailySales,
      'weeklySales': weeklySales,
      'monthlySales': monthlySales,
      'customRangeSales': customRangeSales,
      'totalRevenue': totalRevenue,
      'totalQuantity': totalQuantity,
    };
  }

  Future<void> _selectCustomDateRange() async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: _customDateRange,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).colorScheme.copyWith(
                  primary: Colors.blue,
                ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null && picked != _customDateRange) {
      setState(() {
        _customDateRange = picked;
        if (_scannedProduct != null) {
          final salesProvider =
              Provider.of<SalesProvider>(context, listen: false);
          _productAnalysis =
              _analyzeProduct(_scannedProduct!, salesProvider.sales);
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Ürün Analizi'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        actions: [
          if (_scannedProduct != null)
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _backToSelection,
              tooltip: 'Başa Dön',
            ),
        ],
      ),
      body: _buildContent(),
    );
  }

  Widget _buildContent() {
    if (_showSelectionScreen) {
      return _buildSelectionScreen();
    } else if (_isScanning) {
      return _buildScanner();
    } else if (_showSearchInput) {
      return _buildSearchScreen();
    } else if (_scannedProduct != null) {
      return _buildAnalysis();
    } else {
      return _buildSelectionScreen();
    }
  }

  Widget _buildSelectionScreen() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.analytics,
              size: 80,
              color: Colors.blue[300],
            ),
            const SizedBox(height: 24),
            Text(
              'Ürün Analizi',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Colors.grey[700],
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Analiz yapmak istediğiniz ürünü nasıl seçmek istersiniz?',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 48),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton.icon(
                onPressed: _startQRScanning,
                icon: const Icon(Icons.qr_code_scanner, size: 28),
                label: const Text(
                  'QR Kod Tara',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                  elevation: 3,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton.icon(
                onPressed: _startProductSearch,
                icon: const Icon(Icons.search, size: 28),
                label: const Text(
                  'Ürün Ara',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  elevation: 3,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchScreen() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  labelText: 'Ürün adı veya barkod girin...',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () {
                      _searchController.clear();
                      setState(() {
                        _filteredProducts = [];
                      });
                    },
                  ),
                  border: const OutlineInputBorder(),
                ),
                onChanged: _searchProducts,
                autofocus: true,
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  TextButton.icon(
                    onPressed: _backToSelection,
                    icon: const Icon(Icons.arrow_back),
                    label: const Text('Geri'),
                  ),
                  const Spacer(),
                  TextButton.icon(
                    onPressed: _startQRScanning,
                    icon: const Icon(Icons.qr_code_scanner),
                    label: const Text('QR Tara'),
                  ),
                ],
              ),
            ],
          ),
        ),
        Expanded(
          child: _filteredProducts.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.search,
                        size: 64,
                        color: Colors.grey[400],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        _searchController.text.isEmpty
                            ? 'Ürün aramaya başlayın...'
                            : 'Ürün bulunamadı',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  itemCount: _filteredProducts.length,
                  itemBuilder: (context, index) {
                    final product = _filteredProducts[index];
                    return Card(
                      margin: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 4),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: Colors.blue[100],
                          child: Icon(
                            Icons.inventory,
                            color: Colors.blue[800],
                          ),
                        ),
                        title: Text(
                          product.name,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Barkod: ${product.barcode}'),
                            Text(
                              'Stok: ${product.stock} adet',
                              style: TextStyle(
                                color: product.stock <= product.minStock
                                    ? Colors.red
                                    : Colors.green,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                        trailing: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              _currencyFormat.format(product.salePrice),
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            const Icon(Icons.arrow_forward_ios, size: 16),
                          ],
                        ),
                        onTap: () => _selectProduct(product),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildScanner() {
    return Column(
      children: [
        Expanded(
          child: MobileScanner(
            controller: cameraController,
            onDetect: _onDetect,
          ),
        ),
        Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              const Icon(Icons.qr_code_scanner, size: 48, color: Colors.blue),
              const SizedBox(height: 16),
              const Text(
                'Ürün Barkodunu Tarayın',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                'Kamerayı ürün barkoduna yönlendirin',
                style: TextStyle(color: Colors.grey[600]),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAnalysis() {
    if (_scannedProduct == null || _productAnalysis == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return Column(
      children: [
        // Ürün Bilgileri
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          color: Colors.blue.shade50,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _scannedProduct!.name,
                style:
                    const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.qr_code, size: 16, color: Colors.grey[600]),
                  const SizedBox(width: 4),
                  Text(
                    'Barkod: ${_scannedProduct!.barcode}',
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Icon(Icons.inventory, size: 16, color: Colors.grey[600]),
                  const SizedBox(width: 4),
                  Text(
                    'Stok: ${_scannedProduct!.stock} adet',
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                  const SizedBox(width: 16),
                  Icon(Icons.sell, size: 16, color: Colors.grey[600]),
                  const SizedBox(width: 4),
                  Text(
                    'Fiyat: ${_currencyFormat.format(_scannedProduct!.salePrice)}',
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                ],
              ),
            ],
          ),
        ),

        // Tab Bar
        TabBar(
          controller: _tabController,
          isScrollable: true,
          labelColor: Colors.blue,
          unselectedLabelColor: Colors.grey,
          indicatorColor: Colors.blue,
          tabs: const [
            Tab(text: 'Günlük'),
            Tab(text: 'Haftalık'),
            Tab(text: 'Aylık'),
            Tab(text: 'Özel Tarih'),
          ],
        ),

        // Tab Views
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildDailyAnalysis(),
              _buildWeeklyAnalysis(),
              _buildMonthlyAnalysis(),
              _buildCustomRangeAnalysis(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDailyAnalysis() {
    final analysis = _productAnalysis!;
    final todaySales = analysis['todaySales'] as int;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Bugünkü Satış Kartı
          Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  const Icon(Icons.today, size: 48, color: Colors.blue),
                  const SizedBox(height: 16),
                  const Text(
                    'Bugünkü Satış',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '$todaySales adet',
                    style: const TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Gelir: ${_currencyFormat.format(todaySales * _scannedProduct!.salePrice)}',
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Son 7 Gün Grafiği
          if ((analysis['dailySales'] as Map<String, int>).isNotEmpty)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Son 7 Gün Satış Trendi',
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      height: 250,
                      child: SfCartesianChart(
                        primaryXAxis: const CategoryAxis(),
                        primaryYAxis: const NumericAxis(),
                        tooltipBehavior: TooltipBehavior(enable: true),
                        series: <CartesianSeries>[
                          LineSeries<MapEntry<String, int>, String>(
                            dataSource:
                                (analysis['dailySales'] as Map<String, int>)
                                    .entries
                                    .toList()
                                    .take(7)
                                    .toList(),
                            xValueMapper: (MapEntry<String, int> data, _) =>
                                data.key,
                            yValueMapper: (MapEntry<String, int> data, _) =>
                                data.value,
                            name: 'Satış Adedi',
                            color: Colors.blue,
                            markerSettings:
                                const MarkerSettings(isVisible: true),
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
        ],
      ),
    );
  }

  Widget _buildWeeklyAnalysis() {
    final analysis = _productAnalysis!;
    final weekSales = analysis['weekSales'] as int;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Bu Haftaki Satış Kartı
          Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  const Icon(Icons.date_range, size: 48, color: Colors.green),
                  const SizedBox(height: 16),
                  const Text(
                    'Bu Haftaki Satış',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '$weekSales adet',
                    style: const TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: Colors.green),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Gelir: ${_currencyFormat.format(weekSales * _scannedProduct!.salePrice)}',
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Haftalık Detay Grafiği
          if ((analysis['weeklySales'] as Map<String, int>).isNotEmpty)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Haftalık Satış Detayı',
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      height: 250,
                      child: SfCartesianChart(
                        primaryXAxis: const CategoryAxis(),
                        primaryYAxis: const NumericAxis(),
                        tooltipBehavior: TooltipBehavior(enable: true),
                        series: <CartesianSeries>[
                          ColumnSeries<MapEntry<String, int>, String>(
                            dataSource:
                                (analysis['weeklySales'] as Map<String, int>)
                                    .entries
                                    .toList(),
                            xValueMapper: (MapEntry<String, int> data, _) =>
                                data.key,
                            yValueMapper: (MapEntry<String, int> data, _) =>
                                data.value,
                            name: 'Satış Adedi',
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
        ],
      ),
    );
  }

  Widget _buildMonthlyAnalysis() {
    final analysis = _productAnalysis!;
    final monthSales = analysis['monthSales'] as int;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Bu Ayki Satış Kartı
          Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  const Icon(Icons.calendar_month,
                      size: 48, color: Colors.orange),
                  const SizedBox(height: 16),
                  const Text(
                    'Bu Ayki Satış',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '$monthSales adet',
                    style: const TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: Colors.orange),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Gelir: ${_currencyFormat.format(monthSales * _scannedProduct!.salePrice)}',
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Aylık Detay Grafiği
          if ((analysis['monthlySales'] as Map<String, int>).isNotEmpty)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Aylık Satış Detayı',
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      height: 250,
                      child: SfCartesianChart(
                        primaryXAxis: const CategoryAxis(),
                        primaryYAxis: const NumericAxis(),
                        tooltipBehavior: TooltipBehavior(enable: true),
                        series: <CartesianSeries>[
                          ColumnSeries<MapEntry<String, int>, String>(
                            dataSource:
                                (analysis['monthlySales'] as Map<String, int>)
                                    .entries
                                    .toList(),
                            xValueMapper: (MapEntry<String, int> data, _) =>
                                data.key,
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

          // Toplam İstatistikler
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Genel İstatistikler',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: _buildStatCard(
                          'Toplam Satış',
                          '${analysis['totalQuantity']} adet',
                          Icons.shopping_cart,
                          Colors.blue,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildStatCard(
                          'Toplam Gelir',
                          _currencyFormat.format(analysis['totalRevenue']),
                          Icons.monetization_on,
                          Colors.green,
                        ),
                      ),
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

  Widget _buildCustomRangeAnalysis() {
    final analysis = _productAnalysis!;
    final customSales = analysis['customSales'] as int;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Tarih Seçici
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  const Text(
                    'Özel Tarih Aralığı Seçin',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: _selectCustomDateRange,
                    icon: const Icon(Icons.date_range),
                    label: Text(
                      _customDateRange == null
                          ? 'Tarih Aralığı Seç'
                          : '${DateFormat('dd.MM.yyyy').format(_customDateRange!.start)} - ${DateFormat('dd.MM.yyyy').format(_customDateRange!.end)}',
                    ),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 24, vertical: 12),
                    ),
                  ),
                ],
              ),
            ),
          ),

          if (_customDateRange != null) ...[
            const SizedBox(height: 16),

            // Özel Tarih Aralığı Satış Kartı
            Card(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    const Icon(Icons.analytics, size: 48, color: Colors.purple),
                    const SizedBox(height: 16),
                    const Text(
                      'Seçili Dönem Satışı',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '$customSales adet',
                      style: const TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          color: Colors.purple),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Gelir: ${_currencyFormat.format(customSales * _scannedProduct!.salePrice)}',
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Özel Tarih Aralığı Grafiği
            if ((analysis['customRangeSales'] as Map<String, int>).isNotEmpty)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Seçili Dönem Detayı (${DateFormat('dd.MM.yyyy').format(_customDateRange!.start)} - ${DateFormat('dd.MM.yyyy').format(_customDateRange!.end)})',
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        height: 250,
                        child: SfCartesianChart(
                          primaryXAxis: const CategoryAxis(),
                          primaryYAxis: const NumericAxis(),
                          tooltipBehavior: TooltipBehavior(enable: true),
                          series: <CartesianSeries>[
                            ColumnSeries<MapEntry<String, int>, String>(
                              dataSource: (analysis['customRangeSales']
                                      as Map<String, int>)
                                  .entries
                                  .toList(),
                              xValueMapper: (MapEntry<String, int> data, _) =>
                                  data.key,
                              yValueMapper: (MapEntry<String, int> data, _) =>
                                  data.value,
                              name: 'Satış Adedi',
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
          ],

          if (_customDateRange == null)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  children: [
                    Icon(Icons.calendar_today,
                        size: 64, color: Colors.grey[400]),
                    const SizedBox(height: 16),
                    Text(
                      'Tarih Aralığı Seçin',
                      style: TextStyle(fontSize: 18, color: Colors.grey[600]),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Belirli bir dönemdeki satış verilerini görmek için tarih aralığı seçin',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey[500]),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildStatCard(
      String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, size: 32, color: color),
          const SizedBox(height: 8),
          Text(
            title,
            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
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
    );
  }
}
