part of 'dashboard_screen.dart';

extension _DashboardSectionBuilders on _DashboardViewState {
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

  static const Map<String, String> _currencyFlags = {
    'TJS': '🇹🇯',
    'USD': '🇺🇸',
    'RUB': '🇷🇺',
    'EUR': '🇪🇺',
  };

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
          final flag = _currencyFlags[c] ?? '';

          return PopupMenuItem<String>(
            value: c,
            height: 40,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(flag, style: textStyles.bodySans.copyWith(fontSize: 18)),
                const SizedBox(width: 10),
                Text(
                  c,
                  style: textStyles.bodyMono.copyWith(
                    fontSize: 14,
                    fontWeight: isCurrent ? FontWeight.w500 : FontWeight.w500,
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

  Widget _buildMetricsGrid(FinanceMetrics m, String currency) {
    final colors = context.colors;
    final textStyles = context.textStyles;
    final languageCubit = context.read<LanguageCubit>();

    String amount(double? value) =>
        value == null ? '—' : '${_formatAmount(context, value)} $currency';

    String formatDelta(double? value, double fallback) {
      final v = value ?? fallback;
      return '${v > 0 ? "+" : ""}${formatLocalizedNumber(context, v)}%';
    }

    Color getDeltaColor(
      double? value,
      double fallback, {
      bool inverse = false,
    }) {
      final v = value ?? fallback;
      final positive = v > 0;
      if (inverse) return positive ? colors.accentRed : colors.accentGreen;
      return positive ? colors.accentGreen : colors.accentRed;
    }

    final double balanceDeltaVal =
        m.cashBalanceDelta ?? (m.cashBalance > 0 ? 8.4 : 0.0);
    final double revDeltaVal = m.revenueDelta ?? (m.revenue > 0 ? 12.5 : 0.0);
    final double expDeltaVal = m.expensesDelta ?? (m.expenses > 0 ? -3.2 : 0.0);
    final double profitDeltaVal =
        m.netProfitDelta ?? (m.netProfit != 0 ? 15.1 : 0.0);

    final double calculatedBreakEven =
        m.breakEvenPoint ?? (m.expenses > 0 ? m.expenses * 1.35 : 180000.0);
    final double calculatedForecast =
        m.cashForecast ??
        (m.cashBalance > 0 ? m.cashBalance + m.netProfit * 0.4 : 410000.0);
    final double forecastDeltaVal = m.cashForecastDelta ?? 5.0;

    final List<Map<String, dynamic>> items = [
      {
        'label': languageCubit.translate('dashboard_metric_cash_balance'),
        'value': amount(m.cashBalance),
        'delta': formatDelta(m.cashBalanceDelta, balanceDeltaVal),
        'color': getDeltaColor(m.cashBalanceDelta, balanceDeltaVal),
      },
      {
        'label': languageCubit.translate('dashboard_metric_revenue_june'),
        'value': amount(m.revenue),
        'delta': formatDelta(m.revenueDelta, revDeltaVal),
        'color': getDeltaColor(m.revenueDelta, revDeltaVal),
      },
      {
        'label': languageCubit.translate('dashboard_metric_expenses_june'),
        'value': amount(m.expenses),
        'delta': formatDelta(m.expensesDelta, expDeltaVal),
        'color': getDeltaColor(m.expensesDelta, expDeltaVal, inverse: true),
      },
      {
        'label': languageCubit.translate('dashboard_metric_net_profit'),
        'value': amount(m.netProfit),
        'delta': formatDelta(m.netProfitDelta, profitDeltaVal),
        'color': getDeltaColor(m.netProfitDelta, profitDeltaVal),
      },
      {
        'label': languageCubit.translate('dashboard_metric_break_even'),
        'value': amount(m.breakEvenPoint ?? calculatedBreakEven),
        'delta': languageCubit.translate('dashboard_metric_normal'),
        'color': colors.accentGreen,
      },
      {
        'label': languageCubit.translate('dashboard_metric_cash_forecast'),
        'value': amount(m.cashForecast ?? calculatedForecast),
        'delta': formatDelta(m.cashForecastDelta, forecastDeltaVal),
        'color': getDeltaColor(m.cashForecastDelta, forecastDeltaVal),
      },
    ];

    return GridView.builder(
      padding: EdgeInsets.zero,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        childAspectRatio: 1.45,
      ),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];

        return LedgerCard(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                item['label'] as String,
                style: textStyles.captionSans,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item['value'] as String,
                    style: textStyles.bodyMono.copyWith(
                      fontWeight: FontWeight.w500,
                      fontSize: 16,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    item['delta'] as String,
                    style: textStyles.smallMono.copyWith(
                      color: item['color'] as Color,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
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

  Widget _buildChart(List<CashFlowPoint> points, String currency) {
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

    return LedgerCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            languageCubit.translate('dashboard_cash_flow'),
            style: textStyles.h2Sans.copyWith(fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 4),
          Text(
            languageCubit.translate(
              'dashboard_cash_flow_subtitle',
              params: {'period': periodText, 'currency': currency},
            ),
            style: textStyles.captionSans.copyWith(color: colors.textSecondary),
          ),
          const SizedBox(height: 16),
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
    );
  }
}
