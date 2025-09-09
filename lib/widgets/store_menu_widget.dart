import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart'; // ✅ SharedPreferences import
import '../services/auth_service.dart';
import '../screens/settings_screen.dart';
import '../screens/my_store_screen.dart';

class StoreMenuWidget extends StatefulWidget {
  const StoreMenuWidget({super.key});

  @override
  State<StoreMenuWidget> createState() => _StoreMenuWidgetState();
}

class _StoreMenuWidgetState extends State<StoreMenuWidget> {
  String _userName = 'Kullanıcı';
  String _userEmail = '';
  String _storeName = 'Mağaza';

  @override
  void initState() {
    super.initState();
    _loadUserInfo();
  }

  Future<void> _loadUserInfo() async {
    try {
      // ✅ Firebase Auth'dan kullanıcı bilgilerini al
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser != null) {
        setState(() {
          _userEmail = currentUser.email ?? '';
        });

        // ✅ Firestore'dan kullanıcı detaylarını al
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(currentUser.uid)
            .get();
            
        if (userDoc.exists) {
          final userData = userDoc.data()!;
          setState(() {
            _userName = userData['name'] ?? 'Kullanıcı';
            _storeName = userData['name'] ?? 'Mağaza'; // Ad = Mağaza adı (sadelik için)
          });
        }
      }
    } catch (e) {
      // Debug print removed - Hata durumunda varsayılan değerler kullanılır
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
            title: 'Mağazam',
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const MyStoreScreen(),
                ),
              );
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
        mainAxisAlignment: MainAxisAlignment.spaceEvenly, // ✅ Eşit dağılım
        children: [
          CircleAvatar(
            radius: 25, // ✅ Boyut küçültüldü
            backgroundColor: Colors.white,
            child: Icon(
              Icons.person,
              size: 30, // ✅ Icon boyutu küçültüldü
              color: Theme.of(context).primaryColor,
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _userName,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16, // ✅ Font boyutu küçültüldü
                  fontWeight: FontWeight.bold,
                ),
                maxLines: 1, // ✅ Tek satır sınırı
                overflow: TextOverflow.ellipsis, // ✅ Overflow koruması
              ),
              if (_userEmail.isNotEmpty) ...[
                const SizedBox(height: 2), // ✅ Daha küçük boşluk
                Text(
                  _userEmail,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 11, // ✅ Daha küçük font
                  ),
                  maxLines: 1, // ✅ Tek satır sınırı
                  overflow: TextOverflow.ellipsis, // ✅ Overflow koruması
                ),
              ],
              const SizedBox(height: 2), // ✅ Daha küçük boşluk
              Text(
                '🏪 $_storeName',
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 12, // ✅ Font boyutu küçültüldü
                ),
                maxLines: 1, // ✅ Tek satır sınırı
                overflow: TextOverflow.ellipsis, // ✅ Overflow koruması
              ),
            ],
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
      '/login',
      (route) => false,
    );

    // Background'da logout işlemini tamamla
    _performBackgroundLogout(scaffoldMessenger);
  }

  static void _performBackgroundLogout(
      ScaffoldMessengerState scaffoldMessenger) {
    // Çoklu logout işlemi: hem AuthService hem Firebase Auth
    _performCompleteLogout().then((result) {
      if (result) {
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
      print('❌ Logout error: $e');
    });
  }

  // ✅ Hem SharedPreferences hem Firebase Auth'dan çıkış
  static Future<bool> _performCompleteLogout() async {
    try {
      print('🔄 Starting complete logout process...');
      
      // 1. SharedPreferences temizleme
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear(); // Tüm verileri temizle
      print('✅ SharedPreferences cleared');
      
      // 2. Firebase Auth çıkışı
      try {
        await FirebaseAuth.instance.signOut();
        print('✅ Firebase Auth signed out');
      } catch (firebaseError) {
        print('⚠️ Firebase signOut error: $firebaseError');
        // Firebase hatası olsa bile devam et
      }
      
      // 3. AuthService logout çağrısı
      try {
        final authResult = await AuthService.instance.logout(clearRemembered: true);
        print('✅ AuthService logout: ${authResult.success}');
      } catch (authError) {
        print('⚠️ AuthService logout error: $authError');
        // AuthService hatası olsa bile devam et
      }
      
      print('✅ Complete logout finished successfully');
      return true;
    } catch (e) {
      print('❌ Complete logout failed: $e');
      return false;
    }
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
