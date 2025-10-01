import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:syncfusion_flutter_charts/charts.dart';
import '../models/product.dart';
import '../models/sale.dart';
import '../providers/realtime_product_provider.dart';
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

  // Grafik türü seçimi için state
  String _selectedAnalysisType = 'sales'; // 'sales', 'revenue', 'profit'

  // Aylık analiz için seçili ay
  int _selectedMonth = DateTime.now().month;
  int _selectedYear = DateTime.now().year;

  // Günlük analiz için seçili tarih
  DateTime _selectedDate = DateTime.now();

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
    final realtimeProductProvider =
        Provider.of<RealtimeProductProvider>(context, listen: false);
    final salesProvider = Provider.of<SalesProvider>(context, listen: false);

    try {
      final product = realtimeProductProvider.products.firstWhere(
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

    final realtimeProductProvider =
        Provider.of<RealtimeProductProvider>(context, listen: false);
    setState(() {
      _filteredProducts = realtimeProductProvider.products
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

    // Kar hesaplamaları için
    double todayProfit = 0;
    double weekProfit = 0;
    double monthProfit = 0;
    double customProfit = 0;
    double totalProfit = 0;

    // Günlük kar verisi
    Map<String, double> dailyProfits = {};
    Map<String, double> weeklyProfits = {};
    Map<String, double> monthlyProfits = {};
    Map<String, double> customRangeProfits = {};

    // Günlük ciro verisi
    Map<String, double> dailyRevenues = {};
    Map<String, double> weeklyRevenues = {};
    Map<String, double> monthlyRevenues = {};
    Map<String, double> customRangeRevenues = {};

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

          // Kar hesaplama (Satış Fiyatı - Alış Fiyatı)
          double itemProfit =
              (product.salePrice - (product.purchasePrice ?? 0)) *
                  item.quantity;
          totalProfit += itemProfit;

          // Günlük analiz
          if (saleDate.isAtSameMomentAs(today)) {
            todaySales += item.quantity;
            todayProfit += itemProfit;
          }

          // Haftalık analiz
          if (saleDate.isAfter(weekAgo) &&
              saleDate.isBefore(today.add(const Duration(days: 1)))) {
            weekSales += item.quantity;
            weekProfit += itemProfit;
            final weekKey = '${saleDate.day}.${saleDate.month}';
            weeklySales[weekKey] = (weeklySales[weekKey] ?? 0) + item.quantity;
            weeklyProfits[weekKey] = (weeklyProfits[weekKey] ?? 0) + itemProfit;
            weeklyRevenues[weekKey] =
                (weeklyRevenues[weekKey] ?? 0) + item.totalPrice;
          }

          // Aylık analiz
          if (saleDate.isAfter(monthAgo) &&
              saleDate.isBefore(today.add(const Duration(days: 1)))) {
            monthSales += item.quantity;
            monthProfit += itemProfit;
            final monthKey = '${saleDate.day}.${saleDate.month}';
            monthlySales[monthKey] =
                (monthlySales[monthKey] ?? 0) + item.quantity;
            monthlyProfits[monthKey] =
                (monthlyProfits[monthKey] ?? 0) + itemProfit;
            monthlyRevenues[monthKey] =
                (monthlyRevenues[monthKey] ?? 0) + item.totalPrice;
          }

          // Günlük detay
          final dayKey = DateFormat('dd.MM').format(saleDate);
          dailySales[dayKey] = (dailySales[dayKey] ?? 0) + item.quantity;
          dailyProfits[dayKey] = (dailyProfits[dayKey] ?? 0) + itemProfit;
          dailyRevenues[dayKey] =
              (dailyRevenues[dayKey] ?? 0) + item.totalPrice;

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
              customProfit += itemProfit;
              final customKey = DateFormat('dd.MM').format(saleDate);
              customRangeSales[customKey] =
                  (customRangeSales[customKey] ?? 0) + item.quantity;
              customRangeProfits[customKey] =
                  (customRangeProfits[customKey] ?? 0) + itemProfit;
              customRangeRevenues[customKey] =
                  (customRangeRevenues[customKey] ?? 0) + item.totalPrice;
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
      'todayProfit': todayProfit,
      'weekProfit': weekProfit,
      'monthProfit': monthProfit,
      'customProfit': customProfit,
      'totalProfit': totalProfit,
      'dailyProfits': dailyProfits,
      'weeklyProfits': weeklyProfits,
      'monthlyProfits': monthlyProfits,
      'customRangeProfits': customRangeProfits,
      'dailyRevenues': dailyRevenues,
      'weeklyRevenues': weeklyRevenues,
      'monthlyRevenues': monthlyRevenues,
      'customRangeRevenues': customRangeRevenues,
    };
  }

  // Stok hızı hesaplama fonksiyonu
  Map<String, dynamic> _calculateStockVelocity(
      Product product, List<Sale> sales) {
    final DateTime now = DateTime.now();
    final DateTime thirtyDaysAgo = now.subtract(const Duration(days: 30));

    // Son 30 gündeki toplam satış miktarını hesapla
    int totalSalesLast30Days = 0;

    for (final sale in sales) {
      final saleDate = sale.createdAt;

      // Son 30 gün içinde mi kontrol et
      if (saleDate.isAfter(thirtyDaysAgo) &&
          saleDate.isBefore(now.add(const Duration(days: 1)))) {
        // Bu ürünün satış miktarını bul
        for (final item in sale.items) {
          if (item.productName == product.name) {
            totalSalesLast30Days += item.quantity;
          }
        }
      }
    }

    // Günlük ortalama satış hızını hesapla
    double dailySalesRate = totalSalesLast30Days / 30.0;

    // Kalan gün hesaplama
    int remainingDays = 0;
    String statusMessage = '';

    if (dailySalesRate <= 0) {
      statusMessage = 'Satış verisi yok';
      remainingDays = 0;
    } else if (product.stock <= 0) {
      statusMessage = 'Stok yok';
      remainingDays = 0;
    } else {
      remainingDays = (product.stock / dailySalesRate).floor();
      if (remainingDays <= 0) {
        statusMessage = 'Stok bitmiş';
      } else if (remainingDays <= 7) {
        statusMessage = 'Kritik seviye';
      } else if (remainingDays <= 15) {
        statusMessage = 'Dikkat';
      } else {
        statusMessage = 'Normal';
      }
    }

    return {
      'dailySalesRate': dailySalesRate,
      'remainingDays': remainingDays,
      'totalSalesLast30Days': totalSalesLast30Days,
      'statusMessage': statusMessage,
    };
  }

  // Toplam istatistikler hesaplama (ilk satıştan itibaren)
  Map<String, dynamic> _calculateTotalStatistics(
      Product product, List<Sale> sales) {
    int totalSales = 0;
    double totalRevenue = 0.0;
    double totalProfit = 0.0;
    DateTime? firstSaleDate;
    DateTime? lastSaleDate;
    Map<String, int> dailySalesHistory = {};

    for (final sale in sales) {
      final saleDate = sale.createdAt;

      for (final item in sale.items) {
        if (item.productName == product.name) {
          // İlk ve son satış tarihlerini kaydet
          if (firstSaleDate == null || saleDate.isBefore(firstSaleDate)) {
            firstSaleDate = saleDate;
          }
          if (lastSaleDate == null || saleDate.isAfter(lastSaleDate)) {
            lastSaleDate = saleDate;
          }

          // Toplam değerleri hesapla
          totalSales += item.quantity;
          totalRevenue += item.totalPrice;

          // Kar hesaplama
          final itemProfit =
              (item.unitPrice - (product.purchasePrice ?? 0.0)) * item.quantity;
          totalProfit += itemProfit;

          // Günlük satış geçmişi (trend için)
          final dayKey = DateFormat('yyyy-MM-dd').format(saleDate);
          dailySalesHistory[dayKey] =
              (dailySalesHistory[dayKey] ?? 0) + item.quantity;
        }
      }
    }

    // Satış günü sayısı
    int totalDaysWithSales = dailySalesHistory.keys.length;

    // İlk satıştan itibaren geçen toplam gün sayısı
    int totalDaysSinceFirstSale = 0;
    if (firstSaleDate != null) {
      totalDaysSinceFirstSale =
          DateTime.now().difference(firstSaleDate).inDays + 1;
    }

    return {
      'totalSales': totalSales,
      'totalRevenue': totalRevenue,
      'totalProfit': totalProfit,
      'firstSaleDate': firstSaleDate,
      'lastSaleDate': lastSaleDate,
      'totalDaysWithSales': totalDaysWithSales,
      'totalDaysSinceFirstSale': totalDaysSinceFirstSale,
      'dailySalesHistory': dailySalesHistory,
      'averageDailySales': totalDaysSinceFirstSale > 0
          ? totalSales / totalDaysSinceFirstSale
          : 0.0,
    };
  }

  // Genel trend grafiği için veri hazırlama
  List<MapEntry<String, int>> _prepareGeneralTrendData(
      Map<String, int> dailySalesHistory) {
    if (dailySalesHistory.isEmpty) return [];

    // Tarihleri sırala (eskiden yeniye)
    final sortedEntries = dailySalesHistory.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));

    // Son 30 günü al (çok fazla veri olmasın diye)
    return sortedEntries.take(30).toList();
  }

  // Seçili gün için veri hesaplama
  Map<String, dynamic> _calculateSelectedDayData(
      Map<String, dynamic> analysis) {
    final salesProvider = Provider.of<SalesProvider>(context, listen: false);

    int daySales = 0;
    double dayRevenue = 0.0;
    double dayProfit = 0.0;

    // Seçili tarih için satışları hesapla
    for (final sale in salesProvider.sales) {
      final saleDate = sale.createdAt;

      // Seçili günün başlangıç ve bitiş saatlerini al
      final selectedDayStart =
          DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day);
      final selectedDayEnd = selectedDayStart.add(const Duration(days: 1));

      if (saleDate.isAfter(selectedDayStart) &&
          saleDate.isBefore(selectedDayEnd)) {
        for (final item in sale.items) {
          if (item.productName == _scannedProduct!.name) {
            daySales += item.quantity;
            dayRevenue += item.totalPrice;

            // Kar hesaplama
            final itemProfit =
                (item.unitPrice - (_scannedProduct!.purchasePrice ?? 0.0)) *
                    item.quantity;
            dayProfit += itemProfit;
          }
        }
      }
    }

    return {
      'sales': daySales,
      'revenue': dayRevenue,
      'profit': dayProfit,
    };
  }

  // Seçili tarihe göre günlük grafik verisi hazırlama
  Map<String, dynamic> _getDailyChartDataForSelectedDate(
      Map<String, dynamic> analysis, String label) {
    final salesProvider = Provider.of<SalesProvider>(context, listen: false);
    List<MapEntry<String, int>> chartEntries = [];

    // Seçili tarihten geriye doğru 7 gün için veri hazırla
    for (int i = 6; i >= 0; i--) {
      final date = _selectedDate.subtract(Duration(days: i));
      final dateKey = DateFormat('dd.MM').format(date);

      // O günün satışlarını hesapla
      int daySales = 0;
      for (final sale in salesProvider.sales) {
        final saleDate = sale.createdAt;
        final saleDateStart =
            DateTime(saleDate.year, saleDate.month, saleDate.day);
        final targetDateStart = DateTime(date.year, date.month, date.day);

        if (saleDateStart.isAtSameMomentAs(targetDateStart)) {
          for (final item in sale.items) {
            if (item.productName == _scannedProduct!.name) {
              daySales += item.quantity;
            }
          }
        }
      }

      chartEntries.add(MapEntry(dateKey, daySales));
    }

    return {
      'data': chartEntries,
      'label': label,
    };
  }

  // Seçili tarihe göre günlük ciro grafiği verisi hazırlama
  Map<String, dynamic> _getDailyRevenueChartDataForSelectedDate(
      Map<String, dynamic> analysis, String label) {
    final salesProvider = Provider.of<SalesProvider>(context, listen: false);
    List<MapEntry<String, double>> chartEntries = [];

    // Seçili tarihten geriye doğru 7 gün için veri hazırla
    for (int i = 6; i >= 0; i--) {
      final date = _selectedDate.subtract(Duration(days: i));
      final dateKey = DateFormat('dd.MM').format(date);

      // O günün cirosunu hesapla
      double dayRevenue = 0.0;
      for (final sale in salesProvider.sales) {
        final saleDate = sale.createdAt;
        final saleDateStart =
            DateTime(saleDate.year, saleDate.month, saleDate.day);
        final targetDateStart = DateTime(date.year, date.month, date.day);

        if (saleDateStart.isAtSameMomentAs(targetDateStart)) {
          for (final item in sale.items) {
            if (item.productName == _scannedProduct!.name) {
              dayRevenue += item.totalPrice;
            }
          }
        }
      }

      chartEntries.add(MapEntry(dateKey, dayRevenue));
    }

    return {
      'data': chartEntries,
      'label': label,
    };
  }

  // Seçili tarihe göre günlük kar grafiği verisi hazırlama
  Map<String, dynamic> _getDailyProfitChartDataForSelectedDate(
      Map<String, dynamic> analysis, String label) {
    final salesProvider = Provider.of<SalesProvider>(context, listen: false);
    List<MapEntry<String, double>> chartEntries = [];

    // Seçili tarihten geriye doğru 7 gün için veri hazırla
    for (int i = 6; i >= 0; i--) {
      final date = _selectedDate.subtract(Duration(days: i));
      final dateKey = DateFormat('dd.MM').format(date);

      // O günün karını hesapla
      double dayProfit = 0.0;
      for (final sale in salesProvider.sales) {
        final saleDate = sale.createdAt;
        final saleDateStart =
            DateTime(saleDate.year, saleDate.month, saleDate.day);
        final targetDateStart = DateTime(date.year, date.month, date.day);

        if (saleDateStart.isAtSameMomentAs(targetDateStart)) {
          for (final item in sale.items) {
            if (item.productName == _scannedProduct!.name) {
              final itemProfit =
                  (item.unitPrice - (_scannedProduct!.purchasePrice ?? 0.0)) *
                      item.quantity;
              dayProfit += itemProfit;
            }
          }
        }
      }

      chartEntries.add(MapEntry(dateKey, dayProfit));
    }

    return {
      'data': chartEntries,
      'label': label,
    };
  }

  // Tarih seçici dialog
  Future<void> _selectDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      locale: const Locale('tr', 'TR'),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
          ),
          child: child!,
        );
      },
    );

    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
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
        title: const Text('Ürün analizi'),
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
                  Expanded(
                    flex: 2,
                    child: Text(
                      'Stok: ${_scannedProduct!.stock} adet',
                      style: TextStyle(color: Colors.grey[600]),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(Icons.sell, size: 16, color: Colors.grey[600]),
                  const SizedBox(width: 4),
                  Expanded(
                    flex: 3,
                    child: Text(
                      'Fiyat: ${_currencyFormat.format(_scannedProduct!.salePrice)}',
                      style: TextStyle(color: Colors.grey[600]),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              // Stok Hızı ve Kalan Süre Bilgileri
              Consumer<SalesProvider>(
                builder: (context, salesProvider, child) {
                  final stockVelocity = _calculateStockVelocity(
                      _scannedProduct!, salesProvider.sales);
                  return Row(
                    children: [
                      Icon(Icons.speed, size: 16, color: Colors.grey[600]),
                      const SizedBox(width: 4),
                      Expanded(
                        flex: 2,
                        child: Text(
                          'Satış Hızı: ${stockVelocity['dailySalesRate'].toStringAsFixed(1)} adet/gün',
                          style: TextStyle(color: Colors.grey[600]),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Icon(Icons.schedule, size: 16, color: Colors.grey[600]),
                      const SizedBox(width: 4),
                      Expanded(
                        flex: 2,
                        child: Text(
                          'Kalan Süre: ${stockVelocity['remainingDays']} gün',
                          style: TextStyle(
                            color: stockVelocity['remainingDays'] <= 7
                                ? Colors.red
                                : stockVelocity['remainingDays'] <= 15
                                    ? Colors.orange
                                    : Colors.grey[600],
                            fontWeight: stockVelocity['remainingDays'] <= 15
                                ? FontWeight.bold
                                : FontWeight.normal,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  );
                },
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
            Tab(text: 'Aylık'),
            Tab(text: 'Genel'),
            Tab(text: 'Özel Tarih'),
          ],
        ),

        // Tab Views
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildDailyAnalysis(),
              _buildMonthlyAnalysis(),
              _buildGeneralAnalysis(),
              _buildCustomRangeAnalysis(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDailyAnalysis() {
    final analysis = _productAnalysis!;

    // Seçili tarihe göre veri hesapla
    final selectedDayData = _calculateSelectedDayData(analysis);
    final selectedDaySales = selectedDayData['sales'] as int;
    final selectedDayRevenue = selectedDayData['revenue'] as double;
    final selectedDayProfit = selectedDayData['profit'] as double;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Tarih Seçici
          Card(
            elevation: 2,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(Icons.calendar_today, color: Colors.blue[700], size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'Tarih Seçin:',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey[700],
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: InkWell(
                      onTap: _selectDate,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            vertical: 8, horizontal: 12),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey[300]!),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                DateFormat('dd MMMM yyyy', 'tr_TR')
                                    .format(_selectedDate),
                                style: const TextStyle(fontSize: 14),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Icon(Icons.arrow_drop_down,
                                color: Colors.grey[600]),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          // Üç Kart Yan Yana
          Row(
            children: [
              // Satış Kartı (Sol)
              Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _selectedAnalysisType = 'sales'),
                  child: Card(
                    elevation: _selectedAnalysisType == 'sales' ? 8 : 2,
                    color: _selectedAnalysisType == 'sales'
                        ? Colors.blue.shade50
                        : Colors.white,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          Icon(Icons.shopping_cart,
                              size: 32,
                              color: _selectedAnalysisType == 'sales'
                                  ? Colors.blue
                                  : Colors.grey[600]),
                          const SizedBox(height: 8),
                          Text(
                            'Satış',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: _selectedAnalysisType == 'sales'
                                  ? Colors.blue
                                  : Colors.grey[700],
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '$selectedDaySales adet',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: _selectedAnalysisType == 'sales'
                                  ? Colors.blue
                                  : Colors.grey[800],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // Ciro Kartı (Orta)
              Expanded(
                child: GestureDetector(
                  onTap: () =>
                      setState(() => _selectedAnalysisType = 'revenue'),
                  child: Card(
                    elevation: _selectedAnalysisType == 'revenue' ? 8 : 2,
                    color: _selectedAnalysisType == 'revenue'
                        ? Colors.green.shade50
                        : Colors.white,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          Icon(Icons.monetization_on,
                              size: 32,
                              color: _selectedAnalysisType == 'revenue'
                                  ? Colors.green
                                  : Colors.grey[600]),
                          const SizedBox(height: 8),
                          Text(
                            'Ciro',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: _selectedAnalysisType == 'revenue'
                                  ? Colors.green
                                  : Colors.grey[700],
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _currencyFormat.format(selectedDayRevenue),
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: _selectedAnalysisType == 'revenue'
                                  ? Colors.green
                                  : Colors.grey[800],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // Kar Kartı (Sağ)
              Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _selectedAnalysisType = 'profit'),
                  child: Card(
                    elevation: _selectedAnalysisType == 'profit' ? 8 : 2,
                    color: _selectedAnalysisType == 'profit'
                        ? Colors.orange.shade50
                        : Colors.white,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          Icon(Icons.trending_up,
                              size: 32,
                              color: _selectedAnalysisType == 'profit'
                                  ? Colors.orange
                                  : Colors.grey[600]),
                          const SizedBox(height: 8),
                          Text(
                            'Kar',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: _selectedAnalysisType == 'profit'
                                  ? Colors.orange
                                  : Colors.grey[700],
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _currencyFormat.format(selectedDayProfit),
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: _selectedAnalysisType == 'profit'
                                  ? Colors.orange
                                  : Colors.grey[800],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Dinamik Grafik
          _buildDynamicChart(analysis, 'daily'),
        ],
      ),
    );
  }

  Widget _buildMonthlyAnalysis() {
    final analysis = _productAnalysis!;

    // Seçili aya göre verileri hesapla
    final selectedMonthData = _calculateSelectedMonthData();
    final monthSales = selectedMonthData['sales'] as int;
    final monthRevenue = selectedMonthData['revenue'] as double;
    final monthProfit = selectedMonthData['profit'] as double;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Üç Kart Yan Yana
          Row(
            children: [
              // Satış Kartı (Sol)
              Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _selectedAnalysisType = 'sales'),
                  child: Card(
                    elevation: _selectedAnalysisType == 'sales' ? 8 : 2,
                    color: _selectedAnalysisType == 'sales'
                        ? Colors.blue.shade50
                        : Colors.white,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          Icon(Icons.shopping_cart,
                              size: 32,
                              color: _selectedAnalysisType == 'sales'
                                  ? Colors.blue
                                  : Colors.grey[600]),
                          const SizedBox(height: 8),
                          Text(
                            'Satış',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: _selectedAnalysisType == 'sales'
                                  ? Colors.blue
                                  : Colors.grey[700],
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '$monthSales adet',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: _selectedAnalysisType == 'sales'
                                  ? Colors.blue
                                  : Colors.grey[800],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // Ciro Kartı (Orta)
              Expanded(
                child: GestureDetector(
                  onTap: () =>
                      setState(() => _selectedAnalysisType = 'revenue'),
                  child: Card(
                    elevation: _selectedAnalysisType == 'revenue' ? 8 : 2,
                    color: _selectedAnalysisType == 'revenue'
                        ? Colors.green.shade50
                        : Colors.white,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          Icon(Icons.monetization_on,
                              size: 32,
                              color: _selectedAnalysisType == 'revenue'
                                  ? Colors.green
                                  : Colors.grey[600]),
                          const SizedBox(height: 8),
                          Text(
                            'Ciro',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: _selectedAnalysisType == 'revenue'
                                  ? Colors.green
                                  : Colors.grey[700],
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _currencyFormat.format(monthRevenue),
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: _selectedAnalysisType == 'revenue'
                                  ? Colors.green
                                  : Colors.grey[800],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // Kar Kartı (Sağ)
              Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _selectedAnalysisType = 'profit'),
                  child: Card(
                    elevation: _selectedAnalysisType == 'profit' ? 8 : 2,
                    color: _selectedAnalysisType == 'profit'
                        ? Colors.orange.shade50
                        : Colors.white,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          Icon(Icons.trending_up,
                              size: 32,
                              color: _selectedAnalysisType == 'profit'
                                  ? Colors.orange
                                  : Colors.grey[600]),
                          const SizedBox(height: 8),
                          Text(
                            'Kar',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: _selectedAnalysisType == 'profit'
                                  ? Colors.orange
                                  : Colors.grey[700],
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _currencyFormat.format(monthProfit),
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: _selectedAnalysisType == 'profit'
                                  ? Colors.orange
                                  : Colors.grey[800],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Dinamik Grafik - Ay Seçimi ile
          _buildMonthlyDynamicChart(analysis),
        ],
      ),
    );
  }

  Widget _buildGeneralAnalysis() {
    final salesProvider = Provider.of<SalesProvider>(context, listen: false);
    final totalStats =
        _calculateTotalStatistics(_scannedProduct!, salesProvider.sales);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Toplam İstatistikler Kartları (3 Kart Tek Satırda)
          Row(
            children: [
              // Toplam Satış Kartı
              Expanded(
                child: Card(
                  elevation: 4,
                  color: Colors.blue.shade50,
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      children: [
                        Icon(Icons.shopping_cart, size: 28, color: Colors.blue),
                        const SizedBox(height: 6),
                        Text(
                          'Toplam Satış',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.blue,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${totalStats['totalSales']} adet',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Colors.blue,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              // Toplam Ciro Kartı
              Expanded(
                child: Card(
                  elevation: 4,
                  color: Colors.green.shade50,
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      children: [
                        Icon(Icons.monetization_on,
                            size: 28, color: Colors.green),
                        const SizedBox(height: 6),
                        Text(
                          'Toplam Ciro',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.green,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _currencyFormat.format(totalStats['totalRevenue']),
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Colors.green,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              // Toplam Kar Kartı
              Expanded(
                child: Card(
                  elevation: 4,
                  color: Colors.orange.shade50,
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      children: [
                        Icon(Icons.trending_up, size: 28, color: Colors.orange),
                        const SizedBox(height: 6),
                        Text(
                          'Toplam Kar',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.orange,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _currencyFormat.format(totalStats['totalProfit']),
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Colors.orange,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Genel Satış Trendi Grafiği
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Genel Satış Trendi (İlk Satıştan İtibaren)',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[800],
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildGeneralTrendChart(totalStats),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // İstatistik Bilgileri
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Detaylı İstatistikler',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[800],
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (totalStats['firstSaleDate'] != null) ...[
                    Row(
                      children: [
                        Icon(Icons.event_note,
                            size: 16, color: Colors.grey[600]),
                        const SizedBox(width: 8),
                        Text(
                          'İlk Satış: ${DateFormat('dd MMMM yyyy', 'tr_TR').format(totalStats['firstSaleDate'])}',
                          style: TextStyle(color: Colors.grey[600]),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                  ],
                  if (totalStats['lastSaleDate'] != null) ...[
                    Row(
                      children: [
                        Icon(Icons.event_available,
                            size: 16, color: Colors.grey[600]),
                        const SizedBox(width: 8),
                        Text(
                          'Son Satış: ${DateFormat('dd MMMM yyyy', 'tr_TR').format(totalStats['lastSaleDate'])}',
                          style: TextStyle(color: Colors.grey[600]),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                  ],
                  Row(
                    children: [
                      Icon(Icons.calendar_today,
                          size: 16, color: Colors.grey[600]),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Toplam Satış Yapılan Gün: ${totalStats['totalDaysWithSales']} gün',
                          style: TextStyle(color: Colors.grey[600]),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(Icons.timeline, size: 16, color: Colors.grey[600]),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'İlk Satıştan Geçen Süre: ${totalStats['totalDaysSinceFirstSale']} gün',
                          style: TextStyle(color: Colors.grey[600]),
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

  Widget _buildGeneralTrendChart(Map<String, dynamic> totalStats) {
    final dailySalesHistory =
        totalStats['dailySalesHistory'] as Map<String, int>;
    final chartData = _prepareGeneralTrendData(dailySalesHistory);

    if (chartData.isEmpty) {
      return Container(
        height: 200,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.bar_chart, size: 64, color: Colors.grey[400]),
              const SizedBox(height: 16),
              Text(
                'Henüz satış verisi yok',
                style: TextStyle(fontSize: 16, color: Colors.grey[600]),
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      height: 300,
      child: SfCartesianChart(
        primaryXAxis: CategoryAxis(
          title: AxisTitle(text: 'Tarih'),
          labelRotation: -45,
          labelStyle: TextStyle(fontSize: 10),
        ),
        primaryYAxis: NumericAxis(
          title: AxisTitle(text: 'Satış Adedi'),
          minimum: 0,
        ),
        title: ChartTitle(
          text: 'Genel Satış Trendi',
          textStyle: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
        ),
        legend: Legend(isVisible: false),
        tooltipBehavior: TooltipBehavior(enable: true),
        series: <CartesianSeries>[
          LineSeries<MapEntry<String, int>, String>(
            dataSource: chartData,
            xValueMapper: (MapEntry<String, int> data, _) =>
                DateFormat('dd/MM').format(DateTime.parse(data.key)),
            yValueMapper: (MapEntry<String, int> data, _) => data.value,
            name: 'Satış Adedi',
            color: Colors.blue,
            width: 3,
            markerSettings: MarkerSettings(
              isVisible: true,
              color: Colors.blue,
              borderColor: Colors.white,
              borderWidth: 2,
            ),
            dataLabelSettings: DataLabelSettings(
              isVisible: true,
              labelAlignment: ChartDataLabelAlignment.top,
              textStyle: TextStyle(fontSize: 10),
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

            // Üç Kart Yan Yana
            Row(
              children: [
                // Satış Kartı (Sol)
                Expanded(
                  child: GestureDetector(
                    onTap: () =>
                        setState(() => _selectedAnalysisType = 'sales'),
                    child: Card(
                      elevation: _selectedAnalysisType == 'sales' ? 8 : 2,
                      color: _selectedAnalysisType == 'sales'
                          ? Colors.blue.shade50
                          : Colors.white,
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          children: [
                            Icon(Icons.shopping_cart,
                                size: 32,
                                color: _selectedAnalysisType == 'sales'
                                    ? Colors.blue
                                    : Colors.grey[600]),
                            const SizedBox(height: 8),
                            Text(
                              'Satış',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: _selectedAnalysisType == 'sales'
                                    ? Colors.blue
                                    : Colors.grey[700],
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '$customSales adet',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: _selectedAnalysisType == 'sales'
                                    ? Colors.blue
                                    : Colors.grey[800],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                // Ciro Kartı (Orta)
                Expanded(
                  child: GestureDetector(
                    onTap: () =>
                        setState(() => _selectedAnalysisType = 'revenue'),
                    child: Card(
                      elevation: _selectedAnalysisType == 'revenue' ? 8 : 2,
                      color: _selectedAnalysisType == 'revenue'
                          ? Colors.green.shade50
                          : Colors.white,
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          children: [
                            Icon(Icons.monetization_on,
                                size: 32,
                                color: _selectedAnalysisType == 'revenue'
                                    ? Colors.green
                                    : Colors.grey[600]),
                            const SizedBox(height: 8),
                            Text(
                              'Ciro',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: _selectedAnalysisType == 'revenue'
                                    ? Colors.green
                                    : Colors.grey[700],
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _currencyFormat.format(
                                  customSales * _scannedProduct!.salePrice),
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: _selectedAnalysisType == 'revenue'
                                    ? Colors.green
                                    : Colors.grey[800],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                // Kar Kartı (Sağ)
                Expanded(
                  child: GestureDetector(
                    onTap: () =>
                        setState(() => _selectedAnalysisType = 'profit'),
                    child: Card(
                      elevation: _selectedAnalysisType == 'profit' ? 8 : 2,
                      color: _selectedAnalysisType == 'profit'
                          ? Colors.orange.shade50
                          : Colors.white,
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          children: [
                            Icon(Icons.trending_up,
                                size: 32,
                                color: _selectedAnalysisType == 'profit'
                                    ? Colors.orange
                                    : Colors.grey[600]),
                            const SizedBox(height: 8),
                            Text(
                              'Kar',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: _selectedAnalysisType == 'profit'
                                    ? Colors.orange
                                    : Colors.grey[700],
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _currencyFormat
                                  .format(analysis['customProfit'] as double),
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: _selectedAnalysisType == 'profit'
                                    ? Colors.orange
                                    : Colors.grey[800],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Dinamik Grafik
            _buildDynamicChart(analysis, 'custom'),
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

  // Seçili ay için verileri hesapla
  Map<String, dynamic> _calculateSelectedMonthData() {
    final salesProvider = Provider.of<SalesProvider>(context, listen: false);
    final sales = salesProvider.sales;

    int monthSales = 0;
    double monthRevenue = 0;
    double monthProfit = 0;

    for (var sale in sales) {
      if (sale.createdAt.month == _selectedMonth &&
          sale.createdAt.year == _selectedYear) {
        for (var item in sale.items) {
          if (item.productName == _scannedProduct!.name) {
            monthSales += item.quantity;
            monthRevenue += item.totalPrice;
            double itemProfit = ((_scannedProduct!.salePrice -
                    (_scannedProduct!.purchasePrice ?? 0)) *
                item.quantity);
            monthProfit += itemProfit;
          }
        }
      }
    }

    return {
      'sales': monthSales,
      'revenue': monthRevenue,
      'profit': monthProfit,
    };
  }

  Widget _buildDynamicChart(Map<String, dynamic> analysis, String period) {
    String chartTitle;
    Color chartColor;
    Map<String, dynamic> chartData;

    // Grafik türüne göre veri ve stil belirleme
    switch (_selectedAnalysisType) {
      case 'sales':
        chartTitle = 'Satış Trendi';
        chartColor = Colors.blue;
        chartData = _getSalesChartData(analysis, period);
        break;
      case 'revenue':
        chartTitle = 'Ciro Trendi';
        chartColor = Colors.green;
        chartData = _getRevenueChartData(analysis, period);
        break;
      case 'profit':
        chartTitle = 'Kar Trendi';
        chartColor = Colors.orange;
        chartData = _getProfitChartData(analysis, period);
        break;
      default:
        chartTitle = 'Satış Trendi';
        chartColor = Colors.blue;
        chartData = _getSalesChartData(analysis, period);
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              chartTitle,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 250,
              child: SfCartesianChart(
                primaryXAxis: const CategoryAxis(),
                primaryYAxis: const NumericAxis(),
                tooltipBehavior: TooltipBehavior(enable: true),
                series: <CartesianSeries>[
                  if (period == 'daily' || period == 'monthly')
                    LineSeries<MapEntry<String, dynamic>, String>(
                      dataSource: chartData['data'],
                      xValueMapper: (MapEntry<String, dynamic> data, _) =>
                          data.key,
                      yValueMapper: (MapEntry<String, dynamic> data, _) =>
                          data.value,
                      name: chartData['label'],
                      color: chartColor,
                      markerSettings: const MarkerSettings(isVisible: true),
                      dataLabelSettings:
                          const DataLabelSettings(isVisible: true),
                    )
                  else
                    ColumnSeries<MapEntry<String, dynamic>, String>(
                      dataSource: chartData['data'],
                      xValueMapper: (MapEntry<String, dynamic> data, _) =>
                          data.key,
                      yValueMapper: (MapEntry<String, dynamic> data, _) =>
                          data.value,
                      name: chartData['label'],
                      color: chartColor,
                      dataLabelSettings:
                          const DataLabelSettings(isVisible: true),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Map<String, dynamic> _getSalesChartData(
      Map<String, dynamic> analysis, String period) {
    Map<String, int> data;
    String label = 'Satış Adedi';

    switch (period) {
      case 'daily':
        // Seçili tarihten geriye doğru 7 günlük veri hazırla
        return _getDailyChartDataForSelectedDate(analysis, label);
      case 'weekly':
        data = analysis['weeklySales'] as Map<String, int>;
        break;
      case 'monthly':
        data = analysis['monthlySales'] as Map<String, int>;
        // Seçili aya göre filtrele ve sırala
        var selectedMonthEntries = data.entries.where((entry) {
          var parts = entry.key.split('.');
          return int.parse(parts[1]) == _selectedMonth;
        }).toList()
          ..sort((a, b) {
            var partsA = a.key.split('.');
            var partsB = b.key.split('.');
            return int.parse(partsA[0]).compareTo(int.parse(partsB[0]));
          });
        return {
          'data': selectedMonthEntries,
          'label': label,
        };
      case 'custom':
        data = analysis['customRangeSales'] as Map<String, int>;
        break;
      default:
        data = analysis['dailySales'] as Map<String, int>;
    }

    return {
      'data': data.entries.toList(),
      'label': label,
    };
  }

  Map<String, dynamic> _getRevenueChartData(
      Map<String, dynamic> analysis, String period) {
    Map<String, double> data;
    String label = 'Ciro (₺)';

    switch (period) {
      case 'daily':
        // Seçili tarihten geriye doğru 7 günlük ciro verisi hazırla
        return _getDailyRevenueChartDataForSelectedDate(analysis, label);
      case 'weekly':
        data = analysis['weeklyRevenues'] as Map<String, double>;
        break;
      case 'monthly':
        data = analysis['monthlyRevenues'] as Map<String, double>;
        // Seçili aya göre filtrele ve sırala
        var selectedMonthEntries = data.entries.where((entry) {
          var parts = entry.key.split('.');
          return int.parse(parts[1]) == _selectedMonth;
        }).toList()
          ..sort((a, b) {
            var partsA = a.key.split('.');
            var partsB = b.key.split('.');
            return int.parse(partsA[0]).compareTo(int.parse(partsB[0]));
          });
        return {
          'data': selectedMonthEntries,
          'label': label,
        };
      case 'custom':
        data = analysis['customRangeRevenues'] as Map<String, double>;
        break;
      default:
        data = analysis['dailyRevenues'] as Map<String, double>;
    }

    return {
      'data': data.entries.toList(),
      'label': label,
    };
  }

  Map<String, dynamic> _getProfitChartData(
      Map<String, dynamic> analysis, String period) {
    Map<String, double> data;
    String label = 'Kar (₺)';

    switch (period) {
      case 'daily':
        // Seçili tarihten geriye doğru 7 günlük kar verisi hazırla
        return _getDailyProfitChartDataForSelectedDate(analysis, label);
      case 'weekly':
        data = analysis['weeklyProfits'] as Map<String, double>;
        break;
      case 'monthly':
        data = analysis['monthlyProfits'] as Map<String, double>;
        // Seçili aya göre filtrele ve sırala
        var selectedMonthEntries = data.entries.where((entry) {
          var parts = entry.key.split('.');
          return int.parse(parts[1]) == _selectedMonth;
        }).toList()
          ..sort((a, b) {
            var partsA = a.key.split('.');
            var partsB = b.key.split('.');
            return int.parse(partsA[0]).compareTo(int.parse(partsB[0]));
          });
        return {
          'data': selectedMonthEntries,
          'label': label,
        };
      case 'custom':
        data = analysis['customRangeProfits'] as Map<String, double>;
        break;
      default:
        data = analysis['dailyProfits'] as Map<String, double>;
    }

    return {
      'data': data.entries.toList(),
      'label': label,
    };
  }

  // Ay isimleri
  final List<String> _monthNames = [
    'Ocak',
    'Şubat',
    'Mart',
    'Nisan',
    'Mayıs',
    'Haziran',
    'Temmuz',
    'Ağustos',
    'Eylül',
    'Ekim',
    'Kasım',
    'Aralık'
  ];

  // Aylık grafik için özel dinamik grafik fonksiyonu
  Widget _buildMonthlyDynamicChart(Map<String, dynamic> analysis) {
    String chartTitle;
    Color chartColor;
    Map<String, dynamic> chartData;

    // Grafik türüne göre veri ve stil belirleme
    switch (_selectedAnalysisType) {
      case 'sales':
        chartTitle = 'Satış Trendi';
        chartColor = Colors.blue;
        chartData = _getSalesChartData(analysis, 'monthly');
        break;
      case 'revenue':
        chartTitle = 'Ciro Trendi';
        chartColor = Colors.green;
        chartData = _getRevenueChartData(analysis, 'monthly');
        break;
      case 'profit':
        chartTitle = 'Kar Trendi';
        chartColor = Colors.orange;
        chartData = _getProfitChartData(analysis, 'monthly');
        break;
      default:
        chartTitle = 'Satış Trendi';
        chartColor = Colors.blue;
        chartData = _getSalesChartData(analysis, 'monthly');
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Başlık ve Ay Seçimi
            Row(
              children: [
                Text(
                  chartTitle,
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                // Ay Seçimi Dropdown
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey[300]!),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<int>(
                      value: _selectedMonth,
                      isDense: true,
                      items: List.generate(12, (index) {
                        return DropdownMenuItem<int>(
                          value: index + 1,
                          child: Text(
                            _monthNames[index],
                            style: const TextStyle(fontSize: 14),
                          ),
                        );
                      }),
                      onChanged: (int? newMonth) {
                        if (newMonth != null) {
                          setState(() {
                            _selectedMonth = newMonth;
                            // Yeni ay seçildiğinde analizi yeniden hesapla
                            if (_scannedProduct != null) {
                              final salesProvider = Provider.of<SalesProvider>(
                                  context,
                                  listen: false);
                              _productAnalysis = _analyzeProduct(
                                  _scannedProduct!, salesProvider.sales);
                            }
                          });
                        }
                      },
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 250,
              child: SfCartesianChart(
                primaryXAxis: const CategoryAxis(),
                primaryYAxis: const NumericAxis(),
                tooltipBehavior: TooltipBehavior(enable: true),
                series: <CartesianSeries>[
                  LineSeries<MapEntry<String, dynamic>, String>(
                    dataSource: chartData['data'],
                    xValueMapper: (MapEntry<String, dynamic> data, _) =>
                        data.key,
                    yValueMapper: (MapEntry<String, dynamic> data, _) =>
                        data.value,
                    name: chartData['label'],
                    color: chartColor,
                    markerSettings: const MarkerSettings(isVisible: true),
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
}
