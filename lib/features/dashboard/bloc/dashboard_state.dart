import 'package:equatable/equatable.dart';
import '../domain/finance_model.dart';
import 'dashboard_event.dart';

abstract class DashboardState extends Equatable {
  const DashboardState();

  @override
  List<Object?> get props => [];
}

class DashboardLoading extends DashboardState {}

class DashboardLoaded extends DashboardState {
  final FinanceMetrics metrics;
  final List<CashFlowPoint> history;
  final String currency;
  final PnlReport? pnl;
  final BreakEvenAnalysis? breakEven;
  final AbcAnalysis? abc;
  final BankAccountsReport? bankAccounts;
  final ExchangeRatesReport? rates;
  final AiInsightsReport? aiInsights;
  final PlanFactReport? planFact;
  final ClientAnalysisReport? clients;
  final OneCReconcileReport? onec;
  final List<OneCTarget>? onecTargets;
  final Set<DashboardSection> loadingSections;
  final Map<DashboardSection, String> sectionErrors;
  final String? overviewError;
  final String? actionMessage;
  final DateTime? reportDateFrom;
  final DateTime? reportDateTo;
  final String? planPeriod;

  const DashboardLoaded({
    required this.metrics,
    required this.history,
    required this.currency,
    this.pnl,
    this.breakEven,
    this.abc,
    this.bankAccounts,
    this.rates,
    this.aiInsights,
    this.planFact,
    this.clients,
    this.onec,
    this.onecTargets,
    this.loadingSections = const {},
    this.sectionErrors = const {},
    this.overviewError,
    this.actionMessage,
    this.reportDateFrom,
    this.reportDateTo,
    this.planPeriod,
  });

  DashboardLoaded copyWith({
    FinanceMetrics? metrics,
    List<CashFlowPoint>? history,
    String? currency,
    PnlReport? pnl,
    BreakEvenAnalysis? breakEven,
    AbcAnalysis? abc,
    BankAccountsReport? bankAccounts,
    ExchangeRatesReport? rates,
    AiInsightsReport? aiInsights,
    PlanFactReport? planFact,
    ClientAnalysisReport? clients,
    OneCReconcileReport? onec,
    List<OneCTarget>? onecTargets,
    Set<DashboardSection>? loadingSections,
    Map<DashboardSection, String>? sectionErrors,
    String? overviewError,
    bool clearOverviewError = false,
    String? actionMessage,
    bool clearActionMessage = false,
    DateTime? reportDateFrom,
    DateTime? reportDateTo,
    String? planPeriod,
    bool clearReportDates = false,
  }) {
    return DashboardLoaded(
      metrics: metrics ?? this.metrics,
      history: history ?? this.history,
      currency: currency ?? this.currency,
      pnl: pnl ?? this.pnl,
      breakEven: breakEven ?? this.breakEven,
      abc: abc ?? this.abc,
      bankAccounts: bankAccounts ?? this.bankAccounts,
      rates: rates ?? this.rates,
      aiInsights: aiInsights ?? this.aiInsights,
      planFact: planFact ?? this.planFact,
      clients: clients ?? this.clients,
      onec: onec ?? this.onec,
      onecTargets: onecTargets ?? this.onecTargets,
      loadingSections: loadingSections ?? this.loadingSections,
      sectionErrors: sectionErrors ?? this.sectionErrors,
      overviewError: clearOverviewError
          ? null
          : (overviewError ?? this.overviewError),
      actionMessage: clearActionMessage
          ? null
          : (actionMessage ?? this.actionMessage),
      reportDateFrom: clearReportDates
          ? reportDateFrom
          : (reportDateFrom ?? this.reportDateFrom),
      reportDateTo: clearReportDates
          ? reportDateTo
          : (reportDateTo ?? this.reportDateTo),
      planPeriod: planPeriod ?? this.planPeriod,
    );
  }

  @override
  List<Object?> get props => [
    metrics,
    history,
    currency,
    pnl,
    breakEven,
    abc,
    bankAccounts,
    rates,
    aiInsights,
    planFact,
    clients,
    onec,
    onecTargets,
    loadingSections,
    sectionErrors,
    overviewError,
    actionMessage,
    reportDateFrom,
    reportDateTo,
    planPeriod,
  ];
}

class DashboardError extends DashboardState {
  final String message;

  const DashboardError(this.message);

  @override
  List<Object?> get props => [message];
}
