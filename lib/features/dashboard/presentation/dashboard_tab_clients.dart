part of 'dashboard_screen.dart';

Widget _buildClientsTab(BuildContext context, ClientAnalysisReport report) {
  final colors = context.colors;
  final textStyles = context.textStyles;
  final language = context.read<LanguageCubit>();
  final oCcy = localizedDecimalFormat(context);

  Widget section(String title, List<ClientAnalysisRow> rows, Color accent) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: textStyles.bodySans.copyWith(fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 8),
        if (rows.isEmpty)
          LedgerCard(
            child: Text(
              language.translate('dashboard_clients_empty'),
              style: textStyles.captionSans.copyWith(
                color: colors.textSecondary,
              ),
            ),
          )
        else
          ...rows.map(
            (row) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: LedgerCard(
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            row.name,
                            style: textStyles.bodySans.copyWith(
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            language.translate(
                              'dashboard_clients_purchases',
                              params: {'count': row.purchases},
                            ),
                            style: textStyles.captionSans.copyWith(
                              color: colors.textSecondary,
                            ),
                          ),
                          if (row.daysSince != null)
                            Text(
                              language.translate(
                                'dashboard_clients_days_since',
                                params: {'days': row.daysSince},
                              ),
                              style: textStyles.smallSans.copyWith(
                                color: colors.textTooltip,
                              ),
                            ),
                        ],
                      ),
                    ),
                    Text(
                      '${oCcy.format(row.total)} TJS',
                      style: textStyles.bodyMono.copyWith(
                        fontWeight: FontWeight.w500,
                        color: accent,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }

  return ListView(
    padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
    children: [
      section(
        language.translate('dashboard_clients_frequent'),
        report.frequent,
        colors.accentGreen,
      ),
      const SizedBox(height: 20),
      section(
        language.translate('dashboard_clients_dormant'),
        report.dormant,
        colors.accentRed,
      ),
    ],
  );
}
