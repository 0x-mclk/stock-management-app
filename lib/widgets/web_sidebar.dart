import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../providers/app_provider.dart';
import '../providers/role_access_provider.dart';
import '../providers/notification_provider.dart';
import '../services/store_selection_service.dart';
import '../utils/web_utils.dart';
import '../screens/my_store_screen.dart';
import '../screens/settings_screen.dart';

class WebSidebar extends StatelessWidget {
  final int currentIndex;
  final Function(int) onNavigate;
  final bool extended;

  const WebSidebar({
    super.key,
    required this.currentIndex,
    required this.onNavigate,
    this.extended = true,
  });

  static const List<_NavDestination> _destinations = [
    _NavDestination(icon: Icons.dashboard_rounded, label: 'Ana Sayfa'),
    _NavDestination(icon: Icons.inventory_2_rounded, label: 'Ürünler'),
    _NavDestination(icon: Icons.point_of_sale_rounded, label: 'Satış'),
    _NavDestination(icon: Icons.business_rounded, label: 'Tedarikçiler'),
    _NavDestination(icon: Icons.analytics_rounded, label: 'Raporlar'),
  ];

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final sidebarBg =
        isDark ? const Color(0xFF1A1A2E) : Colors.white;
    final borderColor =
        isDark ? const Color(0xFF2D2D3F) : const Color(0xFFE8ECF0);

    return Container(
      width: extended ? 260.0 : 72.0,
      height: double.infinity,
      decoration: BoxDecoration(
        color: sidebarBg,
        border: Border(
          right: BorderSide(color: borderColor),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 12,
            offset: const Offset(4, 0),
          ),
        ],
      ),
      child: Column(
        children: [
          _SidebarLogo(extended: extended),
          Divider(height: 1, color: borderColor),
          Expanded(
            child: _SidebarNavItems(
              destinations: _destinations,
              currentIndex: currentIndex,
              onNavigate: onNavigate,
              extended: extended,
            ),
          ),
          Divider(height: 1, color: borderColor),
          _SidebarSecondaryItems(extended: extended),
          Divider(height: 1, color: borderColor),
          _SidebarFooter(extended: extended),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Logo
// ─────────────────────────────────────────────
class _SidebarLogo extends StatelessWidget {
  final bool extended;
  const _SidebarLogo({required this.extended});

  @override
  Widget build(BuildContext context) {
    final logo = Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF2196F3), Color(0xFF1565C0)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(10),
      ),
      child:
          const Icon(Icons.inventory_2_rounded, color: Colors.white, size: 20),
    );

    return SizedBox(
      height: 64,
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: extended ? 20 : 0),
        child: extended
            ? Row(
                children: [
                  logo,
                  const SizedBox(width: 12),
                  const Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'StockPro',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.3,
                        ),
                      ),
                      Text(
                        'Stok Yönetim Sistemi',
                        style: TextStyle(fontSize: 10, color: Colors.grey),
                      ),
                    ],
                  ),
                ],
              )
            : Center(child: logo),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Nav Items
// ─────────────────────────────────────────────
class _SidebarNavItems extends StatelessWidget {
  final List<_NavDestination> destinations;
  final int currentIndex;
  final Function(int) onNavigate;
  final bool extended;

