import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_tabler_icons/flutter_tabler_icons.dart';
import '../../core/theme/theme_extensions.dart';
import '../../features/dashboard/bloc/dashboard_bloc.dart';
import '../../features/dashboard/bloc/dashboard_event.dart';
import '../../features/dashboard/bloc/dashboard_state.dart';
import '../../features/dashboard/domain/finance_repository.dart';
import '../../features/dashboard/domain/finance_model.dart';
import '../widgets/ledger_ai_card.dart';
import '../widgets/ledger_card.dart';

/// Входная точка экрана аналитики с внедрением DashboardBloc.
class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider<DashboardBloc>(
      create: (context) => DashboardBloc(context.read<FinanceRepository>())..add(LoadDashboardData()),
      child: const DashboardView(),
    );
  }
}

class DashboardView extends StatefulWidget {
  const DashboardView({super.key});

  @override
  State<DashboardView> createState() => _DashboardViewState();
}

class _DashboardViewState extends State<DashboardView> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 7, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // Разделение тысяч для числовых сумм
  String _formatAmount(double amount) {
    final int val = amount.round();
    final RegExp reg = RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))');
    return val.toString().replaceAllMapped(reg, (Match match) => '${match[1]} ');
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final textStyles = context.textStyles;

    return BlocBuilder<DashboardBloc, DashboardState>(
      builder: (context, state) {
        if (state is DashboardLoading) {
          return Scaffold(
            backgroundColor: colors.background,
            body: const Center(
              child: CircularProgressIndicator(),
            ),
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
                    Icon(TablerIcons.alert_triangle, color: colors.accentRed, size: 40),
                    const SizedBox(height: 12),
                    Text(state.message, style: textStyles.bodySans, textAlign: TextAlign.center),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () {
                        context.read<DashboardBloc>().add(LoadDashboardData());
                      },
                      child: const Text('Повторить попытку'),
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
            appBar: AppBar(
              backgroundColor: colors.surface,
              scrolledUnderElevation: 0,
              title: Text('Финансовая панель', style: textStyles.h1Sans),
              actions: [
                _buildCurrencySelector(context, state.currency),
                const SizedBox(width: 16),
              ],
              bottom: TabBar(
                controller: _tabController,
                isScrollable: true,
                labelColor: colors.brand,
                unselectedLabelColor: colors.textSecondary,
                indicatorColor: colors.brand,
                indicatorSize: TabBarIndicatorSize.tab,
                dividerColor: colors.border,
                labelStyle: textStyles.captionSans.copyWith(fontWeight: FontWeight.w500),
                unselectedLabelStyle: textStyles.captionSans.copyWith(fontWeight: FontWeight.w400),
                tabs: const [
                  Tab(text: 'Обзор'),
                  Tab(text: 'P&L Отчет'),
                  Tab(text: 'План-Факт'),
                  Tab(text: 'Безубыточность'),
                  Tab(text: 'ABC Анализ'),
                  Tab(text: 'Счета и Валюты'),
                  Tab(text: 'ИИ Инсайты'),
                ],
              ),
            ),
            body: TabBarView(
              controller: _tabController,
              children: [
                RefreshIndicator(
                  onRefresh: () async {
                    context.read<DashboardBloc>().add(LoadDashboardData());
                  },
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // AI Рекомендация (MOB-04 / FIN-11)
                          const LedgerAICard(
                            title: 'Рекомендация дня',
                            content: 'Свободный остаток вырос на 8% за неделю. Рекомендуется перевести 15 000 TJS на накопительный счет, чтобы снизить инфляционные риски.',
                          ),
                          const SizedBox(height: 20),

                          // Сетка 6 ключевых цифр
                          Text('ГЛАВНЫЕ ПОКАЗАТЕЛИ', style: textStyles.smallSans),
                          const SizedBox(height: 8),
                          _buildMetricsGrid(m, currency),
                          const SizedBox(height: 20),

                          // Реальный график движения денежных средств
                          Text('ДВИЖЕНИЕ ДЕНЕГ ЗА 30 ДНЕЙ', style: textStyles.smallSans),
                          const SizedBox(height: 8),
                          _buildChart(state.history, currency),
                          const SizedBox(height: 20),
                        ],
                      ),
                    ),
                  ),
                ),
                _buildPnlTab(context, state.pnl, currency),
                _buildPlanFactTab(context, state.planFact, currency),
                _buildBreakEvenTab(context, state.breakEven, currency),
                _buildAbcTab(context, state.abc, currency),
                _buildAccountsRatesTab(context, state.bankAccounts, state.rates, currency),
                _buildAiInsightsTab(context, state.aiInsights, currency),
              ],
            ),
          );
        }

        return const SizedBox.shrink();
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
      offset: const Offset(0, 48),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      color: colors.surface,
      surfaceTintColor: colors.surface,
      elevation: 4,
      itemBuilder: (BuildContext context) {
        return currencies.map((String c) {
          final isCurrent = c == currentCurrency;
          return PopupMenuItem<String>(
            value: c,
            child: Text(
              c,
              style: textStyles.bodyMono.copyWith(
                fontSize: 12,
                fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                color: isCurrent ? colors.brand : colors.textPrimary,
              ),
            ),
          );
        }).toList();
      },
      child: LedgerCard(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
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
            const SizedBox(width: 8),
            Icon(
              Icons.keyboard_arrow_down,
              size: 18,
              color: colors.brand,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricsGrid(FinanceMetrics m, String currency) {
    final colors = context.colors;
    final textStyles = context.textStyles;

    final List<Map<String, dynamic>> items = [
      {
        'label': 'Остаток в кассах',
        'value': _formatAmount(m.cashBalance),
        'delta': '${m.cashBalanceDelta > 0 ? "+" : ""}${m.cashBalanceDelta}%',
        'color': m.cashBalanceDelta > 0 ? colors.accentGreen : colors.accentRed,
      },
      {
        'label': 'Выручка (июнь)',
        'value': _formatAmount(m.revenue),
        'delta': '${m.revenueDelta > 0 ? "+" : ""}${m.revenueDelta}%',
        'color': m.revenueDelta > 0 ? colors.accentGreen : colors.accentRed,
      },
      {
        'label': 'Расходы (июнь)',
        'value': _formatAmount(m.expenses),
        'delta': '${m.expensesDelta > 0 ? "+" : ""}${m.expensesDelta}%',
        'color': m.expensesDelta > 0 ? colors.accentRed : colors.accentGreen, // Расходы вверх - это плохо
      },
      {
        'label': 'Чистая прибыль',
        'value': _formatAmount(m.netProfit),
        'delta': '${m.netProfitDelta > 0 ? "+" : ""}${m.netProfitDelta}%',
        'color': m.netProfitDelta > 0 ? colors.accentGreen : colors.accentRed,
      },
      {
        'label': 'Точка безубыт.',
        'value': _formatAmount(m.breakEvenPoint),
        'delta': 'норма',
        'color': colors.textSecondary,
      },
      {
        'label': 'Прогноз кассы',
        'value': _formatAmount(m.cashForecast),
        'delta': '${m.cashForecastDelta > 0 ? "+" : ""}${m.cashForecastDelta}%',
        'color': m.cashForecastDelta > 0 ? colors.accentGreen : colors.accentRed,
      },
    ];

    return GridView.builder(
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
                    '${item['value']} $currency',
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
                      fontSize: 10,
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

  Widget _buildPnlTab(BuildContext context, PnlReport? report, String currency) {
    final colors = context.colors;
    final textStyles = context.textStyles;

    if (report == null) {
      return const Center(child: CircularProgressIndicator());
    }

    Widget buildPnlList(String title, List<PnlRow> rows, double total, Color totalColor) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: textStyles.bodySans.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          LedgerCard(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            child: Column(
              children: [
                ...rows.map((row) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(row.category, style: textStyles.bodySans),
                          ),
                          Row(
                            children: [
                              Text(
                                '${_formatAmount(row.amount)} $currency',
                                style: textStyles.bodyMono.copyWith(fontWeight: FontWeight.w500),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                width: 50,
                                alignment: Alignment.centerRight,
                                child: Text(
                                  '${row.share.toStringAsFixed(1)}%',
                                  style: textStyles.smallMono.copyWith(color: colors.textSecondary),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    )),
                const Divider(),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Итого', style: textStyles.bodySans.copyWith(fontWeight: FontWeight.bold)),
                      Text(
                        '${_formatAmount(total)} $currency',
                        style: textStyles.bodyMono.copyWith(fontWeight: FontWeight.bold, color: totalColor),
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
      onRefresh: () async {
        context.read<DashboardBloc>().add(LoadDashboardData());
      },
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          buildPnlList('ДОХОДЫ ПО КАТЕГОРИЯМ', report.income, report.totalIncome, colors.accentGreen),
          const SizedBox(height: 24),
          buildPnlList('РАСХОДЫ ПО КАТЕГОРИЯМ', report.expense, report.totalExpense, colors.accentRed),
          const SizedBox(height: 24),
          LedgerCard(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('ЧИСТАЯ ПРИБЫЛЬ', style: textStyles.bodySans.copyWith(fontWeight: FontWeight.bold)),
                Text(
                  '${_formatAmount(report.profit)} $currency',
                  style: textStyles.bodyMono.copyWith(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                    color: report.profit >= 0 ? colors.accentGreen : colors.accentRed,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlanFactTab(BuildContext context, PlanFactReport? report, String currency) {
    final colors = context.colors;
    final textStyles = context.textStyles;

    if (report == null) {
      return const Center(child: CircularProgressIndicator());
    }

    final overallCompletion = report.totalPlanned > 0 ? (report.totalFact / report.totalPlanned) * 100 : 0.0;

    return RefreshIndicator(
      onRefresh: () async {
        context.read<DashboardBloc>().add(LoadDashboardData());
      },
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          LedgerCard(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'ОБЩЕЕ ВЫПОЛНЕНИЕ БЮДЖЕТА',
                  style: textStyles.captionSans.copyWith(color: colors.textSecondary),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '${overallCompletion.toStringAsFixed(1)}%',
                      style: textStyles.h1Sans.copyWith(
                        color: colors.brand,
                        fontSize: 32,
                      ),
                    ),
                    Text(
                      '${_formatAmount(report.totalFact)} / ${_formatAmount(report.totalPlanned)} $currency',
                      style: textStyles.bodyMono.copyWith(color: colors.textSecondary),
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
          Text('СРАВНЕНИЕ ПО КАТЕГОРИЯМ', style: textStyles.smallSans),
          const SizedBox(height: 8),
          ...report.rows.map((row) {
            final isIncome = row.type == 'INFLOW' || row.type == 'income';
            final compVal = row.completion;
            
            Color statusColor;
            if (isIncome) {
              statusColor = compVal >= 90 ? colors.accentGreen : (compVal >= 70 ? colors.accentAmber : colors.accentRed);
            } else {
              statusColor = compVal <= 100 ? colors.accentGreen : (compVal <= 110 ? colors.accentAmber : colors.accentRed);
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
                            row.category,
                            style: textStyles.bodySans.copyWith(fontWeight: FontWeight.w600),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: statusColor.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            '${compVal.toStringAsFixed(1)}%',
                            style: textStyles.smallMono.copyWith(color: statusColor, fontWeight: FontWeight.bold),
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
                            Text('План', style: textStyles.captionSans.copyWith(color: colors.textSecondary)),
                            const SizedBox(height: 2),
                            Text('${_formatAmount(row.planned)} $currency', style: textStyles.bodyMono),
                          ],
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text('Факт', style: textStyles.captionSans.copyWith(color: colors.textSecondary)),
                            const SizedBox(height: 2),
                            Text('${_formatAmount(row.fact)} $currency', style: textStyles.bodyMono.copyWith(fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ],
                    ),
                    const Divider(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Отклонение', style: textStyles.captionSans.copyWith(color: colors.textSecondary)),
                        Text(
                          '${row.deviation >= 0 ? "+" : ""}${_formatAmount(row.deviation)} $currency',
                          style: textStyles.bodyMono.copyWith(
                            color: row.deviation >= 0 ? colors.accentGreen : colors.accentRed,
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

  Widget _buildBreakEvenTab(BuildContext context, BreakEvenAnalysis? report, String currency) {
    final colors = context.colors;
    final textStyles = context.textStyles;

    if (report == null) {
      return const Center(child: CircularProgressIndicator());
    }

    final safetyPercent = report.marginOfSafety;
    final isSafe = safetyPercent > 20;

    return RefreshIndicator(
      onRefresh: () async {
        context.read<DashboardBloc>().add(LoadDashboardData());
      },
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          LedgerCard(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'ЗАПАС ФИНАНСОВОЙ ПРОЧНОСТИ',
                  style: textStyles.captionSans.copyWith(color: colors.textSecondary),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '${safetyPercent.toStringAsFixed(1)}%',
                      style: textStyles.h1Sans.copyWith(
                        color: isSafe ? colors.accentGreen : colors.accentRed,
                        fontSize: 32,
                      ),
                    ),
                    Text(
                      isSafe ? 'Бизнес устойчив' : 'Опасная зона',
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
          Text('ПОКАЗАТЕЛИ БЕЗУБЫТОЧНОСТИ', style: textStyles.smallSans),
          const SizedBox(height: 8),
          LedgerCard(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                _buildReportRow('Текущая выручка', '${_formatAmount(report.revenue)} $currency', textStyles.bodySans),
                const Divider(),
                _buildReportRow('Точка безубыточности', '${_formatAmount(report.breakEvenRevenue)} $currency', textStyles.bodySans, valueColor: colors.brand),
                const Divider(),
                _buildReportRow('Постоянные затраты', '${_formatAmount(report.fixedCosts)} $currency', textStyles.bodySans),
                const Divider(),
                _buildReportRow('Переменные затраты', '${_formatAmount(report.variableCosts)} $currency', textStyles.bodySans),
                const Divider(),
                _buildReportRow('Коэфф. маржинального дохода', (1 - report.variableRatio).toStringAsFixed(2), textStyles.bodySans),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReportRow(String label, String value, TextStyle textStyle, {Color? valueColor}) {
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

  Widget _buildAbcTab(BuildContext context, AbcAnalysis? report, String currency) {
    final colors = context.colors;
    final textStyles = context.textStyles;

    if (report == null) {
      return const Center(child: CircularProgressIndicator());
    }

    final isCategory = report.dimension == 'category';

    return RefreshIndicator(
      onRefresh: () async {
        context.read<DashboardBloc>().add(LoadDashboardData());
      },
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            children: [
              Expanded(
                child: ChoiceChip(
                  label: const Text('По категориям'),
                  selected: isCategory,
                  onSelected: (val) {
                    if (val) {
                      context.read<DashboardBloc>().add(const ChangeAbcDimension('category'));
                    }
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ChoiceChip(
                  label: const Text('По клиентам'),
                  selected: !isCategory,
                  onSelected: (val) {
                    if (val) {
                      context.read<DashboardBloc>().add(const ChangeAbcDimension('client'));
                    }
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Text(
            isCategory ? 'АНАЛИЗ ТОВАРНЫХ КАТЕГОРИЙ (ABC-анализ)' : 'АНАЛИЗ КОНТРАГЕНТОВ (ABC-анализ)',
            style: textStyles.smallSans,
          ),
          const SizedBox(height: 8),
          if (report.rows.isEmpty)
            LedgerCard(
              padding: const EdgeInsets.all(16),
              child: Center(
                child: Text('Нет данных для анализа', style: textStyles.captionSans),
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
                              row.name,
                              style: textStyles.bodySans.copyWith(fontWeight: FontWeight.w500),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Доля в обороте: ${row.share.toStringAsFixed(1)}% (Накоп: ${row.cumulative.toStringAsFixed(1)}%)',
                              style: textStyles.captionSans.copyWith(color: colors.textSecondary),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Row(
                        children: [
                          Text(
                            '${_formatAmount(row.turnover)} $currency',
                            style: textStyles.bodyMono.copyWith(fontWeight: FontWeight.w500),
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
      BuildContext context, BankAccountsReport? accountsReport, ExchangeRatesReport? ratesReport, String currency) {
    final colors = context.colors;
    final textStyles = context.textStyles;

    if (accountsReport == null || ratesReport == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return RefreshIndicator(
      onRefresh: () async {
        context.read<DashboardBloc>().add(LoadDashboardData());
      },
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('БАНКОВСКИЕ СЧЕТА', style: textStyles.smallSans),
          const SizedBox(height: 8),
          ...accountsReport.accounts.map((acc) => Padding(
                padding: const EdgeInsets.only(bottom: 8.0),
                child: LedgerCard(
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(acc.name, style: textStyles.bodySans.copyWith(fontWeight: FontWeight.w500)),
                          const SizedBox(height: 4),
                          Text(
                            '${acc.bank ?? "Расчетный счет"} • ${acc.number ?? ""}',
                            style: textStyles.captionSans.copyWith(color: colors.textSecondary),
                          ),
                        ],
                      ),
                      Text(
                        '${_formatAmount(acc.balance)} ${acc.currency}',
                        style: textStyles.bodyMono.copyWith(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              )),
          const SizedBox(height: 12),
          LedgerCard(
            padding: const EdgeInsets.all(14),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('ОБЩИЙ ОСТАТОК (В TJS ЭКВИВАЛЕНТЕ)', style: textStyles.captionSans.copyWith(fontWeight: FontWeight.bold)),
                Text(
                  '${_formatAmount(accountsReport.totalTjs)} TJS',
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
          Text('КУРСЫ НАЦИОНАЛЬНОГО БАНКА (NBT)', style: textStyles.smallSans),
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
                      Text('1 ${rate.code}', style: textStyles.bodySans.copyWith(fontWeight: FontWeight.w500)),
                      Text(
                        '${rate.rate.toStringAsFixed(4)} TJS',
                        style: textStyles.bodyMono.copyWith(color: colors.textPrimary),
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

  Widget _buildAiInsightsTab(BuildContext context, AiInsightsReport? report, String currency) {
    final colors = context.colors;
    final textStyles = context.textStyles;

    if (report == null) {
      return const Center(child: CircularProgressIndicator());
    }

    final isRisk = report.forecast.atRisk;

    return RefreshIndicator(
      onRefresh: () async {
        context.read<DashboardBloc>().add(LoadDashboardData());
      },
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
                      isRisk ? TablerIcons.alert_triangle : TablerIcons.shield_check,
                      color: isRisk ? colors.accentRed : colors.accentGreen,
                    ),
                    const SizedBox(width: 10),
                    Text(
                      'РИСК КАССОВОГО РАЗРЫВА',
                      style: textStyles.bodySans.copyWith(
                        fontWeight: FontWeight.bold,
                        color: isRisk ? colors.accentRed : colors.accentGreen,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  report.forecast.message,
                  style: textStyles.bodySans,
                ),
                if (report.forecast.daysToZero != null) ...[
                  const SizedBox(height: 10),
                  Text(
                    'Дней до кассового разрыва: ${report.forecast.daysToZero}',
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
          Text('ИИ РЕКОМЕНДАЦИИ И АНАЛИЗ', style: textStyles.smallSans),
          const SizedBox(height: 8),
          LedgerCard(
            padding: const EdgeInsets.all(16),
            child: Text(
              report.recommendations,
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

    return SizedBox(
      height: 160,
      child: LedgerCard(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          children: [
            Expanded(
              child: CustomPaint(
                size: Size.infinite,
                painter: CashFlowChartPainter(
                  points: points,
                  lineColor: colors.brand,
                  gridColor: colors.border,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '01 Июн — 30 Июн • Суммы в $currency',
              style: textStyles.captionSans,
            ),
          ],
        ),
      ),
    );
  }
}

/// CustomPainter для отрисовки чистого линейного графика кассового остатка.
class CashFlowChartPainter extends CustomPainter {
  final List<CashFlowPoint> points;
  final Color lineColor;
  final Color gridColor;

  CashFlowChartPainter({
    required this.points,
    required this.lineColor,
    required this.gridColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (points.isEmpty) return;

    final double width = size.width;
    final double height = size.height;

    // Вычисляем минимум и максимум для вертикального масштабирования
    double minY = points.first.amount;
    double maxY = points.first.amount;
    for (final p in points) {
      if (p.amount < minY) minY = p.amount;
      if (p.amount > maxY) maxY = p.amount;
    }

    final double rangeY = maxY - minY;
    // Делаем небольшие отступы сверху и снизу
    final double paddingY = rangeY > 0 ? rangeY * 0.15 : 10.0;
    final double adjustedMinY = minY - paddingY;
    final double adjustedMaxY = maxY + paddingY;
    final double adjustedRangeY = adjustedMaxY - adjustedMinY;

    final int len = points.length;
    final double stepX = width / (len - 1);

    // Рисуем 3 горизонтальные линии сетки
    final gridPaint = Paint()
      ..color = gridColor
      ..strokeWidth = 0.5
      ..style = PaintingStyle.stroke;

    for (int i = 0; i < 3; i++) {
      final y = height * i / 2;
      canvas.drawLine(Offset(0, y), Offset(width, y), gridPaint);
    }

    // Отрисовка линии графика
    final path = Path();
    final linePaint = Paint()
      ..color = lineColor
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke
      ..isAntiAlias = true;

    for (int i = 0; i < len; i++) {
      final p = points[i];
      final x = i * stepX;
      // Инвертируем Y, так как ось Y на холсте направлена вниз
      final ratioY = adjustedRangeY > 0 ? (p.amount - adjustedMinY) / adjustedRangeY : 0.5;
      final y = height - (ratioY * height);

      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }

    canvas.drawPath(path, linePaint);
  }

  @override
  bool shouldRepaint(covariant CashFlowChartPainter oldDelegate) =>
      oldDelegate.points != points || oldDelegate.lineColor != lineColor;
}
