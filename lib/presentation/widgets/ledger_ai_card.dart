import 'package:flutter/material.dart';
import '../../core/theme/theme_extensions.dart';

/// Карточка AI-советника в дизайн-системе Ledger.
/// Выделяется янтарной границей/акцентом, используется для подсказок, прогнозов и предупреждений.
class LedgerAICard extends StatelessWidget {
  final String title;
  final String content;
  final Widget? trailing;

  const LedgerAICard({
    super.key,
    required this.title,
    required this.content,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final textStyles = context.textStyles;

    return Container(
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border.all(color: colors.accentAmber, width: 1),
        borderRadius: BorderRadius.circular(16),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 4,
                height: 16,
                decoration: BoxDecoration(
                  color: colors.accentAmber,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: textStyles.bodySans.copyWith(
                    color: colors.accentAmber,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              ?trailing,
            ],
          ),
          const SizedBox(height: 8),
          Text(
            content,
            style: textStyles.captionSans.copyWith(color: colors.textSecondary),
          ),
        ],
      ),
    );
  }
}
