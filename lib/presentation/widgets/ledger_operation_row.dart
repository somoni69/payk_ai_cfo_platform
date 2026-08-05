import 'package:flutter/material.dart';
import '../../core/theme/theme_extensions.dart';
import 'ledger_pill.dart';

/// Строка операции в списке транзакций.
/// Содержит заголовок, категорию, статус-пилюлю и сумму в формате Mono.
class LedgerOperationRow extends StatelessWidget {
  final String title;
  final String category;
  final String amount;
  final bool isIncome;
  final String? pillText;
  final Color? pillColor;
  final Color? pillTextColor;
  final VoidCallback? onTap;

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
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final textStyles = context.textStyles;

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: textStyles.bodySans.copyWith(
                      fontSize: 16,
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
                          style: textStyles.captionSans.copyWith(fontSize: 14),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            Text(
              amount,
              style: textStyles.bodyMono.copyWith(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: isIncome ? colors.accentGreen : colors.accentRed,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
