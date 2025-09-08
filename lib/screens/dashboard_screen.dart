import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:stock_management_app/screens/firestore_test_page.dart';
import '../providers/product_provider.dart';
import '../providers/sales_provider.dart';
import '../providers/supplier_provider.dart';
import '../providers/app_provider.dart';
import '../providers/notification_provider.dart';
import '../utils/currency_formatter.dart';
import '../widgets/multi_user_indicators_widget.dart';
import '../widgets/live_product_widget.dart';
import '../widgets/live_sales_widget.dart';
import '../services/firebase_auth_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../widgets/store_menu_widget.dart';
import '../screens/team_management/team_list_screen.dart';
import 'price_check_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  Future<Map<String, dynamic>?> _getCurrentUser() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      return {
        'uid': user.uid,
        'email': user.email,
        'storeId':
            'default_store', // Bu kısım gerçek store ID ile değiştirilmeli
      };
    }
    return null;
  }

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
      body: RefreshIndicator(
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

              // Multi-User Indicators
              FutureBuilder<Map<String, dynamic>?>(
                future: _getCurrentUser(),
                builder: (context, snapshot) {
                  if (snapshot.hasData && snapshot.data != null) {
                    final user = snapshot.data!;
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Takım Durumu',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 16),
                        MultiUserIndicatorsWidget(
                          storeId: user['storeId'] ?? '',
                          currentUserId: user['uid'] ?? '',
                        ),
                        const SizedBox(height: 24),
                      ],
                    );
                  }
                  return const SizedBox.shrink();
                },
              ),

              // Live Data Widgets
              const Text(
                'Anlık Veriler',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              const LiveProductWidget(),
              const SizedBox(height: 16),
              const LiveSalesWidget(),

              const SizedBox(height: 24),

              // Quick Actions
              const Text(
                'Hızlı İşlemler',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.science),
                tooltip: 'Test',
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                        builder: (_) => const FirestoreTestPage()),
                  );
                },
              ),
              const SizedBox(height: 16),
              _buildQuickActions(context),

              const SizedBox(height: 24),
            ],
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

                // Toplam tedarikçi borcunu hesapla
                double totalDebt = supplierProvider.getTotalDebt();

                return Wrap(
                  spacing: 16,
                  runSpacing: 16,
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
                      'Toptancı Borcum',
                      CurrencyFormatter.formatWithSymbol(totalDebt),
                      Icons.people,
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
          'Fiyat Kontrol',
          Icons.qr_code_scanner,
          Colors.teal,
          () => _openPriceCheck(context),
        ),
        _buildQuickActionButton(
          'Raporlar',
          Icons.analytics,
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
    showModalBottomSheet(
      context: context,
      builder: (context) => Consumer<NotificationProvider>(
        builder: (context, notificationProvider, child) {
          if (notificationProvider.notifications.isEmpty) {
            return const SizedBox(
              height: 200,
              child: Center(
                child: Text('Henüz bildirim bulunmuyor.'),
              ),
            );
          }

          return Container(
            height: MediaQuery.of(context).size.height * 0.6,
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Bildirimler',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: ListView.builder(
                    itemCount: notificationProvider.notifications.length,
                    itemBuilder: (context, index) {
                      final notification =
                          notificationProvider.notifications[index];
                      return Card(
                        color: notification.isRead ? null : Colors.blue.shade50,
                        child: ListTile(
                          leading: Icon(
                            _getNotificationIcon(notification.type),
                            color: _getNotificationColor(notification.type),
                          ),
                          title: Text(notification.title),
                          subtitle: Text(notification.message),
                          trailing: IconButton(
                            icon: const Icon(Icons.close),
                            onPressed: () => notificationProvider
                                .removeNotification(notification.id),
                          ),
                          onTap: () =>
                              notificationProvider.markAsRead(notification.id),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  IconData _getNotificationIcon(NotificationType type) {
    switch (type) {
      case NotificationType.lowStock:
        return Icons.inventory;
      case NotificationType.debt:
        return Icons.account_balance;
      case NotificationType.general:
        return Icons.info;
    }
  }

  Color _getNotificationColor(NotificationType type) {
    switch (type) {
      case NotificationType.lowStock:
        return Colors.orange;
      case NotificationType.debt:
        return Colors.red;
      case NotificationType.general:
        return Colors.blue;
    }
  }

  void _openPriceCheck(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const PriceCheckScreen(),
      ),
    );
  }
}
