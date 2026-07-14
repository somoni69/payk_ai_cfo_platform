import 'package:equatable/equatable.dart';
import '../domain/finance_model.dart';

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
      ];
}

class DashboardError extends DashboardState {
  final String message;

  const DashboardError(this.message);

  @override
  List<Object?> get props => [message];
}
