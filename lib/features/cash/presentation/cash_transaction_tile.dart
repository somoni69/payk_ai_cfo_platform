import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_tabler_icons/flutter_tabler_icons.dart';

import '../../../core/localization/language_cubit.dart';
import '../../../core/localization/locale_date_time_format.dart';
import '../../../core/localization/locale_number_format.dart';
import '../../../core/theme/theme_extensions.dart';
import '../../../presentation/widgets/ledger_card.dart';
import '../../../presentation/widgets/ledger_pill.dart';
import '../domain/transaction_model.dart';

/// Modern fintech transaction card with visual category icon and clean detail drawer.
class CashTransactionTile extends StatefulWidget {
  const CashTransactionTile({
    super.key,
    required this.transaction,
    this.onEdit,
    this.onDelete,
  });

  final Transaction transaction;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  @override
  State<CashTransactionTile> createState() => _CashTransactionTileState();
}

class _CashTransactionTileState extends State<CashTransactionTile> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final language = context.watch<LanguageCubit>();
    final colors = context.colors;
    final textStyles = context.textStyles;
    final oCcy = localizedDecimalFormat(context);
    final tx = widget.transaction;

    final amountFormatted =
        '${tx.isIncome ? '+' : '-'}${oCcy.format(tx.amount)}';
    final title = language.translateMessage(tx.title);
    final cashier =
        tx.cashierName == 'cash_system_user' ||
            tx.cashierName.toLowerCase() == 'system'
        ? language.translate('cash_system_user')
        : language.translateMessage(tx.cashierName);
    final registerLabel =
        tx.registerName ??
        (tx.registerId != null
            ? language.translate(
                'cash_register_n',
                params: {'id': tx.registerId!},
              )
            : language.translate('cash_register_main'));

    final iconColor = tx.isIncome ? colors.accentGreen : colors.accentRed;
    final iconBg = iconColor.withValues(alpha: 0.12);

    return LedgerCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      onTap: () => setState(() => _expanded = !_expanded),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              // Pastel circular category icon
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: iconBg,
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Icon(
                  tx.isIncome
                      ? TablerIcons.arrow_down_left
                      : TablerIcons.arrow_up_right,
                  size: 20,
                  color: iconColor,
                ),
              ),
              const SizedBox(width: 12),
              // Main content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: textStyles.bodySans.copyWith(
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        LedgerPill(
                          text: formatLocalizedDateTime(
                            context,
                            tx.dateTime,
                            style: LocalizedDateTimeStyle.time,
                          ),
                          backgroundColor: colors.surfaceNested,
                          textColor: colors.textSecondary,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            '${language.translateMessage(tx.category)} • ${language.translate(tx.paymentMethod.labelKey)}',
                            style: textStyles.captionSans.copyWith(
                              color: colors.textSecondary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              // Amount and chevron
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    amountFormatted,
                    style: textStyles.bodySans.copyWith(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: tx.isIncome
                          ? colors.accentGreen
                          : colors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Icon(
                    _expanded
                        ? TablerIcons.chevron_up
                        : TablerIcons.chevron_down,
                    size: 16,
                    color: colors.textTooltip,
                  ),
                ],
              ),
            ],
          ),
          if (_expanded) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: colors.surfaceNested,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                children: [
                  _DetailRow(
                    label: language.translate('cash_detail_cashier'),
                    value: cashier,
                  ),
                  const SizedBox(height: 6),
                  _DetailRow(
                    label: language.translate('cash_detail_payment'),
                    value: language.translate(tx.paymentMethod.labelKey),
                  ),
                  const SizedBox(height: 6),
                  _DetailRow(
                    label: language.translate('cash_detail_category'),
                    value: language.translateMessage(tx.category),
                  ),
                  const SizedBox(height: 6),
                  _DetailRow(
                    label: language.translate('cash_detail_register'),
                    value: registerLabel,
                  ),
                  if (tx.paymentMethod == PaymentMethod.mixed &&
                      (tx.cashAmount != null || tx.cashlessAmount != null)) ...[
                    const SizedBox(height: 6),
                    _DetailRow(
                      label: language.translate('cash_mixed_cash'),
                      value: oCcy.format(tx.cashAmount ?? 0),
                    ),
                    const SizedBox(height: 6),
                    _DetailRow(
                      label: language.translate('cash_mixed_cashless'),
                      value: oCcy.format(tx.cashlessAmount ?? 0),
                    ),
                  ],
                  if (tx.bankName != null && tx.bankName!.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    _DetailRow(
                      label: language.translate('cash_bank'),
                      value: tx.bankName!,
                    ),
                  ],
                  if (tx.description != null && tx.description!.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    _DetailRow(
                      label: language.translate('cash_description'),
                      value: tx.description!,
                    ),
                  ],
                  if (tx.lines.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    const Divider(height: 1),
                    const SizedBox(height: 8),
                    for (final line in tx.lines)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: _DetailRow(
                          label: line.productName ?? line.productId,
                          value:
                              '${oCcy.format(line.qty)} × ${oCcy.format(line.price)}',
                        ),
                      ),
                  ],
                ],
              ),
            ),
            if (widget.onEdit != null || widget.onDelete != null) ...[
              const SizedBox(height: 10),
              Row(
                children: [
                  if (widget.onEdit != null)
                    TextButton.icon(
                      onPressed: widget.onEdit,
                      icon: const Icon(TablerIcons.pencil, size: 16),
                      label: Text(language.translate('cash_edit_operation')),
                    ),
                  const Spacer(),
                  if (widget.onDelete != null)
                    IconButton(
                      tooltip: language.translate('common_delete'),
                      onPressed: widget.onDelete,
                      icon: Icon(
                        TablerIcons.trash,
                        size: 18,
                        color: colors.accentRed,
                      ),
                    ),
                ],
              ),
            ],
          ],
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final textStyles = context.textStyles;
    final colors = context.colors;
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: textStyles.captionSans.copyWith(color: colors.textSecondary),
          ),
        ),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: textStyles.captionSans.copyWith(
              color: colors.textPrimary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }
}
