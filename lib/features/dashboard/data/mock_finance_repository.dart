import '../domain/finance_model.dart';
import '../domain/finance_repository.dart';

/// Моковая реализация репозитория финансов для локального тестирования.
class MockFinanceRepository implements FinanceRepository {
  @override
  Future<FinanceOverview> getOverview({bool forceRefresh = false}) async {
    final results = await Future.wait([getMetrics(), getCashFlowHistory()]);
    return FinanceOverview(
      metrics: results[0] as FinanceMetrics,
      history: results[1] as List<CashFlowPoint>,
    );
  }

  @override
  Future<FinanceMetrics> getMetrics() async {
    // Имитируем небольшую задержку сети
    await Future.delayed(const Duration(milliseconds: 300));

    return const FinanceMetrics(
      cashBalance: 142500.0,
      revenue: 320800.0,
      expenses: 218400.0,
      netProfit: 102400.0,
      breakEvenPoint: 180000.0,
      cashForecast: 115000.0,
      cashBalanceDelta: 4.2,
      revenueDelta: 15.8,
      expensesDelta: 8.3,
      netProfitDelta: 32.4,
      cashForecastDelta: -12.0,
    );
  }

  @override
  Future<List<CashFlowPoint>> getCashFlowHistory() async {
    await Future.delayed(const Duration(milliseconds: 200));

    final today = DateTime.now();
    final List<CashFlowPoint> points = [];

    final baseline = [
      112000.0,
      115000.0,
      110000.0,
      118000.0,
      122000.0,
      120000.0,
      118000.0,
      125000.0,
      128000.0,
      126000.0,
      124000.0,
      131000.0,
      135000.0,
      132000.0,
      136000.0,
      138000.0,
      135000.0,
      139000.0,
      142000.0,
      140000.0,
      138000.0,
      143000.0,
      145000.0,
      141000.0,
      144000.0,
      146000.0,
      143000.0,
      142500.0,
      145000.0,
      142500.0,
    ];

    final incomes = List<double>.generate(30, (index) {
      if (index == 21) return 8800.0;
      if (index == 15) return 1200.0;
      if (index == 6) return 400.0;
      return (index % 3 == 0) ? 200.0 : 100.0;
    });

    final expenses = List<double>.generate(30, (index) {
      if (index == 15) return 800.0;
      if (index == 21) return 200.0;
      return (index % 4 == 0) ? 150.0 : 80.0;
    });

    for (int i = 0; i < 30; i++) {
      final date = today.subtract(Duration(days: 29 - i));
      points.add(
        CashFlowPoint(
          date: date,
          amount: baseline[i],
          income: incomes[i],
          expense: expenses[i],
        ),
      );
    }

    return points;
  }

  @override
  Future<MetricBreakdown> getBreakdown(String metric) async {
    return MetricBreakdown(
      metric: metric,
      value: 0,
      period: '',
      rows: const [],
    );
  }

  @override
  Future<PnlReport> getPnlReport({DateTime? dateFrom, DateTime? dateTo}) async {
    await Future.delayed(const Duration(milliseconds: 150));
    return const PnlReport(
      income: [
        PnlRow(category: 'Розничная выручка', amount: 285000.0, share: 88.8),
        PnlRow(category: 'Оптовые поставки', amount: 35800.0, share: 11.2),
      ],
      expense: [
        PnlRow(category: 'Закупка сырья', amount: 125000.0, share: 57.2),
        PnlRow(category: 'Аренда помещений', amount: 35000.0, share: 16.0),
        PnlRow(category: 'Зарплаты и KPI', amount: 48400.0, share: 22.2),
        PnlRow(category: 'Маркетинг и реклама', amount: 10000.0, share: 4.6),
      ],
      totalIncome: 320800.0,
      totalExpense: 218400.0,
      profit: 102400.0,
    );
  }

  @override
  Future<BreakEvenAnalysis> getBreakEvenAnalysis({
    DateTime? dateFrom,
    DateTime? dateTo,
  }) async {
    await Future.delayed(const Duration(milliseconds: 100));
    return const BreakEvenAnalysis(
      revenue: 320800.0,
      fixedCosts: 83400.0,
      variableCosts: 135000.0,
      variableRatio: 0.42,
      breakEvenRevenue: 143793.1,
      marginOfSafety: 55.18,
    );
  }

