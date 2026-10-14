import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/network/user_facing_error.dart';
import '../domain/finance_model.dart';
import '../domain/finance_repository.dart';
import 'dashboard_event.dart';
import 'dashboard_state.dart';

class DashboardBloc extends Bloc<DashboardEvent, DashboardState> {
  final FinanceRepository _repository;

  DashboardBloc(this._repository) : super(DashboardLoading()) {
    on<LoadDashboardData>(_onLoadDashboardData);
    on<LoadDashboardSection>(_onLoadDashboardSection);
    on<SetFinanceReportPeriod>(
      _onSetFinanceReportPeriod,
      transformer: restartable(),
    );
    on<SetPlanFactPeriod>(_onSetPlanFactPeriod, transformer: restartable());
    on<ChangeCurrency>(_onChangeCurrency, transformer: restartable());
    on<ChangeAbcDimension>(_onChangeAbcDimension, transformer: restartable());
    on<CreatePlanRequested>(_onCreatePlan);
    on<CreateAccountRequested>(_onCreateAccount);
    on<DeleteAccountRequested>(_onDeleteAccount);
    on<ZeroOutAccountRequested>(_onZeroOutAccount);
    on<RefreshRatesRequested>(_onRefreshRates);
    on<SaveOneCLinkRequested>(_onSaveOneCLink);
    on<RefreshOneCReconcileRequested>(_onRefreshOneCReconcile);
  }

  Future<void> _onLoadDashboardData(
    LoadDashboardData event,
    Emitter<DashboardState> emit,
  ) async {
    final currentLoaded = state is DashboardLoaded
        ? state as DashboardLoaded
        : null;

    if (event.clearCache || currentLoaded == null) {
      emit(DashboardLoading());
    }

    try {
      final overview = await _repository.getOverview(
        forceRefresh: event.forceRefresh || event.clearCache,
      );

      final currency = currentLoaded?.currency ?? 'TJS';
      final convertedMetrics = _convertMetricsWithFactor(overview.metrics, 1.0);
      final convertedHistory = _convertHistoryWithFactor(overview.history, 1.0);

      if (currentLoaded != null && !event.clearCache) {
        emit(
          currentLoaded.copyWith(
            metrics: convertedMetrics,
            history: convertedHistory,
            currency: currency,
            clearOverviewError: true,
          ),
        );
      } else {
        emit(
          DashboardLoaded(
            metrics: convertedMetrics,
            history: convertedHistory,
            currency: currency,
          ),
        );
      }
    } catch (e) {
      final msg = userFacingError(e, fallback: ErrorKeys.loadFailed);
      if (currentLoaded != null && !event.clearCache) {
        emit(currentLoaded.copyWith(overviewError: msg));
      } else {
        emit(DashboardError(msg));
      }
    }
  }

