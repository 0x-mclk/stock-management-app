import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../models/product.dart';
import '../providers/realtime_product_provider.dart';
import '../providers/sales_provider.dart';

class ProductAnalysisScreen extends StatefulWidget {
  const ProductAnalysisScreen({super.key});

  @override
  State<ProductAnalysisScreen> createState() => _ProductAnalysisScreenState();
}

class _ProductAnalysisScreenState extends State<ProductAnalysisScreen>
    with TickerProviderStateMixin {
  MobileScannerController cameraController = MobileScannerController();
  bool _isScanning = false;
  bool _showSearchInput = false;
  Product? _selectedProduct;
  Map<String, dynamic>? _productAnalysis;
  late TabController _tabController;

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
  }

  @override
  void dispose() {
    cameraController.dispose();
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (!_isScanning) return;

    final List<Barcode> barcodes = capture.barcodes;
    if (barcodes.isNotEmpty) {
      final String barcode = barcodes.first.displayValue ?? '';
      _searchProductByBarcode(barcode);
    }
  }

  void _searchProductByBarcode(String barcode) {
    final realtimeProductProvider = context.read<RealtimeProductProvider>();
    final product = realtimeProductProvider.products.firstWhere(
      (p) => p.barcode == barcode,
      orElse: () => Product(
        barcode: barcode,
        name: 'Ürün bulunamadı',
        salePrice: 0,
        stock: 0,
        storeId: 'unknown', // ✅ Default store ID for missing products
      ),
    );

    if (product.id != null) {
      setState(() {
        _selectedProduct = product;
        _isScanning = false;
      });
      _analyzeProduct(product);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Barkod "$barcode" ile ürün bulunamadı'),
          backgroundColor: Colors.red,
        ),
      );
      setState(() {
        _isScanning = false;
      });
    }
  }

  void _searchProducts(String query) {
    if (query.isEmpty) {
      setState(() {
        _filteredProducts = [];
      });
      return;
    }

    final realtimeProductProvider = context.read<RealtimeProductProvider>();
    setState(() {
      _filteredProducts = realtimeProductProvider.products
          .where((product) =>
              product.name.toLowerCase().contains(query.toLowerCase()) ||
              product.barcode.contains(query))
          .toList();
    });
  }

  void _selectProduct(Product product) {
    setState(() {
      _selectedProduct = product;
      _showSearchInput = false;
      _filteredProducts = [];
      _searchController.clear();
    });
    _analyzeProduct(product);
  }

  void _analyzeProduct(Product product) {
    final salesProvider = context.read<SalesProvider>();
    final sales = salesProvider.sales;

    // Ürünün satış verilerini analiz et
    final productSales = sales
        .where((sale) => sale.items.any((item) => item.productId == product.id))
        .toList();

    final now = DateTime.now();
    final last30Days = now.subtract(const Duration(days: 30));
    final last7Days = now.subtract(const Duration(days: 7));
    final today = DateTime(now.year, now.month, now.day);

    // Satış miktarları
    int totalSold = 0;
    int soldLast30Days = 0;
    int soldLast7Days = 0;
    int soldToday = 0;
    double totalRevenue = 0;
    double revenueLast30Days = 0;

    for (var sale in productSales) {
      for (var item in sale.items) {
        if (item.productId == product.id) {
          totalSold += item.quantity;
          totalRevenue += item.unitPrice * item.quantity;

          if (sale.createdAt.isAfter(last30Days)) {
            soldLast30Days += item.quantity;
            revenueLast30Days += item.unitPrice * item.quantity;
          }

          if (sale.createdAt.isAfter(last7Days)) {
            soldLast7Days += item.quantity;
          }

          if (sale.createdAt.isAfter(today)) {
            soldToday += item.quantity;
          }
        }
      }
    }

    // Hareket hızı hesaplamaları
    double velocityDaily = soldLast30Days / 30.0;
    double velocityWeekly = soldLast7Days / 7.0;

    // Stok yeterlilik süresi
    int stockDuration =
        velocityDaily > 0 ? (product.stock / velocityDaily).ceil() : -1;

    // Satış trendi (son 7 gün vs önceki 7 gün karşılaştırması)
    final previous7Days = now.subtract(const Duration(days: 14));
    final previous7DaysEnd = now.subtract(const Duration(days: 7));

    int soldPrevious7Days = 0;
    for (var sale in productSales) {
      if (sale.createdAt.isAfter(previous7Days) &&
          sale.createdAt.isBefore(previous7DaysEnd)) {
        for (var item in sale.items) {
          if (item.productId == product.id) {
            soldPrevious7Days += item.quantity;
          }
        }
      }
    }

    double trendPercentage = soldPrevious7Days > 0
        ? ((soldLast7Days - soldPrevious7Days) / soldPrevious7Days * 100)
        : (soldLast7Days > 0 ? 100 : 0);

    setState(() {
      _productAnalysis = {
        'totalSold': totalSold,
        'soldLast30Days': soldLast30Days,
        'soldLast7Days': soldLast7Days,
        'soldToday': soldToday,
        'totalRevenue': totalRevenue,
        'revenueLast30Days': revenueLast30Days,
        'velocityDaily': velocityDaily,
        'velocityWeekly': velocityWeekly,
        'stockDuration': stockDuration,
        'trendPercentage': trendPercentage,
        'isPositiveTrend': trendPercentage >= 0,
      };
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Ürün Analizi'),
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.qr_code_scanner),
            onPressed: () {
              setState(() {
                _isScanning = true;
                _showSearchInput = false;
              });
            },
          ),
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () {
              setState(() {
                _showSearchInput = !_showSearchInput;
                _isScanning = false;
              });
            },
          ),
        ],
      ),
      body: Column(
        children: [
          if (_showSearchInput) _buildSearchInput(),
          if (_isScanning) _buildQRScanner(),
          if (_selectedProduct != null && !_isScanning) _buildAnalysisContent(),
          if (_selectedProduct == null && !_isScanning && !_showSearchInput)
            _buildWelcomeScreen(),
        ],
      ),
    );
  }

  Widget _buildSearchInput() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          TextField(
            controller: _searchController,
            decoration: const InputDecoration(
              labelText: 'Ürün ara...',
              prefixIcon: Icon(Icons.search),
              border: OutlineInputBorder(),
            ),
            onChanged: _searchProducts,
          ),
          if (_filteredProducts.isNotEmpty)
            Container(
              height: 200,
              margin: const EdgeInsets.only(top: 8),
              child: ListView.builder(
                itemCount: _filteredProducts.length,
                itemBuilder: (context, index) {
                  final product = _filteredProducts[index];
                  return ListTile(
                    title: Text(product.name),
                    subtitle: Text('Barkod: ${product.barcode}'),
                    trailing: Text(_currencyFormat.format(product.salePrice)),
                    onTap: () => _selectProduct(product),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildQRScanner() {
    return Expanded(
      child: Stack(
        children: [
          MobileScanner(
            controller: cameraController,
            onDetect: _onDetect,
          ),
          Center(
            child: Container(
              width: 250,
              height: 250,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.white, width: 2),
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          Positioned(
            bottom: 80,
            left: 0,
            right: 0,
            child: Center(
              child: ElevatedButton(
                onPressed: () {
                  setState(() {
                    _isScanning = false;
                  });
                },
                child: const Text('İptal'),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWelcomeScreen() {
    return Expanded(
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.analytics,
              size: 80,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              'Ürün Analizi',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Analiz yapmak istediğiniz ürünü seçin',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[500],
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton.icon(
                  onPressed: () {
                    setState(() {
                      _isScanning = true;
                    });
                  },
                  icon: const Icon(Icons.qr_code_scanner),
                  label: const Text('QR Kod Tara'),
                ),
                ElevatedButton.icon(
                  onPressed: () {
                    setState(() {
                      _showSearchInput = true;
                    });
                  },
                  icon: const Icon(Icons.search),
                  label: const Text('Ürün Ara'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAnalysisContent() {
    if (_productAnalysis == null) {
      return const Expanded(
        child: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return Expanded(
      child: Column(
        children: [
          _buildProductHeader(),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildOverviewTab(),
                _buildSalesVelocityTab(),
                _buildStockAnalysisTab(),
                _buildTrendAnalysisTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProductHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).primaryColor.withValues(alpha: 0.1),
        border: Border(
          bottom: BorderSide(color: Colors.grey[300]!),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.inventory,
            size: 40,
            color: Theme.of(context).primaryColor,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _selectedProduct!.name,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  'Barkod: ${_selectedProduct!.barcode}',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                ),
                Text(
                  'Stok: ${_selectedProduct!.stock} adet',
                  style: TextStyle(
                    fontSize: 14,
                    color: _selectedProduct!.stock <= _selectedProduct!.minStock
                        ? Colors.red
                        : Colors.green,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          TabBar(
            controller: _tabController,
            isScrollable: true,
            labelColor: Theme.of(context).primaryColor,
            unselectedLabelColor: Colors.grey,
            tabs: const [
              Tab(text: 'Genel'),
              Tab(text: 'Hız'),
              Tab(text: 'Stok'),
              Tab(text: 'Trend'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildOverviewTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _buildMetricCards(),
          const SizedBox(height: 20),
          _buildSalesChart(),
        ],
      ),
    );
  }

  Widget _buildSalesVelocityTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Satış Hızı Analizi',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          _buildVelocityCards(),
          const SizedBox(height: 20),
          _buildVelocityChart(),
        ],
      ),
    );
  }

  Widget _buildStockAnalysisTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Stok Analizi',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          _buildStockCards(),
          const SizedBox(height: 20),
          _buildStockRecommendations(),
        ],
      ),
    );
  }

  Widget _buildTrendAnalysisTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Trend Analizi',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          _buildTrendCards(),
        ],
      ),
    );
  }

  Widget _buildMetricCards() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _buildMetricCard(
                'Toplam Satış',
                '${_productAnalysis!['totalSold']} adet',
                Icons.shopping_cart,
                Colors.blue,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildMetricCard(
                'Son 30 Gün',
                '${_productAnalysis!['soldLast30Days']} adet',
                Icons.calendar_month,
                Colors.green,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _buildMetricCard(
                'Toplam Ciro',
                _currencyFormat.format(_productAnalysis!['totalRevenue']),
                Icons.monetization_on,
                Colors.orange,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildMetricCard(
                'Son 30 Gün Ciro',
                _currencyFormat.format(_productAnalysis!['revenueLast30Days']),
                Icons.trending_up,
                Colors.purple,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildVelocityCards() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _buildMetricCard(
                'Günlük Ortalama',
                '${_productAnalysis!['velocityDaily'].toStringAsFixed(1)} adet/gün',
                Icons.speed,
                Colors.blue,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildMetricCard(
                'Haftalık Ortalama',
                '${_productAnalysis!['velocityWeekly'].toStringAsFixed(1)} adet/gün',
                Icons.timeline,
                Colors.green,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStockCards() {
    final stockDuration = _productAnalysis!['stockDuration'];
    String durationText =
        stockDuration == -1 ? 'Belirsiz' : '$stockDuration gün';
    Color durationColor = stockDuration == -1
        ? Colors.grey
        : stockDuration < 7
            ? Colors.red
            : stockDuration < 30
                ? Colors.orange
                : Colors.green;

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _buildMetricCard(
                'Mevcut Stok',
                '${_selectedProduct!.stock} adet',
                Icons.inventory,
                _selectedProduct!.stock <= _selectedProduct!.minStock
                    ? Colors.red
                    : Colors.green,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildMetricCard(
                'Stok Yeterlik',
                durationText,
                Icons.schedule,
                durationColor,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildTrendCards() {
    final trendPercentage = _productAnalysis!['trendPercentage'];
    final isPositiveTrend = _productAnalysis!['isPositiveTrend'];

    return _buildMetricCard(
      'Satış Trendi (7 gün)',
      '${trendPercentage.toStringAsFixed(1)}%',
      isPositiveTrend ? Icons.trending_up : Icons.trending_down,
      isPositiveTrend ? Colors.green : Colors.red,
    );
  }

  Widget _buildMetricCard(
      String title, String value, IconData icon, Color color) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
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
                fontSize: 14,
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

  Widget _buildSalesChart() {
    // Bu kısım şimdilik basit bir placeholder
    return Card(
      child: Container(
        height: 200,
        padding: const EdgeInsets.all(16),
        child: const Center(
          child: Text(
            'Satış Grafiği\n(Geliştirilecek)',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 16, color: Colors.grey),
          ),
        ),
      ),
    );
  }

  Widget _buildVelocityChart() {
    return Card(
      child: Container(
        height: 200,
        padding: const EdgeInsets.all(16),
        child: const Center(
          child: Text(
            'Hız Grafiği\n(Geliştirilecek)',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 16, color: Colors.grey),
          ),
        ),
      ),
    );
  }

  Widget _buildStockRecommendations() {
    final stockDuration = _productAnalysis!['stockDuration'];
    final velocityDaily = _productAnalysis!['velocityDaily'];

    List<String> recommendations = [];

    if (stockDuration != -1) {
      if (stockDuration < 7) {
        recommendations.add('⚠️ Stok kritik seviyede! Acil tedarik gerekli.');
      } else if (stockDuration < 30) {
        recommendations.add('⚡ Stok azalıyor, tedarik planlaması yapın.');
      } else if (stockDuration > 90) {
        recommendations.add('📦 Stok fazla, satış stratejileri geliştirin.');
      }
    }

    if (velocityDaily < 0.1) {
      recommendations
          .add('📉 Satış hızı düşük, pazarlama aksiyonları düşünün.');
    } else if (velocityDaily > 2) {
      recommendations.add('🚀 Yüksek satış hızı, stok artırımı değerlendirin.');
    }

    if (recommendations.isEmpty) {
      recommendations.add('✅ Stok durumu normal görünüyor.');
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Öneriler',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            ...recommendations.map((rec) => Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(rec, style: const TextStyle(fontSize: 14)),
                )),
          ],
        ),
      ),
    );
  }
}
