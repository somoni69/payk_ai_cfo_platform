import 'package:flutter/material.dart';
import 'package:flutter_tabler_icons/flutter_tabler_icons.dart';
import '../../core/theme/theme_extensions.dart';
import 'ledger_pill.dart';
import 'ledger_spotlight.dart';

/// Строка события: иконка смысла, заголовок, сумма как акцент.
class LedgerOperationRow extends StatelessWidget {
  final String title;
  final String category;
  final String amount;
  final bool isIncome;
  final String? pillText;
  final Color? pillColor;
  final Color? pillTextColor;
  final VoidCallback? onTap;
  final IconData? leadingIcon;

  const LedgerOperationRow({
    super.key,
    required this.title,
    required this.category,
    required this.amount,
    required this.isIncome,
    this.pillText,
    this.pillColor,
    this.pillTextColor,
    this.onTap,
    this.leadingIcon,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final textStyles = context.textStyles;
    final accent = isIncome ? colors.accentGreen : colors.accentRed;

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
        child: Row(
          children: [
            LedgerIconBadge(
              icon:
                  leadingIcon ??
                  (isIncome
                      ? TablerIcons.arrow_down_left
                      : TablerIcons.arrow_up_right),
              color: accent,
              size: 36,
              iconSize: 18,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: textStyles.bodySans.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      if (pillText != null) ...[
                        LedgerPill(
                          text: pillText!,
                          backgroundColor: pillColor ?? colors.surfaceNested,
                          textColor: pillTextColor ?? colors.textSecondary,
                        ),
                        const SizedBox(width: 8),
                      ],
                      Expanded(
                        child: Text(
                          category,
                          style: textStyles.captionSans,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Text(
              amount,
              style: textStyles.bodySans.copyWith(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: accent,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
