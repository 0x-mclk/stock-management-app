import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../providers/notification_provider.dart';
import 'dashboard_screen.dart';
import 'products_screen.dart';
import 'sales_screen.dart';
import 'suppliers_screen.dart';
import 'reports_screen.dart';

class MainScreen extends StatelessWidget {
  const MainScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AppProvider>(
      builder: (context, appProvider, child) {
        return Scaffold(
          body: IndexedStack(
            index: appProvider.currentPageIndex,
            children: const [
              DashboardScreen(),
              ProductsScreen(),
              SalesScreen(),
              SuppliersScreen(),
              ReportsScreen(),
            ],
          ),
          bottomNavigationBar: Consumer<NotificationProvider>(
            builder: (context, notificationProvider, child) {
              return BottomNavigationBar(
                type: BottomNavigationBarType.fixed,
                currentIndex: appProvider.currentPageIndex,
                onTap: appProvider.setCurrentPage,
                selectedItemColor: Theme.of(context).primaryColor,
                unselectedItemColor: Colors.grey,
                items: [
                  const BottomNavigationBarItem(
                    icon: Icon(Icons.dashboard),
                    label: 'Ana Sayfa',
                  ),
                  const BottomNavigationBarItem(
                    icon: Icon(Icons.inventory),
                    label: 'Ürünler',
                  ),
                  const BottomNavigationBarItem(
                    icon: Icon(Icons.point_of_sale),
                    label: 'Satış',
                  ),
                  const BottomNavigationBarItem(
                    icon: Icon(Icons.business),
                    label: 'Tedarikçiler',
                  ),
                  const BottomNavigationBarItem(
                    icon: Icon(Icons.analytics),
                    label: 'Raporlar',
                  ),
                ],
              );
            },
          ),
        );
      },
    );
  }
}
