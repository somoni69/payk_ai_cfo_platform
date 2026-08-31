part of 'dashboard_screen.dart';

Widget _buildLazyDashboardSection<T>({
  required DashboardSection section,
  required T? Function(DashboardLoaded state) select,
  required Widget Function(BuildContext context, T data, String currency)
  contentBuilder,
}) {
  (T?, String, bool, String?) slice(DashboardState state) {
    if (state is! DashboardLoaded) return (null, 'TJS', false, null);
    return (
      select(state),
      state.currency,
      state.loadingSections.contains(section),
      state.sectionErrors[section],
    );
  }

  return BlocBuilder<DashboardBloc, DashboardState>(
    buildWhen: (previous, current) => slice(previous) != slice(current),
    builder: (context, state) {
      if (state is! DashboardLoaded) return const SizedBox.shrink();
      final data = select(state);
      if (data != null) {
        return contentBuilder(context, data, state.currency);
      }

      final error = state.sectionErrors[section];
      if (error == null) {
        return const DashboardSectionShimmer();
      }

      final language = context.read<LanguageCubit>();
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                language.translateMessage(error),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: () {
                  context.read<DashboardBloc>().add(
                    LoadDashboardSection(section, forceRefresh: true),
                  );
                },
                child: Text(language.translate('dashboard_retry')),
              ),
            ],
          ),
        ),
      );
    },
  );
}

Widget _buildCurrencySelector(BuildContext context, String currentCurrency) {
  final colors = context.colors;
  final textStyles = context.textStyles;
  final currencies = ['TJS', 'USD', 'RUB', 'EUR'];

  return PopupMenuButton<String>(
    onSelected: (String c) {
      context.read<DashboardBloc>().add(ChangeCurrency(c));
    },
    offset: const Offset(0, 44),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(16),
      side: BorderSide(color: colors.border, width: 1),
    ),
    color: colors.surface,
    surfaceTintColor: colors.surface,
    elevation: 0,
    itemBuilder: (BuildContext context) {
      return currencies.map((String c) {
        final isCurrent = c == currentCurrency;

        return PopupMenuItem<String>(
          value: c,
          height: 40,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                c,
                style: textStyles.bodySans.copyWith(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: isCurrent ? colors.brand : colors.textPrimary,
                ),
              ),
              if (isCurrent) ...[
                const SizedBox(width: 12),
                Icon(Icons.check, size: 16, color: colors.brand),
              ],
            ],
          ),
        );
      }).toList();
    },
    child: LedgerCard(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            currentCurrency,
            style: textStyles.bodyMono.copyWith(
              fontWeight: FontWeight.w500,
              fontSize: 13,
              color: colors.brand,
            ),
          ),
          const SizedBox(width: 4),
          Icon(Icons.keyboard_arrow_down, size: 18, color: colors.brand),
        ],
      ),
    ),
  );
}

