part of 'dashboard_screen.dart';

Widget _buildAbcTab(
  BuildContext context,
  AbcAnalysis? report,
  String currency,
) {
  final colors = context.colors;
  final textStyles = context.textStyles;
  final languageCubit = context.read<LanguageCubit>();

  if (report == null) {
    return const DashboardSectionShimmer(kind: DashboardShimmerKind.abc);
  }

  final loaded = context.watch<DashboardBloc>().state;
  final isLoading =
      loaded is DashboardLoaded &&
      loaded.loadingSections.contains(DashboardSection.abc);
  final error = loaded is DashboardLoaded
      ? loaded.sectionErrors[DashboardSection.abc]
      : null;
  final isCategory = AbcDimensions.isCategory(report.dimension);

  return ListView(
    padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
    children: [
      _buildFinancePeriodStrip(context),
      const SizedBox(height: 12),
      LedgerSegmentedControl<String>(
        height: 36,
        selectedValue: isCategory
            ? AbcDimensions.category
            : AbcDimensions.counterparty,
        onValueChanged: (value) {
          context.read<DashboardBloc>().add(ChangeAbcDimension(value));
        },
        segments: [
          LedgerSegmentItem(
            value: AbcDimensions.category,
            label: languageCubit.translate('dashboard_abc_by_categories'),
          ),
          LedgerSegmentItem(
            value: AbcDimensions.counterparty,
            label: languageCubit.translate('dashboard_abc_by_clients'),
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
      if (isLoading)
        const LedgerShimmer(
          child: Column(
            children: [
              Padding(
                padding: EdgeInsets.only(bottom: 10),
                child: LedgerCard(
                  padding: EdgeInsets.all(12),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            ShimmerBox(width: 140, height: 14, borderRadius: 4),
                            SizedBox(height: 4),
                            ShimmerBox(width: 180, height: 11, borderRadius: 4),
                          ],
                        ),
                      ),
                      SizedBox(width: 8),
                      ShimmerBox(width: 72, height: 14, borderRadius: 4),
                      SizedBox(width: 12),
                      ShimmerBox(width: 28, height: 28, borderRadius: 4),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: EdgeInsets.only(bottom: 10),
                child: LedgerCard(
                  padding: EdgeInsets.all(12),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            ShimmerBox(width: 120, height: 14, borderRadius: 4),
                            SizedBox(height: 4),
                            ShimmerBox(width: 160, height: 11, borderRadius: 4),
                          ],
                        ),
                      ),
                      SizedBox(width: 8),
                      ShimmerBox(width: 72, height: 14, borderRadius: 4),
                      SizedBox(width: 12),
                      ShimmerBox(width: 28, height: 28, borderRadius: 4),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: EdgeInsets.only(bottom: 10),
                child: LedgerCard(
                  padding: EdgeInsets.all(12),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            ShimmerBox(width: 100, height: 14, borderRadius: 4),
                            SizedBox(height: 4),
                            ShimmerBox(width: 150, height: 11, borderRadius: 4),
                          ],
                        ),
                      ),
                      SizedBox(width: 8),
                      ShimmerBox(width: 72, height: 14, borderRadius: 4),
                      SizedBox(width: 12),
                      ShimmerBox(width: 28, height: 28, borderRadius: 4),
                    ],
                  ),
                ),
              ),
            ],
          ),
        )
      else if (error != null)
        Text(
          languageCubit.translateMessage(error),
          style: textStyles.captionSans.copyWith(color: colors.accentRed),
        )
      else if (report.rows.isEmpty)
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
  );
}
