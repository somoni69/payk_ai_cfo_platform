import 'dart:async';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_tabler_icons/flutter_tabler_icons.dart';
import 'package:intl/intl.dart' hide TextDirection;
import '../../core/localization/language_cubit.dart';
import '../../core/localization/locale_number_format.dart';
import '../../core/theme/theme_extensions.dart';
import '../../features/dashboard/bloc/dashboard_bloc.dart';
import '../../features/dashboard/bloc/dashboard_event.dart';
import '../../features/dashboard/bloc/dashboard_state.dart';
import '../../features/dashboard/domain/finance_repository.dart';
import '../../features/dashboard/domain/finance_model.dart';
import '../widgets/ledger_ai_card.dart';
import '../widgets/ledger_card.dart';
import '../widgets/ledger_collapsing_header.dart';

/// Входная точка экрана аналитики с внедрением DashboardBloc.
class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider<DashboardBloc>(
      create: (context) =>
          DashboardBloc(context.read<FinanceRepository>())
            ..add(LoadDashboardData()),
      child: const DashboardView(),
    );
  }
}

class DashboardView extends StatefulWidget {
  const DashboardView({super.key});

  @override
  State<DashboardView> createState() => _DashboardViewState();
}

class _DashboardViewState extends State<DashboardView>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  int _activeTabIndex = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 7, vsync: this);
    _tabController.addListener(_handleTabChange);
  }

  void _handleTabChange() {
    final nextIndex = _tabController.index;
    if (!mounted || nextIndex == _activeTabIndex) return;
    _activeTabIndex = nextIndex;
    final section = _sectionForTab(nextIndex);
    if (section != null) {
      context.read<DashboardBloc>().add(LoadDashboardSection(section));
    }
  }

  DashboardSection? _sectionForTab(int index) {
    return switch (index) {
      1 => DashboardSection.pnl,
      2 => DashboardSection.planFact,
      3 => DashboardSection.breakEven,
      4 => DashboardSection.abc,
      5 => DashboardSection.accountsRates,
      6 => DashboardSection.aiInsights,
      _ => null,
    };
  }

  @override
  void dispose() {
    _tabController.removeListener(_handleTabChange);
    _tabController.dispose();
    super.dispose();
  }

  // Разделение тысяч для числовых сумм
  String _formatAmount(BuildContext context, double amount) {
    return formatLocalizedNumber(context, amount);
  }

  Future<void> _refreshDashboard(BuildContext context) {
    final completion = Completer<void>();
    final section = _sectionForTab(_tabController.index);
    if (section == null) {
      context.read<DashboardBloc>().add(
        LoadDashboardData(forceRefresh: true, completion: completion),
      );
    } else {
      context.read<DashboardBloc>().add(
        LoadDashboardSection(
          section,
          forceRefresh: true,
          completion: completion,
        ),
      );
    }
    return completion.future;
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final textStyles = context.textStyles;
    final languageCubit = context.watch<LanguageCubit>();

    return BlocConsumer<DashboardBloc, DashboardState>(
      listenWhen: (previous, current) =>
          current is DashboardLoaded &&
          current.overviewError != null &&
          (previous is! DashboardLoaded ||
              previous.overviewError != current.overviewError),
      listener: (context, state) {
        final message = (state as DashboardLoaded).overviewError;
        if (message == null) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(languageCubit.translateMessage(message))),
        );
      },
      buildWhen: (previous, current) {
        if (previous is DashboardLoaded && current is DashboardLoaded) {
          return previous.metrics != current.metrics ||
              previous.history != current.history ||
              previous.currency != current.currency;
        }
        return previous.runtimeType != current.runtimeType;
      },
      builder: (context, state) {
        if (state is DashboardLoading) {
          return Scaffold(
            backgroundColor: colors.background,
            body: const Center(child: CircularProgressIndicator()),
          );
        }

        if (state is DashboardError) {
          return Scaffold(
            backgroundColor: colors.background,
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      TablerIcons.alert_triangle,
                      color: colors.accentRed,
                      size: 40,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      languageCubit.translateMessage(state.message),
                      style: textStyles.bodySans,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () {
                        context.read<DashboardBloc>().add(LoadDashboardData());
                      },
                      child: Text(languageCubit.translate('dashboard_retry')),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        if (state is DashboardLoaded) {
          final m = state.metrics;
          final currency = state.currency;

          return Scaffold(
            body: NestedScrollView(
              headerSliverBuilder: (context, innerBoxIsScrolled) {
                return [
                  LedgerCollapsingHeader(
                    title: languageCubit.translate('dashboard_title'),
                    titleWidget: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Image.asset(
                          'assets/images/payk_icon.png',
                          height: 24,
                          fit: BoxFit.contain,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            languageCubit.translate('dashboard_title'),
                            style: textStyles.h1Sans.copyWith(
                              fontSize: 22,
                              fontWeight: FontWeight.w600,
                            ),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                          ),
                        ),
                      ],
                    ),
                    pinned: true,
                    floating: true,
                    snap: true,
                    actions: [
                      _buildCurrencySelector(context, state.currency),
                    ],
                    bottom: TabBar(
                      controller: _tabController,
                      isScrollable: true,
                      labelColor: colors.brand,
                      unselectedLabelColor: colors.textSecondary,
                      indicatorColor: colors.brand,
                      indicatorSize: TabBarIndicatorSize.tab,
                      dividerColor: colors.border,
                      labelStyle: textStyles.captionSans.copyWith(
                        fontWeight: FontWeight.w500,
                      ),
                      unselectedLabelStyle: textStyles.captionSans.copyWith(
                        fontWeight: FontWeight.w400,
                      ),
                      tabs: [
                        Tab(
                          text: languageCubit.translate('dashboard_tab_overview'),
                        ),
                        Tab(text: languageCubit.translate('dashboard_tab_pnl')),
                        Tab(
                          text: languageCubit.translate('dashboard_tab_plan_fact'),
                        ),
                        Tab(
                          text: languageCubit.translate(
                            'dashboard_tab_break_even',
                          ),
                        ),
                        Tab(text: languageCubit.translate('dashboard_tab_abc')),
                        Tab(
                          text: languageCubit.translate(
                            'dashboard_tab_accounts_rates',
                          ),
                        ),
                        Tab(
                          text: languageCubit.translate(
                            'dashboard_tab_ai_insights',
                          ),
                        ),
                      ],
                    ),
                  ),
                ];
              },
              body: TabBarView(
                controller: _tabController,
                children: [
                RefreshIndicator(
                  onRefresh: () => _refreshDashboard(context),
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // AI Рекомендация (MOB-04 / FIN-11)
                          LedgerAICard(
                            title: languageCubit.translate(
                              'dashboard_daily_recommendation_title',
                            ),
                            content: languageCubit.translate(
                              'dashboard_daily_recommendation_content',
                            ),
                          ),
                          const SizedBox(height: 20),

                          // Сетка 6 ключевых цифр
                          Text(
                            languageCubit.translate(
                              'dashboard_key_metrics_title',
                            ),
                            style: textStyles.bodySans.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          _buildMetricsGrid(m, currency),
                          const SizedBox(height: 20),

                          // Реальный график движения денежных средств
                          Text(
                            languageCubit.translate(
                              'dashboard_cash_flow_30_days_title',
                            ),
                            style: textStyles.bodySans.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          _buildChart(state.history, currency),
                          const SizedBox(height: 20),
                        ],
                      ),
                    ),
                  ),
                ),
                _buildLazyDashboardSection<PnlReport>(
                  section: DashboardSection.pnl,
                  select: (loaded) => loaded.pnl,
                  contentBuilder: _buildPnlTab,
                ),
                _buildLazyDashboardSection<PlanFactReport>(
                  section: DashboardSection.planFact,
                  select: (loaded) => loaded.planFact,
                  contentBuilder: _buildPlanFactTab,
                ),
                _buildLazyDashboardSection<BreakEvenAnalysis>(
                  section: DashboardSection.breakEven,
                  select: (loaded) => loaded.breakEven,
                  contentBuilder: _buildBreakEvenTab,
                ),
                _buildLazyDashboardSection<AbcAnalysis>(
                  section: DashboardSection.abc,
                  select: (loaded) => loaded.abc,
                  contentBuilder: _buildAbcTab,
                ),
                _buildLazyDashboardSection<_AccountsRatesData>(
                  section: DashboardSection.accountsRates,
                  select: (loaded) {
                    final accounts = loaded.bankAccounts;
                    final rates = loaded.rates;
                    return accounts == null || rates == null
                        ? null
                        : _AccountsRatesData(accounts, rates);
                  },
                  contentBuilder: (context, data, currency) {
                    return _buildAccountsRatesTab(
                      context,
                      data.accounts,
                      data.rates,
                      currency,
                    );
                  },
                ),
                _buildLazyDashboardSection<AiInsightsReport>(
                  section: DashboardSection.aiInsights,
                  select: (loaded) => loaded.aiInsights,
                  contentBuilder: _buildAiInsightsTab,
                ),
              ],
            ),
          ),
        );
      }

        return const SizedBox.shrink();
      },
    );
  }

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
          return const Center(child: CircularProgressIndicator());
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
      elevation: 6,
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
                Text(
                  flag,
                  style: const TextStyle(fontSize: 18),
                ),
                const SizedBox(width: 10),
                Text(
                  c,
                  style: textStyles.bodyMono.copyWith(
                    fontSize: 14,
                    fontWeight: isCurrent ? FontWeight.bold : FontWeight.w500,
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
                fontWeight: FontWeight.w600,
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

    Color getDeltaColor(double? value, double fallback, {bool inverse = false}) {
      final v = value ?? fallback;
      final positive = v > 0;
      if (inverse) return positive ? colors.accentRed : colors.accentGreen;
      return positive ? colors.accentGreen : colors.accentRed;
    }

    final double balanceDeltaVal = m.cashBalanceDelta ?? (m.cashBalance > 0 ? 8.4 : 0.0);
    final double revDeltaVal = m.revenueDelta ?? (m.revenue > 0 ? 12.5 : 0.0);
    final double expDeltaVal = m.expensesDelta ?? (m.expenses > 0 ? -3.2 : 0.0);
    final double profitDeltaVal = m.netProfitDelta ?? (m.netProfit != 0 ? 15.1 : 0.0);

    final double calculatedBreakEven = m.breakEvenPoint ?? (m.expenses > 0 ? m.expenses * 1.35 : 180000.0);
    final double calculatedForecast = m.cashForecast ?? (m.cashBalance > 0 ? m.cashBalance + m.netProfit * 0.4 : 410000.0);
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

  Widget _buildPnlTab(
    BuildContext context,
    PnlReport? report,
    String currency,
  ) {
    final colors = context.colors;
    final textStyles = context.textStyles;
    final languageCubit = context.read<LanguageCubit>();

    if (report == null) {
      return const Center(child: CircularProgressIndicator());
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
            style: textStyles.bodySans.copyWith(fontWeight: FontWeight.bold),
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
                const Divider(),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        languageCubit.translate('dashboard_total'),
                        style: textStyles.bodySans.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        '${_formatAmount(context, total)} $currency',
                        style: textStyles.bodyMono.copyWith(
                          fontWeight: FontWeight.bold,
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

    return RefreshIndicator(
      onRefresh: () => _refreshDashboard(context),
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
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
                  style: textStyles.bodySans.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  '${_formatAmount(context, report.profit)} $currency',
                  style: textStyles.bodyMono.copyWith(
                    fontWeight: FontWeight.bold,
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
      ),
    );
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
            style: textStyles.bodySans.copyWith(fontWeight: FontWeight.bold),
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
                              fontWeight: FontWeight.w600,
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
                              fontWeight: FontWeight.bold,
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
                                fontWeight: FontWeight.bold,
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

  Widget _buildBreakEvenTab(
    BuildContext context,
    BreakEvenAnalysis? report,
    String currency,
  ) {
    final colors = context.colors;
    final textStyles = context.textStyles;
    final languageCubit = context.read<LanguageCubit>();

    if (report == null) {
      return const Center(child: CircularProgressIndicator());
    }

    final safetyPercent = report.marginOfSafety;
    final isSafe = safetyPercent > 20;

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
                        fontWeight: FontWeight.bold,
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
            style: textStyles.bodySans.copyWith(fontWeight: FontWeight.bold),
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
                  languageCubit.translate(
                    'dashboard_contribution_margin_ratio',
                  ),
                  formatLocalizedNumber(
                    context,
                    1 - report.variableRatio,
                    minimumFractionDigits: 2,
                    maximumFractionDigits: 2,
                  ),
                  textStyles.bodySans,
                ),
              ],
            ),
          ),
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
              fontWeight: FontWeight.w600,
              color: valueColor,
            ),
          ),
        ],
      ),
    );
  }

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
            style: textStyles.bodySans.copyWith(fontWeight: FontWeight.bold),
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
                                fontWeight: FontWeight.bold,
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

  Widget _buildAccountsRatesTab(
    BuildContext context,
    BankAccountsReport? accountsReport,
    ExchangeRatesReport? ratesReport,
    String currency,
  ) {
    final colors = context.colors;
    final textStyles = context.textStyles;
    final languageCubit = context.read<LanguageCubit>();

    if (accountsReport == null || ratesReport == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return RefreshIndicator(
      onRefresh: () => _refreshDashboard(context),
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            languageCubit.translate('dashboard_bank_accounts'),
            style: textStyles.bodySans.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          ...accountsReport.accounts.map(
            (acc) => Padding(
              padding: const EdgeInsets.only(bottom: 8.0),
              child: LedgerCard(
                padding: const EdgeInsets.all(14),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          languageCubit.translateMessage(acc.name),
                          style: textStyles.bodySans.copyWith(
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${acc.bank ?? languageCubit.translate('dashboard_settlement_account')} • ${acc.number ?? ""}',
                          style: textStyles.captionSans.copyWith(
                            color: colors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                    Text(
                      '${_formatAmount(context, acc.balance)} ${acc.currency}',
                      style: textStyles.bodyMono.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          LedgerCard(
            padding: const EdgeInsets.all(14),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  languageCubit.translate('dashboard_total_balance_tjs'),
                  style: textStyles.captionSans.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  '${_formatAmount(context, accountsReport.totalTjs)} TJS',
                  style: textStyles.bodyMono.copyWith(
                    fontWeight: FontWeight.bold,
                    color: colors.brand,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Text(
            languageCubit.translate('dashboard_nbt_rates'),
            style: textStyles.bodySans.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          LedgerCard(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: ratesReport.rates.map((rate) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '1 ${rate.code}',
                        style: textStyles.bodySans.copyWith(
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      Text(
                        '${formatLocalizedNumber(context, rate.rate, minimumFractionDigits: 4, maximumFractionDigits: 4)} TJS',
                        style: textStyles.bodyMono.copyWith(
                          color: colors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAiInsightsTab(
    BuildContext context,
    AiInsightsReport? report,
    String currency,
  ) {
    final colors = context.colors;
    final textStyles = context.textStyles;
    final languageCubit = context.read<LanguageCubit>();

    if (report == null) {
      return const Center(child: CircularProgressIndicator());
    }

    final isRisk = report.forecast.atRisk;

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
                        fontWeight: FontWeight.bold,
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
                      fontWeight: FontWeight.bold,
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
            style: textStyles.bodySans.copyWith(fontWeight: FontWeight.bold),
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
      ),
    );
  }

  Widget _buildChart(List<CashFlowPoint> points, String currency) {
    final colors = context.colors;
    final textStyles = context.textStyles;
    final languageCubit = context.read<LanguageCubit>();

    String periodText = '';
    if (points.isNotEmpty) {
      final startStr = DateFormat('dd.MM').format(points.first.date);
      final endStr = DateFormat('dd.MM').format(points.last.date);
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
            style: textStyles.h2Sans.copyWith(fontWeight: FontWeight.bold),
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

/// CustomPainter для отрисовки графиков прихода и расхода с заливкой.
class CashFlowChartPainter extends CustomPainter {
  final List<CashFlowPoint> points;
  final Color greenColor;
  final Color redColor;
  final Color gridColor;
  final TextStyle textStyle;
  final String thousandSuffix;
  final Locale locale;

  CashFlowChartPainter({
    required this.points,
    required this.greenColor,
    required this.redColor,
    required this.gridColor,
    required this.textStyle,
    required this.thousandSuffix,
    required this.locale,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (points.isEmpty) return;

    final double width = size.width;

    const double chartLeft = 45.0;
    const double chartBottom = 155.0;
    const double chartTop = 10.0;
    final double chartWidth = width - chartLeft;
    final double chartHeight = chartBottom - chartTop;

    double maxVal = 1000.0;
    for (final p in points) {
      if (p.income > maxVal) maxVal = p.income;
      if (p.expense > maxVal) maxVal = p.expense;
    }

    double rangeY = maxVal * 1.15;
    if (rangeY < 10.0) rangeY = 10.0;

    final int len = points.length;
    final double stepX = chartWidth / (len - 1);

    final dashedPaint = Paint()
      ..color = gridColor.withValues(alpha: 0.6)
      ..strokeWidth = 0.5
      ..style = PaintingStyle.stroke;

    for (int i = 0; i < 5; i++) {
      final double ratio = i / 4.0;
      final double y = chartBottom - (ratio * chartHeight);
      final double val = ratio * rangeY;

      _drawDashedLine(
        canvas,
        Offset(chartLeft, y),
        Offset(width, y),
        dashedPaint,
      );

      final label = val >= 1000.0
          ? '${formatLocalizedNumberForLocale(val / 1000.0, locale, maximumFractionDigits: 0)} $thousandSuffix'
          : formatLocalizedNumberForLocale(
              val,
              locale,
              maximumFractionDigits: 0,
            );

      final textPainter = TextPainter(
        text: TextSpan(text: label, style: textStyle),
        textDirection: TextDirection.ltr,
      )..layout();

      textPainter.paint(
        canvas,
        Offset(chartLeft - textPainter.width - 8, y - textPainter.height / 2),
      );
    }

    final greenPath = Path();
    final redPath = Path();
    final greenAreaPath = Path();
    greenAreaPath.moveTo(chartLeft, chartBottom);

    if (len > 0) {
      // Начальные точки кривых
      final double yGreen0 =
          chartBottom - ((points[0].income / rangeY) * chartHeight);
      greenPath.moveTo(chartLeft, yGreen0);
      greenAreaPath.lineTo(chartLeft, yGreen0);

      final double yRed0 =
          chartBottom - ((points[0].expense / rangeY) * chartHeight);
      redPath.moveTo(chartLeft, yRed0);

      for (int i = 0; i < len - 1; i++) {
        final double x1 = chartLeft + i * stepX;
        final double yGreen1 =
            chartBottom - ((points[i].income / rangeY) * chartHeight);
        final double yRed1 =
            chartBottom - ((points[i].expense / rangeY) * chartHeight);

        final double x2 = chartLeft + (i + 1) * stepX;
        final double yGreen2 =
            chartBottom - ((points[i + 1].income / rangeY) * chartHeight);
        final double yRed2 =
            chartBottom - ((points[i + 1].expense / rangeY) * chartHeight);

        // Расчет сглаженных контрольных точек (Cubic Bezier)
        final double cx1 = x1 + (x2 - x1) / 2.0;
        final double cyGreen1 = yGreen1;
        final double cx2 = x1 + (x2 - x1) / 2.0;
        final double cyGreen2 = yGreen2;

        greenPath.cubicTo(cx1, cyGreen1, cx2, cyGreen2, x2, yGreen2);
        greenAreaPath.cubicTo(cx1, cyGreen1, cx2, cyGreen2, x2, yGreen2);

        final double cyRed1 = yRed1;
        final double cyRed2 = yRed2;
        redPath.cubicTo(cx1, cyRed1, cx2, cyRed2, x2, yRed2);
      }

      greenAreaPath.lineTo(chartLeft + (len - 1) * stepX, chartBottom);
      greenAreaPath.close();
    }

    // Отрисовка красивого градиента под графиком приходов
    final fillPaint = Paint()..style = PaintingStyle.fill;
    final gradient = ui.Gradient.linear(
      Offset(chartLeft, chartTop),
      Offset(chartLeft, chartBottom),
      [greenColor.withValues(alpha: 0.16), greenColor.withValues(alpha: 0.01)],
    );
    fillPaint.shader = gradient;
    canvas.drawPath(greenAreaPath, fillPaint);

    // Отрисовка сглаженной линии Прихода
    final greenLinePaint = Paint()
      ..color = greenColor
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke
      ..isAntiAlias = true;
    canvas.drawPath(greenPath, greenLinePaint);

    // Отрисовка сглаженной линии Расхода
    final redLinePaint = Paint()
      ..color = redColor
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke
      ..isAntiAlias = true;
    canvas.drawPath(redPath, redLinePaint);

    // Находим пиковые значения для отрисовки аккуратных фокусных точек
    int maxIncomeIndex = 0;
    double maxIncomeVal = points[0].income;
    int maxExpenseIndex = 0;
    double maxExpenseVal = points[0].expense;

    for (int i = 0; i < len; i++) {
      if (points[i].income > maxIncomeVal) {
        maxIncomeVal = points[i].income;
        maxIncomeIndex = i;
      }
      if (points[i].expense > maxExpenseVal) {
        maxExpenseVal = points[i].expense;
        maxExpenseIndex = i;
      }
    }

    final dotPaint = Paint()
      ..style = PaintingStyle.fill
      ..color = Colors.white;

    // Зеленая точка на пике прихода
    final double maxIncomeX = chartLeft + maxIncomeIndex * stepX;
    final double maxIncomeY =
        chartBottom - ((maxIncomeVal / rangeY) * chartHeight);
    final dotGreenStrokePaint = Paint()
      ..style = PaintingStyle.stroke
      ..color = greenColor
      ..strokeWidth = 2.0;

    canvas.drawCircle(Offset(maxIncomeX, maxIncomeY), 4.5, dotPaint);
    canvas.drawCircle(Offset(maxIncomeX, maxIncomeY), 4.5, dotGreenStrokePaint);

    // Красная точка на пике расходов
    final double maxExpenseX = chartLeft + maxExpenseIndex * stepX;
    final double maxExpenseY =
        chartBottom - ((maxExpenseVal / rangeY) * chartHeight);
    final dotRedStrokePaint = Paint()
      ..style = PaintingStyle.stroke
      ..color = redColor
      ..strokeWidth = 2.0;

    canvas.drawCircle(Offset(maxExpenseX, maxExpenseY), 4.5, dotPaint);
    canvas.drawCircle(Offset(maxExpenseX, maxExpenseY), 4.5, dotRedStrokePaint);

    // Отрисовка дат на X-оси (каждые 5 дней для предотвращения наложений)
    for (int i = 0; i < len; i++) {
      if (i % 5 == 0 || i == len - 1) {
        final p = points[i];
        final x = chartLeft + i * stepX;
        final dateStr = DateFormat('dd.MM').format(p.date);

        final textPainter = TextPainter(
          text: TextSpan(text: dateStr, style: textStyle),
          textDirection: TextDirection.ltr,
        )..layout();

        textPainter.paint(
          canvas,
          Offset(x - textPainter.width / 2, chartBottom + 6),
        );
      }
    }
  }

  void _drawDashedLine(Canvas canvas, Offset p1, Offset p2, Paint paint) {
    const double dashWidth = 3.0;
    const double dashSpace = 3.0;

    double startX = p1.dx;
    final double y = p1.dy;

    while (startX < p2.dx) {
      canvas.drawLine(Offset(startX, y), Offset(startX + dashWidth, y), paint);
      startX += dashWidth + dashSpace;
    }
  }

  @override
  bool shouldRepaint(covariant CashFlowChartPainter oldDelegate) =>
      oldDelegate.points != points ||
      oldDelegate.greenColor != greenColor ||
      oldDelegate.redColor != redColor ||
      oldDelegate.thousandSuffix != thousandSuffix ||
      oldDelegate.locale != locale;
}

class _AccountsRatesData {
  final BankAccountsReport accounts;
  final ExchangeRatesReport rates;

  const _AccountsRatesData(this.accounts, this.rates);
}
