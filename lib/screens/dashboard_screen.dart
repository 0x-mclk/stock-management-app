import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/realtime_product_provider.dart';
import '../providers/sales_provider.dart';
import '../providers/app_provider.dart';
import '../providers/role_access_provider.dart';
import '../providers/notification_provider.dart';
import '../utils/currency_formatter.dart';
import '../utils/web_utils.dart';
import '../widgets/store_menu_widget.dart';
import 'price_check_screen.dart';
import 'notifications_screen.dart';
import '../utils/navigation_helper.dart';
import 'team_management_screen.dart';
import 'report_chat_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
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
      final realtimeProvider =
          Provider.of<RealtimeProductProvider>(context, listen: false);
      realtimeProvider.startRealtimeUpdates();

      // Satış ve tedarikçi verilerini de yükle; splash atlanırsa kartlar boş görünmesin
      final salesProvider =
          Provider.of<SalesProvider>(context, listen: false);
      if (salesProvider.sales.isEmpty) {
        await salesProvider.loadSales();
      }
    } catch (e) {
      // Yükleme hatası dashboard'u bozmaz
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = WebBreakpoints.isDesktop(context);

    return Scaffold(
      drawer: isDesktop ? null : const StoreMenuWidget(),
      appBar: isDesktop ? null : _buildMobileAppBar(context),
      body: isDesktop ? _buildBody(context) : SafeArea(child: _buildBody(context)),
      floatingActionButton: _AiChatFab(onTap: () => _openReportChat(context)),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
  }

  PreferredSizeWidget _buildMobileAppBar(BuildContext context) {
    return AppBar(
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
    );
  }

  Widget _buildBody(BuildContext context) {
    final isDesktop = WebBreakpoints.isDesktop(context);

    Widget content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        WebPageTitle(
          title: 'Ana Sayfa',
          subtitle: 'Mağazanızın genel durumuna bakış',
        ),
        const Text(
          'Genel Durum',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 12),
        _buildSummaryCards(context),
        const SizedBox(height: 28),
        const Text(
          'Hızlı İşlemler',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 12),
        _buildQuickActions(context),
        SizedBox(height: isDesktop ? 32 : 80),
      ],
    );

    if (isDesktop) {
      return SingleChildScrollView(
        child: WebPageWrapper(child: content),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadData,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: content,
      ),
    );
  }

  Widget _buildSummaryCards(BuildContext context) {
    return Consumer<RoleAccessProvider>(
      builder: (context, roleAccess, _) {
        final hideValues = !roleAccess.canViewDashboardSummary;
        const masked = '***';

        return Consumer<RealtimeProductProvider>(
          builder: (context, realtimeProvider, child) {
            return Consumer<SalesProvider>(
              builder: (context, salesProvider, child) {
                DateTime today = DateTime.now();
                DateTime startOfDay =
                    DateTime(today.year, today.month, today.day);
                DateTime endOfDay =
                    DateTime(today.year, today.month, today.day, 23, 59, 59);

                double dailySales = salesProvider.getTotalSalesAmount(
                  startDate: startOfDay,
                  endDate: endOfDay,
                );

                double dailyProfit =
                    salesProvider.getDailyProfitFromRealtime(realtimeProvider);

                final stockValue =
                    _calculateStockValue(realtimeProvider.products);

                return WebResponsiveGrid(
                  mobileCols: 2,
                  tabletCols: 2,
                  desktopCols: 4,
                  spacing: 12,
                  children: [
                    _buildSummaryCard(
                      'Toplam Ürün',
                      hideValues
                          ? masked
                          : '${realtimeProvider.products.length}',
                      Icons.inventory_2_rounded,
                      Colors.blue,
                    ),
                    _buildSummaryCard(
                      'Günlük Satış',
                      hideValues
                          ? masked
                          : CurrencyFormatter.formatWithSymbol(dailySales),
                      Icons.trending_up_rounded,
                      Colors.green,
                    ),
                    _buildSummaryCard(
                      'Günlük Kâr',
                      hideValues
                          ? masked
                          : CurrencyFormatter.formatWithSymbol(dailyProfit),
                      Icons.monetization_on_rounded,
                      Colors.orange,
                    ),
                    _buildSummaryCard(
                      'Stok Değeri',
                      hideValues
                          ? masked
                          : CurrencyFormatter.formatWithSymbol(stockValue),
                      Icons.account_balance_wallet_rounded,
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
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.13),
            blurRadius: 10,
            spreadRadius: 0,
            offset: const Offset(0, 3),
          ),
          BoxShadow(
            color: color.withValues(alpha: 0.08),
            blurRadius: 14,
            spreadRadius: -2,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: color.withValues(alpha: 0.07),
          border: Border.all(color: color.withValues(alpha: 0.10), width: 1),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, size: 22, color: color),
            ),
            const SizedBox(height: 10),
            Text(
              title,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: Colors.grey.shade600,
                letterSpacing: 0.2,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 3),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                value,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: color,
                  letterSpacing: -0.3,
                ),
                maxLines: 1,
              ),
            ),
          ],
        ),
      ),
    ));
  }

  Widget _buildQuickActions(BuildContext context) {
    final roleAccess = context.watch<RoleAccessProvider>();

    void guarded(String key, VoidCallback action) {
      if (roleAccess.canUseQuickAction(key)) {
        action();
      } else {
        showRoleAccessDenied(context);
      }
    }

    final actions = [
      ('Ürün Ekle', Icons.add_box_rounded, Colors.blue, 'product_add',
          () => tryNavigateWithRole(
              context, 1, context.read<AppProvider>().setCurrentPage)),
      ('Satış Yap', Icons.point_of_sale_rounded, Colors.green, 'sales',
          () => tryNavigateWithRole(
              context, 2, context.read<AppProvider>().setCurrentPage)),
      ('Takım Yönetimi', Icons.group_rounded, Colors.indigo, 'team',
          () => guarded('team', () => _openTeamManagement(context))),
      ('Ürün Analizi', Icons.analytics_rounded, Colors.teal, 'analysis',
          () => guarded('analysis', () => _openProductAnalysis(context))),
      ('Fiyat Kontrol', Icons.qr_code_scanner_rounded, Colors.orange,
          'price_check',
          () => guarded('price_check', () => _openPriceCheck(context))),
      ('Raporlar', Icons.assessment_rounded, Colors.purple, 'reports',
          () => tryNavigateWithRole(
              context, 4, context.read<AppProvider>().setCurrentPage)),
    ];

    return WebResponsiveGrid(
      mobileCols: 2,
      tabletCols: 3,
      desktopCols: 3,
      spacing: 12,
      children: actions
          .map((a) => _buildQuickActionButton(a.$1, a.$2, a.$3, a.$5))
          .toList(),
    );
  }

  Widget _buildQuickActionButton(
      String title, IconData icon, Color color, VoidCallback onTap) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: Card(
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: Colors.grey.withValues(alpha: 0.12),
                width: 1,
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, size: 17, color: color),
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
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
    showWebPanel(
      context: context,
      child: const NotificationsScreen(),
      panelWidth: 480,
    );
  }

  void _openPriceCheck(BuildContext context) {
    showWebPanel(
      context: context,
      child: const PriceCheckScreen(),
      panelWidth: 560,
    );
  }

  void _openTeamManagement(BuildContext context) {
    showWebPanel(
      context: context,
      child: const TeamManagementScreen(),
      panelWidth: 820,
    );
  }

  void _openProductAnalysis(BuildContext context) {
    NavigationHelper.openProductAnalysis(
      context,
      source: 'dashboard',
    );
  }

  void _openReportChat(BuildContext context) {
    showWebPanel(
      context: context,
      child: const ReportChatScreen(),
      panelWidth: 520,
    );
  }
}

