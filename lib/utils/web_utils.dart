import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

// ─────────────────────────────────────────────
// Breakpoints
// ─────────────────────────────────────────────
class WebBreakpoints {
  static const double mobile = 700;
  static const double tablet = 1100;
  // >= tablet → desktop

  static bool isMobile(BuildContext context) =>
      MediaQuery.of(context).size.width < mobile;

  static bool isTablet(BuildContext context) {
    final w = MediaQuery.of(context).size.width;
    return w >= mobile && w < tablet;
  }

  static bool isDesktop(BuildContext context) =>
      MediaQuery.of(context).size.width >= tablet;

  static bool isWebOrDesktop(BuildContext context) =>
      kIsWeb || isDesktop(context);
}

// ─────────────────────────────────────────────
// WebPageWrapper
// Ekran genişliğini 1400px ile sınırlar, yatayda ortalar,
// web'de daha büyük padding uygular.
// ─────────────────────────────────────────────
class WebPageWrapper extends StatelessWidget {
  final Widget child;
  final double maxWidth;
  final EdgeInsetsGeometry? padding;

  const WebPageWrapper({
    super.key,
    required this.child,
    this.maxWidth = 1400,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    final isDesktop = WebBreakpoints.isDesktop(context);
    final defaultPadding = isDesktop
        ? const EdgeInsets.symmetric(horizontal: 32, vertical: 24)
        : const EdgeInsets.all(16);

    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: Padding(
          padding: padding ?? defaultPadding,
          child: child,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// WebResponsiveGrid
// Ekran genişliğine göre sütun sayısını otomatik ayarlar.
// ─────────────────────────────────────────────
class WebResponsiveGrid extends StatelessWidget {
  final List<Widget> children;
  final int mobileCols;
  final int tabletCols;
  final int desktopCols;
  final double spacing;

  const WebResponsiveGrid({
    super.key,
    required this.children,
    this.mobileCols = 2,
    this.tabletCols = 3,
    this.desktopCols = 4,
    this.spacing = 16,
  });

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final cols = width >= WebBreakpoints.tablet
        ? desktopCols
        : width >= WebBreakpoints.mobile
            ? tabletCols
            : mobileCols;

    return LayoutBuilder(
      builder: (context, constraints) {
        final itemWidth =
            (constraints.maxWidth - spacing * (cols - 1)) / cols;
        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: children
              .map((child) => SizedBox(width: itemWidth, child: child))
              .toList(),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────
// Web-aware page title widget
// ─────────────────────────────────────────────
class WebPageTitle extends StatelessWidget {
  final String title;
  final String? subtitle;
  final List<Widget>? actions;

  const WebPageTitle({
    super.key,
    required this.title,
    this.subtitle,
    this.actions,
  });

  @override
  Widget build(BuildContext context) {
    final isDesktop = WebBreakpoints.isDesktop(context);
    if (!isDesktop) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.5,
                  ),
                ),
                if (subtitle != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      subtitle!,
                      style: const TextStyle(
                        fontSize: 14,
                        color: Colors.grey,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          if (actions != null) ...actions!,
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Web-aware dialog helper — daha geniş dialog
// ─────────────────────────────────────────────
Future<T?> showWebDialog<T>({
  required BuildContext context,
  required Widget Function(BuildContext) builder,
  double maxWidth = 560,
}) {
  return showDialog<T>(
    context: context,
    builder: (ctx) => Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: builder(ctx),
      ),
    ),
  );
}

// ─────────────────────────────────────────────
// Web panel açıcı
// Desktop'ta: sağdan kayan büyük panel (sidebar görünür kalır)
// Mobil'de: tam ekran route push
// ─────────────────────────────────────────────
Future<T?> showWebPanel<T>({
  required BuildContext context,
  required Widget child,
  double panelWidth = 820,
}) {
  if (!WebBreakpoints.isDesktop(context)) {
    return Navigator.of(context).push<T>(
      MaterialPageRoute(builder: (_) => child),
    );
  }

  final screenWidth = MediaQuery.of(context).size.width;
  final screenHeight = MediaQuery.of(context).size.height;

  return showGeneralDialog<T>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Panel',
    barrierColor: Colors.black.withValues(alpha: 0.35),
    transitionDuration: const Duration(milliseconds: 220),
    pageBuilder: (ctx, anim1, anim2) {
      return Align(
        alignment: Alignment.centerRight,
        child: Material(
          color: Colors.transparent,
          child: Container(
            width: panelWidth.clamp(400, screenWidth * 0.75),
            height: screenHeight,
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(16),
                bottomLeft: Radius.circular(16),
              ),
            ),
            clipBehavior: Clip.antiAlias,
            child: child,
          ),
        ),
      );
    },
    transitionBuilder: (ctx, anim1, anim2, child) {
      final curved = CurvedAnimation(
        parent: anim1,
        curve: Curves.easeOutCubic,
      );
      return SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(1, 0),
          end: Offset.zero,
        ).animate(curved),
        child: child,
      );
    },
  );
}
