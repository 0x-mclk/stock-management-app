import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/supplier_provider.dart';
import '../providers/purchase_provider.dart';
import '../models/supplier.dart';
import '../models/purchase.dart';
import '../utils/currency_formatter.dart';

class SupplierDetailScreen extends StatefulWidget {
  final Supplier supplier;
  final int initialTabIndex;

  const SupplierDetailScreen({
    super.key,
    required this.supplier,
    this.initialTabIndex = 0,
  });

  @override
  State<SupplierDetailScreen> createState() => _SupplierDetailScreenState();
}

class _SupplierDetailScreenState extends State<SupplierDetailScreen>
    with TickerProviderStateMixin {
  late TabController _tabController;
  late Supplier _currentSupplier; // Local supplier state
  DateTime _startDate = DateTime.now().subtract(const Duration(days: 30));
  DateTime _endDate = DateTime.now();
  String _selectedPeriod = 'last_30_days';

  // Aylık analiz için yıl ve ay seçimi
  int _selectedYear = DateTime.now().year;
  int _selectedMonth = DateTime.now().month;

  // Yıllık analiz için yıl seçimi
  int _selectedYearForYearly = DateTime.now().year;

  @override
  void initState() {
    super.initState();
    _currentSupplier = widget.supplier; // Initialize current supplier
    _tabController = TabController(
      length: 5,
      vsync: this,
      initialIndex: widget.initialTabIndex,
    ); // 4'ten 5'e çıkarıldı

    // ✅ Purchase provider'ı başlat - storeId ile birlikte
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && widget.supplier.id != null) {
        context.read<PurchaseProvider>().loadPurchasesBySupplier(
            widget.supplier.id!,
            storeId: widget.supplier.storeId);
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    // Firebase listener'ını temizle
    if (mounted) {
      context.read<PurchaseProvider>().stopFirebaseListener();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _currentSupplier.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () => _editSupplier(),
          ),
          IconButton(
            icon: const Icon(Icons.date_range),
            onPressed: () => _showDateRangePicker(),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabs: const [
            Tab(icon: Icon(Icons.info), text: 'Genel Bilgi'),
            Tab(icon: Icon(Icons.shopping_cart), text: 'Alışveriş Geçmişi'),
            Tab(icon: Icon(Icons.payment), text: 'Ödeme Geçmişi'),
            Tab(icon: Icon(Icons.calendar_today), text: 'Aylık Analiz'),
            Tab(icon: Icon(Icons.analytics), text: 'Yıllık Analiz'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildGeneralInfo(),
          _buildPurchaseHistory(),
          _buildPaymentHistory(),
          _buildMonthlyAnalysis(),
          _buildYearlyAnalysis(),
        ],
      ),
    );
  }

  Widget _buildGeneralInfo() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Tedarikçi Bilgi Kartı
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 25,
                        backgroundColor: Colors.blue,
                        child: Text(
                          _currentSupplier.name.isNotEmpty
                              ? _currentSupplier.name[0].toUpperCase()
                              : '?',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _currentSupplier.name,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Üyelik: ${_formatDate(_currentSupplier.createdAt)}',
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 12,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // İletişim Bilgileri
                  _buildInfoRow(Icons.phone, 'Telefon',
                      _currentSupplier.phone ?? 'Belirtilmemiş'),
                  _buildInfoRow(Icons.location_on, 'Adres',
                      _currentSupplier.address ?? 'Belirtilmemiş'),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Mali Durum Özeti
          _buildFinancialStatusSection(),

          const SizedBox(height: 16),

          // Hızlı İşlemler
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Hızlı İşlemler',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () => _addPayment(),
                          icon: const Icon(Icons.payment, size: 18),
                          label: const Text('Ödeme',
                              style: TextStyle(fontSize: 12)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () => _addDebt(),
                          icon: const Icon(Icons.add_shopping_cart, size: 18),
                          label: const Text('Alışveriş',
                              style: TextStyle(fontSize: 12)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
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

  Widget _buildPurchaseHistory() {
    return Consumer<PurchaseProvider>(
      builder: (context, purchaseProvider, child) {
        // ✅ YENİ: PurchaseProvider'dan gerçek purchases'ları al
        final allPurchases = purchaseProvider.purchases;
        final supplierPurchases = allPurchases
            .where((p) => p.supplierId == widget.supplier.id)
            .toList();
        final filteredPurchases = supplierPurchases; // Şimdilik filtresiz

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildPeriodSelector(),
              const SizedBox(height: 16),

              // Özet Kartları - Gerçek verilerle
              Row(
                children: [
                  Flexible(
                    child: _buildSummaryCard(
                      'Toplam Alışveriş',
                      '${filteredPurchases.length}',
                      Icons.shopping_cart,
                      Colors.blue,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: _buildSummaryCard(
                      'Toplam Tutar',
                      _formatCurrency(filteredPurchases.fold<double>(
                          0, (sum, p) => sum + p.amount)),
                      Icons.monetization_on,
                      Colors.green,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              if (filteredPurchases.isEmpty)
                const Center(
                  child: Column(
                    children: [
                      Icon(Icons.shopping_cart_outlined,
                          size: 64, color: Colors.grey),
                      SizedBox(height: 16),
                      Text(
                        'Seçilen dönemde alışveriş bulunamadı',
                        style: TextStyle(color: Colors.grey),
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Bu tedarikçiden henüz alışveriş yapılmamış',
                        style: TextStyle(color: Colors.grey, fontSize: 12),
                      ),
                    ],
                  ),
                )
              else
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: filteredPurchases.length,
                  itemBuilder: (context, index) {
                    final purchase = filteredPurchases[index];
                    return _buildPurchaseCardNew(purchase);
                  },
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMonthlyAnalysis() {
    return Consumer<PurchaseProvider>(
      builder: (context, purchaseProvider, child) {
        // Her tedarikçi için kendi gerçek verilerini al
        final purchases = _getSupplierPurchases(purchaseProvider.purchases);
        final monthlyData = _getFilteredMonthlyData(purchases);

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Aylık Alışveriş Analizi',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),

              // Yıl ve Ay Seçici
              _buildYearMonthSelector(),
              const SizedBox(height: 16),

              // Seçilen ay/yıl için özet kart
              _buildSelectedMonthSummary(monthlyData),
              const SizedBox(height: 16),

              // Tüm aylık veriler
              const Text(
                'Tüm Aylar',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),

              if (monthlyData.isEmpty)
                const Center(
                  child: Column(
                    children: [
                      Icon(Icons.calendar_month, size: 64, color: Colors.grey),
                      SizedBox(height: 16),
                      Text(
                        'Bu tedarikçi için aylık veri bulunmuyor',
                        style: TextStyle(color: Colors.grey),
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Henüz bu tedarikçiden alışveriş yapılmamış',
                        style: TextStyle(color: Colors.grey, fontSize: 12),
                      ),
                    ],
                  ),
                )
              else
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: monthlyData.length,
                  itemBuilder: (context, index) {
                    final data = monthlyData[index];
                    final isSelected = data['year'] == _selectedYear &&
                        data['monthNumber'] == _selectedMonth;
                    return _buildMonthlyCard(data, isSelected);
                  },
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildYearlyAnalysis() {
    return Consumer<PurchaseProvider>(
      builder: (context, purchaseProvider, child) {
        // Her tedarikçi için kendi gerçek verilerini al
        final purchases = _getSupplierPurchases(purchaseProvider.purchases);
        final yearlyData = _getYearlyData(purchases);

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Yıllık Alışveriş Analizi',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),

              // Yıl Seçici
              _buildYearSelector(),
              const SizedBox(height: 16),

              // Seçilen yıl için özet kart
              _buildSelectedYearSummary(yearlyData),
              const SizedBox(height: 16),

              // Tüm yıllık veriler
              const Text(
                'Tüm Yıllar',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),

              if (yearlyData.isEmpty)
                const Center(
                  child: Column(
                    children: [
                      Icon(Icons.calendar_today, size: 64, color: Colors.grey),
                      SizedBox(height: 16),
                      Text(
                        'Bu tedarikçi için yıllık veri bulunmuyor',
                        style: TextStyle(color: Colors.grey),
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Henüz bu tedarikçiden alışveriş yapılmamış',
                        style: TextStyle(color: Colors.grey, fontSize: 12),
                      ),
                    ],
                  ),
                )
              else
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: yearlyData.length,
                  itemBuilder: (context, index) {
                    final data = yearlyData[index];
                    final isSelected = data['year'] == _selectedYearForYearly;
                    return _buildYearlyCard(data, isSelected);
                  },
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSummaryCard(
      String title, String value, IconData icon, Color color) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withValues(alpha: 0.1),
            spreadRadius: 1,
            blurRadius: 3,
            offset: const Offset(0, 2),
          ),
        ],
        border: Border.all(
          color: color.withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(8), // Padding'i azalttım
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize:
              MainAxisSize.min, // Column'un minimum alan kaplaması için
          children: [
            Container(
              padding: const EdgeInsets.all(6), // İkon padding'ini azalttım
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child:
                  Icon(icon, color: color, size: 20), // İkon boyutunu azalttım
            ),
            const SizedBox(height: 6), // Boşlukları azalttım
            Text(
              title,
              style: const TextStyle(
                fontSize: 11, // Font boyutunu azalttım
                fontWeight: FontWeight.w600,
                color: Colors.grey,
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2), // Boşluğu azalttım
            Text(
              value,
              style: TextStyle(
                fontSize: 13, // Font boyutunu azalttım
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

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, color: Colors.grey[600], size: 18),
          const SizedBox(width: 8),
          SizedBox(
            width: 60,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
            ),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              value,
              style: TextStyle(color: Colors.grey[700], fontSize: 12),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPeriodSelector() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Tarih Aralığı',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              children: [
                _buildPeriodChip('Son 7 Gün', 'last_7_days'),
                _buildPeriodChip('Son 30 Gün', 'last_30_days'),
                _buildPeriodChip('Bu Ay', 'this_month'),
                _buildPeriodChip('Bu Yıl', 'this_year'),
                _buildPeriodChip('Özel', 'custom'),
              ],
            ),
            if (_selectedPeriod == 'custom') ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Başlangıç: ${_formatDate(_startDate)}',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                  const Text(' - '),
                  Expanded(
                    child: Text(
                      'Bitiş: ${_formatDate(_endDate)}',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildPeriodChip(String label, String value) {
    return FilterChip(
      label: Text(label),
      selected: _selectedPeriod == value,
      onSelected: (selected) {
        if (selected) {
          setState(() {
            _selectedPeriod = value;
            _updateDateRange(value);
          });
        }
      },
    );
  }

  Widget _buildPurchaseCardNew(dynamic purchase) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        title: Text(
          purchase.productName ?? 'Ürün bilgisi yok',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Tarih: ${_formatDate(purchase.purchaseDate)}'),
            if (purchase.notes != null && purchase.notes!.isNotEmpty)
              Text('Not: ${purchase.notes}'),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              CurrencyFormatter.formatWithSymbol(purchase.amount),
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            PopupMenuButton<String>(
              onSelected: (value) {
                if (value == 'edit') {
                  _showEditPurchaseDialog(purchase);
                } else if (value == 'delete') {
                  _confirmDeletePurchase(purchase);
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'edit',
                  child: Row(
                    children: [
                      Icon(Icons.edit, size: 18),
                      SizedBox(width: 8),
                      Text('Düzenle'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'delete',
                  child: Row(
                    children: [
                      Icon(Icons.delete, size: 18, color: Colors.red),
                      SizedBox(width: 8),
                      Text('Sil', style: TextStyle(color: Colors.red)),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
        onTap: () {
          _showPurchaseDetails(purchase);
        },
      ),
    );
  }

  Widget _buildMonthlyCard(Map<String, dynamic> data,
      [bool isSelected = false]) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      color: isSelected ? Colors.blue.shade50 : null,
      elevation: isSelected ? 4 : 1,
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: isSelected ? Colors.blue : Colors.orange,
          child: Text(
            data['count'].toString(),
            style: const TextStyle(
                color: Colors.white, fontWeight: FontWeight.bold),
          ),
        ),
        title: Text(
          data['month'],
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: isSelected ? Colors.blue : null,
          ),
        ),
        subtitle: Text('${data['count']} alışveriş'),
        trailing: Text(
          CurrencyFormatter.formatWithSymbol(data['total']),
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
            color: isSelected ? Colors.blue : null,
          ),
        ),
        onTap: () {
          setState(() {
            _selectedYear = data['year'];
            _selectedMonth = data['monthNumber'];
          });
        },
      ),
    );
  }

  Widget _buildYearlyCard(Map<String, dynamic> data,
      [bool isSelected = false]) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      color: isSelected ? Colors.purple.shade50 : null,
      elevation: isSelected ? 4 : 1,
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: isSelected ? Colors.purple : Colors.purple,
          child: Text(
            data['year'].toString(),
            style: const TextStyle(
                color: Colors.white, fontWeight: FontWeight.bold),
          ),
        ),
        title: Text(
          '${data['year']} Yılı',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: isSelected ? Colors.purple : null,
          ),
        ),
        subtitle: Text('${data['count']} alışveriş'),
        trailing: Text(
          CurrencyFormatter.formatWithSymbol(data['total']),
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
            color: isSelected ? Colors.purple : null,
          ),
        ),
        onTap: () {
          setState(() {
            _selectedYearForYearly = data['year'];
          });
        },
      ),
    );
  }

  // Helper methods
  List<dynamic> _getSupplierPurchases(List<dynamic> allPurchases) {
    // Sadece gerçek alışverişleri göster
    if (allPurchases.isEmpty) return [];
    final supplierId = widget.supplier.id;
    // Sadece bu tedarikçiye ait alışverişleri filtrele
    final supplierPurchases = allPurchases
        .where((purchase) => purchase.supplierId == supplierId)
        .toList();
    // Tarihe göre sırala (en yeni en üstte)
    supplierPurchases.sort((a, b) => b.purchaseDate.compareTo(a.purchaseDate));
    return supplierPurchases;
  }

  List<Map<String, dynamic>> _getFilteredMonthlyData(List<dynamic> purchases) {
    final monthlyMap = <String, Map<String, dynamic>>{};

    for (final purchase in purchases) {
      final monthKey =
          '${purchase.purchaseDate.year}-${purchase.purchaseDate.month.toString().padLeft(2, '0')}';
      final monthName = _getMonthName(
          purchase.purchaseDate.month, purchase.purchaseDate.year);

      if (monthlyMap.containsKey(monthKey)) {
        monthlyMap[monthKey]!['total'] += purchase.amount;
        monthlyMap[monthKey]!['count']++;
      } else {
        monthlyMap[monthKey] = {
          'month': monthName,
          'monthNumber': purchase.purchaseDate.month,
          'year': purchase.purchaseDate.year,
          'total': purchase.amount,
          'count': 1,
        };
      }
    }

    return monthlyMap.values.toList()
      ..sort((a, b) {
        final aDate = DateTime(a['year'], a['monthNumber']);
        final bDate = DateTime(b['year'], b['monthNumber']);
        return bDate.compareTo(aDate);
      });
  }

  List<Map<String, dynamic>> _getYearlyData(List<dynamic> purchases) {
    final yearlyMap = <int, Map<String, dynamic>>{};

    for (final purchase in purchases) {
      final year = purchase.purchaseDate.year;

      if (yearlyMap.containsKey(year)) {
        yearlyMap[year]!['total'] += purchase.amount;
        yearlyMap[year]!['count']++;
      } else {
        yearlyMap[year] = {
          'year': year,
          'total': purchase.amount,
          'count': 1,
        };
      }
    }

    return yearlyMap.values.toList()
      ..sort((a, b) => b['year'].compareTo(a['year']));
  }

  Widget _buildYearMonthSelector() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Tarih Seçimi',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Yıl',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 4),
                      DropdownButtonFormField<int>(
                        value: _selectedYear,
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                          contentPadding:
                              EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        ),
                        items: _getAvailableYears().map((year) {
                          return DropdownMenuItem(
                            value: year,
                            child: Text(year.toString()),
                          );
                        }).toList(),
                        onChanged: (value) {
                          if (value != null) {
                            setState(() {
                              _selectedYear = value;
                            });
                          }
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Ay',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 4),
                      DropdownButtonFormField<int>(
                        value: _selectedMonth,
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                          contentPadding:
                              EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        ),
                        items: _getMonthItems(),
                        onChanged: (value) {
                          if (value != null) {
                            setState(() {
                              _selectedMonth = value;
                            });
                          }
                        },
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

  Widget _buildSelectedMonthSummary(List<Map<String, dynamic>> monthlyData) {
    final selectedData = monthlyData.firstWhere(
      (data) =>
          data['year'] == _selectedYear &&
          data['monthNumber'] == _selectedMonth,
      orElse: () => <String, dynamic>{},
    );

    final hasData = selectedData.isNotEmpty;
    final monthName = _getMonthName(_selectedMonth, _selectedYear);

    return Card(
      color: Colors.blue.shade50,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Seçilen Dönem: $monthName',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.blue,
              ),
            ),
            const SizedBox(height: 12),
            if (hasData) ...[
              Row(
                children: [
                  Expanded(
                    child: _buildSummaryItem(
                      'Alışveriş Sayısı',
                      selectedData['count'].toString(),
                      Icons.shopping_cart,
                      Colors.blue,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildSummaryItem(
                      'Toplam Tutar',
                      _formatCurrency(selectedData['total']),
                      Icons.monetization_on,
                      Colors.green,
                    ),
                  ),
                ],
              ),
            ] else ...[
              const Center(
                child: Column(
                  children: [
                    Icon(Icons.info_outline, size: 48, color: Colors.grey),
                    SizedBox(height: 8),
                    Text(
                      'Seçilen dönemde alışveriş bulunmuyor',
                      style: TextStyle(color: Colors.grey),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryItem(
      String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 4),
          Text(
            title,
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
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
    );
  }

  Widget _buildYearSelector() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Yıl Seçimi',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: DropdownButtonFormField<int>(
                value: _selectedYearForYearly,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  labelText: 'Yıl Seçin',
                ),
                items: _getAvailableYears().map((year) {
                  return DropdownMenuItem(
                    value: year,
                    child: Text('$year Yılı'),
                  );
                }).toList(),
                onChanged: (value) {
                  if (value != null) {
                    setState(() {
                      _selectedYearForYearly = value;
                    });
                  }
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSelectedYearSummary(List<Map<String, dynamic>> yearlyData) {
    final selectedData = yearlyData.firstWhere(
      (data) => data['year'] == _selectedYearForYearly,
      orElse: () => <String, dynamic>{},
    );

    final hasData = selectedData.isNotEmpty;

    return Card(
      color: Colors.purple.shade50,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Seçilen Yıl: $_selectedYearForYearly',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.purple,
              ),
            ),
            const SizedBox(height: 12),
            if (hasData) ...[
              Row(
                children: [
                  Expanded(
                    child: _buildYearlySummaryItem(
                      'Alışveriş Sayısı',
                      selectedData['count'].toString(),
                      Icons.shopping_cart,
                      Colors.purple,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildYearlySummaryItem(
                      'Toplam Tutar',
                      _formatCurrency(selectedData['total']),
                      Icons.monetization_on,
                      Colors.green,
                    ),
                  ),
                ],
              ),
            ] else ...[
              const Center(
                child: Column(
                  children: [
                    Icon(Icons.info_outline, size: 48, color: Colors.grey),
                    SizedBox(height: 8),
                    Text(
                      'Seçilen yılda alışveriş bulunmuyor',
                      style: TextStyle(color: Colors.grey),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildYearlySummaryItem(
      String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 4),
          Text(
            title,
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
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
    );
  }

  List<int> _getAvailableYears() {
    final currentYear = DateTime.now().year;
    final years = <int>[];
    for (int year = currentYear; year >= currentYear - 5; year--) {
      years.add(year);
    }
    return years;
  }

  List<DropdownMenuItem<int>> _getMonthItems() {
    const monthNames = [
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

    return List.generate(12, (index) {
      final month = index + 1;
      return DropdownMenuItem(
        value: month,
        child: Text(monthNames[index]),
      );
    });
  }

  void _updateDateRange(String period) {
    final now = DateTime.now();
    switch (period) {
      case 'last_7_days':
        _startDate = now.subtract(const Duration(days: 7));
        _endDate = now;
        break;
      case 'last_30_days':
        _startDate = now.subtract(const Duration(days: 30));
        _endDate = now;
        break;
      case 'this_month':
        _startDate = DateTime(now.year, now.month, 1);
        _endDate = now;
        break;
      case 'this_year':
        _startDate = DateTime(now.year, 1, 1);
        _endDate = now;
        break;
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  String _getMonthName(int month, int year) {
    final monthNames = [
      '',
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
    return '${monthNames[month]} $year';
  }

  String _formatCurrency(double amount) {
    // Türk Lirası formatı: binlik ayırıcı nokta (.), ondalık ayraç virgül (,)
    String formatted = amount.toStringAsFixed(2);

    // Ondalık kısmı ayır
    List<String> parts = formatted.split('.');
    String integerPart = parts[0];
    String decimalPart = parts[1];

    // Binlik ayırıcıları ekle (nokta ile)
    String formattedInteger = '';
    for (int i = 0; i < integerPart.length; i++) {
      if (i > 0 && (integerPart.length - i) % 3 == 0) {
        formattedInteger += '.';
      }
      formattedInteger += integerPart[i];
    }

    // Ondalık kısmı sıfırsa gösterme, değilse virgül ile göster
    if (decimalPart == '00') {
      return '₺$formattedInteger';
    } else {
      return '₺$formattedInteger,$decimalPart';
    }
  }

  void _editSupplier() {
    _showSupplierEditDialog();
  }

  void _showSupplierEditDialog() {
    final nameController = TextEditingController(text: _currentSupplier.name);
    final phoneController =
        TextEditingController(text: _currentSupplier.phone ?? '');
    final addressController =
        TextEditingController(text: _currentSupplier.address ?? '');

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Tedarikçi Düzenle'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'Tedarikçi Adı *',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: phoneController,
                decoration: const InputDecoration(
                  labelText: 'Telefon',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: addressController,
                decoration: const InputDecoration(
                  labelText: 'Adres',
                  border: OutlineInputBorder(),
                ),
                maxLines: 2,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('İptal'),
          ),
          ElevatedButton(
            onPressed: () {
              if (nameController.text.trim().isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Tedarikçi adı zorunludur'),
                    backgroundColor: Colors.red,
                  ),
                );
                return;
              }

              final updatedSupplier = _currentSupplier.copyWith(
                name: nameController.text.trim(),
                phone: phoneController.text.trim().isEmpty
                    ? null
                    : phoneController.text.trim(),
                address: addressController.text.trim().isEmpty
                    ? null
                    : addressController.text.trim(),
                updatedAt: DateTime.now(),
              );

              context.read<SupplierProvider>().updateSupplier(updatedSupplier);

              // Update local state to reflect changes immediately
              setState(() {
                _currentSupplier = updatedSupplier;
              });

              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Tedarikçi güncellendi'),
                  backgroundColor: Colors.green,
                ),
              );
            },
            child: const Text('Güncelle'),
          ),
        ],
      ),
    );
  }

  void _addPayment() {
    // Show payment dialog
    _showPaymentDialog();
  }

  void _addDebt() {
    // Show add purchase dialog
    _showAddPurchaseDialog();
  }

  void _showPurchaseDetails(dynamic purchase) {
    String productName = purchase.productName ?? 'Ürün bilgisi yok';

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          productName,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Tarih: ${_formatDate(purchase.purchaseDate)}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              Text(
                'Toplam Tutar: ${CurrencyFormatter.formatWithSymbol(purchase.amount)}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              if (purchase.notes != null && purchase.notes!.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  'Not: ${purchase.notes}',
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
              const SizedBox(height: 8),
              Text(
                'Ödeme: ${purchase.paymentMethod ?? 'Belirtilmemiş'}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
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

  void _showAddPurchaseDialog() {
    final amountController = TextEditingController();
    final productNameController = TextEditingController();
    DateTime selectedDate = DateTime.now();

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text(
            '${_currentSupplier.name} - Alışveriş Ekle',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Ürün Adı
                TextField(
                  controller: productNameController,
                  decoration: const InputDecoration(
                    labelText: 'Ürün Adı',
                    border: OutlineInputBorder(),
                    hintText: 'Örn: Patates, Domates vb.',
                  ),
                ),
                const SizedBox(height: 16),

                // Toplam Tutar
                TextField(
                  controller: amountController,
                  decoration: const InputDecoration(
                    labelText: 'Toplam Tutar',
                    border: OutlineInputBorder(),
                    prefixText: '₺',
                    hintText: '0.00',
                  ),
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                ),
                const SizedBox(height: 16),

                // Tarih Seçimi
                InkWell(
                  onTap: () async {
                    final DateTime? picked = await showDatePicker(
                      context: context,
                      initialDate: selectedDate,
                      firstDate: DateTime(2020),
                      lastDate: DateTime.now(),
                    );
                    if (picked != null && picked != selectedDate) {
                      setState(() {
                        selectedDate = picked;
                      });
                    }
                  },
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.calendar_today, color: Colors.grey),
                        const SizedBox(width: 8),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Alım Tarihi',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey,
                              ),
                            ),
                            Text(
                              _formatDate(selectedDate),
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                        const Spacer(),
                        const Icon(Icons.arrow_drop_down, color: Colors.grey),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Geçmiş tarihli alışverişler de eklenebilir',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('İptal'),
            ),
            ElevatedButton(
              onPressed: () {
                final productName = productNameController.text.trim();
                final amountText = amountController.text.trim();

                // Validasyon
                if (productName.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Ürün adı girilmelidir')),
                  );
                  return;
                }

                final amount = double.tryParse(amountText) ?? 0;
                if (amount <= 0) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text('Geçerli bir tutar girilmelidir')),
                  );
                  return;
                }

                // Alışverişi kaydet
                _savePurchase(productName, amount, selectedDate);
                Navigator.pop(context);
              },
              child: const Text('Kaydet'),
            ),
          ],
        ),
      ),
    );
  }

  void _savePurchase(
      String productName, double amount, DateTime purchaseDate) async {
    try {
      // ✅ YENİ YÖNTEM: Purchase Provider kullan (Sale değil!)
      final purchaseProvider = context.read<PurchaseProvider>();
      final storeId = widget.supplier.storeId;

      if (storeId.isEmpty) {
        throw Exception('Store ID bulunamadı');
      }

      final purchaseId = await purchaseProvider.createPurchase(
        supplierId: widget.supplier.id!,
        storeId: storeId,
        productName: productName,
        amount: amount,
        purchaseDate: purchaseDate,
        paymentMethod: 'cash',
        notes: 'Tedarikçi alımı',
      );

      if (purchaseId == null) {
        throw Exception('Purchase kaydedilemedi');
      }

    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Hata: $e'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Başarı mesajı
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
            '$productName - ${CurrencyFormatter.formatWithSymbol(amount)} (${_formatDate(purchaseDate)}) eklendi'),
        duration: const Duration(seconds: 3),
      ),
    );

    // Sayfayı yenile
    setState(() {});
  }

  // Alışveriş düzenleme dialog'u
  void _showEditPurchaseDialog(dynamic purchase) {
    final productNameController = TextEditingController(
      text: purchase.productName ?? '',
    );
    final amountController = TextEditingController(
      text: purchase.amount.toString(),
    );
    DateTime selectedDate = purchase.purchaseDate;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Alışveriş Düzenle'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Ürün Adı
                TextField(
                  controller: productNameController,
                  decoration: const InputDecoration(
                    labelText: 'Ürün Adı',
                    border: OutlineInputBorder(),
                    hintText: 'Örn: Patates, Domates vb.',
                  ),
                ),
                const SizedBox(height: 16),

                // Toplam Tutar
                TextField(
                  controller: amountController,
                  decoration: const InputDecoration(
                    labelText: 'Toplam Tutar',
                    border: OutlineInputBorder(),
                    prefixText: '₺',
                    hintText: '0.00',
                  ),
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                ),
                const SizedBox(height: 16),

                // Tarih Seçimi
                InkWell(
                  onTap: () async {
                    final DateTime? picked = await showDatePicker(
                      context: context,
                      initialDate: selectedDate,
                      firstDate: DateTime(2020),
                      lastDate: DateTime.now(),
                    );
                    if (picked != null && picked != selectedDate) {
                      setState(() {
                        selectedDate = picked;
                      });
                    }
                  },
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.calendar_today, color: Colors.grey),
                        const SizedBox(width: 8),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Alım Tarihi',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey,
                              ),
                            ),
                            Text(
                              _formatDate(selectedDate),
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                        const Spacer(),
                        const Icon(Icons.arrow_drop_down, color: Colors.grey),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('İptal'),
            ),
            ElevatedButton(
              onPressed: () {
                final productName = productNameController.text.trim();
                final amountText = amountController.text.trim();

                // Validasyon
                if (productName.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Ürün adı girilmelidir')),
                  );
                  return;
                }

                final amount = double.tryParse(amountText) ?? 0;
                if (amount <= 0) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text('Geçerli bir tutar girilmelidir')),
                  );
                  return;
                }

                // Alışverişi güncelle
                _updatePurchase(purchase, productName, amount, selectedDate);
                Navigator.pop(context);
              },
              child: const Text('Güncelle'),
            ),
          ],
        ),
      ),
    );
  }

  // Alışveriş silme onay dialog'u
  void _confirmDeletePurchase(dynamic purchase) {
    final productName = purchase.productName ?? 'Ürün bilgisi yok';

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Alışveriş Sil'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Bu alışverişi silmek istediğinizden emin misiniz?'),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Ürün: $productName',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Text('Tarih: ${_formatDate(purchase.purchaseDate)}'),
                  Text(
                    'Tutar: ${CurrencyFormatter.formatWithSymbol(purchase.amount)}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.red,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Bu işlem geri alınamaz!',
              style: TextStyle(
                color: Colors.red,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('İptal'),
          ),
          ElevatedButton(
            onPressed: () {
              _deletePurchase(purchase);
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Sil'),
          ),
        ],
      ),
    );
  }

  // Alışveriş güncelleme
  void _updatePurchase(dynamic purchase, String productName, double amount,
      DateTime purchaseDate) async {
    try {
      final purchaseProvider = context.read<PurchaseProvider>();

      // Yeni Purchase objesi oluştur
      final updatedPurchase = Purchase(
        id: purchase.id,
        supplierId: widget.supplier.id!,
        storeId: purchase.storeId,
        productName: productName,
        amount: amount,
        paymentMethod: purchase.paymentMethod ?? 'cash',
        notes: purchase.notes ?? '',
        purchaseDate: purchaseDate,
        createdAt: purchase.createdAt,
        updatedAt: DateTime.now(),
      );

      // Purchase'ı güncelle
      final success = await purchaseProvider.updatePurchase(updatedPurchase);

      if (success) {
        // Başarı mesajı
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$productName alışverişi güncellendi'),
            duration: const Duration(seconds: 2),
          ),
        );

        // Sayfayı yenile
        setState(() {});
      } else {
        throw Exception('Purchase güncellenemedi');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Hata: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // Alışveriş silme
  void _deletePurchase(dynamic purchase) async {
    final productName = purchase.productName ?? 'Ürün bilgisi yok';

    try {
      final purchaseProvider = context.read<PurchaseProvider>();

      // Purchase'ı sil
      final success = await purchaseProvider.deletePurchase(
        purchase.id,
        widget.supplier.id!,
      );

      if (success) {
        // Başarı mesajı
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$productName alışverişi silindi'),
            duration: const Duration(seconds: 2),
            backgroundColor: Colors.red,
          ),
        );

        // Sayfayı yenile
        setState(() {});
      } else {
        throw Exception('Purchase silinemedi');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Hata: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }

    // Sayfayı yenile
    setState(() {});
  }

  // Mali durum bölümü - ✅ YENİ: SupplierProvider kullan
  Widget _buildFinancialStatusSection() {
    return Consumer<SupplierProvider>(
      builder: (context, supplierProvider, child) {
        // ✅ Güncel tedarikçi bilgilerini Firebase'dan al
        final currentSupplier = supplierProvider.suppliers.firstWhere(
            (s) => s.id == widget.supplier.id,
            orElse: () => widget.supplier);

        // ✅ YENİ: Supplier model'den direkt values al
        final totalPurchases = currentSupplier.totalPurchases;
        final monthlyPurchases = currentSupplier.monthlyPurchases;
        final yearlyPurchases = currentSupplier.yearlyPurchases;

        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Mali Durum başlığı
                const Text(
                  'Mali Durum',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),

                // Mali durum verileri - Düz görünüm, container yok
                _buildSimpleFinancialRow(
                    'Toplam Alışveriş', _formatCurrency(totalPurchases)),
                const SizedBox(height: 12),
                _buildSimpleFinancialRow(
                    'Toplam Borç', _formatCurrency(currentSupplier.debt)),
                const SizedBox(height: 12),
                _buildSimpleFinancialRow(
                    'Bu Aylık Alışveriş', _formatCurrency(monthlyPurchases)),
                const SizedBox(height: 12),
                _buildSimpleFinancialRow(
                    'Bu Yılki Alışveriş', _formatCurrency(yearlyPurchases)),
              ],
            ),
          ),
        );
      },
    );
  }

  // Basit mali durum satırı - Sadece yazı, ikon yok
  Widget _buildSimpleFinancialRow(String title, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
            color: Colors.black87,
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
      ],
    );
  }

  // Compact summary card - Overflow problemi olmayan yeni tasarım
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
        _selectedPeriod = 'custom';
      });
    }
  }

  Widget _buildPaymentHistory() {
    return Consumer<SupplierProvider>(
      builder: (context, supplierProvider, child) {
        // Güncel tedarikçi bilgilerini al
        final currentSupplier = supplierProvider.suppliers.firstWhere(
            (s) => s.id == widget.supplier.id,
            orElse: () => widget.supplier);

        return FutureBuilder<List<Map<String, dynamic>>>(
          future: supplierProvider.getPaymentHistory(widget.supplier.id!),
          builder: (context, snapshot) {
            final paymentHistory = snapshot.data ?? [];

            return SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Mevcut Borç Durumu Kartı
                  Card(
                    color: currentSupplier.debt > 0
                        ? Colors.red.shade50
                        : Colors.green.shade50,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                currentSupplier.debt > 0
                                    ? Icons.warning_amber
                                    : Icons.check_circle,
                                color: currentSupplier.debt > 0
                                    ? Colors.red
                                    : Colors.green,
                                size: 24,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Mevcut Borç Durumu',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: currentSupplier.debt > 0
                                      ? Colors.red.shade700
                                      : Colors.green.shade700,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Toplam Borç:',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.grey.shade700,
                                ),
                              ),
                              Text(
                                CurrencyFormatter.formatWithSymbol(
                                    currentSupplier.debt),
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: currentSupplier.debt > 0
                                      ? Colors.red
                                      : Colors.green,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          // Butonları her zaman göster
                          Row(
                            children: [
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed: () => _showAddDebtDialog(),
                                  icon: const Icon(Icons.add, size: 18),
                                  label: const Text('Borç Ekle'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.orange,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 12),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed: () => _showPaymentDialog(),
                                  icon: const Icon(Icons.payment, size: 18),
                                  label: const Text('Ödeme Yap'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.green,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 12),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Ödeme Geçmişi Listesi
                  const Text(
                    'Ödeme Geçmişi',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),

                  if (snapshot.connectionState == ConnectionState.waiting)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.all(32),
                        child: CircularProgressIndicator(),
                      ),
                    )
                  else if (paymentHistory.isEmpty)
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: Column(
                          children: [
                            Icon(
                              Icons.payment_outlined,
                              size: 64,
                              color: Colors.grey.shade400,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Henüz ödeme yapılmamış',
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.grey.shade600,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Bu tedarikçiye yapılan ödemeler ve borçlar burada görünecek',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey.shade500,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: paymentHistory.length,
                      itemBuilder: (context, index) {
                        final payment = paymentHistory[index];
                        return _buildPaymentCard(payment);
                      },
                    ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildPaymentCard(Map<String, dynamic> payment) {
    final DateTime createdAt = DateTime.parse(payment['created_at']);
    final String formattedDate = _formatDate(createdAt);
    final double previousDebt = payment['previous_debt']?.toDouble() ?? 0.0;
    final double newDebt = payment['new_debt']?.toDouble() ?? 0.0;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor:
              payment['type'] == 'payment' ? Colors.green : Colors.orange,
          child: Icon(
            payment['type'] == 'payment' ? Icons.payment : Icons.add_circle,
            color: Colors.white,
            size: 20,
          ),
        ),
        title: Text(
          payment['type'] == 'payment' ? 'Ödeme' : 'Borç Eklendi',
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '$formattedDate • ${payment['description'] ?? 'Açıklama yok'}',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: payment['type'] == 'payment'
                    ? Colors.green.shade50
                    : Colors.orange.shade50,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(
                  color: payment['type'] == 'payment'
                      ? Colors.green.shade200
                      : Colors.orange.shade200,
                ),
              ),
              child: Text(
                'Önceki Borç: ${CurrencyFormatter.formatWithSymbol(previousDebt)} → Yeni Borç: ${CurrencyFormatter.formatWithSymbol(newDebt)}',
                style: TextStyle(
                  fontSize: 10,
                  color: payment['type'] == 'payment'
                      ? Colors.green.shade700
                      : Colors.orange.shade700,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
        trailing: Text(
          CurrencyFormatter.formatWithSymbol(payment['amount']),
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: payment['type'] == 'payment' ? Colors.green : Colors.orange,
          ),
        ),
        isThreeLine: true,
      ),
    );
  }

  void _showPaymentDialog() {
    final amountController = TextEditingController();
    final descriptionController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Ödeme Yap'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: amountController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Ödeme Tutarı',
                prefixText: '₺',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: descriptionController,
              decoration: const InputDecoration(
                labelText: 'Açıklama (İsteğe Bağlı)',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('İptal'),
          ),
          ElevatedButton(
            onPressed: () async {
              final amount = double.tryParse(amountController.text);
              if (amount != null && amount > 0) {
                await Provider.of<SupplierProvider>(context, listen: false)
                    .makePayment(widget.supplier.id.toString(), amount);
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                        '${CurrencyFormatter.formatWithSymbol(amount)} ödeme yapıldı'),
                    backgroundColor: Colors.green,
                  ),
                );
                // Sayfayı yenile
                setState(() {});
              }
            },
            child: const Text('Ödeme Yap'),
          ),
        ],
      ),
    );
  }

  void _showAddDebtDialog() {
    final amountController = TextEditingController();
    final descriptionController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Borç Ekle'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: amountController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Borç Tutarı',
                prefixText: '₺',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: descriptionController,
              decoration: const InputDecoration(
                labelText: 'Açıklama (İsteğe Bağlı)',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('İptal'),
          ),
          ElevatedButton(
            onPressed: () async {
              final amount = double.tryParse(amountController.text);
              if (amount != null && amount > 0) {
                await Provider.of<SupplierProvider>(context, listen: false)
                    .addDebt(widget.supplier.id!, amount);
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                        '${CurrencyFormatter.formatWithSymbol(amount)} borç eklendi'),
                    backgroundColor: Colors.orange,
                  ),
                );
                // Sayfayı yenile
                setState(() {});
              }
            },
            child: const Text('Borç Ekle'),
          ),
        ],
      ),
    );
  }
}
