import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:payk_ai_cfo_platform/features/dashboard/bloc/dashboard_bloc.dart';
import 'package:payk_ai_cfo_platform/features/dashboard/bloc/dashboard_event.dart';
import 'package:payk_ai_cfo_platform/features/dashboard/bloc/dashboard_state.dart';
import 'package:payk_ai_cfo_platform/features/dashboard/domain/finance_model.dart';
import 'package:payk_ai_cfo_platform/features/dashboard/domain/finance_repository.dart';

class MockFinanceTestRepository implements FinanceRepository {
  @override
  Future<FinanceOverview> getOverview({bool forceRefresh = false}) async {
    final results = await Future.wait([getMetrics(), getCashFlowHistory()]);
    return FinanceOverview(
      metrics: results[0] as FinanceMetrics,
      history: results[1] as List<CashFlowPoint>,
    );
  }

  bool shouldFail = false;
  int rateReads = 0;
  Completer<ExchangeRatesReport>? rateGate;
  final rateRequestStarted = Completer<void>();
  final Map<String, Completer<AbcAnalysis>> abcGates = {};
  final Map<String, Completer<void>> abcRequestsStarted = {};

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
    return [CashFlowPoint(date: DateTime(2026, 7, 1), amount: 1000.0)];
  }

  @override
  Future<MetricBreakdown> getBreakdown(String metric) async {
    return MetricBreakdown(metric: metric, value: 0, period: '');
  }

  @override
  Future<PnlReport> getPnlReport({DateTime? dateFrom, DateTime? dateTo}) async {
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
  Future<BreakEvenAnalysis> getBreakEvenAnalysis({
    DateTime? dateFrom,
    DateTime? dateTo,
  }) async {
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
  Future<AbcAnalysis> getAbcAnalysis(
    String dimension, {
    DateTime? dateFrom,
    DateTime? dateTo,
  }) async {
    final started = abcRequestsStarted[dimension];
    if (started != null && !started.isCompleted) started.complete();
    if (shouldFail) throw Exception('Abc fail');
    final gate = abcGates[dimension];
    if (gate != null) return gate.future;
    return AbcAnalysis(
      dimension: dimension,
      rows: const [
        AbcRow(
          name: 'Item A',
          turnover: 1600.0,
          share: 80.0,
          cumulative: 80.0,
          abcClass: 'A',
        ),
      ],
      total: 2000.0,
    );
  }

  @override
  Future<BankAccountsReport> getBankAccounts() async {
    if (shouldFail) throw Exception('Accounts fail');
    return const BankAccountsReport(
      accounts: [
        BankAccountInfo(
          id: '1',
          name: 'Main',
          currency: 'TJS',
          balance: 1000.0,
        ),
      ],
      totalTjs: 1000.0,
    );
  }

  @override
  Future<ExchangeRatesReport> getExchangeRates() async {
    rateReads++;
    if (!rateRequestStarted.isCompleted) rateRequestStarted.complete();
    if (shouldFail) throw Exception('Rates fail');
    final gate = rateGate;
    if (gate != null) return gate.future;
    return ExchangeRatesReport(
      rates: [RateRow(code: 'USD', rate: 11.0, rateDate: DateTime.now())],
    );
  }

  @override
  Future<CurrencyBoard> getCurrencyBoard() async {
    return const CurrencyBoard();
  }

  @override
  Future<AiInsightsReport> getAiInsights() async {
    if (shouldFail) throw Exception('AI fail');
    return const AiInsightsReport(
      forecast: CashGapForecast(
        atRisk: false,
        avgDailyNet: 10.0,
        balance: 1000.0,
        message: 'All good',
      ),
      recommendations: 'Keep going',
    );
  }

  @override
  Future<PlanFactReport> getPlanFactReport({String? period}) async {
    if (shouldFail) throw Exception('PlanFact fail');
    return const PlanFactReport(
      period: '2026-07',
      rows: [
        PlanFactRow(
          category: 'Sales',
          type: 'INFLOW',
          planned: 2000.0,
          fact: 1800.0,
          deviation: -200.0,
          completion: 90.0,
        ),
      ],
      totalPlanned: 2000.0,
      totalFact: 1800.0,
    );
  }

  @override
  Future<ClientAnalysisReport> getClientAnalysis() async {
    if (shouldFail) throw Exception('Clients fail');
    return const ClientAnalysisReport();
  }

  @override
  Future<List<PlanItem>> getPlans({String? period}) async => const [];

  @override
  Future<PlanItem> createPlan({
    required String period,
    required String category,
    required String type,
    required double plannedAmount,
  }) async {
    return PlanItem(
      id: 1,
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
      id: '9',
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
    return ConvertResult(base: base, amount: amount, values: {'TJS': amount});
  }

  @override
  Future<void> refreshRates() async {}

  @override
  Future<OneCReconcileReport> getOneCReconcile({
    String? day,
    bool forceRefresh = false,
  }) async {
    if (shouldFail) throw Exception('OneC fail');
    return const OneCReconcileReport(
      date: '2026-08-25',
      totalOnec: 1000.0,
      totalPayk: 1000.0,
      rows: [],
      notInOnec: [],
    );
  }

  @override
  Future<List<OneCTarget>> getOneCTargets({bool forceRefresh = false}) async {
    if (shouldFail) throw Exception('Targets fail');
    return const [];
  }

  @override
  Future<void> saveOneCLink(OneCLinkInput input) async {
    if (shouldFail) throw Exception('Save link fail');
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

    test(
      'dashboard loads overview first and reports only when requested',
      () async {
        bloc.add(const LoadDashboardData());
        final overview =
            await bloc.stream.firstWhere((state) => state is DashboardLoaded)
                as DashboardLoaded;

        expect(overview.metrics.revenue, 2000.0);
        expect(overview.history, hasLength(1));
        expect(overview.pnl, isNull);
        expect(overview.breakEven, isNull);
        expect(overview.abc, isNull);
        expect(overview.bankAccounts, isNull);
        expect(overview.rates, isNull);
        expect(overview.aiInsights, isNull);
        expect(overview.planFact, isNull);

        final reportsFuture = bloc.stream.firstWhere(
          (state) =>
              state is DashboardLoaded &&
              state.pnl != null &&
              state.breakEven != null &&
              state.abc != null &&
              state.bankAccounts != null &&
              state.rates != null &&
              state.aiInsights != null &&
              state.planFact != null,
        );

        for (final section in DashboardSection.values) {
          bloc.add(LoadDashboardSection(section));
        }

        final loaded = await reportsFuture as DashboardLoaded;
        expect(loaded.pnl?.totalIncome, 2000.0);
        expect(loaded.breakEven?.marginOfSafety, 75.0);
        expect(loaded.abc?.rows.first.name, 'Item A');
        expect(loaded.bankAccounts?.totalTjs, 1000.0);
        expect(loaded.rates?.rates.first.code, 'USD');
        expect(loaded.aiInsights?.recommendations, 'Keep going');
        expect(loaded.planFact?.totalFact, 1800.0);
      },
    );

    test(
      'ChangeAbcDimension dispatches ABC update and emits new state',
      () async {
        bloc.add(LoadDashboardData());
        await bloc.stream.firstWhere((s) => s is DashboardLoaded);

        final updatedFuture = bloc.stream.firstWhere(
          (state) =>
              state is DashboardLoaded &&
              state.abc?.dimension == AbcDimensions.counterparty &&
              !state.loadingSections.contains(DashboardSection.abc),
        );

        bloc.add(const ChangeAbcDimension(AbcDimensions.counterparty));

        final loaded = await updatedFuture as DashboardLoaded;
        expect(loaded.abc?.dimension, AbcDimensions.counterparty);
      },
    );
    test(
      'latest ABC dimension wins when responses finish out of order',
      () async {
        bloc.add(const LoadDashboardData());
        await bloc.stream.firstWhere((state) => state is DashboardLoaded);

        final categoryGate = Completer<AbcAnalysis>();
        final clientGate = Completer<AbcAnalysis>();
        repository
          ..abcGates[AbcDimensions.category] = categoryGate
          ..abcGates[AbcDimensions.counterparty] = clientGate
          ..abcRequestsStarted[AbcDimensions.category] = Completer<void>()
          ..abcRequestsStarted[AbcDimensions.counterparty] = Completer<void>();

        bloc.add(const ChangeAbcDimension(AbcDimensions.category));
        await repository.abcRequestsStarted[AbcDimensions.category]!.future;
        bloc.add(const ChangeAbcDimension(AbcDimensions.counterparty));
        await repository.abcRequestsStarted[AbcDimensions.counterparty]!.future;

        final clientLoaded = bloc.stream.firstWhere(
          (state) =>
              state is DashboardLoaded &&
              state.abc?.dimension == AbcDimensions.counterparty &&
              !state.loadingSections.contains(DashboardSection.abc),
        );
        clientGate.complete(
          const AbcAnalysis(
            dimension: AbcDimensions.counterparty,
            rows: [],
            total: 20,
          ),
        );
        await clientLoaded;

        categoryGate.complete(
          const AbcAnalysis(
            dimension: AbcDimensions.category,
            rows: [],
            total: 10,
          ),
        );
        await Future<void>.delayed(Duration.zero);

        final state = bloc.state as DashboardLoaded;
        expect(state.abc?.dimension, AbcDimensions.counterparty);
        expect(state.abc?.total, 20);
        expect(state.loadingSections, isNot(contains(DashboardSection.abc)));
      },
    );
    test(
      'currency conversion uses loaded rates for every monetary report',
      () async {
        final overview = bloc.stream.firstWhere(
          (state) => state is DashboardLoaded,
        );
        bloc.add(const LoadDashboardData());
        await overview;

        final reports = bloc.stream.firstWhere(
          (state) =>
              state is DashboardLoaded &&
              state.pnl != null &&
              state.breakEven != null &&
              state.abc != null &&
              state.planFact != null &&
              state.rates != null,
        );
        bloc
          ..add(const LoadDashboardSection(DashboardSection.pnl))
          ..add(const LoadDashboardSection(DashboardSection.breakEven))
          ..add(const LoadDashboardSection(DashboardSection.abc))
          ..add(const LoadDashboardSection(DashboardSection.planFact))
          ..add(const LoadDashboardSection(DashboardSection.accountsRates));
        await reports;

        final converted = bloc.stream.firstWhere(
          (state) => state is DashboardLoaded && state.currency == 'USD',
        );
        bloc.add(const ChangeCurrency('USD'));
        final state = await converted as DashboardLoaded;

        expect(state.metrics.cashBalance, closeTo(1000 / 11, 0.0001));
        expect(state.pnl!.totalIncome, closeTo(2000 / 11, 0.0001));
        expect(state.breakEven!.revenue, closeTo(2000 / 11, 0.0001));
        expect(state.abc!.total, closeTo(2000 / 11, 0.0001));
        expect(state.planFact!.totalFact, closeTo(1800 / 11, 0.0001));
        expect(repository.rateReads, 1);
      },
    );

    test('latest currency selection wins while rates are loading', () async {
      bloc.add(const LoadDashboardData());
      await bloc.stream.firstWhere((state) => state is DashboardLoaded);

      final rateGate = Completer<ExchangeRatesReport>();
      repository.rateGate = rateGate;
      bloc.add(const ChangeCurrency('USD'));
      await repository.rateRequestStarted.future;

      bloc.add(const ChangeCurrency('TJS'));
      await Future<void>.delayed(Duration.zero);
      rateGate.complete(
        ExchangeRatesReport(
          rates: [
            RateRow(code: 'USD', rate: 11, rateDate: DateTime(2026, 7, 20)),
          ],
        ),
      );
      await Future<void>.delayed(Duration.zero);

      final state = bloc.state as DashboardLoaded;
      expect(state.currency, 'TJS');
      expect(state.metrics.cashBalance, 1000);
    });

    test('unavailable currency does not relabel unconverted values', () async {
      final overview = bloc.stream.firstWhere(
        (state) => state is DashboardLoaded,
      );
      bloc.add(const LoadDashboardData());
      await overview;

      final failed = bloc.stream.firstWhere(
        (state) => state is DashboardLoaded && state.overviewError != null,
      );
      bloc.add(const ChangeCurrency('EUR'));
      final state = await failed as DashboardLoaded;

      expect(state.currency, 'TJS');
      expect(state.metrics.cashBalance, 1000);
      expect(state.overviewError, 'error_load_failed');
    });

    test('failed overview refresh keeps the last confirmed data', () async {
      final overview = bloc.stream.firstWhere(
        (state) => state is DashboardLoaded,
      );
      bloc.add(const LoadDashboardData());
      await overview;

      repository.shouldFail = true;
      final failedRefresh = bloc.stream.firstWhere(
        (state) => state is DashboardLoaded && state.overviewError != null,
      );
      bloc.add(const LoadDashboardData(forceRefresh: true));
      await failedRefresh;

      final state = bloc.state as DashboardLoaded;
      expect(state.metrics.cashBalance, 1000);
      expect(state.overviewError, 'error_load_failed');
    });

    test('loads OneC reconciliation section and handles save link', () async {
      final overview = bloc.stream.firstWhere(
        (state) => state is DashboardLoaded,
      );
      bloc.add(const LoadDashboardData());
      await overview;

      final onecLoaded = bloc.stream.firstWhere(
        (state) => state is DashboardLoaded && state.onec != null,
      );
      bloc.add(const LoadDashboardSection(DashboardSection.onec));
      final loadedState = await onecLoaded as DashboardLoaded;

      expect(loadedState.onec, isNotNull);
      expect(loadedState.onec!.totalOnec, 1000.0);
      expect(loadedState.onec!.totalPayk, 1000.0);
      expect(loadedState.onecTargets, isNotNull);

      bloc.add(
        const SaveOneCLinkRequested(
          onecName: 'Касса 1',
          kind: 'register',
          targetId: 1,
        ),
      );
      await Future<void>.delayed(const Duration(milliseconds: 50));
      final stateAfterSave = bloc.state as DashboardLoaded;
      expect(stateAfterSave.onec, isNotNull);
    });
  });
}
