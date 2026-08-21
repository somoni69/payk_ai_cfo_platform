part of 'dashboard_screen.dart';

/// API period key `yyyy-MM` (not a display string).
String _defaultPlanPeriod() {
  final now = DateTime.now();
  final m = now.month.toString().padLeft(2, '0');
  return '${now.year}-$m';
}

Widget _buildPlanFactTab(
  BuildContext context,
  PlanFactReport? report,
  String currency,
) {
  final colors = context.colors;
  final textStyles = context.textStyles;
  final languageCubit = context.read<LanguageCubit>();

  if (report == null) {
    return const DashboardSectionShimmer();
  }

  final overallCompletion = report.totalPlanned > 0
      ? (report.totalFact / report.totalPlanned) * 100
      : 0.0;

  return ListView(
    padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
    children: [
      LedgerCard(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              languageCubit.translate('dashboard_budget_completion'),
              style: textStyles.captionSans.copyWith(
                color: colors.textSecondary,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${formatLocalizedNumber(context, overallCompletion, minimumFractionDigits: 1, maximumFractionDigits: 1)}%',
                  style: textStyles.h1Sans.copyWith(
                    color: colors.brand,
                    fontSize: 32,
                  ),
                ),
                Text(
                  '${_formatAmount(context, report.totalFact)} / ${_formatAmount(context, report.totalPlanned)} $currency',
                  style: textStyles.bodyMono.copyWith(
                    color: colors.textSecondary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: (overallCompletion / 100).clamp(0.0, 1.0),
                backgroundColor: colors.border,
                color: colors.brand,
                minHeight: 8,
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: 20),
      Text(
        languageCubit.translate('dashboard_category_comparison'),
        style: textStyles.bodySans.copyWith(fontWeight: FontWeight.w500),
      ),
      const SizedBox(height: 8),
      ...report.rows.map((row) {
        final isIncome =
            row.type == 'INFLOW' ||
            row.type == 'income' ||
            row.type.toLowerCase() == 'income';
        final compVal = row.completion;

        Color statusColor;
        if (isIncome) {
          statusColor = compVal >= 90
              ? colors.accentGreen
              : (compVal >= 70 ? colors.accentAmber : colors.accentRed);
        } else {
          statusColor = compVal <= 100
              ? colors.accentGreen
              : (compVal <= 110 ? colors.accentAmber : colors.accentRed);
        }

        return Padding(
          padding: const EdgeInsets.only(bottom: 10.0),
          child: LedgerCard(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        languageCubit.translateMessage(row.category),
                        style: textStyles.bodySans.copyWith(
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        '${formatLocalizedNumber(context, compVal, minimumFractionDigits: 1, maximumFractionDigits: 1)}%',
                        style: textStyles.smallMono.copyWith(
                          color: statusColor,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          languageCubit.translate('dashboard_plan'),
                          style: textStyles.captionSans.copyWith(
                            color: colors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${_formatAmount(context, row.planned)} $currency',
                          style: textStyles.bodyMono,
                        ),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          languageCubit.translate('dashboard_fact'),
                          style: textStyles.captionSans.copyWith(
                            color: colors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${_formatAmount(context, row.fact)} $currency',
                          style: textStyles.bodyMono.copyWith(
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const Divider(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      languageCubit.translate('dashboard_deviation'),
                      style: textStyles.captionSans.copyWith(
                        color: colors.textSecondary,
                      ),
                    ),
                    Text(
                      '${row.deviation >= 0 ? "+" : ""}${_formatAmount(context, row.deviation)} $currency',
                      style: textStyles.bodyMono.copyWith(
                        color: row.deviation >= 0
                            ? colors.accentGreen
                            : colors.accentRed,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      }),
    ],
  );
}

Future<void> _showCreatePlanSheet(BuildContext context, String period) async {
  final colors = context.colors;
  final textStyles = context.textStyles;
  final language = context.read<LanguageCubit>();
  final categoryCtrl = TextEditingController();
  final amountCtrl = TextEditingController();
  String type = 'expense';

  try {
    await LedgerBottomSheet.show(
      context: context,
      title: language.translate('dashboard_plan_add'),
      builder: (context, setSheetState) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: categoryCtrl,
              style: textStyles.bodySans,
              decoration: InputDecoration(
                labelText: language.translate('dashboard_plan_category'),
              ),
            ),
            const SizedBox(height: 12),
            ExpansibleWidget<String>.selection(
              cardPadding: EdgeInsets.zero,
              tilePadding: const EdgeInsets.symmetric(horizontal: 8),
              title: Text(
                type == 'income'
                    ? language.translate('cash_income')
                    : language.translate('cash_expense'),
                style: textStyles.bodySans.copyWith(
                  fontWeight: FontWeight.w500,
                ),
              ),
              items: const ['income', 'expense'],
              selectedValue: type,
              itemLabelBuilder: (v) => v == 'income'
                  ? language.translate('cash_income')
                  : language.translate('cash_expense'),
              onSelected: (v) => setSheetState(() => type = v),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: amountCtrl,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              style: textStyles.bodySans,
              decoration: InputDecoration(
                labelText: language.translate('dashboard_plan_amount'),
              ),
            ),
          ],
        );
      },
      footerBuilder: (context, setSheetState) {
        return SizedBox(
          width: double.infinity,
          height: 48,
          child: ElevatedButton(
            onPressed: () {
              final category = categoryCtrl.text.trim();
              final amount =
                  parseLocalizedNumber(context, amountCtrl.text.trim()) ?? 0;
              if (category.isEmpty || amount <= 0) return;
              context.read<DashboardBloc>().add(
                CreatePlanRequested(
                  period: period.isEmpty ? _defaultPlanPeriod() : period,
                  category: category,
                  type: type,
                  plannedAmount: amount,
                ),
              );
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: colors.brand,
              foregroundColor: colors.surface,
              elevation: 0,
            ),
            child: Text(language.translate('common_create')),
          ),
        );
      },
    );
  } finally {
    categoryCtrl.dispose();
    amountCtrl.dispose();
  }
}
