import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_tabler_icons/flutter_tabler_icons.dart';

import '../../../core/localization/language_cubit.dart';
import '../../../core/localization/locale_number_format.dart';
import '../../../core/theme/theme_extensions.dart';
import '../../../presentation/widgets/ledger_segmented_control.dart';
import '../../../presentation/widgets/ledger_shimmer.dart';
import '../domain/cash_repository.dart';
import '../domain/transaction_model.dart';

/// Чистая прибыль магазина с продаж (выручка − закупка).
class SalesProfitCard extends StatefulWidget {
  const SalesProfitCard({
    super.key,
    this.hideOnError = false,
    this.wrapCard = true,
  });

  final bool hideOnError;
  final bool wrapCard;

  @override
  State<SalesProfitCard> createState() => _SalesProfitCardState();
}

enum _ProfitPeriod { today, week, month }

class _SalesProfitCardState extends State<SalesProfitCard> {
  _ProfitPeriod _period = _ProfitPeriod.today;
  SalesProfit? _data;
  var _loading = true;
  var _failed = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  ({DateTime from, DateTime to}) _range() {
    final now = DateTime.now();
    final to = DateTime(now.year, now.month, now.day, 23, 59, 59);
    return switch (_period) {
      _ProfitPeriod.today => (
        from: DateTime(now.year, now.month, now.day),
        to: to,
      ),
      _ProfitPeriod.week => (
        from: DateTime(
          now.year,
          now.month,
          now.day,
        ).subtract(const Duration(days: 6)),
        to: to,
      ),
      _ProfitPeriod.month => (from: DateTime(now.year, now.month, 1), to: to),
    };
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _failed = false;
    });
    try {
      final range = _range();
      final data = await context.read<CashRepository>().getSalesProfit(
        dateFrom: range.from,
        dateTo: range.to,
      );
      if (!mounted) return;
      setState(() {
        _data = data;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _failed = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_failed && widget.hideOnError) return const SizedBox.shrink();

    final colors = context.colors;
    final textStyles = context.textStyles;
    final language = context.watch<LanguageCubit>();

    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: colors.brand.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                TablerIcons.chart_line,
                size: 18,
                color: colors.brand,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                language.translate('cash_profit_title'),
                style: textStyles.h2Sans.copyWith(
                  fontSize: context.fontSize(16),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        LedgerSegmentedControl<_ProfitPeriod>(
          height: 38,
          segments: [
            for (var i = 0; i < _ProfitPeriod.values.length; i++)
              LedgerSegmentItem(
                value: _ProfitPeriod.values[i],
                label: language.translate(
                  'cash_profit_${_ProfitPeriod.values[i].name}',
                ),
              ),
          ],
          selectedValue: _period,
          onValueChanged: (val) {
            setState(() => _period = val);
            _load();
          },
        ),
        const SizedBox(height: 12),
        if (_failed)
          Text(
            language.translate('cash_profit_load_error'),
            style: textStyles.captionSans.copyWith(color: colors.textSecondary),
          )
        else if (_loading || _data == null)
          LedgerShimmer(
            child: widget.wrapCard
                ? const Row(
                    children: [
                      Expanded(child: ShimmerBox(height: 52, borderRadius: 8)),
                      SizedBox(width: 8),
                      Expanded(child: ShimmerBox(height: 52, borderRadius: 8)),
                    ],
                  )
                : Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: colors.surface,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: colors.border),
                              ),
                              child: const Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  ShimmerBox(
                                    width: 60,
                                    height: 11,
                                    borderRadius: 4,
                                  ),
                                  SizedBox(height: 6),
                                  ShimmerBox(
                                    width: 80,
                                    height: 16,
                                    borderRadius: 4,
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: colors.surface,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: colors.border),
                              ),
                              child: const Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  ShimmerBox(
                                    width: 60,
                                    height: 11,
                                    borderRadius: 4,
                                  ),
                                  SizedBox(height: 6),
                                  ShimmerBox(
                                    width: 80,
                                    height: 16,
                                    borderRadius: 4,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: colors.surface,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: colors.border),
                              ),
                              child: const Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  ShimmerBox(
                                    width: 60,
                                    height: 11,
                                    borderRadius: 4,
                                  ),
                                  SizedBox(height: 6),
                                  ShimmerBox(
                                    width: 80,
                                    height: 16,
                                    borderRadius: 4,
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: colors.surface,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: colors.border),
                              ),
                              child: const Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  ShimmerBox(
                                    width: 60,
                                    height: 11,
                                    borderRadius: 4,
                                  ),
                                  SizedBox(height: 6),
                                  ShimmerBox(
                                    width: 80,
                                    height: 16,
                                    borderRadius: 4,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
          )
        else ...[
          if (!widget.wrapCard) ...[
            Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: colors.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: colors.border),
                    ),
                    child: _metricContent(
                      context,
                      language.translate('cash_profit_revenue'),
                      formatLocalizedNumber(context, _data!.revenue),
                      colors.textPrimary,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: colors.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: colors.border),
                    ),
                    child: _metricContent(
                      context,
                      language.translate('cash_profit_cost'),
                      formatLocalizedNumber(context, _data!.cost),
                      colors.textPrimary,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: colors.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: colors.border),
                    ),
                    child: _metricContent(
                      context,
                      language.translate('cash_profit_profit'),
                      formatLocalizedNumber(context, _data!.profit),
                      _data!.profit >= 0
                          ? colors.accentGreen
                          : colors.accentRed,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: colors.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: colors.border),
                    ),
                    child: _metricContent(
                      context,
                      language.translate('cash_profit_markup'),
                      _data!.markupPercent == null
                          ? '—'
                          : '${formatLocalizedNumber(context, _data!.markupPercent!)}%',
                      colors.textPrimary,
                    ),
                  ),
                ),
              ],
            ),
          ] else ...[
            Row(
              children: [
                _metric(
                  context,
                  language.translate('cash_profit_revenue'),
                  formatLocalizedNumber(context, _data!.revenue),
                  colors.textPrimary,
                ),
                _metric(
                  context,
                  language.translate('cash_profit_cost'),
                  formatLocalizedNumber(context, _data!.cost),
                  colors.textPrimary,
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                _metric(
                  context,
                  language.translate('cash_profit_profit'),
                  formatLocalizedNumber(context, _data!.profit),
                  _data!.profit >= 0 ? colors.accentGreen : colors.accentRed,
                ),
                _metric(
                  context,
                  language.translate('cash_profit_markup'),
                  _data!.markupPercent == null
                      ? '—'
                      : '${formatLocalizedNumber(context, _data!.markupPercent!)}%',
                  colors.textPrimary,
                ),
              ],
            ),
          ],
          if (_data!.itemsSold == 0) ...[
            const SizedBox(height: 8),
            Text(
              language.translate('cash_profit_no_sales'),
              style: textStyles.smallSans.copyWith(color: colors.textTooltip),
            ),
          ],
          if (_data!.missingCost.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              language.translate(
                'cash_profit_missing_cost',
                params: {
                  'names':
                      _data!.missingCost.take(5).join(', ') +
                      (_data!.missingCost.length > 5 ? '…' : ''),
                },
              ),
              style: textStyles.smallSans.copyWith(color: colors.accentAmber),
            ),
          ],
        ],
      ],
    );

    if (!widget.wrapCard) {
      return content;
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.border),
      ),
      child: content,
    );
  }

  Widget _metricContent(
    BuildContext context,
    String label,
    String value,
    Color valueColor,
  ) {
    final textStyles = context.textStyles;
    final colors = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: textStyles.captionSans.copyWith(color: colors.textSecondary),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: textStyles.bodyMono.copyWith(
            fontWeight: FontWeight.w600,
            fontSize: context.fontSize(15),
            color: valueColor,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }

  Widget _metric(
    BuildContext context,
    String label,
    String value,
    Color valueColor,
  ) {
    final textStyles = context.textStyles;
    final colors = context.colors;
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: textStyles.smallSans.copyWith(color: colors.textTooltip),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: textStyles.bodyMono.copyWith(
              fontWeight: FontWeight.w500,
              color: valueColor,
            ),
          ),
        ],
      ),
    );
  }
}