  const _SidebarNavItems({
    required this.destinations,
    required this.currentIndex,
    required this.onNavigate,
    required this.extended,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer<NotificationProvider>(
      builder: (context, notifProvider, _) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
          child: Column(
            children: List.generate(destinations.length, (i) {
              final hasBadge =
                  i == 0 && notifProvider.unreadCount > 0;
              return _NavItem(
                icon: destinations[i].icon,
                label: destinations[i].label,
                isActive: currentIndex == i,
                extended: extended,
                badgeCount: hasBadge ? notifProvider.unreadCount : 0,
                onTap: () => tryNavigateWithRole(context, i, onNavigate),
              );
            }),
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────
// Footer (user info + logout)
// ─────────────────────────────────────────────
class _SidebarFooter extends StatefulWidget {
  final bool extended;
  const _SidebarFooter({required this.extended});

  @override
  State<_SidebarFooter> createState() => _SidebarFooterState();
}

class _SidebarFooterState extends State<_SidebarFooter> {
  String _storeName = 'Mağaza';

  @override
  void initState() {
    super.initState();
    _loadStoreName();
  }

  Future<void> _loadStoreName() async {
    final name = await StoreSelectionService.instance.getCurrentStoreName();
    if (mounted) setState(() => _storeName = name);
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final email = user?.email ?? 'kullanıcı';
    final displayName = email.contains('@') ? email.split('@').first : email;
    final initial = displayName.isNotEmpty ? displayName[0].toUpperCase() : 'K';

    final avatar = CircleAvatar(
      radius: 18,
      backgroundColor: const Color(0xFF2196F3),
      child: Text(
        initial,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w700,
          fontSize: 14,
        ),
      ),
    );

    final logoutBtn = Tooltip(
      message: 'Çıkış',
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () => _confirmLogout(context),
        child: const Padding(
          padding: EdgeInsets.all(6),
          child: Icon(Icons.logout_rounded, size: 18, color: Colors.grey),
        ),
      ),
    );

    return Padding(
      padding: EdgeInsets.symmetric(
        vertical: 12,
        horizontal: widget.extended ? 16 : 8,
      ),
      child: widget.extended
          ? Row(
              children: [
                avatar,
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        displayName,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        _storeName,
                        style: const TextStyle(
                          fontSize: 11,
                          color: Colors.grey,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                logoutBtn,
              ],
            )
          : Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                avatar,
                const SizedBox(height: 8),
                logoutBtn,
              ],
            ),
    );
  }

  void _confirmLogout(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Çıkış Yap'),
        content: const Text('Oturumu kapatmak istediğinize emin misiniz?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('İptal'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              context.read<RoleAccessProvider>().reset();
              context.read<AppProvider>().signOut();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              shape:
                  RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text(
              'Çıkış Yap',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Single nav item with hover state
// ─────────────────────────────────────────────
class _NavItem extends StatefulWidget {
  final IconData icon;
  final String label;
  final bool isActive;
  final bool extended;
  final int badgeCount;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.isActive,
    required this.extended,
    required this.badgeCount,
    required this.onTap,
  });

  @override
  State<_NavItem> createState() => _NavItemState();
}

class _NavItemState extends State<_NavItem> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    const activeColor = Color(0xFF2196F3);
    const activeBg = Color(0xFFE3F2FD);

    final bg = widget.isActive
        ? activeBg
        : _hovered
            ? Colors.grey.withValues(alpha: 0.08)
            : Colors.transparent;

    final iconColor =
        widget.isActive ? activeColor : Colors.grey.shade600;
    final textColor =
        widget.isActive ? activeColor : Colors.grey.shade700;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          margin: const EdgeInsets.symmetric(vertical: 2),
          padding: EdgeInsets.symmetric(
            horizontal: widget.extended ? 12 : 0,
            vertical: 10,
          ),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(10),
          ),
          child: widget.extended
              ? Row(
                  children: [
                    _IconWithBadge(
                      icon: widget.icon,
                      color: iconColor,
                      badgeCount: widget.badgeCount,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        widget.label,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: widget.isActive
                              ? FontWeight.w600
                              : FontWeight.w500,
                          color: textColor,
                        ),
                      ),
                    ),
                    if (widget.isActive)
                      Container(
                        width: 5,
                        height: 5,
                        decoration: const BoxDecoration(
                          color: activeColor,
                          shape: BoxShape.circle,
                        ),
                      ),
                  ],
                )
              : Center(
                  child: _IconWithBadge(
                    icon: widget.icon,
                    color: iconColor,
                    badgeCount: widget.badgeCount,
                  ),
                ),
        ),
      ),
    );
  }
}

class _IconWithBadge extends StatelessWidget {
  final IconData icon;
  final Color color;
  final int badgeCount;

