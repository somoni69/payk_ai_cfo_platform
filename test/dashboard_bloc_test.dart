import 'package:flutter_test/flutter_test.dart';
import 'package:payk_ai_cfo_platform/features/dashboard/bloc/dashboard_bloc.dart';
import 'package:payk_ai_cfo_platform/features/dashboard/bloc/dashboard_event.dart';
import 'package:payk_ai_cfo_platform/features/dashboard/bloc/dashboard_state.dart';
import 'package:payk_ai_cfo_platform/features/dashboard/domain/finance_model.dart';
import 'package:payk_ai_cfo_platform/features/dashboard/domain/finance_repository.dart';

class MockFinanceTestRepository implements FinanceRepository {
  bool shouldFail = false;

  @override
  Future<FinanceMetrics> getMetrics() async {
    if (shouldFail) throw Exception('Metrics fail');
    return const FinanceMetrics(
      cashBalance: 1000.0,
      revenue: 2000.0,
      expenses: 800.0,
      netProfit: 1200.0,
      breakEvenPoint: 500.0,
      cashForecast: 1100.0,
      cashBalanceDelta: 5.0,
      revenueDelta: 10.0,
      expensesDelta: 2.0,
      netProfitDelta: 15.0,
      cashForecastDelta: 1.0,
    );
  }

  @override
  Future<List<CashFlowPoint>> getCashFlowHistory() async {
    if (shouldFail) throw Exception('History fail');
    return [
      CashFlowPoint(date: DateTime(2026, 7, 1), amount: 1000.0),
    ];
  }

  @override
  Future<PnlReport> getPnlReport() async {
    if (shouldFail) throw Exception('Pnl fail');
    return const PnlReport(
      income: [PnlRow(category: 'Sales', amount: 2000.0, share: 100.0)],
      expense: [PnlRow(category: 'Rent', amount: 800.0, share: 100.0)],
      totalIncome: 2000.0,
      totalExpense: 800.0,
      profit: 1200.0,
    );
  }

  @override
  Future<BreakEvenAnalysis> getBreakEvenAnalysis() async {
    if (shouldFail) throw Exception('BE fail');
    return const BreakEvenAnalysis(
      revenue: 2000.0,
      fixedCosts: 400.0,
      variableCosts: 400.0,
      variableRatio: 0.2,
      breakEvenRevenue: 500.0,
      marginOfSafety: 75.0,
    );
  }

  @override
  Future<AbcAnalysis> getAbcAnalysis(String dimension) async {
    if (shouldFail) throw Exception('Abc fail');
    return AbcAnalysis(
      dimension: dimension,
      rows: const [
        AbcRow(name: 'Item A', turnover: 1600.0, share: 80.0, cumulative: 80.0, abcClass: 'A'),
      ],
      total: 2000.0,
    );
  }

  @override
  Future<BankAccountsReport> getBankAccounts() async {
    if (shouldFail) throw Exception('Accounts fail');
    return const BankAccountsReport(
      accounts: [
        BankAccountInfo(id: '1', name: 'Main', currency: 'TJS', balance: 1000.0),
      ],
      totalTjs: 1000.0,
    );
  }

  @override
  Future<ExchangeRatesReport> getExchangeRates() async {
    if (shouldFail) throw Exception('Rates fail');
    return ExchangeRatesReport(
      rates: [RateRow(code: 'USD', rate: 11.0, rateDate: DateTime.now())],
    );
  }

  @override
  Future<AiInsightsReport> getAiInsights() async {
    if (shouldFail) throw Exception('AI fail');
    return const AiInsightsReport(
      forecast: CashGapForecast(atRisk: false, avgDailyNet: 10.0, balance: 1000.0, message: 'All good'),
      recommendations: 'Keep going',
    );
  }

  @override
  Future<PlanFactReport> getPlanFactReport() async {
    if (shouldFail) throw Exception('PlanFact fail');
    return const PlanFactReport(
      period: '2026-07',
      rows: [
        PlanFactRow(category: 'Sales', type: 'INFLOW', planned: 2000.0, fact: 1800.0, deviation: -200.0, completion: 90.0),
      ],
      totalPlanned: 2000.0,
      totalFact: 1800.0,
    );
  }
}

void main() {
  group('DashboardBloc Unit Tests', () {
    late MockFinanceTestRepository repository;
    late DashboardBloc bloc;

    setUp(() {
      repository = MockFinanceTestRepository();
      bloc = DashboardBloc(repository);
    });

    tearDown(() {
      bloc.close();
    });

    test('Initial state is DashboardLoading', () {
      expect(bloc.state, isA<DashboardLoading>());
    });

    test('LoadDashboardData emits loaded state with all 6 reports', () async {
      final expected = [
        isA<DashboardLoading>(),
        isA<DashboardLoaded>()
            .having((s) => s.metrics.revenue, 'revenue', 2000.0)
            .having((s) => s.history.length, 'history count', 1)
            .having((s) => s.pnl?.totalIncome, 'pnl income', 2000.0)
            .having((s) => s.breakEven?.marginOfSafety, 'safety margin', 75.0)
            .having((s) => s.abc?.rows.first.name, 'abc first item', 'Item A')
            .having((s) => s.bankAccounts?.totalTjs, 'accounts total', 1000.0)
            .having((s) => s.rates?.rates.first.code, 'rates first code', 'USD')
            .having((s) => s.aiInsights?.recommendations, 'ai recommendations', 'Keep going')
            .having((s) => s.planFact?.totalFact, 'planfact total fact', 1800.0),
      ];

      expectLater(bloc.stream, emitsInOrder(expected));
      bloc.add(LoadDashboardData());
    });

    test('ChangeAbcDimension dispatches ABC update and emits new state', () async {
      bloc.add(LoadDashboardData());
      await bloc.stream.firstWhere((s) => s is DashboardLoaded);

      bloc.add(const ChangeAbcDimension('client'));

      final List<DashboardState> emitted = [];
      final sub = bloc.stream.listen(emitted.add);

      await Future.delayed(const Duration(milliseconds: 50));
      sub.cancel();

      expect(emitted, isNotEmpty);
      final loaded = emitted.first as DashboardLoaded;
      expect(loaded.abc?.dimension, 'client');
    });
  });
}
