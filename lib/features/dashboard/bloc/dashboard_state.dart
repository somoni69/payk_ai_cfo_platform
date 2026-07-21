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
  final Set<DashboardSection> loadingSections;
  final Map<DashboardSection, String> sectionErrors;
  final String? overviewError;

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
    this.loadingSections = const {},
    this.sectionErrors = const {},
    this.overviewError,
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
    Set<DashboardSection>? loadingSections,
    Map<DashboardSection, String>? sectionErrors,
    String? overviewError,
    bool clearOverviewError = false,
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
      loadingSections: loadingSections ?? this.loadingSections,
      sectionErrors: sectionErrors ?? this.sectionErrors,
      overviewError: clearOverviewError
          ? null
          : (overviewError ?? this.overviewError),
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
    loadingSections,
    sectionErrors,
    overviewError,
  ];
}

class DashboardError extends DashboardState {
  final String message;

  const DashboardError(this.message);

  @override
  List<Object?> get props => [message];
}
