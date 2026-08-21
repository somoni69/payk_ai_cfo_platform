import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/network/user_facing_error.dart';
import '../domain/finance_model.dart';
import '../domain/finance_repository.dart';
import 'dashboard_event.dart';
import 'dashboard_state.dart';

class DashboardBloc extends Bloc<DashboardEvent, DashboardState> {
  final FinanceRepository _repository;

  FinanceMetrics? _cachedBaseMetrics;
  List<CashFlowPoint>? _cachedBaseHistory;
  PnlReport? _cachedPnl;
  BreakEvenAnalysis? _cachedBreakEven;
  AbcAnalysis? _cachedAbc;
  BankAccountsReport? _cachedBankAccounts;
  ExchangeRatesReport? _cachedRates;
  AiInsightsReport? _cachedAiInsights;
  PlanFactReport? _cachedPlanFact;
  ClientAnalysisReport? _cachedClients;
  String _currentCurrency = 'TJS';

  final Set<DashboardSection> _loadingSections = {};
  final Map<DashboardSection, String> _sectionErrors = {};
  final Map<DashboardSection, Future<void>> _sectionRequests = {};
  Future<FinanceOverview>? _overviewRequest;
  Future<ExchangeRatesReport>? _ratesRequest;
  int _currencyRevision = 0;
  int _abcRevision = 0;

  DashboardBloc(this._repository) : super(DashboardLoading()) {
    on<LoadDashboardData>(_onLoadDashboardData);
    on<LoadDashboardSection>(_onLoadDashboardSection);
    on<ChangeCurrency>(_onChangeCurrency);
    on<ChangeAbcDimension>(_onChangeAbcDimension);
    on<CreatePlanRequested>(_onCreatePlan);
    on<CreateAccountRequested>(_onCreateAccount);
    on<DeleteAccountRequested>(_onDeleteAccount);
    on<ZeroOutAccountRequested>(_onZeroOutAccount);
    on<RefreshRatesRequested>(_onRefreshRates);
  }

  Future<void> _onLoadDashboardData(
    LoadDashboardData event,
    Emitter<DashboardState> emit,
  ) async {
    if (event.clearCache) {
      _cachedBaseMetrics = null;
      _cachedBaseHistory = null;
      _cachedPnl = null;
      _cachedBreakEven = null;
      _cachedAbc = null;
      _cachedBankAccounts = null;
      _cachedRates = null;
      _cachedAiInsights = null;
      _cachedPlanFact = null;
      _cachedClients = null;
      _overviewRequest = null;
      _sectionRequests.clear();
      _loadingSections.clear();
      _sectionErrors.clear();
    } else if (event.forceRefresh) {
      _cachedPnl = null;
      _cachedBreakEven = null;
      _cachedAbc = null;
      _cachedBankAccounts = null;
      _cachedRates = null;
      _cachedAiInsights = null;
      _cachedPlanFact = null;
      _cachedClients = null;
      _overviewRequest = null;
      _sectionRequests.clear();
    }

    final hasCachedOverview =
        _cachedBaseMetrics != null && _cachedBaseHistory != null;
    if (hasCachedOverview) {
      _emitCurrentState(emit);
    } else {
      emit(DashboardLoading());
    }

    var request = _overviewRequest;
    if (request == null) {
      request = _repository.getOverview(
        forceRefresh: event.forceRefresh || event.clearCache,
      );
      _overviewRequest = request;
    }

    try {
      final overview = await request;
      if (emit.isDone) return;
      _cachedBaseMetrics = overview.metrics;
      _cachedBaseHistory = overview.history;
      _emitCurrentState(emit);
    } catch (_) {
      if (emit.isDone) return;
      if (_cachedBaseMetrics != null && _cachedBaseHistory != null) {
        _emitCurrentState(emit, overviewError: ErrorKeys.loadFailed);
      } else {
        emit(const DashboardError(ErrorKeys.loadFailed));
      }
    } finally {
      if (identical(_overviewRequest, request)) {
        _overviewRequest = null;
      }
      if (event.completion?.isCompleted == false) event.completion!.complete();
    }
  }

