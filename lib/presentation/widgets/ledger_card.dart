import 'package:flutter/material.dart';
import '../../core/theme/theme_extensions.dart';

/// Карточка в дизайн-системе Ledger.
/// Применяет скругление 10px, границу 1px и отключает тени.
class LedgerCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color? backgroundColor;
  final Color? borderColor;

  const LedgerCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.backgroundColor,
    this.borderColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: backgroundColor ?? context.colors.surface,
        border: Border.all(
          color: borderColor ?? context.colors.border,
          width: 1,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      padding: padding,
      child: child,
    );
  }
}