  const _IconWithBadge({
    required this.icon,
    required this.color,
    required this.badgeCount,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Icon(icon, size: 22, color: color),
        if (badgeCount > 0)
          Positioned(
            right: -7,
            top: -5,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
              decoration: BoxDecoration(
                color: Colors.red,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '$badgeCount',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

// ─────────────────────────────────────────────
// Secondary items: Mağazam, Ayarlar, Yardım
// ─────────────────────────────────────────────
class _SidebarSecondaryItems extends StatelessWidget {
  final bool extended;
  const _SidebarSecondaryItems({required this.extended});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
      child: Column(
        children: [
          _SecondaryNavItem(
            icon: Icons.store_rounded,
            label: 'Mağazam',
            extended: extended,
            onTap: () => showWebPanel(
              context: context,
              child: const MyStoreScreen(),
              panelWidth: 720,
            ),
          ),
          _SecondaryNavItem(
            icon: Icons.settings_rounded,
            label: 'Ayarlar',
            extended: extended,
            onTap: () => showWebPanel(
              context: context,
              child: const SettingsScreen(),
              panelWidth: 560,
            ),
          ),
          _SecondaryNavItem(
            icon: Icons.help_outline_rounded,
            label: 'Yardım & Destek',
            extended: extended,
            onTap: () => _showHelpDialog(context),
          ),
        ],
      ),
    );
  }

  void _showHelpDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.help_outline_rounded, color: Colors.blue),
            SizedBox(width: 8),
            Text('Yardım & Destek'),
          ],
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(Icons.article_rounded, color: Colors.blue),
              title: Text('Kullanım Kılavuzu'),
              subtitle: Text('Uygulamayı nasıl kullanacağınızı öğrenin'),
              trailing: Icon(Icons.arrow_forward_ios_rounded, size: 14),
            ),
            ListTile(
              leading: Icon(Icons.video_library_rounded, color: Colors.red),
              title: Text('Video Eğitimler'),
              subtitle: Text('Adım adım video anlatımlar'),
              trailing: Icon(Icons.arrow_forward_ios_rounded, size: 14),
            ),
            ListTile(
              leading: Icon(Icons.chat_rounded, color: Colors.green),
              title: Text('Canlı Destek'),
              subtitle: Text('7/24 müşteri hizmetleri'),
              trailing: Icon(Icons.arrow_forward_ios_rounded, size: 14),
            ),
            ListTile(
              leading: Icon(Icons.bug_report_rounded, color: Colors.orange),
              title: Text('Hata Bildir'),
              subtitle: Text('Karşılaştığınız sorunları bildirin'),
              trailing: Icon(Icons.arrow_forward_ios_rounded, size: 14),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Kapat'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
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

class _SecondaryNavItem extends StatefulWidget {
  final IconData icon;
  final String label;
  final bool extended;
  final VoidCallback onTap;

  const _SecondaryNavItem({
    required this.icon,
    required this.label,
    required this.extended,
    required this.onTap,
  });

  @override
  State<_SecondaryNavItem> createState() => _SecondaryNavItemState();
}

class _SecondaryNavItemState extends State<_SecondaryNavItem> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final bg = _hovered
        ? Colors.grey.withValues(alpha: 0.08)
        : Colors.transparent;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          margin: const EdgeInsets.symmetric(vertical: 2),
          padding: EdgeInsets.symmetric(
            horizontal: widget.extended ? 12 : 0,
            vertical: 9,
          ),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(10),
          ),
          child: widget.extended
              ? Row(
                  children: [
                    Icon(widget.icon,
                        size: 20, color: Colors.grey.shade500),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        widget.label,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: Colors.grey.shade700,
                        ),
                      ),
                    ),
                  ],
                )
              : Center(
                  child: Tooltip(
                    message: widget.label,
                    child: Icon(widget.icon,
                        size: 20, color: Colors.grey.shade500),
                  ),
                ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Helper data class
// ─────────────────────────────────────────────
class _NavDestination {
  final IconData icon;
  final String label;
  const _NavDestination({required this.icon, required this.label});
}