  Future<void> _onLoadDashboardSection(
    LoadDashboardSection event,
    Emitter<DashboardState> emit,
  ) async {
    if (_cachedBaseMetrics == null || _cachedBaseHistory == null) {
      if (event.completion?.isCompleted == false) event.completion!.complete();
      return;
    }

    if (!event.forceRefresh && _hasSectionData(event.section)) {
      if (event.completion?.isCompleted == false) event.completion!.complete();
      return;
    }

    final currentRequest = _sectionRequests[event.section];
    if (currentRequest != null) {
      await currentRequest;
      if (event.completion?.isCompleted == false) event.completion!.complete();
      return;
    }

    late final Future<void> request;
    request =
        _loadSection(
          event.section,
          emit,
          forceRefresh: event.forceRefresh,
        ).whenComplete(() {
          if (identical(_sectionRequests[event.section], request)) {
            _sectionRequests.remove(event.section);
          }
        });
    _sectionRequests[event.section] = request;

    try {
      await request;
    } finally {
      if (event.completion?.isCompleted == false) event.completion!.complete();
    }
  }

  Future<void> _loadSection(
    DashboardSection section,
    Emitter<DashboardState> emit, {
    bool forceRefresh = false,
  }) async {
    final abcRevision = section == DashboardSection.abc ? ++_abcRevision : null;
    _loadingSections.add(section);
    _sectionErrors.remove(section);
    _emitCurrentState(emit);

    try {
      switch (section) {
        case DashboardSection.pnl:
          _cachedPnl = await _repository.getPnlReport();
          break;
        case DashboardSection.planFact:
          _cachedPlanFact = await _repository.getPlanFactReport();
          break;
        case DashboardSection.breakEven:
          _cachedBreakEven = await _repository.getBreakEvenAnalysis();
          break;
        case DashboardSection.abc:
          final abc = await _repository.getAbcAnalysis(
            AbcDimensions.toApi(
              _cachedAbc?.dimension ?? AbcDimensions.category,
            ),
          );
          if (abcRevision == _abcRevision) {
            _cachedAbc = abc;
          }
          break;
        case DashboardSection.accountsRates:
          final values = await Future.wait<Object>([
            _repository.getBankAccounts(),
            _loadRates(forceRefresh: forceRefresh),
          ]);
          _cachedBankAccounts = values[0] as BankAccountsReport;
          _cachedRates = values[1] as ExchangeRatesReport;
          break;
        case DashboardSection.clients:
          _cachedClients = await _repository.getClientAnalysis();
          break;
        case DashboardSection.aiInsights:
          _cachedAiInsights = await _repository.getAiInsights();
          break;
      }
      if (abcRevision == null || abcRevision == _abcRevision) {
        _sectionErrors.remove(section);
      }
    } catch (error) {
      if (abcRevision == null || abcRevision == _abcRevision) {
        _sectionErrors[section] = ErrorKeys.loadFailed;
      }
    } finally {
      if (abcRevision == null || abcRevision == _abcRevision) {
        _loadingSections.remove(section);
        _emitCurrentState(emit);
      }
    }
  }

  Future<ExchangeRatesReport> _loadRates({bool forceRefresh = false}) async {
    final cached = _cachedRates;
    if (cached != null && !forceRefresh) return cached;

    var request = _ratesRequest;
    if (request == null) {
      request = _repository.getExchangeRates();
      _ratesRequest = request;
    }

    try {
      final rates = await request;
      _cachedRates = rates;
      return rates;
    } finally {
      if (identical(_ratesRequest, request)) {
        _ratesRequest = null;
      }
    }
  }

  bool _hasSectionData(DashboardSection section) {
    return switch (section) {
      DashboardSection.pnl => _cachedPnl != null,
      DashboardSection.planFact => _cachedPlanFact != null,
      DashboardSection.breakEven => _cachedBreakEven != null,
      DashboardSection.abc => _cachedAbc != null,
      DashboardSection.accountsRates =>
        _cachedBankAccounts != null && _cachedRates != null,
      DashboardSection.clients => _cachedClients != null,
      DashboardSection.aiInsights => _cachedAiInsights != null,
    };
  }

