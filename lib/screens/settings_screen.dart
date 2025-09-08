import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/theme_provider.dart';
import '../providers/product_provider.dart';
import '../providers/sales_provider.dart';
import '../providers/supplier_provider.dart';
import '../providers/notification_provider.dart';
import '../services/connectivity_service.dart';
import '../services/offline_service.dart';
import '../services/database_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Ayarlar'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Görünüm Ayarları
            _buildSectionHeader('Görünüm'),
            _buildThemeSettings(),

            const SizedBox(height: 24),

            // Bağlantı Ayarları
            _buildSectionHeader('Bağlantı ve Senkronizasyon'),
            _buildConnectivitySettings(),

            const SizedBox(height: 24),

            // İş Ayarları
            _buildSectionHeader('İş Ayarları'),
            _buildBusinessSettings(),

            const SizedBox(height: 24),

            // Sistem Ayarları
            _buildSectionHeader('Sistem'),
            _buildSystemSettings(),

            const SizedBox(height: 24),

            // Veri Yönetimi
            _buildSectionHeader('Veri Yönetimi'),
            _buildDataManagement(),

            const SizedBox(height: 24),

            // Hakkında
            _buildSectionHeader('Hakkında'),
            _buildAboutSection(),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: Colors.blue,
        ),
      ),
    );
  }

  Widget _buildThemeSettings() {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, child) {
        return Card(
          child: Column(
            children: [
              ListTile(
                leading: const Icon(Icons.palette),
                title: const Text('Tema'),
                subtitle: Text(_getThemeName(themeProvider.themeMode)),
                trailing: const Icon(Icons.arrow_forward_ios),
                onTap: () => _showThemeDialog(),
              ),
              ListTile(
                leading: const Icon(Icons.dark_mode),
                title: const Text('Karanlık Mod'),
                trailing: Switch(
                  value: themeProvider.themeMode == ThemeMode.dark,
                  onChanged: (value) {
                    themeProvider.setThemeMode(
                      value ? ThemeMode.dark : ThemeMode.light,
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildConnectivitySettings() {
    return Consumer2<ConnectivityService, OfflineService>(
      builder: (context, connectivity, offline, child) {
        return Card(
          child: Column(
            children: [
              ListTile(
                leading: Icon(
                  connectivity.getConnectionIcon(),
                  color: connectivity.getConnectionColor(),
                ),
                title: const Text('İnternet Bağlantısı'),
                subtitle: Text(connectivity.getConnectionStatusText()),
                trailing: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: connectivity.isOnline ? Colors.green : Colors.red,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    connectivity.isOnline ? 'Çevrimiçi' : 'Çevrimdışı',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              if (offline.hasPendingOperations) ...[
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.sync_problem, color: Colors.orange),
                  title: const Text('Bekleyen İşlemler'),
                  subtitle: Text(
                      '${offline.pendingOperationsCount} işlem senkronize edilmeyi bekliyor'),
                  trailing: connectivity.isOnline
                      ? IconButton(
                          onPressed: () => _showSyncDialog(),
                          icon: const Icon(Icons.sync),
                          tooltip: 'Senkronize Et',
                        )
                      : const Icon(Icons.wifi_off, color: Colors.grey),
                ),
              ],
              if (offline.hasPendingOperations) ...[
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.storage),
                  title: const Text('Offline Veri Boyutu'),
                  subtitle: Text(offline.getDataSizeEstimate()),
                  trailing: TextButton(
                    onPressed: () => _showOfflineDataDialog(),
                    child: const Text('Detay'),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildBusinessSettings() {
    return Card(
      child: Column(
        children: [
          ListTile(
            leading: const Icon(Icons.store),
            title: const Text('İş Yeri Bilgileri'),
            subtitle: const Text('Mağaza adı, adres, vergi bilgileri'),
            trailing: const Icon(Icons.arrow_forward_ios),
            onTap: () => _showBusinessInfoDialog(),
          ),
          ListTile(
            leading: const Icon(Icons.receipt),
            title: const Text('Fiş Ayarları'),
            subtitle: const Text('Fiş başlığı, alt bilgi, logo'),
            trailing: const Icon(Icons.arrow_forward_ios),
            onTap: () => _showReceiptSettingsDialog(),
          ),
          ListTile(
            leading: const Icon(Icons.warning),
            title: const Text('Stok Uyarıları'),
            subtitle: const Text('Minimum stok seviyesi bildirimleri'),
            trailing: Switch(
              value: true, // Bu değer shared preferences'dan gelecek
              onChanged: (value) {
                // Burada stok uyarı ayarı kaydedilecek
              },
            ),
          ),
          ListTile(
            leading: const Icon(Icons.local_offer),
            title: const Text('Vergi Oranı'),
            subtitle: const Text('KDV ve diğer vergi ayarları'),
            trailing: const Icon(Icons.arrow_forward_ios),
            onTap: () => _showTaxSettingsDialog(),
          ),
        ],
      ),
    );
  }

  Widget _buildSystemSettings() {
    return Card(
      child: Column(
        children: [
          Consumer<NotificationProvider>(
            builder: (context, notificationProvider, child) {
              return SwitchListTile(
                secondary: const Icon(Icons.notifications),
                title: const Text('Bildirimler'),
                subtitle: const Text('Stok uyarı bildirimleri'),
                value: notificationProvider.stockAlertsEnabled,
                onChanged: (bool value) {
                  notificationProvider.setStockAlertsEnabled(value);
                },
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.language),
            title: const Text('Dil'),
            subtitle: const Text('Türkçe'),
            trailing: const Icon(Icons.arrow_forward_ios),
            onTap: () => _showLanguageDialog(),
          ),
          ListTile(
            leading: const Icon(Icons.currency_exchange),
            title: const Text('Para Birimi'),
            subtitle: const Text('Türk Lirası (₺)'),
            trailing: const Icon(Icons.arrow_forward_ios),
            onTap: () => _showCurrencyDialog(),
          ),
          ListTile(
            leading: const Icon(Icons.security),
            title: const Text('Güvenlik'),
            subtitle: const Text('PIN kodu, yedekleme ayarları'),
            trailing: const Icon(Icons.arrow_forward_ios),
            onTap: () => _showSecurityDialog(),
          ),
        ],
      ),
    );
  }

  Widget _buildDataManagement() {
    return Card(
      child: Column(
        children: [
          ListTile(
            leading: const Icon(Icons.backup),
            title: const Text('Veri Yedekleme'),
            subtitle: const Text('Verileri yedekle ve geri yükle'),
            trailing: const Icon(Icons.arrow_forward_ios),
            onTap: () => _showBackupDialog(),
          ),
          ListTile(
            leading: const Icon(Icons.file_download),
            title: const Text('Veri Dışa Aktarma'),
            subtitle: const Text('Excel, PDF formatında rapor al'),
            trailing: const Icon(Icons.arrow_forward_ios),
            onTap: () => _showExportDialog(),
          ),
          ListTile(
            leading: const Icon(Icons.delete_forever),
            title: const Text('Tüm Verileri Sil'),
            subtitle: const Text('Dikkat: Bu işlem geri alınamaz'),
            trailing: const Icon(Icons.arrow_forward_ios),
            onTap: () => _showDeleteAllDataDialog(),
          ),
        ],
      ),
    );
  }

  Widget _buildAboutSection() {
    return Card(
      child: Column(
        children: [
          ListTile(
            leading: const Icon(Icons.info),
            title: const Text('Uygulama Bilgileri'),
            subtitle: const Text('Sürüm 1.0.0'),
            trailing: const Icon(Icons.arrow_forward_ios),
            onTap: () => _showAppInfoDialog(),
          ),
          ListTile(
            leading: const Icon(Icons.privacy_tip),
            title: const Text('Gizlilik Politikası'),
            trailing: const Icon(Icons.arrow_forward_ios),
            onTap: () => _showPrivacyPolicyDialog(),
          ),
          ListTile(
            leading: const Icon(Icons.help),
            title: const Text('Yardım ve Destek'),
            trailing: const Icon(Icons.arrow_forward_ios),
            onTap: () => _showHelpDialog(),
          ),
          ListTile(
            leading: const Icon(Icons.star),
            title: const Text('Uygulamayı Değerlendir'),
            trailing: const Icon(Icons.arrow_forward_ios),
            onTap: () => _showRateAppDialog(),
          ),
        ],
      ),
    );
  }

  String _getThemeName(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.light:
        return 'Açık Tema';
      case ThemeMode.dark:
        return 'Koyu Tema';
      case ThemeMode.system:
        return 'Sistem Ayarı';
    }
  }

  void _showThemeDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Tema Seçin'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            RadioListTile<ThemeMode>(
              title: const Text('Açık Tema'),
              value: ThemeMode.light,
              groupValue: context.read<ThemeProvider>().themeMode,
              onChanged: (value) {
                context.read<ThemeProvider>().setThemeMode(value!);
                Navigator.pop(context);
              },
            ),
            RadioListTile<ThemeMode>(
              title: const Text('Koyu Tema'),
              value: ThemeMode.dark,
              groupValue: context.read<ThemeProvider>().themeMode,
              onChanged: (value) {
                context.read<ThemeProvider>().setThemeMode(value!);
                Navigator.pop(context);
              },
            ),
            RadioListTile<ThemeMode>(
              title: const Text('Sistem Ayarı'),
              value: ThemeMode.system,
              groupValue: context.read<ThemeProvider>().themeMode,
              onChanged: (value) {
                context.read<ThemeProvider>().setThemeMode(value!);
                Navigator.pop(context);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showSyncDialog() {
    final offline = context.read<OfflineService>();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Veri Senkronizasyonu'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
                '${offline.pendingOperationsCount} işlem senkronize edilecek:'),
            const SizedBox(height: 16),
            ...offline.getPendingOperationsSummary().entries.map(
                  (entry) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Row(
                      children: [
                        Icon(_getOperationIcon(entry.key), size: 16),
                        const SizedBox(width: 8),
                        Text('${entry.key}: ${entry.value} işlem'),
                      ],
                    ),
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
              Navigator.pop(context);
              await offline.syncPendingOperations();
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Senkronizasyon tamamlandı'),
                    backgroundColor: Colors.green,
                  ),
                );
              }
            },
            child: const Text('Senkronize Et'),
          ),
        ],
      ),
    );
  }

  void _showOfflineDataDialog() {
    final offline = context.read<OfflineService>();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Offline Veri Detayları'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Toplam veri boyutu: ${offline.getDataSizeEstimate()}'),
            const SizedBox(height: 16),
            const Text('İşlem türlerine göre dağılım:'),
            const SizedBox(height: 8),
            ...offline.getPendingOperationsSummary().entries.map(
                  (entry) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Row(
                      children: [
                        Icon(_getOperationIcon(entry.key), size: 16),
                        const SizedBox(width: 8),
                        Expanded(child: Text(entry.key)),
                        Text('${entry.value}'),
                      ],
                    ),
                  ),
                ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Kapat'),
          ),
          if (offline.hasPendingOperations)
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                _showClearOfflineDataDialog();
              },
              child: const Text('Temizle', style: TextStyle(color: Colors.red)),
            ),
        ],
      ),
    );
  }

  void _showClearOfflineDataDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Offline Veriyi Temizle'),
        content: const Text(
          'Tüm bekleyen işlemler silinecek. Bu işlem geri alınamaz. Emin misiniz?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('İptal'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await context.read<OfflineService>().clearPendingOperations();
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Offline veriler temizlendi'),
                    backgroundColor: Colors.orange,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Temizle', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  IconData _getOperationIcon(String operationType) {
    switch (operationType.toLowerCase()) {
      case 'sales':
      case 'satış':
        return Icons.point_of_sale;
      case 'products':
      case 'ürün':
        return Icons.inventory;
      case 'suppliers':
      case 'tedarikçi':
        return Icons.business;
      default:
        return Icons.sync;
    }
  }

  // Placeholder methods for other dialogs
  void _showBusinessInfoDialog() {
    // TODO: Implement business info dialog
  }

  void _showReceiptSettingsDialog() {
    // TODO: Implement receipt settings dialog
  }

  void _showTaxSettingsDialog() {
    // TODO: Implement tax settings dialog
  }

  void _showLanguageDialog() {
    // TODO: Implement language dialog
  }

  void _showCurrencyDialog() {
    // TODO: Implement currency dialog
  }

  void _showSecurityDialog() {
    // TODO: Implement security dialog
  }

  void _showBackupDialog() {
    // TODO: Implement backup dialog
  }

  void _showExportDialog() {
    // TODO: Implement export dialog
  }

  void _showDeleteAllDataDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text(
          'Tüm Verileri Sil',
          style: TextStyle(color: Colors.red),
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Bu işlem tüm verileri kalıcı olarak silecektir:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            Text('• Tüm ürünler'),
            Text('• Tüm satışlar'),
            Text('• Tüm müşteriler'),
            Text('• Tüm tedarikçiler'),
            Text('• Tüm kasa işlemleri'),
            Text('• Tüm ödeme geçmişi'),
            SizedBox(height: 16),
            Text(
              'Bu işlem GERİ ALINAMAZ!',
              style: TextStyle(
                color: Colors.red,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Emin misiniz?',
              style: TextStyle(fontSize: 16),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('İptal'),
          ),
          ElevatedButton(
            onPressed: () => _confirmDeleteAllData(),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Evet, Tümünü Sil'),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteAllData() {
    Navigator.pop(context); // Close first dialog

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text(
          'SON UYARI',
          style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
        ),
        content: const Text(
          'Bu işlemi onaylarsanız TÜM VERİLER silinecektir.\n\nBu işlem kesinlikle geri alınamaz!\n\nDevam etmek istediğinizden emin misiniz?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Hayır, İptal Et'),
          ),
          ElevatedButton(
            onPressed: () => _deleteAllData(),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('EVET, SİL'),
          ),
        ],
      ),
    );
  }

  void _deleteAllData() async {
    Navigator.pop(context); // Close confirmation dialog

    // Show loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const AlertDialog(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Veriler siliniyor...'),
          ],
        ),
      ),
    );

    try {
      // Clear database
      await DatabaseService.instance.clearAllUserData();

      // Reload all providers
      if (mounted) {
        await context.read<ProductProvider>().loadProducts();
        await context.read<SalesProvider>().loadSales();
        await context.read<SupplierProvider>().loadSuppliers();
      }

      // Close loading dialog
      if (mounted) Navigator.pop(context);

      // Show success message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Tüm veriler başarıyla silindi'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      // Close loading dialog
      if (mounted) Navigator.pop(context);

      // Show error message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Hata: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

  void _showAppInfoDialog() {
    // TODO: Implement app info dialog
  }

  void _showPrivacyPolicyDialog() {
    // TODO: Implement privacy policy dialog
  }

  void _showHelpDialog() {
    // TODO: Implement help dialog
  }

  void _showRateAppDialog() {
    // TODO: Implement rate app dialog
  }
}




