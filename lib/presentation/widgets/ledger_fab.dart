import 'package:flutter/material.dart';
import 'package:flutter_tabler_icons/flutter_tabler_icons.dart';

import '../../core/theme/ledger_buttons.dart';
import '../../core/theme/theme_extensions.dart';

/// Branded floating action button used on screens (not inside sheets).
class LedgerFab extends StatelessWidget {
  const LedgerFab({
    super.key,
    required this.onPressed,
    required this.label,
    this.icon = TablerIcons.plus,
    this.iconWidget,
    this.heroTag,
  });

  final VoidCallback? onPressed;
  final String label;
  final IconData icon;
  final Widget? iconWidget;
  final Object? heroTag;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final textStyles = context.textStyles;

    return FloatingActionButton.extended(
      heroTag: heroTag,
      onPressed: onPressed,
      backgroundColor: colors.brand,
      foregroundColor: colors.surface,
      elevation: 0,
      highlightElevation: 0,
      focusElevation: 0,
      hoverElevation: 0,
      disabledElevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(kLedgerScreenButtonRadius),
      ),
      icon:
          iconWidget ??
          Icon(icon, size: kLedgerScreenButtonIcon, color: colors.surface),
      label: Text(
        label,
        style: textStyles.bodySans.copyWith(
          color: colors.surface,
          fontWeight: FontWeight.w600,
          fontSize: kLedgerScreenButtonFont,
        ),
      ),
    );
  }
}