  @override
  Future<AbcAnalysis> getAbcAnalysis(
    String dimension, {
    DateTime? dateFrom,
    DateTime? dateTo,
  }) async {
    await Future.delayed(const Duration(milliseconds: 150));
    if (AbcDimensions.toApi(dimension) == AbcDimensions.counterparty) {
      return const AbcAnalysis(
        dimension: AbcDimensions.counterparty,
        rows: [
          AbcRow(
            name: 'ООО «Сомон Кофе»',
            turnover: 185000.0,
            share: 57.6,
            cumulative: 57.6,
            abcClass: 'A',
          ),
          AbcRow(
            name: 'ОсОО «Шоколадница»',
            turnover: 85000.0,
            share: 26.5,
            cumulative: 84.1,
            abcClass: 'A',
          ),
          AbcRow(
            name: 'Кафе «Сафо»',
            turnover: 35800.0,
            share: 11.2,
            cumulative: 95.3,
            abcClass: 'B',
          ),
          AbcRow(
            name: 'ЧП Азимов Ш.',
            turnover: 15000.0,
            share: 4.7,
            cumulative: 100.0,
            abcClass: 'C',
          ),
        ],
        total: 320800.0,
      );
    } else {
      return const AbcAnalysis(
        dimension: 'category',
        rows: [
          AbcRow(
            name: 'Кофейное зерно арабика',
            turnover: 210000.0,
            share: 65.4,
            cumulative: 65.4,
            abcClass: 'A',
          ),
          AbcRow(
            name: 'Сиропы и топпинги',
            turnover: 75000.0,
            share: 23.4,
            cumulative: 88.8,
            abcClass: 'B',
          ),
          AbcRow(
            name: 'Одноразовые стаканчики',
            turnover: 25800.0,
            share: 8.0,
            cumulative: 96.8,
            abcClass: 'B',
          ),
          AbcRow(
            name: 'Сахар и брендирование',
            turnover: 10000.0,
            share: 3.2,
            cumulative: 100.0,
            abcClass: 'C',
          ),
        ],
        total: 320800.0,
      );
    }
  }

  @override
  Future<BankAccountsReport> getBankAccounts() async {
    await Future.delayed(const Duration(milliseconds: 100));
    return const BankAccountsReport(
      accounts: [
        BankAccountInfo(
          id: '1',
          name: 'Расчетный сомоневый (Алиф Банк)',
          bank: 'Alif Bank',
          number: '20202972900187290',
          currency: 'TJS',
          balance: 95000.0,
        ),
        BankAccountInfo(
          id: '2',
          name: 'Валютный USD (Ориёнбанк)',
          bank: 'Oriyentbank',
          number: '20202840900188301',
          currency: 'USD',
          balance: 4000.0,
        ),
      ],
      totalTjs: 139000.0, // 95000 + 4000 * 11.0
    );
  }

  @override
  Future<ExchangeRatesReport> getExchangeRates() async {
    await Future.delayed(const Duration(milliseconds: 100));
    return ExchangeRatesReport(
      rates: [
        RateRow(code: 'USD', rate: 11.0, rateDate: DateTime.now()),
        RateRow(code: 'RUB', rate: 0.125, rateDate: DateTime.now()),
        RateRow(code: 'EUR', rate: 12.0, rateDate: DateTime.now()),
      ],
    );
  }

  @override
  Future<CurrencyBoard> getCurrencyBoard() async {
    return CurrencyBoard(
      official: [
        RateRow(code: 'USD', rate: 11.0, rateDate: DateTime.now()),
        RateRow(code: 'EUR', rate: 12.0, rateDate: DateTime.now()),
        RateRow(code: 'RUB', rate: 0.125, rateDate: DateTime.now()),
      ],
    );
  }

  @override
  Future<AiInsightsReport> getAiInsights() async {
    await Future.delayed(const Duration(milliseconds: 200));
    return const AiInsightsReport(
      forecast: CashGapForecast(
        atRisk: false,
        avgDailyNet: 3413.33,
        balance: 142500.0,
        message:
            'Кассовый разрыв не прогнозируется. Финансовая устойчивость высокая.',
      ),
      recommendations:
          '• Расходы на маркетинг окупаются: выручка выросла на 15.8% при росте затрат всего на 4.6%.\n'
          '• Запас финансовой прочности составляет 55.18% — это отличный показатель для розничного бизнеса.\n'
          '• Рекомендуется рассмотреть расширение товарной матрицы категории B (Сиропы и стаканчики) для перехода в категорию A.',
    );
  }