  Future<void> _onChangeCurrency(
    ChangeCurrency event,
    Emitter<DashboardState> emit,
  ) async {
    final currency = event.currency.toUpperCase();
    final revision = ++_currencyRevision;
    if (_cachedBaseMetrics == null ||
        _cachedBaseHistory == null ||
        currency == _currentCurrency) {
      return;
    }

    if (currency == 'TJS') {
      _currentCurrency = currency;
      _sectionErrors.remove(DashboardSection.accountsRates);
      _emitCurrentState(emit);
      return;
    }

    try {
      final rates = await _loadRates();
      if (revision != _currencyRevision || emit.isDone) return;
      final hasRate = rates.rates.any(
        (row) => row.code.toUpperCase() == currency && row.rate > 0,
      );
      if (!hasRate) {
        const message = ErrorKeys.loadFailed;
        _sectionErrors[DashboardSection.accountsRates] = message;
        _emitCurrentState(emit, overviewError: message);
        return;
      }

      _currentCurrency = currency;
      _sectionErrors.remove(DashboardSection.accountsRates);
      _emitCurrentState(emit);
    } catch (_) {
      if (revision != _currencyRevision || emit.isDone) return;
      const message = ErrorKeys.loadFailed;
      _sectionErrors[DashboardSection.accountsRates] = message;
      _emitCurrentState(emit, overviewError: message);
    }
  }

  Future<void> _onChangeAbcDimension(
    ChangeAbcDimension event,
    Emitter<DashboardState> emit,
  ) async {
    if (_cachedBaseMetrics == null || _cachedBaseHistory == null) return;

    final dimension = AbcDimensions.toApi(event.dimension);
    final previous = _cachedAbc;
    final revision = ++_abcRevision;
    _loadingSections.add(DashboardSection.abc);
    _sectionErrors.remove(DashboardSection.abc);
    if (previous != null) {
      _cachedAbc = AbcAnalysis(
        dimension: dimension,
        rows: previous.rows,
        total: previous.total,
      );
    }
    _emitCurrentState(emit);
    try {
      final abc = await _repository.getAbcAnalysis(dimension);
      if (revision != _abcRevision || emit.isDone) return;
      _cachedAbc = AbcAnalysis(
        dimension: dimension,
        rows: abc.rows,
        total: abc.total,
      );
    } catch (error) {
      if (revision == _abcRevision && !emit.isDone) {
        _cachedAbc = previous;
        _sectionErrors[DashboardSection.abc] = ErrorKeys.loadFailed;
      }
    } finally {
      if (revision == _abcRevision) {
        _loadingSections.remove(DashboardSection.abc);
        _emitCurrentState(emit);
      }
    }
  }

  void _emitCurrentState(
    Emitter<DashboardState> emit, {
    String? overviewError,
  }) {
    final baseMetrics = _cachedBaseMetrics;
    final baseHistory = _cachedBaseHistory;
    if (emit.isDone || baseMetrics == null || baseHistory == null) return;

    final currency = _currentCurrency;
    emit(
      DashboardLoaded(
        metrics: _convertMetrics(baseMetrics, currency),
        history: _convertHistory(baseHistory, currency),
        currency: currency,
        pnl: _convertPnl(_cachedPnl, currency),
        breakEven: _convertBreakEven(_cachedBreakEven, currency),
        abc: _convertAbc(_cachedAbc, currency),
        bankAccounts: _cachedBankAccounts,
        rates: _cachedRates,
        aiInsights: _cachedAiInsights,
        planFact: _convertPlanFact(_cachedPlanFact, currency),
        clients: _cachedClients,
        loadingSections: Set.unmodifiable(_loadingSections),
        sectionErrors: Map.unmodifiable(_sectionErrors),
        overviewError: overviewError,
      ),
    );
  }

