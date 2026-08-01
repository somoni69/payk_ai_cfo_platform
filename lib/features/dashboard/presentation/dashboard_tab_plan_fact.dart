part of 'dashboard_screen.dart';

extension _DashboardPlanFactTab on _DashboardViewState {
  Widget _buildPlanFactTab(
    BuildContext context,
    PlanFactReport? report,
    String currency,
  ) {
    final colors = context.colors;
    final textStyles = context.textStyles;
    final languageCubit = context.read<LanguageCubit>();

    if (report == null) {
      return const Center(child: CircularProgressIndicator());
    }

    final overallCompletion = report.totalPlanned > 0
        ? (report.totalFact / report.totalPlanned) * 100
        : 0.0;

    return RefreshIndicator(
      onRefresh: () => _refreshDashboard(context),
      child: ListView(
        padding: const EdgeInsets.all(16),
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
            final isIncome = row.type == 'INFLOW' || row.type == 'income';
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
      ),
    );
  }
}
