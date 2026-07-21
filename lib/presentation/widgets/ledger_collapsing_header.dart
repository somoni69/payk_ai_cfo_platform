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
    this.floating = true,
    this.snap = true,
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
      minScaleFactor: 0.85,
      maxScaleFactor: 1.15,
    );

    // Подбираем сбалансированный размер шрифта AppBar (22px для телефонов, 24px для крупных экранов/планшетов)
    final double appBarFontSize = screenWidth >= 600 ? 24.0 : 22.0;
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
              Expanded(child: titleChild),
              Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: actions!,
              ),
            ],
          )
        : titleChild;

    final bool canPop = ModalRoute.of(context)?.canPop ?? false;

    return MediaQuery(
      data: mediaQuery.copyWith(textScaler: clampedTextScaler),
      child: DefaultTextStyle.merge(
        style: appBarTitleStyle,
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
      ),
    );
  }
}
