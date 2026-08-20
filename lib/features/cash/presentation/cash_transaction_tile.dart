import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_tabler_icons/flutter_tabler_icons.dart';

import '../../../core/localization/language_cubit.dart';
import '../../../core/localization/locale_date_time_format.dart';
import '../../../core/localization/locale_number_format.dart';
import '../../../core/theme/theme_extensions.dart';
import '../../../presentation/widgets/expansible_widget.dart';
import '../../../presentation/widgets/ledger_operation_row.dart';
import '../domain/transaction_model.dart';

/// Ledger-styled cash operation row with expandable detail footer.
class CashTransactionTile extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final language = context.watch<LanguageCubit>();
    final colors = context.colors;
    final oCcy = localizedDecimalFormat(context);
    final amount =
        '${transaction.isIncome ? '+' : '-'}${oCcy.format(transaction.amount)}';
    final title = language.translateMessage(transaction.title);
    final category =
        '${language.translateMessage(transaction.category)} • ${language.translate(transaction.paymentMethod.labelKey)}';
    final cashier =
        transaction.cashierName == 'cash_system_user' ||
            transaction.cashierName.toLowerCase() == 'system'
        ? language.translate('cash_system_user')
        : language.translateMessage(transaction.cashierName);
    final registerLabel =
        transaction.registerName ??
        (transaction.registerId != null
            ? language.translate(
                'cash_register_n',
                params: {'id': transaction.registerId!},
              )
            : language.translate('cash_register_main'));

    return ExpansibleWidget(
      cardPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
      title: LedgerOperationRow(
        title: title,
        category: category,
        amount: amount,
        isIncome: transaction.isIncome,
        pillText: formatLocalizedDateTime(
          context,
          transaction.dateTime,
          style: LocalizedDateTimeStyle.dateTime,
        ),
        pillColor: colors.surfaceNested,
        pillTextColor: colors.textSecondary,
      ),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: Column(
            children: [
              _DetailRow(
                label: language.translate('cash_detail_cashier'),
                value: cashier,
              ),
              const SizedBox(height: 6),
              _DetailRow(
                label: language.translate('cash_detail_payment'),
                value: language.translate(transaction.paymentMethod.labelKey),
              ),
              const SizedBox(height: 6),
              _DetailRow(
                label: language.translate('cash_detail_category'),
                value: language.translateMessage(transaction.category),
              ),
              const SizedBox(height: 6),
              _DetailRow(
                label: language.translate('cash_detail_register'),
                value: registerLabel,
              ),
              if (transaction.paymentMethod == PaymentMethod.mixed &&
                  (transaction.cashAmount != null ||
                      transaction.cashlessAmount != null)) ...[
                const SizedBox(height: 6),
                _DetailRow(
                  label: language.translate('cash_mixed_cash'),
                  value: oCcy.format(transaction.cashAmount ?? 0),
                ),
                const SizedBox(height: 6),
                _DetailRow(
                  label: language.translate('cash_mixed_cashless'),
                  value: oCcy.format(transaction.cashlessAmount ?? 0),
                ),
              ],
              if (transaction.bankName != null &&
                  transaction.bankName!.isNotEmpty) ...[
                const SizedBox(height: 6),
                _DetailRow(
                  label: language.translate('cash_bank'),
                  value: transaction.bankName!,
                ),
              ],
              if (transaction.description != null &&
                  transaction.description!.isNotEmpty) ...[
                const SizedBox(height: 6),
                _DetailRow(
                  label: language.translate('cash_description'),
                  value: transaction.description!,
                ),
              ],
              for (final line in transaction.lines) ...[
                const SizedBox(height: 6),
                _DetailRow(
                  label: line.productName ?? line.productId,
                  value:
                      '${oCcy.format(line.qty)} × ${oCcy.format(line.price)}',
                ),
              ],
              if (onEdit != null || onDelete != null) ...[
                const SizedBox(height: 10),
                Row(
                  children: [
                    if (onEdit != null)
                      TextButton(
                        onPressed: onEdit,
                        child: Text(language.translate('cash_edit_operation')),
                      ),
                    const Spacer(),
                    if (onDelete != null)
                      IconButton(
                        tooltip: language.translate('common_delete'),
                        onPressed: onDelete,
                        icon: Icon(
                          TablerIcons.trash,
                          size: 20,
                          color: colors.accentRed,
                        ),
                      ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ],
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
            style: textStyles.captionSans.copyWith(color: colors.textPrimary),
          ),
        ),
      ],
    );
  }
}
