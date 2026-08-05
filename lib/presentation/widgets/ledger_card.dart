import 'package:flutter/material.dart';
import '../../core/theme/theme_extensions.dart';

/// Карточка в дизайн-системе Ledger.
/// Скругление 16px, граница 1px (`border`), без теней.
class LedgerCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color? backgroundColor;
  final Color? borderColor;
  final double borderRadius;
  final VoidCallback? onTap;

  const LedgerCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.backgroundColor,
    this.borderColor,
    this.borderRadius = 16,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cardChild = Padding(padding: padding, child: child);

    return Container(
      decoration: BoxDecoration(
        color: backgroundColor ?? context.colors.surface,
        border: Border.all(
          color: borderColor ?? context.colors.border,
          width: 1,
        ),
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
