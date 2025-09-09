import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:stock_management_app/screens/firestore_test_page.dart';
import '../providers/product_provider.dart';
import '../providers/sales_provider.dart';
import '../providers/supplier_provider.dart';
import '../providers/app_provider.dart';
import '../providers/notification_provider.dart';
import '../utils/currency_formatter.dart';
import '../widgets/store_menu_widget.dart';
import 'price_check_screen.dart';
import 'notifications_screen.dart';
import 'qr_product_analysis_screen.dart';
import 'firebase_auth_screen.dart';
import 'team_management_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  @override
  void initState() {
    super.initState();
    // Post frame callback ile async işlemleri geciktir
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadData();
    });
  }

  Future<void> _loadData() async {
    try {
      // Don't load any data initially - let each screen load its own data when needed
      // This prevents memory overload at startup
      // Debug print removed
    } catch (e) {
      // Debug print removed
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: const StoreMenuWidget(),
      appBar: AppBar(
        title: const Text('Stok Takip - Ana Sayfa'),
        actions: [
          // Firebase sync button - DEVRE DIŞI
          Consumer<AppProvider>(
            builder: (context, appProvider, child) {
              return IconButton(
                icon: const Icon(Icons.cloud_off, color: Colors.grey),
                onPressed: null, // Devre dışı
                tooltip: 'Giriş sistemi yenileniyor',
              );
            },
          ),
          Consumer<NotificationProvider>(
            builder: (context, notificationProvider, child) {
              return IconButton(
                icon: Stack(
                  children: [
                    const Icon(Icons.notifications),
                    if (notificationProvider.unreadCount > 0)
                      Positioned(
                        right: 0,
                        top: 0,
                        child: Container(
                          padding: const EdgeInsets.all(2),
                          decoration: BoxDecoration(
                            color: Colors.red,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          constraints: const BoxConstraints(
                            minWidth: 12,
                            minHeight: 12,
                          ),
                          child: Text(
                            '${notificationProvider.unreadCount}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 8,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                  ],
                ),
                onPressed: () => _showNotifications(context),
              );
            },
          ),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            await _loadData();
          },
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Summary Cards
                const Text(
                  'Genel Durum',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                _buildSummaryCards(context),

                const SizedBox(height: 24),

                // Quick Actions
                const Text(
                  'Hızlı İşlemler',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                _buildQuickActions(context),

                const SizedBox(height: 80), // Bottom navigation için ek alan
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryCards(BuildContext context) {
    return Consumer<ProductProvider>(
      builder: (context, productProvider, child) {
        return Consumer<SalesProvider>(
          builder: (context, salesProvider, child) {
            return Consumer<SupplierProvider>(
              builder: (context, supplierProvider, child) {
                // Bugünkü satış tutarını hesapla
                DateTime today = DateTime.now();
                DateTime startOfDay =
                    DateTime(today.year, today.month, today.day);
                DateTime endOfDay =
                    DateTime(today.year, today.month, today.day, 23, 59, 59);

                double dailySales = salesProvider.getTotalSalesAmount(
                  startDate: startOfDay,
                  endDate: endOfDay,
                );

                // Gerçek günlük kâr hesaplama (satış fiyatı - alış fiyatı)
                double dailyProfit =
                    salesProvider.getDailyProfit(productProvider);

                return LayoutBuilder(
                  builder: (context, constraints) {
                    return GridView.count(
                      crossAxisCount: 2,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      mainAxisSpacing: 12,
                      crossAxisSpacing: 12,
                      childAspectRatio: 1.2,
                      children: [
                        _buildSummaryCard(
                          'Toplam Ürün',
                          '${productProvider.products.length}',
                          Icons.inventory,
                          Colors.blue,
                        ),
                        _buildSummaryCard(
                          'Günlük Satış',
                          CurrencyFormatter.formatWithSymbol(dailySales),
                          Icons.trending_up,
                          Colors.green,
                        ),
                        _buildSummaryCard(
                          'Günlük Kâr',
                          CurrencyFormatter.formatWithSymbol(dailyProfit),
                          Icons.monetization_on,
                          Colors.orange,
                        ),
                        _buildSummaryCard(
                          'Stok Değeri',
                          CurrencyFormatter.formatWithSymbol(
                              _calculateStockValue(productProvider.products)),
                          Icons.account_balance_wallet,
                          Colors.purple,
                        ),
                      ],
                    );
                  },
                );
              },
            );
          },
        );
      },
    );
  }

  double _calculateStockValue(List products) {
    if (products.isEmpty) return 0.0;
    return products.fold(0.0, (total, product) {
      try {
        final stock = product.stock ?? 0;
        final price = product.purchasePrice ?? 0.0;
        return total + (stock * price);
      } catch (e) {
        return total;
      }
    });
  }

  Widget _buildSummaryCard(
      String title, String value, IconData icon, Color color) {
    final screenWidth = MediaQuery.of(context).size.width;
    final cardWidth =
        (screenWidth - 48) / 2; // 16 padding each side + 16 spacing

    return SizedBox(
      width: cardWidth,
      child: Card(
        elevation: 4,
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            gradient: LinearGradient(
              colors: [
                color.withValues(alpha: 0.1),
                color.withValues(alpha: 0.05)
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 28,
                color: color,
              ),
              const SizedBox(height: 6),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: Colors.grey,
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
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
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQuickActions(BuildContext context) {
    return Wrap(
      spacing: 16,
      runSpacing: 16,
      children: [
        _buildQuickActionButton(
          'Ürün Ekle',
          Icons.add_box,
          Colors.blue,
          () => context.read<AppProvider>().setCurrentPage(1),
        ),
        _buildQuickActionButton(
          'Satış Yap',
          Icons.point_of_sale,
          Colors.green,
          () => context.read<AppProvider>().setCurrentPage(2),
        ),
        _buildQuickActionButton(
          'Takım Yönetimi',
          Icons.group,
          Colors.indigo,
          () => _openTeamManagement(context),
        ),
        _buildQuickActionButton(
          'Ürün Analizi',
          Icons.analytics,
          Colors.teal,
          () => _openProductAnalysis(context),
        ),
        _buildQuickActionButton(
          'Fiyat Kontrol',
          Icons.qr_code_scanner,
          Colors.orange,
          () => _openPriceCheck(context),
        ),
        _buildQuickActionButton(
          'Raporlar',
          Icons.assessment,
          Colors.purple,
          () => context.read<AppProvider>().setCurrentPage(4),
        ),
      ],
    );
  }

  Widget _buildQuickActionButton(
      String title, IconData icon, Color color, VoidCallback onTap) {
    final screenWidth = MediaQuery.of(context).size.width;
    final buttonWidth =
        (screenWidth - 48) / 2; // 16 padding each side + 16 spacing

    return SizedBox(
      width: buttonWidth,
      child: Card(
        elevation: 2,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Icon(
                  icon,
                  size: 20,
                  color: color,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showNotifications(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const NotificationsScreen(),
      ),
    );
  }

  void _handleFirebaseSync(BuildContext context) async {
    final appProvider = Provider.of<AppProvider>(context, listen: false);

    if (!appProvider.isLoggedIn) {
      // Show Firebase auth screen
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => const FirebaseAuthScreen(),
        ),
      );
      return;
    }

    // Show sync options dialog
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.7,
        ),
        child: Consumer<AppProvider>(
          builder: (context, appProvider, child) {
            return SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Bulut Senkronizasyonu',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Sync status
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: appProvider.isLoggedIn
                          ? Colors.green.shade100
                          : Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          appProvider.isLoggedIn
                              ? Icons.cloud_done
                              : Icons.cloud_off,
                          color: appProvider.isLoggedIn
                              ? Colors.green
                              : Colors.grey,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                appProvider.isLoggedIn
                                    ? 'Firebase\'e bağlı'
                                    : 'Firebase\'e bağlı değil',
                                style: const TextStyle(
                                    fontWeight: FontWeight.w500),
                              ),
                              if (appProvider.lastSyncTime != null)
                                Text(
                                  'Son senkronizasyon: ${_formatDateTime(appProvider.lastSyncTime!)}',
                                  style: const TextStyle(fontSize: 12),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Sync buttons
                  if (appProvider.isLoggedIn) ...[
                    ListTile(
                      leading: const Icon(Icons.sync),
                      title: const Text('Tam Senkronizasyon'),
                      subtitle:
                          const Text('Yerel ve bulut verilerini senkronize et'),
                      onTap: appProvider.isSyncing
                          ? null
                          : () async {
                              Navigator.pop(context);
                              await appProvider.performSync();
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      appProvider.syncError != null
                                          ? 'Senkronizasyon hatası: ${appProvider.syncError}'
                                          : 'Senkronizasyon tamamlandı!',
                                    ),
                                    backgroundColor:
                                        appProvider.syncError != null
                                            ? Colors.red
                                            : Colors.green,
                                  ),
                                );
                              }
                            },
                    ),
                    ListTile(
                      leading: const Icon(Icons.cloud_upload),
                      title: const Text('Buluta Yükle'),
                      subtitle: const Text('Yerel verileri buluta gönder'),
                      onTap: appProvider.isSyncing
                          ? null
                          : () async {
                              Navigator.pop(context);
                              await appProvider.syncToCloud();
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      appProvider.syncError != null
                                          ? 'Yükleme hatası: ${appProvider.syncError}'
                                          : 'Veriler buluta yüklendi!',
                                    ),
                                    backgroundColor:
                                        appProvider.syncError != null
                                            ? Colors.red
                                            : Colors.green,
                                  ),
                                );
                              }
                            },
                    ),
                    ListTile(
                      leading: const Icon(Icons.cloud_download),
                      title: const Text('Buluttan İndir'),
                      subtitle: const Text(
                          'Bulut verilerini yerel veritabanına indir'),
                      onTap: appProvider.isSyncing
                          ? null
                          : () async {
                              Navigator.pop(context);
                              await appProvider.syncFromCloud();
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      appProvider.syncError != null
                                          ? 'İndirme hatası: ${appProvider.syncError}'
                                          : 'Veriler buluttan indirildi!',
                                    ),
                                    backgroundColor:
                                        appProvider.syncError != null
                                            ? Colors.red
                                            : Colors.green,
                                  ),
                                );
                              }
                            },
                    ),
                    const Divider(),
                    ListTile(
                      leading: const Icon(Icons.logout, color: Colors.red),
                      title: const Text('Çıkış Yap',
                          style: TextStyle(color: Colors.red)),
                      subtitle:
                          const Text('Farklı hesap ile giriş yapabilirsiniz'),
                      onTap: () => _showLogoutDialog(context),
                    ),
                  ],
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.day}/${dateTime.month}/${dateTime.year} ${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
  }

  void _openPriceCheck(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const PriceCheckScreen(),
      ),
    );
  }

  void _openTeamManagement(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const TeamManagementScreen(),
      ),
    );
  }

  void _openProductAnalysis(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const QRProductAnalysisScreen(),
      ),
    );
  }

  void _showLogoutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Çıkış Yap'),
          content: const Text(
              'Hesabınızdan çıkış yapmak istediğinizden emin misiniz?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('İptal'),
            ),
            ElevatedButton(
              onPressed: () => _performLogout(context),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: const Text('Çıkış Yap',
                  style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  void _performLogout(BuildContext context) async {
    try {
      // Dialog'u kapat
      Navigator.of(context).pop();

      // Loading göster
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext context) {
          return const AlertDialog(
            content: Row(
              children: [
                CircularProgressIndicator(),
                SizedBox(width: 20),
                Text('Çıkış yapılıyor...'),
              ],
            ),
          );
        },
      );

      // Firebase'den çıkış yap
      final appProvider = context.read<AppProvider>();
      await appProvider.signOut();

      // Loading dialog'unu kapat
      if (mounted) Navigator.of(context).pop();

      // Login screen'e git ve tüm geçmiş sayfaları temizle
      if (mounted) {
        Navigator.of(context).pushNamedAndRemoveUntil(
          '/login',
          (Route<dynamic> route) => false,
        );
      }
    } catch (e) {
      // Loading dialog'unu kapat
      if (mounted) Navigator.of(context).pop();

      // Hata mesajı göster
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Çıkış yapılırken hata oluştu: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
