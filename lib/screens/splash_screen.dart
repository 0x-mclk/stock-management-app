import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../widgets/offline_status_widget.dart';
import '../providers/realtime_product_provider.dart';
import '../providers/sales_provider.dart';
import '../providers/supplier_provider.dart';
import 'main_screen.dart';
import 'login_screen.dart'; // ✅ Ana login sayfasını kullan

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    try {
      // Show splash for minimum 2 seconds
      await Future.delayed(const Duration(seconds: 2));

      // Load all provider data upfront to ensure data is available
      // Debug print removed

      if (mounted) {
        final realtimeProductProvider =
            Provider.of<RealtimeProductProvider>(context, listen: false);
        final salesProvider =
            Provider.of<SalesProvider>(context, listen: false);
        final supplierProvider =
            Provider.of<SupplierProvider>(context, listen: false);

        // Load all data in parallel for faster initialization
        await Future.wait([
          realtimeProductProvider.startRealtimeUpdates(),
          salesProvider.loadSales(),
          supplierProvider.loadSuppliers(),
        ]);

        // Debug print removed
      }

      // Debug print removed

      // Navigate to new registration screen instead of main screen
      if (mounted) {
        // Firebase Auth kontrolü - kullanıcı giriş yapmış mı?
        final currentUser = FirebaseAuth.instance.currentUser;

        if (currentUser != null) {
          // Kullanıcı giriş yapmış, main screen'e git
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (context) => const Scaffold(
                body: Column(
                  children: [
                    OfflineStatusWidget(),
                    Expanded(child: MainScreen()),
                  ],
                ),
              ),
            ),
          );
        } else {
          // Kullanıcı giriş yapmamış, ana login sayfasına git
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (context) => const LoginScreen(),
            ),
          );
        }
      }
    } catch (e) {
      // Debug print removed
      // Even if there's an error, navigate to login screen
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) => const LoginScreen(),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).primaryColor,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // App Logo
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.2),
                    blurRadius: 10,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: const Icon(
                Icons.inventory_2,
                size: 60,
                color: Color(0xFF2196F3),
              ),
            ),
            const SizedBox(height: 30),

            // App Title
            const Text(
              'Stok Takip',
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 10),

            // Subtitle
            Text(
              'Yönetim Sistemi',
              style: TextStyle(
                fontSize: 16,
                color: Colors.white.withValues(alpha: 0.8),
              ),
            ),
            const SizedBox(height: 50),

            // Loading Indicator
            const CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
            ),
            const SizedBox(height: 20),

            Text(
              'Uygulama başlatılıyor...',
              style: TextStyle(
                fontSize: 14,
                color: Colors.white.withValues(alpha: 0.7),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
