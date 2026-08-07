part of 'dashboard_screen.dart';

extension _DashboardAbcTab on _DashboardViewState {
  Widget _buildAbcTab(
    BuildContext context,
    AbcAnalysis? report,
    String currency,
  ) {
    final colors = context.colors;
    final textStyles = context.textStyles;
    final languageCubit = context.read<LanguageCubit>();

    if (report == null) {
      return const Center(child: CircularProgressIndicator());
    }

    final isCategory = report.dimension == 'category';

    return RefreshIndicator(
      onRefresh: () => _refreshDashboard(context),
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            children: [
              Expanded(
                child: ChoiceChip(
                  label: Text(
                    languageCubit.translate('dashboard_abc_by_categories'),
                  ),
                  labelStyle: textStyles.captionSans.copyWith(
                    color: isCategory ? Colors.white : colors.textPrimary,
                    fontWeight: isCategory ? FontWeight.w500 : FontWeight.w400,
                  ),
                  checkmarkColor: Colors.white,
                  selected: isCategory,
                  onSelected: (val) {
                    if (val) {
                      context.read<DashboardBloc>().add(
                        const ChangeAbcDimension('category'),
                      );
                    }
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ChoiceChip(
                  label: Text(
                    languageCubit.translate('dashboard_abc_by_clients'),
                  ),
                  labelStyle: textStyles.captionSans.copyWith(
                    color: !isCategory ? Colors.white : colors.textPrimary,
                    fontWeight: !isCategory ? FontWeight.w500 : FontWeight.w400,
                  ),
                  checkmarkColor: Colors.white,
                  selected: !isCategory,
                  onSelected: (val) {
                    if (val) {
                      context.read<DashboardBloc>().add(
                        const ChangeAbcDimension('client'),
                      );
                    }
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Text(
            isCategory
                ? languageCubit.translate('dashboard_abc_category_analysis')
                : languageCubit.translate('dashboard_abc_client_analysis'),
            style: textStyles.bodySans.copyWith(fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 8),
          if (report.rows.isEmpty)
            LedgerCard(
              padding: const EdgeInsets.all(16),
              child: Center(
                child: Text(
                  languageCubit.translate('dashboard_no_analysis_data'),
                  style: textStyles.captionSans,
                ),
              ),
            )
          else
            ...report.rows.map((row) {
              Color classColor = colors.accentRed;
              if (row.abcClass == 'A') {
                classColor = colors.accentGreen;
              } else if (row.abcClass == 'B') {
                classColor = colors.accentAmber;
              }

              return Padding(
                padding: const EdgeInsets.only(bottom: 10.0),
                child: LedgerCard(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              languageCubit.translateMessage(row.name),
                              style: textStyles.bodySans.copyWith(
                                fontWeight: FontWeight.w500,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              languageCubit.translate(
                                'dashboard_turnover_share',
                                params: {
                                  'share': formatLocalizedNumber(
                                    context,
                                    row.share,
                                    minimumFractionDigits: 1,
                                    maximumFractionDigits: 1,
                                  ),
                                  'cumulative': formatLocalizedNumber(
                                    context,
                                    row.cumulative,
                                    minimumFractionDigits: 1,
                                    maximumFractionDigits: 1,
                                  ),
                                },
                              ),
                              style: textStyles.captionSans.copyWith(
                                color: colors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Row(
                        children: [
                          Text(
                            '${_formatAmount(context, row.turnover)} $currency',
                            style: textStyles.bodyMono.copyWith(
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Container(
                            decoration: BoxDecoration(
                              color: classColor.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            width: 28,
                            height: 28,
                            alignment: Alignment.center,
                            child: Text(
                              row.abcClass,
                              style: textStyles.bodySans.copyWith(
                                color: classColor,
                                fontWeight: FontWeight.w500,
                              ),
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