  Future<void> _onLoadDashboardSection(
    LoadDashboardSection event,
    Emitter<DashboardState> emit,
  ) async {
    if (state is! DashboardLoaded) return;
    final current = state as DashboardLoaded;

    if (!event.forceRefresh &&
        !_sectionLoading(current, event.section) &&
        _sectionHasData(current, event.section)) {
      return;
    }

    final updatedLoading = Set<DashboardSection>.from(current.loadingSections)
      ..add(event.section);
    final updatedErrors = Map<DashboardSection, String>.from(
      current.sectionErrors,
    )..remove(event.section);

    emit(
      current.copyWith(
        loadingSections: updatedLoading,
        sectionErrors: updatedErrors,
      ),
    );

    try {
      DashboardLoaded next = current.copyWith(
        loadingSections: updatedLoading,
        sectionErrors: updatedErrors,
      );

      switch (event.section) {
        case DashboardSection.pnl:
          final pnl = await _repository.getPnlReport(
            dateFrom: current.reportDateFrom,
            dateTo: current.reportDateTo,
          );
          next = next.copyWith(pnl: pnl);
          break;
        case DashboardSection.planFact:
          final planFact = await _repository.getPlanFactReport(
            period: current.planPeriod,
          );
          next = next.copyWith(planFact: planFact);
          break;
        case DashboardSection.breakEven:
          final breakEven = await _repository.getBreakEvenAnalysis(
            dateFrom: current.reportDateFrom,
            dateTo: current.reportDateTo,
          );
          next = next.copyWith(breakEven: breakEven);
          break;
        case DashboardSection.abc:
          final abc = await _repository.getAbcAnalysis(
            AbcDimensions.toApi(
              current.abc?.dimension ?? AbcDimensions.category,
            ),
            dateFrom: current.reportDateFrom,
            dateTo: current.reportDateTo,
          );
          next = next.copyWith(abc: abc);
          break;
        case DashboardSection.accountsRates:
          final values = await Future.wait<Object>([
            _repository.getBankAccounts(),
            _repository.getExchangeRates(),
          ]);
          next = next.copyWith(
            bankAccounts: values[0] as BankAccountsReport,
            rates: values[1] as ExchangeRatesReport,
          );
          break;
        case DashboardSection.clients:
          final clients = await _repository.getClientAnalysis();
          next = next.copyWith(clients: clients);
          break;
        case DashboardSection.aiInsights:
          final ai = await _repository.getAiInsights();
          next = next.copyWith(aiInsights: ai);
          break;
        case DashboardSection.onec:
          final values = await Future.wait<Object>([
            _repository.getOneCReconcile(forceRefresh: event.forceRefresh),
            _repository.getOneCTargets(forceRefresh: event.forceRefresh),
          ]);
          next = next.copyWith(
            onec: values[0] as OneCReconcileReport,
            onecTargets: values[1] as List<OneCTarget>,
          );
          break;
      }

      final finishLoading = Set<DashboardSection>.from(next.loadingSections)
        ..remove(event.section);
      emit(
        _applySectionCurrency(
          next.copyWith(loadingSections: finishLoading),
          event.section,
        ),
      );
    } catch (e) {
      if (state is! DashboardLoaded) return;
      final latest = state as DashboardLoaded;
      final finishLoading = Set<DashboardSection>.from(latest.loadingSections)
        ..remove(event.section);
      final finishErrors = Map<DashboardSection, String>.from(
        latest.sectionErrors,
      )..[event.section] = userFacingError(e, fallback: ErrorKeys.loadFailed);

      emit(
        latest.copyWith(
          loadingSections: finishLoading,
          sectionErrors: finishErrors,
        ),
      );
    }
  }

  Future<void> _onSetFinanceReportPeriod(
    SetFinanceReportPeriod event,
    Emitter<DashboardState> emit,
  ) async {
    if (state is! DashboardLoaded) return;
    final current = state as DashboardLoaded;
    final clearDates = event.dateFrom == null && event.dateTo == null;
    final reload = <DashboardSection>{
      if (current.pnl != null) DashboardSection.pnl,
      if (current.breakEven != null) DashboardSection.breakEven,
      if (current.abc != null) DashboardSection.abc,
    };
    emit(
      current.copyWith(
        clearReportDates: clearDates,
        reportDateFrom: event.dateFrom,
        reportDateTo: event.dateTo,
        loadingSections: Set<DashboardSection>.from(current.loadingSections)
          ..addAll(reload),
      ),
    );
    if (reload.isEmpty) return;

    try {
      final results = await Future.wait([
        if (reload.contains(DashboardSection.pnl))
          _repository.getPnlReport(
            dateFrom: event.dateFrom,
            dateTo: event.dateTo,
          ),
        if (reload.contains(DashboardSection.breakEven))
          _repository.getBreakEvenAnalysis(
            dateFrom: event.dateFrom,
            dateTo: event.dateTo,
          ),
        if (reload.contains(DashboardSection.abc))
          _repository.getAbcAnalysis(
            AbcDimensions.toApi(
              current.abc?.dimension ?? AbcDimensions.category,
            ),
            dateFrom: event.dateFrom,
            dateTo: event.dateTo,
          ),
      ]);
      if (state is! DashboardLoaded) return;
      final latest = state as DashboardLoaded;
      var i = 0;
      var next = latest;
      if (reload.contains(DashboardSection.pnl)) {
        next = next.copyWith(pnl: results[i++] as PnlReport);
      }
      if (reload.contains(DashboardSection.breakEven)) {
        next = next.copyWith(breakEven: results[i++] as BreakEvenAnalysis);
      }
      if (reload.contains(DashboardSection.abc)) {
        next = next.copyWith(abc: results[i++] as AbcAnalysis);
      }
      emit(
        _applyLoadedCurrency(
          next.copyWith(
            loadingSections: Set<DashboardSection>.from(latest.loadingSections)
              ..removeAll(reload),
          ),
        ),
      );
    } catch (e) {
      if (state is! DashboardLoaded) return;
      final latest = state as DashboardLoaded;
      emit(
        latest.copyWith(
          loadingSections: Set<DashboardSection>.from(latest.loadingSections)
            ..removeAll(reload),
          sectionErrors: {
            ...latest.sectionErrors,
            for (final section in reload)
              section: userFacingError(e, fallback: ErrorKeys.loadFailed),
          },
        ),
      );
    }
  }

