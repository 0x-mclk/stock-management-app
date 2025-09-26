import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'providers/app_provider.dart';
//import 'providers/product_provider.dart';
import 'providers/realtime_product_provider.dart';
import 'providers/sales_provider.dart';
import 'providers/supplier_provider.dart';
import 'providers/notification_provider.dart';
import 'providers/theme_provider.dart';
import 'screens/splash_screen.dart';
import 'screens/login_screen.dart';
import 'services/database_service.dart'; // ✅ Firebase uyumlu SQLite
import 'services/notification_service.dart';
import 'services/connectivity_service.dart';
import 'services/offline_service.dart'; // ✅ Firebase uyumlu offline service

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    // Debug: print('Firebase initialized successfully');
  } catch (e) {
    // Debug: print('Firebase initialization error: $e');
  }

  // Initialize locale data for Turkish formatting
  try {
    await initializeDateFormatting('tr_TR', null);
    await initializeDateFormatting('tr', null);
    Intl.defaultLocale = 'tr_TR';
    // Debug: print('Turkish locale initialized');
  } catch (e) {
    // Debug: print('Turkish locale error: $e');
    // Fallback to English if Turkish fails
    try {
      await initializeDateFormatting('en_US', null);
      Intl.defaultLocale = 'en_US';
    } catch (e2) {
      // Debug: print('English locale error: $e2');
    }
  }

  // Initialize services (web'de database ve notification servisleri çalışmaz)
  if (!kIsWeb) {
    try {
      // ✅ Firebase uyumlu SQLite database başlatılıyor
      await DatabaseService.instance.database;

      // Initialize notification service
      await NotificationService.initialize();

      // Initialize connectivity and offline services (non-blocking)
      ConnectivityService().initialize();

      // ✅ Firebase uyumlu offline service başlatılıyor
      OfflineService().loadPendingOperations().catchError((error) {
        // Debug: print('Error loading pending operations: $error');
      });
    } catch (e) {
      // Debug: print('Error in main: $e');
    }
  }

  runApp(const StockManagementApp());
}

class StockManagementApp extends StatelessWidget {
  const StockManagementApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => AppProvider()),
        ChangeNotifierProvider(create: (_) => NotificationProvider()),
        ChangeNotifierProvider(create: (_) => RealtimeProductProvider()),
        ChangeNotifierProvider(create: (_) => SalesProvider()),
        ChangeNotifierProvider(create: (_) => SupplierProvider()),
        ChangeNotifierProvider(create: (_) => ConnectivityService()),
        ChangeNotifierProvider(
            create: (_) =>
                OfflineService()), // ✅ Firebase uyumlu offline service
      ],
      child: Consumer<ThemeProvider>(
        builder: (context, themeProvider, child) {
          return MaterialApp(
            title: 'Stok Takip',
            debugShowCheckedModeBanner: false,
            routes: {
              '/login': (context) => const LoginScreen(),
            },
            theme: ThemeData(
              useMaterial3: true,
              colorScheme: ColorScheme.fromSeed(
                seedColor: const Color(0xFF2196F3),
                brightness: themeProvider.isDarkMode
                    ? Brightness.dark
                    : Brightness.light,
              ),
              textTheme: GoogleFonts.robotoTextTheme(
                themeProvider.isDarkMode
                    ? ThemeData.dark().textTheme
                    : ThemeData.light().textTheme,
              ),
              appBarTheme: AppBarTheme(
                centerTitle: true,
                elevation: 0,
                backgroundColor: themeProvider.isDarkMode
                    ? const Color(0xFF1E1E1E)
                    : const Color(0xFF2196F3),
                foregroundColor: Colors.white,
              ),
              bottomNavigationBarTheme: BottomNavigationBarThemeData(
                backgroundColor: themeProvider.isDarkMode
                    ? const Color(0xFF1E1E1E)
                    : Colors.white,
                selectedItemColor: const Color(0xFF2196F3),
                unselectedItemColor: Colors.grey,
                type: BottomNavigationBarType.fixed,
              ),
            ),
            home: const SplashScreen(),
          );
        },
      ),
    );
  }
}
