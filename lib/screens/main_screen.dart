import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../providers/notification_provider.dart';
import '../providers/role_access_provider.dart';
import '../widgets/web_sidebar.dart';
import 'dashboard_screen.dart';
import 'products_screen.dart';
import 'sales_screen.dart';
import 'suppliers_screen.dart';
import 'reports_screen.dart';

// ─────────────────────────────────────────────
// LazyIndexedStack
// Ekranı yalnızca ilk kez seçildiğinde build eder.
// Sonraki gezinmelerde Offstage ile gizler/gösterir
// (State korunur, ama render edilmez).
// ─────────────────────────────────────────────
class _LazyIndexedStack extends StatefulWidget {
  final int index;
  final List<Widget> children;

  const _LazyIndexedStack({
    required this.index,
    required this.children,
  });

  @override
  State<_LazyIndexedStack> createState() => _LazyIndexedStackState();
}

class _LazyIndexedStackState extends State<_LazyIndexedStack> {
  late List<bool> _activated;

  @override
  void initState() {
    super.initState();
    _activated = List.generate(
      widget.children.length,
      (i) => i == widget.index,
    );
  }

  @override
  void didUpdateWidget(_LazyIndexedStack old) {
    super.didUpdateWidget(old);
    if (!_activated[widget.index]) {
      // Ekran ilk kez açıldı — build et
      _activated[widget.index] = true;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: List.generate(widget.children.length, (i) {
        if (!_activated[i]) return const SizedBox.shrink();
        return Offstage(
          offstage: i != widget.index,
          child: widget.children[i],
        );
      }),
    );
  }
}

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  // Breakpoints
  static const double _desktopBreak = 1100;
  static const double _tabletBreak = 700;

  static const List<Widget> _screens = [
    DashboardScreen(),
    ProductsScreen(),
    SalesScreen(),
    SuppliersScreen(),
    ReportsScreen(),
  ];

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<RoleAccessProvider>().ensureLoaded();
    });
  }

  void _onNavigate(BuildContext context, int index) {
    final appProvider = context.read<AppProvider>();
    tryNavigateWithRole(context, index, appProvider.setCurrentPage);
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AppProvider>(
      builder: (context, appProvider, _) {
        return LayoutBuilder(
          builder: (context, constraints) {
            final w = constraints.maxWidth;
            final onNavigate = (int index) => _onNavigate(context, index);

            if (w >= MainScreen._desktopBreak) {
              return _DesktopLayout(
                currentIndex: appProvider.currentPageIndex,
                onNavigate: onNavigate,
              );
            } else if (w >= MainScreen._tabletBreak) {
              return _TabletLayout(
                currentIndex: appProvider.currentPageIndex,
                onNavigate: onNavigate,
              );
            } else {
              return _MobileLayout(
                currentIndex: appProvider.currentPageIndex,
                onNavigate: onNavigate,
              );
            }
          },
        );
      },
    );
  }
}

// ─────────────────────────────────────────────
// Desktop  ≥ 1100px  —  full sidebar (260px)
// ─────────────────────────────────────────────
class _DesktopLayout extends StatelessWidget {
  final int currentIndex;
  final Function(int) onNavigate;

  const _DesktopLayout({
    required this.currentIndex,
    required this.onNavigate,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          WebSidebar(
            currentIndex: currentIndex,
            onNavigate: onNavigate,
            extended: true,
          ),
          Expanded(
            child: _LazyIndexedStack(
              index: currentIndex,
              children: MainScreen._screens,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Tablet  700–1099px  —  compact rail (72px)
// ─────────────────────────────────────────────
class _TabletLayout extends StatelessWidget {
  final int currentIndex;
  final Function(int) onNavigate;

  const _TabletLayout({
    required this.currentIndex,
    required this.onNavigate,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          WebSidebar(
            currentIndex: currentIndex,
            onNavigate: onNavigate,
            extended: false,
          ),
          Expanded(
            child: _LazyIndexedStack(
              index: currentIndex,
              children: MainScreen._screens,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Mobile  < 700px  —  bottom navigation (unchanged)
// ─────────────────────────────────────────────
class _MobileLayout extends StatelessWidget {
  final int currentIndex;
  final Function(int) onNavigate;

  const _MobileLayout({
    required this.currentIndex,
    required this.onNavigate,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _LazyIndexedStack(
        index: currentIndex,
        children: MainScreen._screens,
      ),
      bottomNavigationBar: Consumer<NotificationProvider>(
        builder: (context, notifProvider, _) {
          return BottomNavigationBar(
            type: BottomNavigationBarType.fixed,
            currentIndex: currentIndex,
            onTap: onNavigate,
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
              BottomNavigationBarItem(
                icon: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    const Icon(Icons.analytics),
                    if (notifProvider.unreadCount > 0)
                      Positioned(
                        right: -4,
                        top: -4,
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
                            '${notifProvider.unreadCount}',
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
                label: 'Raporlar',
              ),
            ],
          );
        },
      ),
    );
  }
}