  Future<void> _onSetPlanFactPeriod(
    SetPlanFactPeriod event,
    Emitter<DashboardState> emit,
  ) async {
    if (state is! DashboardLoaded) return;
    final current = state as DashboardLoaded;
    emit(
      current.copyWith(
        planPeriod: event.period,
        loadingSections: Set<DashboardSection>.from(current.loadingSections)
          ..add(DashboardSection.planFact),
      ),
    );
    try {
      final report = await _repository.getPlanFactReport(period: event.period);
      if (state is! DashboardLoaded) return;
      final latest = state as DashboardLoaded;
      emit(
        _applySectionCurrency(
          latest.copyWith(
            planFact: report,
            loadingSections: Set<DashboardSection>.from(latest.loadingSections)
              ..remove(DashboardSection.planFact),
          ),
          DashboardSection.planFact,
        ),
      );
    } catch (e) {
      if (state is! DashboardLoaded) return;
      final latest = state as DashboardLoaded;
      emit(
        latest.copyWith(
          loadingSections: Set<DashboardSection>.from(latest.loadingSections)
            ..remove(DashboardSection.planFact),
          sectionErrors: {
            ...latest.sectionErrors,
            DashboardSection.planFact: userFacingError(
              e,
              fallback: ErrorKeys.loadFailed,
            ),
          },
        ),
      );
    }
  }

