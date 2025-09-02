import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../screens/settings_screen.dart';
import '../screens/store_management_screen.dart';
import '../screens/profile_management_screen.dart';

class StoreMenuWidget extends StatefulWidget {
  const StoreMenuWidget({super.key});

  @override
  State<StoreMenuWidget> createState() => _StoreMenuWidgetState();
}

class _StoreMenuWidgetState extends State<StoreMenuWidget> {
  String _userName = 'Kullanıcı';
  String _storeName = 'Mağaza';

  @override
  void initState() {
    super.initState();
    _loadUserInfo();
  }

  Future<void> _loadUserInfo() async {
    try {
      final userSession = AuthService.instance.currentSession;
      if (userSession != null) {
        setState(() {
          _userName = userSession.userName;
          _storeName = userSession.storeName;
        });
      }
    } catch (e) {
      // Debug print removed
    }
  }

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          _buildDrawerHeader(),

          // Ana Özellikler
          _buildMenuItem(
            icon: Icons.store,
            title: 'Mağaza Yönetimi',
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const StoreManagementScreen(),
                ),
              );
            },
          ),
          _buildMenuItem(
            icon: Icons.person,
            title: 'Profil Yönetimi',
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const ProfileManagementScreen(),
                ),
              );
            },
          ),
          _buildMenuItem(
            icon: Icons.business_center,
            title: 'Mağaza Bilgileri',
            onTap: () {
              Navigator.pop(context);
              _showStoreInfoDialog(context);
            },
          ),

          const Divider(),

          // Ödeme ve Premium
          _buildMenuItem(
            icon: Icons.payment,
            title: 'Ödeme Yöntemleri',
            onTap: () {
              Navigator.pop(context);
              _showPaymentMethodsDialog(context);
            },
          ),
          _buildMenuItem(
            icon: Icons.workspace_premium,
            title: 'Premium\'a Geç',
            onTap: () {
              Navigator.pop(context);
              _showPremiumDialog(context);
            },
            iconColor: Colors.amber,
            textColor: Colors.amber[700],
          ),

          const Divider(),

          // Ayarlar ve Çıkış
          _buildMenuItem(
            icon: Icons.settings,
            title: 'Ayarlar',
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const SettingsScreen(),
                ),
              );
            },
          ),
          _buildMenuItem(
            icon: Icons.help_outline,
            title: 'Yardım & Destek',
            onTap: () {
              Navigator.pop(context);
              _showHelpDialog(context);
            },
          ),
          _buildMenuItem(
            icon: Icons.exit_to_app,
            title: 'Çıkış Yap',
            onTap: () => _showLogoutDialog(context),
            iconColor: Colors.red,
            textColor: Colors.red,
          ),
        ],
      ),
    );
  }

  Widget _buildDrawerHeader() {
    return DrawerHeader(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Theme.of(context).primaryColor,
            Theme.of(context).primaryColor.withValues(alpha: 0.8),
          ],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 30,
            backgroundColor: Colors.white,
            child: Icon(
              Icons.person,
              size: 35,
              color: Theme.of(context).primaryColor,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            _userName,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            _storeName,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMenuItem({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    Color? iconColor,
    Color? textColor,
  }) {
    return ListTile(
      leading: Icon(
        icon,
        color: iconColor ?? Theme.of(context).primaryColor,
      ),
      title: Text(
        title,
        style: TextStyle(
          color: textColor ?? Colors.black87,
          fontWeight: FontWeight.w500,
        ),
      ),
      onTap: onTap,
    );
  }

  void _showLogoutDialog(BuildContext context) {
    if (!mounted) return;

    // Extract context data before any async operations
    final navigator = Navigator.of(context);
    final scaffoldMessenger = ScaffoldMessenger.of(context);

    showDialog(
      context: context,
      builder: (BuildContext dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: const Row(
          children: [
            Icon(Icons.logout, color: Colors.orange, size: 24),
            SizedBox(width: 8),
            Text('Çıkış Yap', style: TextStyle(fontSize: 18)),
          ],
        ),
        content: const Text(
          'Hesabınızdan çıkmak istediğinizden emin misiniz?',
          style: TextStyle(fontSize: 15),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(
              'İptal',
              style: TextStyle(color: Colors.grey[600]),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              _performLogoutWithStaticContext(navigator, scaffoldMessenger);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Çıkış Yap'),
          ),
        ],
      ),
    );
  }

  static Future<void> _performLogoutWithStaticContext(
    NavigatorState navigator,
    ScaffoldMessengerState scaffoldMessenger,
  ) async {
    // Hızlı loading göster (çok kısa)
    navigator.push(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => const Scaffold(
          backgroundColor: Colors.black54,
          body: Center(
            child: Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    SizedBox(width: 12),
                    Text('Çıkış yapılıyor...'),
                  ],
                ),
              ),
            ),
          ),
        ),
        transitionDuration: const Duration(milliseconds: 100),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
        fullscreenDialog: true,
      ),
    );

    // Çok kısa bir feedback sonrası hemen redirect et
    await Future.delayed(const Duration(milliseconds: 150));

    navigator.pushNamedAndRemoveUntil(
      '/welcome-back',
      (route) => false,
    );

    // Background'da logout işlemini tamamla
    _performBackgroundLogout(scaffoldMessenger);
  }

  static void _performBackgroundLogout(
      ScaffoldMessengerState scaffoldMessenger) {
    // AuthService logout'u arkaplanda çalıştır
    AuthService.instance.logout().then((result) {
      if (result.success) {
        // Minimal success feedback (opsiyonel)
        scaffoldMessenger.showSnackBar(
          SnackBar(
            content: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.check_circle, color: Colors.white, size: 16),
                SizedBox(width: 8),
                Text('Çıkış yapıldı', style: TextStyle(fontSize: 13)),
              ],
            ),
            backgroundColor: Colors.green.shade600,
            duration: const Duration(milliseconds: 1500),
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.only(bottom: 100, left: 20, right: 20),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
        );
      }
    }).catchError((e) {
      // Silent error handling in production
    });
  }

  void _showStoreInfoDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: const Row(
          children: [
            Icon(Icons.business_center, color: Colors.blue, size: 24),
            SizedBox(width: 8),
            Text('Mağaza Bilgileri', style: TextStyle(fontSize: 18)),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildInfoRow('Mağaza Adı', _storeName),
              const SizedBox(height: 12),
              _buildInfoRow('Sahip', _userName),
              const SizedBox(height: 12),
              _buildInfoRow('Durum', 'Aktif'),
              const SizedBox(height: 12),
              _buildInfoRow('Plan', 'Ücretsiz'),
              const SizedBox(height: 12),
              _buildInfoRow('Kayıt Tarihi', '15 Ağustos 2024'),
              const SizedBox(height: 12),
              _buildInfoRow('Son Güncelleme', 'Bugün'),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue.withValues(alpha: 0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.info_outline,
                            color: Colors.blue, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          'Mağaza İstatistikleri',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.blue[800],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    _buildStatRow('Toplam Ürün', '150'),
                    _buildStatRow('Aktif Ürün', '140'),
                    _buildStatRow('Düşük Stok', '12'),
                    _buildStatRow('Bu Ay Satış', '₺15,250'),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Kapat'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const StoreManagementScreen(),
                ),
              );
            },
            child: const Text('Düzenle'),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 100,
          child: Text(
            '$label:',
            style: TextStyle(
              fontWeight: FontWeight.w500,
              color: Colors.grey[700],
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStatRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey[700],
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  void _showPaymentMethodsDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: const Row(
          children: [
            Icon(Icons.payment, color: Colors.blue, size: 24),
            SizedBox(width: 8),
            Text('Ödeme Yöntemleri', style: TextStyle(fontSize: 18)),
          ],
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(Icons.credit_card, color: Colors.green),
              title: Text('Kredi Kartı'),
              subtitle: Text('Visa, MasterCard, American Express'),
              trailing: Icon(Icons.arrow_forward_ios, size: 16),
            ),
            ListTile(
              leading: Icon(Icons.account_balance_wallet, color: Colors.orange),
              title: Text('Dijital Cüzdan'),
              subtitle: Text('Apple Pay, Google Pay, Samsung Pay'),
              trailing: Icon(Icons.arrow_forward_ios, size: 16),
            ),
            ListTile(
              leading: Icon(Icons.account_balance, color: Colors.blue),
              title: Text('Banka Transferi'),
              subtitle: Text('EFT, Havale'),
              trailing: Icon(Icons.arrow_forward_ios, size: 16),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Kapat'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                    content: Text('Ödeme yöntemi ekleme özelliği yakında...')),
              );
            },
            child: const Text('Yöntem Ekle'),
          ),
        ],
      ),
    );
  }

  void _showPremiumDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Row(
          children: [
            const Icon(Icons.workspace_premium, color: Colors.amber, size: 24),
            const SizedBox(width: 8),
            const Text('Premium\'a Geç', style: TextStyle(fontSize: 18)),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.amber,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text(
                'YENİ',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Premium Özellikleri:',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 12),
            _buildPremiumFeature('Sınırsız ürün ekleme'),
            _buildPremiumFeature('Gelişmiş raporlar ve analizler'),
            _buildPremiumFeature('Çoklu mağaza yönetimi'),
            _buildPremiumFeature('Otomatik yedekleme'),
            _buildPremiumFeature('Öncelikli müşteri desteği'),
            _buildPremiumFeature('Reklamsız deneyim'),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.amber.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.amber.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.local_fire_department, color: Colors.orange),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'İlk ay ücretsiz! Sonrasında sadece ₺29.99/ay',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.amber[800],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child:
                Text('Belki Sonra', style: TextStyle(color: Colors.grey[600])),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content:
                      Text('Premium üyelik özelliği yakında aktif olacak!'),
                  backgroundColor: Colors.amber,
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.amber,
              foregroundColor: Colors.white,
            ),
            child: const Text('Premium\'a Geç'),
          ),
        ],
      ),
    );
  }

  Widget _buildPremiumFeature(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          const Icon(Icons.check_circle, color: Colors.green, size: 20),
          const SizedBox(width: 8),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }

  void _showHelpDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: const Row(
          children: [
            Icon(Icons.help_outline, color: Colors.blue, size: 24),
            SizedBox(width: 8),
            Text('Yardım & Destek', style: TextStyle(fontSize: 18)),
          ],
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(Icons.article, color: Colors.blue),
              title: Text('Kullanım Kılavuzu'),
              subtitle: Text('Uygulamayı nasıl kullanacağınızı öğrenin'),
              trailing: Icon(Icons.arrow_forward_ios, size: 16),
            ),
            ListTile(
              leading: Icon(Icons.video_library, color: Colors.red),
              title: Text('Video Eğitimler'),
              subtitle: Text('Adım adım video anlatımlar'),
              trailing: Icon(Icons.arrow_forward_ios, size: 16),
            ),
            ListTile(
              leading: Icon(Icons.chat, color: Colors.green),
              title: Text('Canlı Destek'),
              subtitle: Text('7/24 müşteri hizmetleri'),
              trailing: Icon(Icons.arrow_forward_ios, size: 16),
            ),
            ListTile(
              leading: Icon(Icons.bug_report, color: Colors.orange),
              title: Text('Hata Bildir'),
              subtitle: Text('Karşılaştığınız sorunları bildirin'),
              trailing: Icon(Icons.arrow_forward_ios, size: 16),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Kapat'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                    content: Text('Destek sistemi yakında aktif olacak!')),
              );
            },
            child: const Text('İletişime Geç'),
          ),
        ],
      ),
    );
  }
}