  Future<void> _onCreatePlan(
    CreatePlanRequested event,
    Emitter<DashboardState> emit,
  ) async {
    try {
      await _repository.createPlan(
        period: event.period,
        category: event.category,
        type: event.type,
        plannedAmount: event.plannedAmount,
      );
      _cachedPlanFact = await _repository.getPlanFactReport();
      if (state is DashboardLoaded) {
        emit(
          (state as DashboardLoaded).copyWith(
            planFact: _convertPlanFact(_cachedPlanFact, _currentCurrency),
            actionMessage: 'dashboard_toast_plan_created',
          ),
        );
      } else {
        _emitCurrentState(emit);
      }
    } catch (e) {
      if (state is DashboardLoaded) {
        emit((state as DashboardLoaded).copyWith(actionMessage: e.toString()));
      }
    }
  }

  Future<void> _onCreateAccount(
    CreateAccountRequested event,
    Emitter<DashboardState> emit,
  ) async {
    try {
      await _repository.createAccount(
        name: event.name,
        bank: event.bank,
        number: event.number,
        currency: event.currency,
        balance: event.balance,
      );
      _cachedBankAccounts = await _repository.getBankAccounts();
      if (state is DashboardLoaded) {
        emit(
          (state as DashboardLoaded).copyWith(
            bankAccounts: _cachedBankAccounts,
            actionMessage: 'dashboard_toast_account_created',
          ),
        );
      } else {
        _emitCurrentState(emit);
      }
    } catch (e) {
      if (state is DashboardLoaded) {
        emit((state as DashboardLoaded).copyWith(actionMessage: e.toString()));
      }
    }
  }

  Future<void> _onDeleteAccount(
    DeleteAccountRequested event,
    Emitter<DashboardState> emit,
  ) async {
    try {
      await _repository.deleteAccount(event.id);
      _cachedBankAccounts = await _repository.getBankAccounts();
      if (state is DashboardLoaded) {
        emit(
          (state as DashboardLoaded).copyWith(
            bankAccounts: _cachedBankAccounts,
            actionMessage: 'dashboard_toast_account_deleted',
          ),
        );
      } else {
        _emitCurrentState(emit);
      }
    } catch (e) {
      if (state is DashboardLoaded) {
        emit((state as DashboardLoaded).copyWith(actionMessage: e.toString()));
      }
    }
  }

  Future<void> _onZeroOutAccount(
    ZeroOutAccountRequested event,
    Emitter<DashboardState> emit,
  ) async {
    try {
      await _repository.zeroOutAccount(event.id);
      _cachedBankAccounts = await _repository.getBankAccounts();
      if (state is DashboardLoaded) {
        emit(
          (state as DashboardLoaded).copyWith(
            bankAccounts: _cachedBankAccounts,
            actionMessage: 'dashboard_toast_account_zeroed',
          ),
        );
      } else {
        _emitCurrentState(emit);
      }
    } catch (e) {
      if (state is DashboardLoaded) {
        emit((state as DashboardLoaded).copyWith(actionMessage: e.toString()));
      }
    }
  }

  Future<void> _onRefreshRates(
    RefreshRatesRequested event,
    Emitter<DashboardState> emit,
  ) async {
    try {
      await _repository.refreshRates();
      _cachedRates = await _repository.getExchangeRates();
      if (state is DashboardLoaded) {
        emit(
          (state as DashboardLoaded).copyWith(
            rates: _cachedRates,
            actionMessage: 'dashboard_toast_rates_refreshed',
          ),
        );
      } else {
        _emitCurrentState(emit);
      }
    } catch (e) {
      if (state is DashboardLoaded) {
        emit((state as DashboardLoaded).copyWith(actionMessage: e.toString()));
      }
    }
  }

  double _convert(double amount, String targetCurrency) {
    if (targetCurrency == 'TJS') return amount;
    final rates = _cachedRates?.rates ?? const <RateRow>[];
    for (final row in rates) {
      if (row.code.toUpperCase() == targetCurrency && row.rate > 0) {
        return amount / row.rate;
      }
    }
    return amount;
  }