  Future<void> _onChangeCurrency(
    ChangeCurrency event,
    Emitter<DashboardState> emit,
  ) async {
    if (state is! DashboardLoaded) return;
    final current = state as DashboardLoaded;
    if (current.currency == event.currency) return;

    if (event.currency == 'TJS') {
      emit(current.copyWith(currency: 'TJS', clearOverviewError: true));
      add(const LoadDashboardData());
      return;
    }

    ExchangeRatesReport? rates = current.rates;
    if (rates == null) {
      try {
        rates = await _repository.getExchangeRates();
      } catch (e) {
        emit(current.copyWith(overviewError: 'error_load_failed'));
        return;
      }
    }

    final rateRow = rates.rates.firstWhere(
      (r) => r.code == event.currency,
      orElse: () => RateRow(code: '', rate: 0, rateDate: DateTime(2000)),
    );

    if (rateRow.rate <= 0) {
      emit(current.copyWith(overviewError: 'error_load_failed'));
      return;
    }

    final factor = 1.0 / rateRow.rate;
    final latest = state is DashboardLoaded
        ? state as DashboardLoaded
        : current;
    if (latest.currency == event.currency) return;

    final convertedMetrics = _convertMetricsWithFactor(latest.metrics, factor);
    final convertedHistory = _convertHistoryWithFactor(latest.history, factor);
    final convertedPnl = latest.pnl != null
        ? PnlReport(
            income: latest.pnl!.income
                .map(
                  (r) => PnlRow(
                    category: r.category,
                    amount: r.amount * factor,
                    share: r.share,
                  ),
                )
                .toList(),
            expense: latest.pnl!.expense
                .map(
                  (r) => PnlRow(
                    category: r.category,
                    amount: r.amount * factor,
                    share: r.share,
                  ),
                )
                .toList(),
            totalIncome: latest.pnl!.totalIncome * factor,
            totalExpense: latest.pnl!.totalExpense * factor,
            profit: latest.pnl!.profit * factor,
          )
        : null;
    final convertedBreakEven = latest.breakEven != null
        ? BreakEvenAnalysis(
            revenue: latest.breakEven!.revenue * factor,
            fixedCosts: latest.breakEven!.fixedCosts * factor,
            variableCosts: latest.breakEven!.variableCosts * factor,
            variableRatio: latest.breakEven!.variableRatio,
            breakEvenRevenue: latest.breakEven!.breakEvenRevenue * factor,
            marginOfSafety: latest.breakEven!.marginOfSafety,
          )
        : null;
    final convertedAbc = latest.abc != null
        ? AbcAnalysis(
            dimension: latest.abc!.dimension,
            rows: latest.abc!.rows
                .map(
                  (r) => AbcRow(
                    name: r.name,
                    turnover: r.turnover * factor,
                    share: r.share,
                    cumulative: r.cumulative,
                    abcClass: r.abcClass,
                  ),
                )
                .toList(),
            total: latest.abc!.total * factor,
          )
        : null;
    final convertedPlanFact = latest.planFact != null
        ? PlanFactReport(
            period: latest.planFact!.period,
            rows: latest.planFact!.rows
                .map(
                  (r) => PlanFactRow(
                    category: r.category,
                    type: r.type,
                    planned: r.planned * factor,
                    fact: r.fact * factor,
                    deviation: r.deviation * factor,
                    completion: r.completion,
                  ),
                )
                .toList(),
            totalPlanned: latest.planFact!.totalPlanned * factor,
            totalFact: latest.planFact!.totalFact * factor,
          )
        : null;

    emit(
      latest.copyWith(
        currency: event.currency,
        rates: rates,
        metrics: convertedMetrics,
        history: convertedHistory,
        pnl: convertedPnl,
        breakEven: convertedBreakEven,
        abc: convertedAbc,
        planFact: convertedPlanFact,
        clearOverviewError: true,
      ),
    );
  }

  Future<void> _onChangeAbcDimension(
    ChangeAbcDimension event,
    Emitter<DashboardState> emit,
  ) async {
    if (state is! DashboardLoaded) return;
    final current = state as DashboardLoaded;
    final dimension = AbcDimensions.toApi(event.dimension);
    final currentDimension = current.abc?.dimension;
    final alreadyShowing =
        currentDimension != null &&
        AbcDimensions.toApi(currentDimension) == dimension &&
        !current.loadingSections.contains(DashboardSection.abc);
    if (alreadyShowing) return;

    final loading = Set<DashboardSection>.from(current.loadingSections)
      ..add(DashboardSection.abc);
    final errors = Map<DashboardSection, String>.from(current.sectionErrors)
      ..remove(DashboardSection.abc);

    emit(
      current.copyWith(
        loadingSections: loading,
        sectionErrors: errors,
        abc: AbcAnalysis(dimension: dimension, rows: const [], total: 0),
      ),
    );

    try {
      final abc = await _repository.getAbcAnalysis(
        dimension,
        dateFrom: current.reportDateFrom,
        dateTo: current.reportDateTo,
      );
      if (state is! DashboardLoaded) return;
      final latest = state as DashboardLoaded;
      emit(
        _applySectionCurrency(
          latest.copyWith(
            abc: abc,
            loadingSections: Set<DashboardSection>.from(latest.loadingSections)
              ..remove(DashboardSection.abc),
          ),
          DashboardSection.abc,
        ),
      );
    } catch (e) {
      if (state is! DashboardLoaded) return;
      final latest = state as DashboardLoaded;
      final updatedErrors =
          Map<DashboardSection, String>.from(latest.sectionErrors)
            ..[DashboardSection.abc] = userFacingError(
              e,
              fallback: ErrorKeys.loadFailed,
            );
      emit(
        latest.copyWith(
          loadingSections: Set<DashboardSection>.from(latest.loadingSections)
            ..remove(DashboardSection.abc),
          sectionErrors: updatedErrors,
        ),
      );
    }
  }