  @override
  Future<PlanFactReport> getPlanFactReport({String? period}) async {
    await Future.delayed(const Duration(milliseconds: 100));
    return const PlanFactReport(
      period: '2026-07',
      rows: [
        PlanFactRow(
          category: 'Розничная выручка',
          type: 'INFLOW',
          planned: 300000.0,
          fact: 285000.0,
          deviation: -15000.0,
          completion: 95.0,
        ),
        PlanFactRow(
          category: 'Оптовые поставки',
          type: 'INFLOW',
          planned: 30000.0,
          fact: 35800.0,
          deviation: 5800.0,
          completion: 119.3,
        ),
        PlanFactRow(
          category: 'Закупка сырья',
          type: 'OUTFLOW',
          planned: 130000.0,
          fact: 125000.0,
          deviation: -5000.0,
          completion: 96.1,
        ),
        PlanFactRow(
          category: 'Аренда помещений',
          type: 'OUTFLOW',
          planned: 35000.0,
          fact: 35000.0,
          deviation: 0.0,
          completion: 100.0,
        ),
        PlanFactRow(
          category: 'Зарплаты и KPI',
          type: 'OUTFLOW',
          planned: 50000.0,
          fact: 48400.0,
          deviation: -1600.0,
          completion: 96.8,
        ),
        PlanFactRow(
          category: 'Маркетинг и реклама',
          type: 'OUTFLOW',
          planned: 8000.0,
          fact: 10000.0,
          deviation: 2000.0,
          completion: 125.0,
        ),
      ],
      totalPlanned: 330000.0,
      totalFact: 320800.0,
    );
  }

  @override
  Future<ClientAnalysisReport> getClientAnalysis() async {
    await Future.delayed(const Duration(milliseconds: 80));
    return ClientAnalysisReport(
      frequent: [
        ClientAnalysisRow(
          name: 'ООО «СтройМаркет»',
          purchases: 18,
          total: 42000,
          lastPurchase: DateTime.now().subtract(const Duration(days: 2)),
          daysSince: 2,
        ),
      ],
      dormant: [
        ClientAnalysisRow(
          name: 'ИП Каримов',
          purchases: 3,
          total: 5100,
          lastPurchase: DateTime.now().subtract(const Duration(days: 95)),
          daysSince: 95,
        ),
      ],
    );
  }

  @override
  Future<PlanItem> createPlan({
    required String period,
    required String category,
    required String type,
    required double plannedAmount,
  }) async {
    return PlanItem(
      id: DateTime.now().millisecondsSinceEpoch,
      period: period,
      category: category,
      type: type,
      plannedAmount: plannedAmount,
    );
  }

  @override
  Future<void> deletePlan(int planId) async {}

  @override
  Future<BankAccountInfo> createAccount({
    required String name,
    String? bank,
    String? number,
    String currency = 'TJS',
    double balance = 0,
  }) async {
    return BankAccountInfo(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: name,
      bank: bank,
      number: number,
      currency: currency,
      balance: balance,
    );
  }

  @override
  Future<void> deleteAccount(String accountId) async {}

  @override
  Future<void> zeroOutAccount(String accountId) async {}

  @override
  Future<ConvertResult> convertAmount(double amount, String base) async {
    return ConvertResult(
      base: base,
      amount: amount,
      values: {
        'TJS': amount * 11,
        'USD': amount,
        'EUR': amount * 0.92,
        'RUB': amount * 90,
      },
    );
  }

  @override
  Future<void> refreshRates() async {}

  @override
  Future<OneCReconcileReport> getOneCReconcile({
    String? day,
    bool forceRefresh = false,
  }) async {
    await Future.delayed(const Duration(milliseconds: 150));
    return const OneCReconcileReport(
      date: '2026-08-25',
      totalOnec: 125400.0,
      totalPayk: 125400.0,
      rows: [
        OneCRow(
          onecName: 'Основная касса (1С)',
          onecAmount: 45000.0,
          paykKind: 'register',
          paykId: 1,
          paykName: 'Главная касса',
          paykAmount: 45000.0,
          difference: 0.0,
          matchedBy: 'auto',
        ),
        OneCRow(
          onecName: 'Р/с Алиф Банк (1С)',
          onecAmount: 80400.0,
          paykKind: 'account',
          paykId: 1,
          paykName: 'Расчетный сомоневый (Алиф Банк)',
          paykAmount: 80400.0,
          difference: 0.0,
          matchedBy: 'manual',
        ),
      ],
      notInOnec: [],
    );
  }

  @override
  Future<List<OneCTarget>> getOneCTargets({bool forceRefresh = false}) async {
    await Future.delayed(const Duration(milliseconds: 100));
    return const [
      OneCTarget(
        kind: 'register',
        id: 1,
        name: 'Главная касса',
        amount: 45000.0,
      ),
      OneCTarget(
        kind: 'account',
        id: 1,
        name: 'Расчетный сомоневый (Алиф Банк)',
        amount: 80400.0,
      ),
    ];
  }

  @override
  Future<void> saveOneCLink(OneCLinkInput input) async {
    await Future.delayed(const Duration(milliseconds: 100));
  }
}