Widget _buildOverviewHome(
  BuildContext context,
  DashboardLoaded loaded,
  String currency,
) {
  final colors = context.colors;
  final textStyles = context.textStyles;
  final language = context.read<LanguageCubit>();
  final m = loaded.metrics;

  String money(double value) => '${_formatAmount(context, value)} $currency';

  String deltaLabel(double? value) {
    final v = value ?? 0;
    final sign = v > 0 ? '+' : '';
    return '$sign${formatLocalizedNumber(context, v)}%';
  }

  Color deltaColor(double? value, {bool inverse = false}) {
    final v = value ?? 0;
    final up = v >= 0;
    if (inverse) return up ? colors.accentRed : colors.accentGreen;
    return up ? colors.accentGreen : colors.accentRed;
  }

  final profitOk = m.netProfit >= 0;
  final caption = profitOk
      ? language.translate(
          'dashboard_hero_profit_ok',
          params: {'amount': money(m.netProfit)},
        )
      : language.translate(
          'dashboard_hero_profit_loss',
          params: {'amount': money(m.netProfit.abs())},
        );

  final reports = <(DashboardSection, IconData, String)>[
    (
      DashboardSection.pnl,
      TablerIcons.report_money,
      language.translate('dashboard_tab_pnl'),
    ),
    (
      DashboardSection.planFact,
      TablerIcons.chart_bar,
      language.translate('dashboard_tab_plan_fact'),
    ),
    (
      DashboardSection.breakEven,
      TablerIcons.target,
      language.translate('dashboard_tab_break_even'),
    ),
    (
      DashboardSection.abc,
      TablerIcons.chart_dots,
      language.translate('dashboard_tab_abc'),
    ),
    (
      DashboardSection.accountsRates,
      TablerIcons.building_bank,
      language.translate('dashboard_tab_accounts_rates'),
    ),
    (
      DashboardSection.clients,
      TablerIcons.users,
      language.translate('dashboard_tab_clients'),
    ),
    (
      DashboardSection.aiInsights,
      TablerIcons.bulb,
      language.translate('dashboard_tab_ai_insights'),
    ),
    (
      DashboardSection.onec,
      TablerIcons.arrows_exchange,
      language.translate('dashboard_tab_onec'),
    ),
  ];

  return RefreshIndicator(
    onRefresh: () => _refreshDashboard(context),
    child: SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16 + kLiquidNavClearance),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const LedgerAdvicePanel(module: 'finance'),
          const SizedBox(height: 16),
          GestureDetector(
            onTap: () => _showMetricBreakdown(context, 'balance'),
            child: LedgerHero(
              label: language.translate('dashboard_metric_cash_balance'),
              value: money(m.cashBalance),
              caption: caption,
              captionColor: profitOk ? colors.accentGreen : colors.accentRed,
              trailing: LedgerIconBadge(
                icon: TablerIcons.wallet,
                color: colors.brand,
                size: 48,
                iconSize: 24,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: LedgerMetricTile(
                  icon: TablerIcons.trending_up,
                  iconColor: colors.accentGreen,
                  label: language.translate('dashboard_metric_net_profit'),
                  value: money(m.netProfit),
                  delta: deltaLabel(m.netProfitDelta),
                  deltaColor: deltaColor(m.netProfitDelta),
                  onTap: () => _showMetricBreakdown(context, 'profit'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: LedgerMetricTile(
                  icon: TablerIcons.trending_down,
                  iconColor: colors.accentRed,
                  label: language.translate('dashboard_metric_expenses_june'),
                  value: money(m.expenses),
                  delta: deltaLabel(m.expensesDelta),
                  deltaColor: deltaColor(m.expensesDelta, inverse: true),
                  onTap: () => _showMetricBreakdown(context, 'expenses'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          LedgerMetricTile(
            icon: TablerIcons.cash,
            iconColor: colors.brand,
            label: language.translate('dashboard_metric_revenue_june'),
            value: money(m.revenue),
            delta: deltaLabel(m.revenueDelta),
            deltaColor: deltaColor(m.revenueDelta),
            onTap: () => _showMetricBreakdown(context, 'revenue'),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: LedgerMetricTile(
                  icon: TablerIcons.receipt,
                  iconColor: colors.brand,
                  label: language.translate('dashboard_metric_operations'),
                  value: '${m.operationsCount}',
                  onTap: () => _showMetricBreakdown(context, 'operations'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: LedgerMetricTile(
                  icon: TablerIcons.receipt_2,
                  iconColor: colors.accentGreen,
                  label: language.translate('dashboard_metric_avg_check'),
                  value: money(m.avgCheck),
                  onTap: () => _showMetricBreakdown(context, 'avg_check'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          const SalesProfitCard(hideOnError: true, wrapCard: false),
          const SizedBox(height: 24),
          const CurrencyBoardCard(),
          const SizedBox(height: 24),
          _buildChart(context, loaded.history, currency),
          const SizedBox(height: 24),
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
                  TablerIcons.file_analytics,
                  size: 18,
                  color: colors.brand,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      language.translate('dashboard_reports_title'),
                      style: textStyles.h2Sans.copyWith(
                        fontSize: context.fontSize(16),
                      ),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      language.translate('dashboard_reports_subtitle'),
                      style: textStyles.captionSans.copyWith(
                        color: colors.textSecondary,
                        fontSize: context.fontSize(11),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          for (var i = 0; i < reports.length; i += 2)
            Padding(
              padding: EdgeInsets.only(bottom: i + 2 < reports.length ? 8 : 0),
              child: IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      child: LedgerReportTile(
                        icon: reports[i].$2,
                        title: reports[i].$3,
                        onTap: () =>
                            _openDashboardReport(context, reports[i].$1),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: i + 1 < reports.length
                          ? LedgerReportTile(
                              icon: reports[i + 1].$2,
                              title: reports[i + 1].$3,
                              onTap: () => _openDashboardReport(
                                context,
                                reports[i + 1].$1,
                              ),
                            )
                          : const SizedBox.shrink(),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    ),
  );
}

void _showMetricBreakdown(BuildContext context, String metric) {
  final language = context.read<LanguageCubit>();
  final colors = context.colors;
  final textStyles = context.textStyles;
  final repo = context.read<FinanceRepository>();
  final currency = context.read<DashboardBloc>().state is DashboardLoaded
      ? (context.read<DashboardBloc>().state as DashboardLoaded).currency
      : 'TJS';

  LedgerBottomSheet.show(
    context: context,
    title: language.translate('dashboard_breakdown_title'),
    builder: (ctx, setSheetState) {
      return FutureBuilder<MetricBreakdown>(
        future: repo.getBreakdown(metric),
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
            );
          }
          if (snapshot.hasError || snapshot.data == null) {
            return Text(
              language.translate('dashboard_load_error'),
              style: textStyles.bodySans.copyWith(color: colors.accentRed),
            );
          }
          final data = snapshot.data!;
          if (data.rows.isEmpty) {
            return Text(
              language.translate('dashboard_breakdown_empty'),
              style: textStyles.captionSans.copyWith(
                color: colors.textSecondary,
              ),
            );
          }
          return Column(
            children: [
              for (final row in data.rows)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          language.translateMessage(row.label),
                          style: textStyles.bodySans,
                        ),
                      ),
                      Text(
                        '${_formatAmount(context, row.value)} $currency',
                        style: textStyles.bodyMono.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          );
        },
      );
    },
  );
}

Widget _buildFinancePeriodStrip(BuildContext context) {
  final language = context.read<LanguageCubit>();
  final loaded = context.read<DashboardBloc>().state;
  DateTime? from;
  DateTime? to;
  if (loaded is DashboardLoaded) {
    from = loaded.reportDateFrom;
    to = loaded.reportDateTo;
  }
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final monthStart = DateTime(now.year, now.month, 1);
  final yearStart = DateTime(now.year, 1, 1);

  String keyOf(DateTime? a, DateTime? b) {
    if (a == null && b == null) return 'all';
    if (a == today && b == today) return 'today';
    if (a == monthStart && b == today) return 'month';
    if (a == yearStart && b == today) return 'year';
    return 'custom';
  }

  final current = keyOf(from, to);
  final items = [
    ('month', language.translate('network_period_month'), monthStart, today),
    ('today', language.translate('network_period_today'), today, today),
    ('year', language.translate('dashboard_period_year'), yearStart, today),
    ('all', language.translate('network_period_all'), null, null),
  ];

  return LedgerSegmentedControl<String>(
    height: 36,
    selectedValue: current == 'custom' ? 'month' : current,
    onValueChanged: (key) {
      final item = items.firstWhere((e) => e.$1 == key);
      context.read<DashboardBloc>().add(
        SetFinanceReportPeriod(dateFrom: item.$3, dateTo: item.$4),
      );
    },
    segments: [
      for (final item in items)
        LedgerSegmentItem(value: item.$1, label: item.$2),
    ],
  );
}

Widget _buildPlanMonthStrip(BuildContext context, String currentPeriod) {
  final now = DateTime.now();
  final months = List.generate(6, (i) {
    final d = DateTime(now.year, now.month - i, 1);
    return '${d.year}-${d.month.toString().padLeft(2, '0')}';
  }).reversed.toList();
  final selected = months.contains(currentPeriod)
      ? currentPeriod
      : months.last;
  return SingleChildScrollView(
    scrollDirection: Axis.horizontal,
    child: Row(
      children: [
        for (final month in months) ...[
          ChoiceChip(
            label: Text(month),
            selected: selected == month,
            onSelected: (_) {
              context.read<DashboardBloc>().add(SetPlanFactPeriod(month));
            },
          ),
          const SizedBox(width: 8),
        ],
      ],
    ),
  );
}

Widget _buildReportRow(
  String label,
  String value,
  TextStyle textStyle, {
  Color? valueColor,
}) {
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 8.0),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: textStyle),
        Text(
          value,
          style: textStyle.copyWith(
            fontWeight: FontWeight.w500,
            color: valueColor,
          ),
        ),
      ],
    ),
  );
}

Widget _buildChart(
  BuildContext context,
  List<CashFlowPoint> points,
  String currency,
) {
  final colors = context.colors;
  final textStyles = context.textStyles;
  final languageCubit = context.read<LanguageCubit>();

  String periodText = '';
  if (points.isNotEmpty) {
    final startStr = formatLocalizedDateTime(
      context,
      points.first.date,
      style: LocalizedDateTimeStyle.date,
    );
    final endStr = formatLocalizedDateTime(
      context,
      points.last.date,
      style: LocalizedDateTimeStyle.date,
    );
    periodText = '$startStr — $endStr';
  }

  var peakIncome = 0.0;
  var peakExpense = 0.0;
  for (final point in points) {
    if (point.income > peakIncome) peakIncome = point.income;
    if (point.expense > peakExpense) peakExpense = point.expense;
  }
  final chartSemanticsLabel =
      '${languageCubit.translate('dashboard_income')}: '
      '${formatLocalizedNumber(context, peakIncome)} $currency; '
      '${languageCubit.translate('dashboard_expense')}: '
      '${formatLocalizedNumber(context, peakExpense)} $currency';

  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
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
              TablerIcons.chart_area_line,
              size: 18,
              color: colors.brand,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  languageCubit.translate('dashboard_cash_flow'),
                  style: textStyles.h2Sans.copyWith(
                    fontSize: context.fontSize(16),
                  ),
                ),
                if (periodText.isNotEmpty) ...[
                  const SizedBox(height: 1),
                  Text(
                    languageCubit.translate(
                      'dashboard_cash_flow_subtitle',
                      params: {'period': periodText, 'currency': currency},
                    ),
                    style: textStyles.captionSans.copyWith(
                      color: colors.textSecondary,
                      fontSize: context.fontSize(11),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
      const SizedBox(height: 12),
      LedgerCard(
        padding: const EdgeInsets.fromLTRB(12, 16, 12, 12),
        child: Column(
          children: [
            SizedBox(
              height: 180,
              child: Semantics(
                image: true,
                label: chartSemanticsLabel,
                child: CustomPaint(
                  size: Size.infinite,
                  painter: CashFlowChartPainter(
                    points: points,
                    greenColor: colors.accentGreen,
                    redColor: colors.accentRed,
                    gridColor: colors.border,
                    surfaceColor: colors.surface,
                    textStyle: textStyles.smallMono.copyWith(
                      color: colors.textTooltip,
                      fontSize: 10,
                    ),
                    thousandSuffix: languageCubit.translate(
                      'dashboard_thousands_short',
                    ),
                    locale: Localizations.localeOf(context),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: colors.accentGreen,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  languageCubit.translate('dashboard_income'),
                  style: textStyles.captionSans,
                ),
                const SizedBox(width: 20),
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: colors.accentRed,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  languageCubit.translate('dashboard_expense'),
                  style: textStyles.captionSans,
                ),
              ],
            ),
          ],
        ),
      ),
    ],
  );
}