  Future<void> _onCreatePlan(
    CreatePlanRequested event,
    Emitter<DashboardState> emit,
  ) async {
    if (state is! DashboardLoaded) return;
    final current = state as DashboardLoaded;
    try {
      await _repository.createPlan(
        period: event.period,
        category: event.category,
        type: event.type,
        plannedAmount: event.plannedAmount,
      );
      final refreshed = await _repository.getPlanFactReport(
        period: current.planPeriod ?? event.period,
      );
      emit(
        current.copyWith(
          planFact: refreshed,
          actionMessage: 'dashboard_plan_created',
        ),
      );
    } catch (e) {
      emit(
        current.copyWith(
          actionMessage: userFacingError(e, fallback: ErrorKeys.saveFailed),
        ),
      );
    }
  }

  Future<void> _onCreateAccount(
    CreateAccountRequested event,
    Emitter<DashboardState> emit,
  ) async {
    if (state is! DashboardLoaded) return;
    final current = state as DashboardLoaded;
    try {
      await _repository.createAccount(
        name: event.name,
        bank: event.bank,
        number: event.number,
        currency: event.currency,
        balance: event.balance,
      );
      final refreshed = await _repository.getBankAccounts();
      emit(
        current.copyWith(
          bankAccounts: refreshed,
          actionMessage: 'dashboard_account_created',
        ),
      );
    } catch (e) {
      emit(
        current.copyWith(
          actionMessage: userFacingError(e, fallback: ErrorKeys.saveFailed),
        ),
      );
    }
  }

  Future<void> _onDeleteAccount(
    DeleteAccountRequested event,
    Emitter<DashboardState> emit,
  ) async {
    if (state is! DashboardLoaded) return;
    final current = state as DashboardLoaded;
    try {
      await _repository.deleteAccount(event.id);
      final refreshed = await _repository.getBankAccounts();
      emit(
        current.copyWith(
          bankAccounts: refreshed,
          actionMessage: 'dashboard_account_deleted',
        ),
      );
    } catch (e) {
      emit(
        current.copyWith(
          actionMessage: userFacingError(e, fallback: ErrorKeys.saveFailed),
        ),
      );
    }
  }

  Future<void> _onZeroOutAccount(
    ZeroOutAccountRequested event,
    Emitter<DashboardState> emit,
  ) async {
    if (state is! DashboardLoaded) return;
    final current = state as DashboardLoaded;
    try {
      await _repository.zeroOutAccount(event.id);
      final refreshed = await _repository.getBankAccounts();
      emit(
        current.copyWith(
          bankAccounts: refreshed,
          actionMessage: 'dashboard_account_zeroed',
        ),
      );
    } catch (e) {
      emit(
        current.copyWith(
          actionMessage: userFacingError(e, fallback: ErrorKeys.saveFailed),
        ),
      );
    }
  }

  Future<void> _onRefreshRates(
    RefreshRatesRequested event,
    Emitter<DashboardState> emit,
  ) async {
    if (state is! DashboardLoaded) return;
    final current = state as DashboardLoaded;
    try {
      await _repository.refreshRates();
      final rates = await _repository.getExchangeRates();
      emit(current.copyWith(rates: rates));
    } catch (e) {
      emit(
        current.copyWith(
          actionMessage: userFacingError(e, fallback: ErrorKeys.loadFailed),
        ),
      );
    }
  }

