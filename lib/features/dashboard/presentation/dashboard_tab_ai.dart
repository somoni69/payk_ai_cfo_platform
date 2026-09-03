part of 'dashboard_screen.dart';

Widget _buildAiInsightsTab(
  BuildContext context,
  AiInsightsReport? report,
  String currency,
) {
  final colors = context.colors;
  final textStyles = context.textStyles;
  final languageCubit = context.read<LanguageCubit>();

  if (report == null) {
    return const DashboardSectionShimmer(kind: DashboardShimmerKind.ai);
  }

  final isRisk = report.forecast.atRisk;

  return ListView(
    padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
    children: [
      LedgerCard(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  isRisk
                      ? TablerIcons.alert_triangle
                      : TablerIcons.shield_check,
                  color: isRisk ? colors.accentRed : colors.accentGreen,
                ),
                const SizedBox(width: 10),
                Text(
                  languageCubit.translate('dashboard_cash_gap_risk'),
                  style: textStyles.bodySans.copyWith(
                    fontWeight: FontWeight.w500,
                    color: isRisk ? colors.accentRed : colors.accentGreen,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              languageCubit.translateMessage(report.forecast.message),
              style: textStyles.bodySans,
            ),
            if (report.forecast.daysToZero != null) ...[
              const SizedBox(height: 10),
              Text(
                languageCubit.translate(
                  'dashboard_days_to_cash_gap',
                  params: {'days': report.forecast.daysToZero},
                ),
                style: textStyles.bodySans.copyWith(
                  fontWeight: FontWeight.w500,
                  color: colors.accentRed,
                ),
              ),
            ],
          ],
        ),
      ),
      const SizedBox(height: 20),
      Text(
        languageCubit.translate('dashboard_ai_recommendations_analysis'),
        style: textStyles.bodySans.copyWith(fontWeight: FontWeight.w500),
      ),
      const SizedBox(height: 8),
      LedgerCard(
        padding: const EdgeInsets.all(16),
        child: Text(
          languageCubit.translateMessage(report.recommendations),
          style: textStyles.bodySans.copyWith(height: 1.4),
        ),
      ),
    ],
  );
}
