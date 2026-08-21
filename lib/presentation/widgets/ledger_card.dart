import 'package:flutter/material.dart';
import '../../core/theme/theme_extensions.dart';

/// Visual weight of a [LedgerCard].
enum LedgerCardStyle {
  /// 1px border — lists, forms, dense reports.
  outlined,

  /// No border; separation by spacing.
  plain,

  /// Soft brand/tint fill, no border — heroes and callouts.
  tinted,
}

/// Карточка PAYK: 16px radius, no shadow.
class LedgerCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color? backgroundColor;
  final Color? borderColor;
  final double borderRadius;
  final BoxConstraints? constraints;
  final VoidCallback? onTap;
  final LedgerCardStyle style;

  const LedgerCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.backgroundColor,
    this.borderColor,
    this.borderRadius = 16,
    this.constraints,
    this.onTap,
    this.style = LedgerCardStyle.outlined,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final cardChild = Padding(padding: padding, child: child);

    final Color fill = switch (style) {
      LedgerCardStyle.tinted =>
        backgroundColor ?? colors.brand.withValues(alpha: 0.08),
      LedgerCardStyle.plain ||
      LedgerCardStyle.outlined => backgroundColor ?? colors.surface,
    };

    final BoxBorder? border = switch (style) {
      LedgerCardStyle.outlined => Border.all(
        color: borderColor ?? colors.border,
        width: 1,
      ),
      LedgerCardStyle.plain || LedgerCardStyle.tinted =>
        borderColor == null ? null : Border.all(color: borderColor!, width: 1),
    };

    return Container(
      constraints: constraints,
      decoration: BoxDecoration(
        color: fill,
        border: border,
        borderRadius: BorderRadius.circular(borderRadius),
      ),
      child: onTap != null
          ? Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(borderRadius),
                onTap: onTap,
                child: cardChild,
              ),
            )
          : cardChild,
    );
  }
}