  PnlReport? _convertPnl(PnlReport? base, String targetCurrency) {
    if (base == null || targetCurrency == 'TJS') return base;
    PnlRow convertRow(PnlRow row) => PnlRow(
      category: row.category,
      amount: _convert(row.amount, targetCurrency),
      share: row.share,
    );

    return PnlReport(
      income: base.income.map(convertRow).toList(growable: false),
      expense: base.expense.map(convertRow).toList(growable: false),
      totalIncome: _convert(base.totalIncome, targetCurrency),
      totalExpense: _convert(base.totalExpense, targetCurrency),
      profit: _convert(base.profit, targetCurrency),
    );
  }

  BreakEvenAnalysis? _convertBreakEven(
    BreakEvenAnalysis? base,
    String targetCurrency,
  ) {
    if (base == null || targetCurrency == 'TJS') return base;
    return BreakEvenAnalysis(
      revenue: _convert(base.revenue, targetCurrency),
      fixedCosts: _convert(base.fixedCosts, targetCurrency),
      variableCosts: _convert(base.variableCosts, targetCurrency),
      variableRatio: base.variableRatio,
      breakEvenRevenue: _convert(base.breakEvenRevenue, targetCurrency),
      marginOfSafety: base.marginOfSafety,
    );
  }

  AbcAnalysis? _convertAbc(AbcAnalysis? base, String targetCurrency) {
    if (base == null || targetCurrency == 'TJS') return base;
    return AbcAnalysis(
      dimension: base.dimension,
      rows: base.rows
          .map(
            (row) => AbcRow(
              name: row.name,
              turnover: _convert(row.turnover, targetCurrency),
              share: row.share,
              cumulative: row.cumulative,
              abcClass: row.abcClass,
            ),
          )
          .toList(growable: false),
      total: _convert(base.total, targetCurrency),
    );
  }

  PlanFactReport? _convertPlanFact(
    PlanFactReport? base,
    String targetCurrency,
  ) {
    if (base == null || targetCurrency == 'TJS') return base;
    return PlanFactReport(
      period: base.period,
      rows: base.rows
          .map(
            (row) => PlanFactRow(
              category: row.category,
              type: row.type,
              planned: _convert(row.planned, targetCurrency),
              fact: _convert(row.fact, targetCurrency),
              deviation: _convert(row.deviation, targetCurrency),
              completion: row.completion,
            ),
          )
          .toList(growable: false),
      totalPlanned: _convert(base.totalPlanned, targetCurrency),
      totalFact: _convert(base.totalFact, targetCurrency),
    );
  }

  FinanceMetrics _convertMetrics(FinanceMetrics base, String targetCurrency) {
    return FinanceMetrics(
      cashBalance: _convert(base.cashBalance, targetCurrency),
      revenue: _convert(base.revenue, targetCurrency),
      expenses: _convert(base.expenses, targetCurrency),
      netProfit: _convert(base.netProfit, targetCurrency),
      breakEvenPoint: base.breakEvenPoint == null
          ? null
          : _convert(base.breakEvenPoint!, targetCurrency),
      cashForecast: base.cashForecast == null
          ? null
          : _convert(base.cashForecast!, targetCurrency),
      cashBalanceDelta: base.cashBalanceDelta,
      revenueDelta: base.revenueDelta,
      expensesDelta: base.expensesDelta,
      netProfitDelta: base.netProfitDelta,
      cashForecastDelta: base.cashForecastDelta,
    );
  }

  List<CashFlowPoint> _convertHistory(
    List<CashFlowPoint> base,
    String targetCurrency,
  ) {
    return base
        .map(
          (point) => CashFlowPoint(
            date: point.date,
            amount: _convert(point.amount, targetCurrency),
            income: _convert(point.income, targetCurrency),
            expense: _convert(point.expense, targetCurrency),
          ),
        )
        .toList(growable: false);
  }
}
