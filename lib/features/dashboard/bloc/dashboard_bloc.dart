import 'package:flutter_bloc/flutter_bloc.dart';
import '../domain/finance_model.dart';
import '../domain/finance_repository.dart';
import 'dashboard_event.dart';
import 'dashboard_state.dart';

class DashboardBloc extends Bloc<DashboardEvent, DashboardState> {
  final FinanceRepository _repository;
  
  // Кэш базовых данных в национальной валюте TJS
  FinanceMetrics? _cachedBaseMetrics;
  List<CashFlowPoint>? _cachedBaseHistory;
  PnlReport? _cachedPnl;
  BreakEvenAnalysis? _cachedBreakEven;
  AbcAnalysis? _cachedAbc;
  BankAccountsReport? _cachedBankAccounts;
  ExchangeRatesReport? _cachedRates;
  AiInsightsReport? _cachedAiInsights;
  PlanFactReport? _cachedPlanFact;
  String _currentCurrency = 'TJS';

  DashboardBloc(this._repository) : super(DashboardLoading()) {
    on<LoadDashboardData>(_onLoadDashboardData);
    on<ChangeCurrency>(_onChangeCurrency);
    on<ChangeAbcDimension>(_onChangeAbcDimension);
  }

  void _onLoadDashboardData(LoadDashboardData event, Emitter<DashboardState> emit) async {
    if (_cachedBaseMetrics != null && _cachedBaseHistory != null) {
      _emitCurrentState(emit);
    } else {
      emit(DashboardLoading());
    }
    Future<T?> safe<T>(Future<T> future) async {
      try {
        return await future;
      } catch (_) {
        return null;
      }
    }

    try {
      final results = await Future.wait([
        _repository.getMetrics(),
        _repository.getCashFlowHistory(),
        safe(_repository.getPnlReport()),
        safe(_repository.getBreakEvenAnalysis()),
        safe(_repository.getAbcAnalysis('category')),
        safe(_repository.getBankAccounts()),
        safe(_repository.getExchangeRates()),
        safe(_repository.getAiInsights()),
        safe(_repository.getPlanFactReport()),
      ]);

      _cachedBaseMetrics = results[0] as FinanceMetrics;
      _cachedBaseHistory = results[1] as List<CashFlowPoint>;
      _cachedPnl = results[2] as PnlReport?;
      _cachedBreakEven = results[3] as BreakEvenAnalysis?;
      _cachedAbc = results[4] as AbcAnalysis?;
      _cachedBankAccounts = results[5] as BankAccountsReport?;
      _cachedRates = results[6] as ExchangeRatesReport?;
      _cachedAiInsights = results[7] as AiInsightsReport?;
      _cachedPlanFact = results[8] as PlanFactReport?;
      
      _emitCurrentState(emit);
    } catch (e) {
      emit(DashboardError('Не удалось загрузить финансовые данные: ${e.toString()}'));
    }
  }

  void _onChangeCurrency(ChangeCurrency event, Emitter<DashboardState> emit) {
    if (_cachedBaseMetrics == null || _cachedBaseHistory == null) return;
    _currentCurrency = event.currency;
    _emitCurrentState(emit);
  }

  void _onChangeAbcDimension(ChangeAbcDimension event, Emitter<DashboardState> emit) async {
    if (state is! DashboardLoaded) return;
    final currentState = state as DashboardLoaded;
    try {
      final abc = await _repository.getAbcAnalysis(event.dimension);
      _cachedAbc = abc;
      emit(currentState.copyWith(abc: abc));
    } catch (e) {
      // ignore
    }
  }

  void _emitCurrentState(Emitter<DashboardState> emit) {
    final convertedMetrics = _convertMetrics(_cachedBaseMetrics!, _currentCurrency);
    final convertedHistory = _convertHistory(_cachedBaseHistory!, _currentCurrency);
    
    emit(DashboardLoaded(
      metrics: convertedMetrics,
      history: convertedHistory,
      currency: _currentCurrency,
      pnl: _cachedPnl,
      breakEven: _cachedBreakEven,
      abc: _cachedAbc,
      bankAccounts: _cachedBankAccounts,
      rates: _cachedRates,
      aiInsights: _cachedAiInsights,
      planFact: _cachedPlanFact,
    ));
  }

  // Конвертация числовых значений согласно ТЗ (FIN-09 / Курсы валют)
  double _convert(double amount, String targetCurrency) {
    switch (targetCurrency) {
      case 'USD':
        return amount / 10.90; // Курс USD/TJS
      case 'RUB':
        return amount / 0.12;  // Курс RUB/TJS
      case 'EUR':
        return amount / 11.80; // Курс EUR/TJS
      case 'TJS':
      default:
        return amount;
    }
  }

  FinanceMetrics _convertMetrics(FinanceMetrics base, String targetCurrency) {
    return FinanceMetrics(
      cashBalance: _convert(base.cashBalance, targetCurrency),
      revenue: _convert(base.revenue, targetCurrency),
      expenses: _convert(base.expenses, targetCurrency),
      netProfit: _convert(base.netProfit, targetCurrency),
      breakEvenPoint: _convert(base.breakEvenPoint, targetCurrency),
      cashForecast: _convert(base.cashForecast, targetCurrency),
      cashBalanceDelta: base.cashBalanceDelta,
      revenueDelta: base.revenueDelta,
      expensesDelta: base.expensesDelta,
      netProfitDelta: base.netProfitDelta,
      cashForecastDelta: base.cashForecastDelta,
    );
  }

  List<CashFlowPoint> _convertHistory(List<CashFlowPoint> base, String targetCurrency) {
    return base.map((p) => CashFlowPoint(
      date: p.date,
      amount: _convert(p.amount, targetCurrency),
    )).toList();
  }
}
