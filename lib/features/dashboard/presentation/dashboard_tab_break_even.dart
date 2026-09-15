part of 'dashboard_screen.dart';

Widget _buildBreakEvenTab(
  BuildContext context,
  BreakEvenAnalysis? report,
  String currency,
) {
  final colors = context.colors;
  final textStyles = context.textStyles;
  final languageCubit = context.read<LanguageCubit>();

  final blocState = context.watch<DashboardBloc>().state;
  final isLoading =
      blocState is DashboardLoaded &&
      blocState.loadingSections.contains(DashboardSection.breakEven);
  if (report == null || isLoading) {
    return const DashboardSectionShimmer(kind: DashboardShimmerKind.breakEven);
  }

  final safetyPercent = report.marginOfSafety;
  final isSafe = safetyPercent > 20;

  return ListView(
    padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
    children: [
      _buildFinancePeriodStrip(context),
      const SizedBox(height: 12),
      LedgerCard(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              languageCubit.translate('dashboard_margin_of_safety'),
              style: textStyles.captionSans.copyWith(
                color: colors.textSecondary,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${formatLocalizedNumber(context, safetyPercent, minimumFractionDigits: 1, maximumFractionDigits: 1)}%',
                  style: textStyles.h1Sans.copyWith(
                    color: isSafe ? colors.accentGreen : colors.accentRed,
                    fontSize: 32,
                  ),
                ),
                Text(
                  isSafe
                      ? languageCubit.translate('dashboard_business_stable')
                      : languageCubit.translate('dashboard_danger_zone'),
                  style: textStyles.captionSans.copyWith(
                    color: isSafe ? colors.accentGreen : colors.accentRed,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: (safetyPercent / 100).clamp(0.0, 1.0),
                backgroundColor: colors.border,
                color: isSafe ? colors.accentGreen : colors.accentRed,
                minHeight: 8,
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: 20),
      Text(
        languageCubit.translate('dashboard_break_even_metrics'),
        style: textStyles.bodySans.copyWith(fontWeight: FontWeight.w500),
      ),
      const SizedBox(height: 8),
      LedgerCard(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _buildReportRow(
              languageCubit.translate('dashboard_current_revenue'),
              '${_formatAmount(context, report.revenue)} $currency',
              textStyles.bodySans,
            ),
            const Divider(),
            _buildReportRow(
              languageCubit.translate('dashboard_break_even_point'),
              '${_formatAmount(context, report.breakEvenRevenue)} $currency',
              textStyles.bodySans,
              valueColor: colors.brand,
            ),
            const Divider(),
            _buildReportRow(
              languageCubit.translate('dashboard_fixed_costs'),
              '${_formatAmount(context, report.fixedCosts)} $currency',
              textStyles.bodySans,
            ),
            const Divider(),
            _buildReportRow(
              languageCubit.translate('dashboard_variable_costs'),
              '${_formatAmount(context, report.variableCosts)} $currency',
              textStyles.bodySans,
            ),
            const Divider(),
            _buildReportRow(
              languageCubit.translate('dashboard_variable_ratio'),
              '${formatLocalizedNumber(context, report.variableRatio * 100, minimumFractionDigits: 1, maximumFractionDigits: 1)}%',
              textStyles.bodySans,
            ),
            const Divider(),
            _buildReportRow(
              languageCubit.translate('dashboard_contribution_margin_ratio'),
              '${formatLocalizedNumber(context, (1 - report.variableRatio) * 100, minimumFractionDigits: 1, maximumFractionDigits: 1)}%',
              textStyles.bodySans,
            ),
          ],
        ),
      ),
    ],
  );
}