  Future<void> _onSaveOneCLink(
    SaveOneCLinkRequested event,
    Emitter<DashboardState> emit,
  ) async {
    if (state is! DashboardLoaded) return;
    final current = state as DashboardLoaded;
    try {
      await _repository.saveOneCLink(
        OneCLinkInput(
          onecName: event.onecName,
          kind: event.kind,
          targetId: event.targetId,
        ),
      );
      final refreshed = await Future.wait([
        _repository.getOneCReconcile(forceRefresh: true),
        _repository.getOneCTargets(forceRefresh: true),
      ]);
      emit(
        current.copyWith(
          onec: refreshed[0] as OneCReconcileReport,
          onecTargets: refreshed[1] as List<OneCTarget>,
          actionMessage: 'dashboard_onec_link_saved',
        ),
      );
    } catch (e) {
      emit(
        current.copyWith(
          actionMessage: userFacingError(e, fallback: ErrorKeys.saveFailed),
        ),
      );
    }
  }

  Future<void> _onRefreshOneCReconcile(
    RefreshOneCReconcileRequested event,
    Emitter<DashboardState> emit,
  ) async {
    if (state is! DashboardLoaded) return;
    final current = state as DashboardLoaded;
    emit(
      current.copyWith(
        loadingSections: Set<DashboardSection>.from(current.loadingSections)
          ..add(DashboardSection.onec),
      ),
    );
    try {
      final refreshed = await Future.wait([
        _repository.getOneCReconcile(forceRefresh: true, day: event.day),
        _repository.getOneCTargets(forceRefresh: true),
      ]);
      if (state is! DashboardLoaded) return;
      final latest = state as DashboardLoaded;
      emit(
        latest.copyWith(
          onec: refreshed[0] as OneCReconcileReport,
          onecTargets: refreshed[1] as List<OneCTarget>,
          loadingSections: Set<DashboardSection>.from(latest.loadingSections)
            ..remove(DashboardSection.onec),
        ),
      );
    } catch (e) {
      if (state is! DashboardLoaded) return;
      final latest = state as DashboardLoaded;
      emit(
        latest.copyWith(
          loadingSections: Set<DashboardSection>.from(latest.loadingSections)
            ..remove(DashboardSection.onec),
          actionMessage: userFacingError(e, fallback: ErrorKeys.loadFailed),
        ),
      );
    }
  }

  bool _sectionHasData(DashboardLoaded state, DashboardSection section) {
    return switch (section) {
      DashboardSection.pnl => state.pnl != null,
      DashboardSection.planFact => state.planFact != null,
      DashboardSection.breakEven => state.breakEven != null,
      DashboardSection.abc => state.abc != null,
      DashboardSection.accountsRates =>
        state.bankAccounts != null && state.rates != null,
      DashboardSection.clients => state.clients != null,
      DashboardSection.aiInsights => state.aiInsights != null,
      DashboardSection.onec => state.onec != null && state.onecTargets != null,
    };
  }

  bool _sectionLoading(DashboardLoaded state, DashboardSection section) {
    return state.loadingSections.contains(section);
  }

  double _rateFactor(DashboardLoaded state) {
    if (state.currency == 'TJS' || state.rates == null) return 1;
    for (final row in state.rates!.rates) {
      if (row.code == state.currency && row.rate > 0) {
        return 1.0 / row.rate;
      }
    }
    return 1;
  }

  DashboardLoaded _applySectionCurrency(
    DashboardLoaded state,
    DashboardSection section,
  ) {
    final factor = _rateFactor(state);
    if (factor == 1) return state;
    return switch (section) {
      DashboardSection.pnl when state.pnl != null => state.copyWith(
        pnl: _convertPnlWithFactor(state.pnl!, factor),
      ),
      DashboardSection.breakEven when state.breakEven != null => state.copyWith(
        breakEven: _convertBreakEvenWithFactor(state.breakEven!, factor),
      ),
      DashboardSection.abc when state.abc != null => state.copyWith(
        abc: _convertAbcWithFactor(state.abc!, factor),
      ),
      DashboardSection.planFact when state.planFact != null => state.copyWith(
        planFact: _convertPlanFactWithFactor(state.planFact!, factor),
      ),
      _ => state,
    };
  }

