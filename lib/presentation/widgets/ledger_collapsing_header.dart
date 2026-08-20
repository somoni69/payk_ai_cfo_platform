import 'package:flutter/material.dart';
import '../../core/theme/theme_extensions.dart';

/// Reusable Collapsing Header (SliverAppBar) for Ledger design system.
///
/// Implements collapsing toolbar behavior with [pinned], [floating], and [snap] options.
class LedgerCollapsingHeader extends StatelessWidget {
  final String title;
  final Widget? titleWidget;
  final List<Widget>? actions;
  final PreferredSizeWidget? bottom;
  final double? expandedHeight;
  final bool pinned;
  final bool floating;
  final bool snap;

  const LedgerCollapsingHeader({
    super.key,
    required this.title,
    this.titleWidget,
    this.actions,
    this.bottom,
    this.expandedHeight,
    this.pinned = true,
    this.floating = false,
    this.snap = false,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final textStyles = context.textStyles;
    final mediaQuery = MediaQuery.of(context);
    final screenWidth = mediaQuery.size.width;

    // Ревизия типографики AppBar для пропорциональности на всех типах экранов (от компактных до больших)
    // Ограничиваем масштабирование (clamp textScaler) 0.85..1.15, чтобы заголовок в AppBar не раздувался
    final clampedTextScaler = mediaQuery.textScaler.clamp(
      minScaleFactor: 0.9,
      maxScaleFactor: 1.25,
    );

    final double appBarFontSize = screenWidth >= 600
        ? context.fontSize(24)
        : screenWidth >= 428
        ? context.fontSize(23)
        : context.fontSize(22);
    final TextStyle appBarTitleStyle = textStyles.h1Sans.copyWith(
      fontSize: appBarFontSize,
      fontWeight: FontWeight.w600,
      height: 1.2,
    );

    final Widget defaultTitleWidget = Text(
      title,
      style: appBarTitleStyle,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );

    final Widget titleChild = titleWidget ?? defaultTitleWidget;

    final Widget headerTitle = actions != null && actions!.isNotEmpty
        ? Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: DefaultTextStyle.merge(
                  style: appBarTitleStyle,
                  child: titleChild,
                ),
              ),
              DefaultTextStyle.merge(
                style: textStyles.captionSans.copyWith(
                  fontWeight: FontWeight.w500,
                  color: colors.brand,
                ),
                child: IconTheme.merge(
                  data: IconThemeData(size: 18, color: colors.brand),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: actions!,
                  ),
                ),
              ),
            ],
          )
        : DefaultTextStyle.merge(style: appBarTitleStyle, child: titleChild);

    final bool canPop = ModalRoute.of(context)?.canPop ?? false;

    return MediaQuery(
      data: mediaQuery.copyWith(textScaler: clampedTextScaler),
      child: SliverAppBar(
        pinned: pinned,
        floating: floating,
        snap: snap,
        expandedHeight: expandedHeight,
        backgroundColor: colors.surface,
        surfaceTintColor: colors.surface,
        elevation: 0,
        scrolledUnderElevation: 1.0,
        centerTitle: false,
        titleSpacing: canPop ? 0 : 16,
        title: headerTitle,
        actions: null,
        bottom: bottom,
      ),
    );
  }
}

/// Tabs under a screen title: always [captionSans] 14px (w500 selected / w400 idle).
///
/// Prevents header [h1Sans] from leaking into the tab row and keeps every
/// module consistent with [design_language.md].
class LedgerTabBar extends StatelessWidget implements PreferredSizeWidget {
  final TabController? controller;
  final List<Widget> tabs;
  final bool isScrollable;
  final TabAlignment? tabAlignment;
  final ValueChanged<int>? onTap;

  const LedgerTabBar({
    super.key,
    this.controller,
    required this.tabs,
    this.isScrollable = false,
    this.tabAlignment,
    this.onTap,
  });

  @override
  Size get preferredSize => const Size.fromHeight(kTextTabBarHeight);

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final textStyles = context.textStyles;
    return TabBar(
      controller: controller,
      isScrollable: isScrollable,
      tabAlignment:
          tabAlignment ??
          (isScrollable ? TabAlignment.start : TabAlignment.fill),
      onTap: onTap,
      labelColor: colors.brand,
      unselectedLabelColor: colors.textSecondary,
      indicatorColor: colors.brand,
      indicatorSize: TabBarIndicatorSize.tab,
      dividerColor: colors.border,
      labelStyle: textStyles.captionSans.copyWith(
        fontWeight: FontWeight.w500,
        color: colors.brand,
      ),
      unselectedLabelStyle: textStyles.captionSans.copyWith(
        fontWeight: FontWeight.w400,
        color: colors.textSecondary,
      ),
      tabs: tabs,
    );
  }
}