class _AiChatFab extends StatefulWidget {
  final VoidCallback onTap;

  const _AiChatFab({required this.onTap});

  @override
  State<_AiChatFab> createState() => _AiChatFabState();
}

class _AiChatFabState extends State<_AiChatFab>
    with TickerProviderStateMixin {
  late AnimationController _hoverController;
  late AnimationController _pulseController;
  late Animation<double> _scaleAnim;
  late Animation<double> _pulseAnim;

  @override
  void initState() {
    super.initState();

    _hoverController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _scaleAnim = Tween<double>(begin: 1.0, end: 1.1).animate(
      CurvedAnimation(parent: _hoverController, curve: Curves.easeOutBack),
    );

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    );
    _pulseAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    _pulseController.repeat(reverse: true);
  }

  @override
  void dispose() {
    _hoverController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => _hoverController.forward(),
      onExit: (_) => _hoverController.reverse(),
      child: ScaleTransition(
        scale: _scaleAnim,
        child: GestureDetector(
          onTap: widget.onTap,
          child: AnimatedBuilder(
            animation: _pulseAnim,
            builder: (context, child) {
              return Container(
                width: 76,
                height: 76,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF00E5FF).withValues(
                        alpha: 0.18 + (_pulseAnim.value * 0.22),
                      ),
                      blurRadius: 18 + (_pulseAnim.value * 14),
                      spreadRadius: _pulseAnim.value * 4,
                    ),
                    BoxShadow(
                      color: const Color(0xFFFF4FC8).withValues(
                        alpha: 0.12 + (_pulseAnim.value * 0.15),
                      ),
                      blurRadius: 22 + (_pulseAnim.value * 10),
                      spreadRadius: _pulseAnim.value * 2,
                    ),
                  ],
                ),
                child: CustomPaint(
                  size: const Size(76, 76),
                  painter: _RobotFacePainter(),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _RobotFacePainter extends CustomPainter {
  static const _cyan = Color(0xFF00E8CC);
  static const _pink = Color(0xFFFF4FC8);
  static const _darkBg = Color(0xFF0E0C2A);
  static const _headColor = Color(0xFF111538);
  static const _borderCyan = Color(0xFF00C8FF);

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final r = size.width / 2;

    // ── Arka plan dairesi (koyu lacivert) ──
    final bgPaint = Paint()
      ..shader = RadialGradient(
        colors: [const Color(0xFF1A1650), _darkBg],
        center: const Alignment(-0.2, -0.3),
        radius: 1.0,
      ).createShader(Rect.fromCircle(center: Offset(cx, cy), radius: r));
    canvas.drawCircle(Offset(cx, cy), r, bgPaint);

    // ── Dış gradient border (cyan → pink) ──
    final borderPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..shader = const SweepGradient(
        colors: [_borderCyan, _pink, _borderCyan],
        startAngle: 0,
        endAngle: 6.28,
      ).createShader(Rect.fromCircle(center: Offset(cx, cy), radius: r));
    canvas.drawCircle(Offset(cx, cy), r - 1.5, borderPaint);

    // ── Küçük dekoratif noktalar (çevresinde) ──
    final dotPaintCyan = Paint()..color = _cyan.withValues(alpha: 0.7);
    final dotPaintPink = Paint()..color = _pink.withValues(alpha: 0.7);
    canvas.drawCircle(Offset(cx - r * 0.65, cy - r * 0.55), 3, dotPaintCyan);
    canvas.drawCircle(Offset(cx + r * 0.70, cy - r * 0.45), 2.5, dotPaintPink);
    canvas.drawCircle(Offset(cx - r * 0.60, cy + r * 0.62), 2, dotPaintCyan);
    canvas.drawCircle(Offset(cx + r * 0.62, cy + r * 0.58), 2.5, dotPaintPink);

    // ── Robot baş gövdesi ──
    final headW = size.width * 0.50;
    final headH = size.height * 0.44;
    final headTop = cy - headH * 0.60;
    final headRect = RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset(cx, headTop + headH / 2), width: headW, height: headH),
      const Radius.circular(9),
    );
    final headFillPaint = Paint()
      ..shader = LinearGradient(
        colors: [const Color(0xFF161B45), _headColor],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ).createShader(Rect.fromCenter(center: Offset(cx, cy), width: headW, height: headH));
    canvas.drawRRect(headRect, headFillPaint);

    // baş outline
    final headOutline = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..shader = const LinearGradient(
        colors: [_borderCyan, _pink],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ).createShader(Rect.fromCenter(center: Offset(cx, cy), width: headW, height: headH));
    canvas.drawRRect(headRect, headOutline);

    // ── Sol kulak ──
    final leftEarRect = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(cx - headW / 2 - 5, cy - 4),
        width: 7, height: 16,
      ),
      const Radius.circular(3.5),
    );
    canvas.drawRRect(leftEarRect, Paint()..color = _cyan.withValues(alpha: 0.85));

    // ── Sağ kulak ──
    final rightEarRect = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(cx + headW / 2 + 5, cy - 4),
        width: 7, height: 16,
      ),
      const Radius.circular(3.5),
    );
    canvas.drawRRect(rightEarRect, Paint()..color = _pink.withValues(alpha: 0.85));

    // sağ kulak üst topuz
    canvas.drawCircle(
      Offset(cx + headW / 2 + 5, cy - 4 - 11),
      4,
      Paint()..color = _pink,
    );

    // ── Üst baş aksan (saç/kask kavis) ──
    final hairPaint = Paint()
      ..color = _cyan.withValues(alpha: 0.5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.5
      ..strokeCap = StrokeCap.round;
    final hairPath = Path()
      ..moveTo(cx - headW * 0.28, headTop + 2)
      ..quadraticBezierTo(cx, headTop - 7, cx + headW * 0.28, headTop + 2);
    canvas.drawPath(hairPath, hairPaint);

    // ── Sol göz (cam göbeği / teal) ──
    final eyeY = cy - headH * 0.08;
    final eyeR = headW * 0.145;
    final leftEyeX = cx - headW * 0.22;

    canvas.drawCircle(Offset(leftEyeX, eyeY), eyeR + 2,
        Paint()..color = _cyan.withValues(alpha: 0.25));
    canvas.drawCircle(Offset(leftEyeX, eyeY), eyeR,
        Paint()..color = _cyan);
    canvas.drawCircle(Offset(leftEyeX - eyeR * 0.3, eyeY - eyeR * 0.3), eyeR * 0.35,
        Paint()..color = Colors.white.withValues(alpha: 0.45));

    // ── Sağ göz (pembe / magenta) ──
    final rightEyeX = cx + headW * 0.22;
    canvas.drawCircle(Offset(rightEyeX, eyeY), eyeR + 2,
        Paint()..color = _pink.withValues(alpha: 0.25));
    canvas.drawCircle(Offset(rightEyeX, eyeY), eyeR,
        Paint()..color = _pink);
    canvas.drawCircle(Offset(rightEyeX - eyeR * 0.3, eyeY - eyeR * 0.3), eyeR * 0.35,
        Paint()..color = Colors.white.withValues(alpha: 0.45));

    // ── Yanak noktaları sol (2×2) ──
    final cheekDotPaint = Paint()..color = const Color(0xFF3D4E7A);
    for (int row = 0; row < 2; row++) {
      for (int col = 0; col < 2; col++) {
        canvas.drawCircle(
          Offset(cx - headW * 0.38 + col * 4.5, eyeY + eyeR * 0.6 + row * 4.5),
          1.6, cheekDotPaint,
        );
      }
    }

    // ── Yanak noktaları sağ (2×2) ──
    for (int row = 0; row < 2; row++) {
      for (int col = 0; col < 2; col++) {
        canvas.drawCircle(
          Offset(cx + headW * 0.22 + col * 4.5, eyeY + eyeR * 0.6 + row * 4.5),
          1.6, cheekDotPaint,
        );
      }
    }

    // ── Ağız (yatay yuvarlak dikdörtgen) ──
    final mouthY = cy + headH * 0.26;
    final mouthRect = RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset(cx, mouthY), width: headW * 0.38, height: 6),
      const Radius.circular(3),
    );
    canvas.drawRRect(mouthRect, Paint()..color = const Color(0xFFFF8FAB));

    // ── Boyun / alt bağlantı ──
    final neckRect = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(cx, headTop + headH + 8),
        width: headW * 0.32, height: 7,
      ),
      const Radius.circular(3.5),
    );
    canvas.drawRRect(neckRect,
        Paint()..color = _cyan.withValues(alpha: 0.55));
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
