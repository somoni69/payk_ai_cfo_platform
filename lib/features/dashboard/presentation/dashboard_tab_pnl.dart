part of 'dashboard_screen.dart';

Widget _buildPnlTab(BuildContext context, PnlReport? report, String currency) {
  final colors = context.colors;
  final textStyles = context.textStyles;
  final languageCubit = context.read<LanguageCubit>();

  if (report == null) {
    return const DashboardSectionShimmer();
  }

  Widget buildPnlList(
    String title,
    List<PnlRow> rows,
    double total,
    Color totalColor,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: textStyles.bodySans.copyWith(fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 8),
        LedgerCard(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          child: Column(
            children: [
              ...rows.map(
                (row) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          languageCubit.translateMessage(row.category),
                          style: textStyles.bodySans,
                        ),
                      ),
                      Row(
                        children: [
                          Text(
                            '${_formatAmount(context, row.amount)} $currency',
                            style: textStyles.bodyMono.copyWith(
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            width: 50,
                            alignment: Alignment.centerRight,
                            child: Text(
                              '${formatLocalizedNumber(context, row.share, minimumFractionDigits: 1, maximumFractionDigits: 1)}%',
                              style: textStyles.smallMono.copyWith(
                                color: colors.textSecondary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              if (rows.isNotEmpty) const Divider(),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      languageCubit.translate('dashboard_total'),
                      style: textStyles.bodySans.copyWith(
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Text(
                      '${_formatAmount(context, total)} $currency',
                      style: textStyles.bodyMono.copyWith(
                        fontWeight: FontWeight.w500,
                        color: totalColor,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  return ListView(
    padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
    children: [
      _buildFinancePeriodStrip(context),
      const SizedBox(height: 12),
      buildPnlList(
        languageCubit.translate('dashboard_pnl_income_by_category'),
        report.income,
        report.totalIncome,
        colors.accentGreen,
      ),
      const SizedBox(height: 24),
      buildPnlList(
        languageCubit.translate('dashboard_pnl_expenses_by_category'),
        report.expense,
        report.totalExpense,
        colors.accentRed,
      ),
      const SizedBox(height: 24),
      LedgerCard(
        padding: const EdgeInsets.all(16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              languageCubit.translate('dashboard_pnl_net_profit'),
              style: textStyles.bodySans.copyWith(fontWeight: FontWeight.w500),
            ),
            Text(
              '${_formatAmount(context, report.profit)} $currency',
              style: textStyles.bodyMono.copyWith(
                fontWeight: FontWeight.w500,
                fontSize: 18,
                color: report.profit >= 0
                    ? colors.accentGreen
                    : colors.accentRed,
              ),
            ),
          ],
        ),
      ),
    ],
  );
}