  DashboardLoaded _applyLoadedCurrency(DashboardLoaded state) {
    final factor = _rateFactor(state);
    if (factor == 1) return state;
    return state.copyWith(
      pnl: state.pnl == null ? null : _convertPnlWithFactor(state.pnl!, factor),
      breakEven: state.breakEven == null
          ? null
          : _convertBreakEvenWithFactor(state.breakEven!, factor),
      abc: state.abc == null ? null : _convertAbcWithFactor(state.abc!, factor),
      planFact: state.planFact == null
          ? null
          : _convertPlanFactWithFactor(state.planFact!, factor),
    );
  }

  PnlReport _convertPnlWithFactor(PnlReport pnl, double factor) {
    return PnlReport(
      income: pnl.income
          .map(
            (r) => PnlRow(
              category: r.category,
              amount: r.amount * factor,
              share: r.share,
            ),
          )
          .toList(),
      expense: pnl.expense
          .map(
            (r) => PnlRow(
              category: r.category,
              amount: r.amount * factor,
              share: r.share,
            ),
          )
          .toList(),
      totalIncome: pnl.totalIncome * factor,
      totalExpense: pnl.totalExpense * factor,
      profit: pnl.profit * factor,
    );
  }

  BreakEvenAnalysis _convertBreakEvenWithFactor(
    BreakEvenAnalysis report,
    double factor,
  ) {
    return BreakEvenAnalysis(
      revenue: report.revenue * factor,
      fixedCosts: report.fixedCosts * factor,
      variableCosts: report.variableCosts * factor,
      variableRatio: report.variableRatio,
      breakEvenRevenue: report.breakEvenRevenue * factor,
      marginOfSafety: report.marginOfSafety,
    );
  }

  AbcAnalysis _convertAbcWithFactor(AbcAnalysis report, double factor) {
    return AbcAnalysis(
      dimension: report.dimension,
      rows: report.rows
          .map(
            (r) => AbcRow(
              name: r.name,
              turnover: r.turnover * factor,
              share: r.share,
              cumulative: r.cumulative,
              abcClass: r.abcClass,
            ),
          )
          .toList(),
      total: report.total * factor,
    );
  }

  PlanFactReport _convertPlanFactWithFactor(
    PlanFactReport report,
    double factor,
  ) {
    return PlanFactReport(
      period: report.period,
      rows: report.rows
          .map(
            (r) => PlanFactRow(
              category: r.category,
              type: r.type,
              planned: r.planned * factor,
              fact: r.fact * factor,
              deviation: r.deviation * factor,
              completion: r.completion,
            ),
          )
          .toList(),
      totalPlanned: report.totalPlanned * factor,
      totalFact: report.totalFact * factor,
    );
  }

  FinanceMetrics _convertMetricsWithFactor(
    FinanceMetrics metrics,
    double factor,
  ) {
    return FinanceMetrics(
      revenue: metrics.revenue * factor,
      expenses: metrics.expenses * factor,
      netProfit: metrics.netProfit * factor,
      cashBalance: metrics.cashBalance * factor,
      breakEvenPoint: metrics.breakEvenPoint != null
          ? metrics.breakEvenPoint! * factor
          : null,
      cashForecast: metrics.cashForecast != null
          ? metrics.cashForecast! * factor
          : null,
      cashBalanceDelta: metrics.cashBalanceDelta,
      revenueDelta: metrics.revenueDelta,
      expensesDelta: metrics.expensesDelta,
      netProfitDelta: metrics.netProfitDelta,
      cashForecastDelta: metrics.cashForecastDelta,
      operationsCount: metrics.operationsCount,
      avgCheck: metrics.avgCheck * factor,
      period: metrics.period,
    );
  }

  List<CashFlowPoint> _convertHistoryWithFactor(
    List<CashFlowPoint> history,
    double factor,
  ) {
    return history
        .map(
          (point) => CashFlowPoint(
            date: point.date,
            amount: point.amount * factor,
            income: point.income * factor,
            expense: point.expense * factor,
          ),
        )
        .toList();
  }
}
