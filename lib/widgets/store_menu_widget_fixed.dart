import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../screens/settings_screen.dart';
import '../screens/store_management_screen_new.dart';
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
          const Divider(),
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
    // AuthService logout'u arkaplanda çalıştır - Remember Me bilgilerini de temizle
    // // Debug print removed // Removed for production
    AuthService.instance.logout(clearRemembered: true).then((result) {
      // // Debug print removed // Removed for production
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
}




