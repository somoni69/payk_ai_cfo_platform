import 'package:equatable/equatable.dart';
import '../domain/crm_models.dart';

abstract class CrmState extends Equatable {
  const CrmState();

  @override
  List<Object?> get props => [];
}

class CrmLoading extends CrmState {}

class CrmLoaded extends CrmState {
  final List<CrmClient> clients;
  final int clientsTotal;
  final int clientsPage;
  final int clientsSize;
  final ClientListFilters clientFilters;
  final List<CrmDeal> deals;
  final CrmStatsData stats;
  final List<LoyaltySummaryRow> loyaltySummary;
  final List<CrmClient> reactivation;
  final List<CrmClient> churn;
  final List<BirthdayRow> birthdays;

  /// Unfiltered pool for pickers (bonus / deal client), up to 200.
  final List<CrmClient> pickClients;

  /// Global loyalty journal on Loyalty tab.
  final List<LoyaltyTxn> loyaltyTxns;
  final String? loyaltyFilterClientId;
  final bool loyaltyTxnsLoading;
  final int loyaltyTxnPage;
  final int loyaltyTxnTotal;
  final bool loyaltyTxnsLoadingMore;

  /// Open client card payload.
  final CrmClient? detailClient;
  final List<CrmDeal> detailDeals;
  final List<LoyaltyTxn> detailLoyalty;
  final bool detailLoading;
  final ChurnAdvice? churnAdvice;
  final bool churnAnalyzing;

  final String? errorMessage;
  final String? successMessage;
  final bool isRefreshing;

  const CrmLoaded({
    required this.clients,
    required this.clientsTotal,
    required this.clientsPage,
    required this.clientsSize,
    required this.clientFilters,
    required this.deals,
    required this.stats,
    required this.loyaltySummary,
    required this.reactivation,
    required this.churn,
    required this.birthdays,
    this.pickClients = const [],
    this.loyaltyTxns = const [],
    this.loyaltyFilterClientId,
    this.loyaltyTxnsLoading = false,
    this.loyaltyTxnPage = 1,
    this.loyaltyTxnTotal = 0,
    this.loyaltyTxnsLoadingMore = false,
    this.detailClient,
    this.detailDeals = const [],
    this.detailLoyalty = const [],
    this.detailLoading = false,
    this.churnAdvice,
    this.churnAnalyzing = false,
    this.errorMessage,
    this.successMessage,
    this.isRefreshing = false,
  });

  CrmLoaded copyWith({
    List<CrmClient>? clients,
    int? clientsTotal,
    int? clientsPage,
    int? clientsSize,
    ClientListFilters? clientFilters,
    List<CrmDeal>? deals,
    CrmStatsData? stats,
    List<LoyaltySummaryRow>? loyaltySummary,
    List<CrmClient>? reactivation,
    List<CrmClient>? churn,
    List<BirthdayRow>? birthdays,
    List<CrmClient>? pickClients,
    List<LoyaltyTxn>? loyaltyTxns,
    String? loyaltyFilterClientId,
    bool? loyaltyTxnsLoading,
    int? loyaltyTxnPage,
    int? loyaltyTxnTotal,
    bool? loyaltyTxnsLoadingMore,
    CrmClient? detailClient,
    List<CrmDeal>? detailDeals,
    List<LoyaltyTxn>? detailLoyalty,
    bool? detailLoading,
    ChurnAdvice? churnAdvice,
    bool? churnAnalyzing,
    String? errorMessage,
    String? successMessage,
    bool? isRefreshing,
    bool clearError = false,
    bool clearSuccess = false,
    bool clearDetail = false,
    bool clearChurnAdvice = false,
    bool clearLoyaltyFilter = false,
  }) {
    return CrmLoaded(
      clients: clients ?? this.clients,
      clientsTotal: clientsTotal ?? this.clientsTotal,
      clientsPage: clientsPage ?? this.clientsPage,
      clientsSize: clientsSize ?? this.clientsSize,
      clientFilters: clientFilters ?? this.clientFilters,
      deals: deals ?? this.deals,
      stats: stats ?? this.stats,
      loyaltySummary: loyaltySummary ?? this.loyaltySummary,
      reactivation: reactivation ?? this.reactivation,
      churn: churn ?? this.churn,
      birthdays: birthdays ?? this.birthdays,
      pickClients: pickClients ?? this.pickClients,
      loyaltyTxns: loyaltyTxns ?? this.loyaltyTxns,
      loyaltyFilterClientId: clearLoyaltyFilter
          ? null
          : (loyaltyFilterClientId ?? this.loyaltyFilterClientId),
      loyaltyTxnsLoading: loyaltyTxnsLoading ?? this.loyaltyTxnsLoading,
      loyaltyTxnPage: loyaltyTxnPage ?? this.loyaltyTxnPage,
      loyaltyTxnTotal: loyaltyTxnTotal ?? this.loyaltyTxnTotal,
      loyaltyTxnsLoadingMore:
          loyaltyTxnsLoadingMore ?? this.loyaltyTxnsLoadingMore,
      detailClient: clearDetail ? null : (detailClient ?? this.detailClient),
      detailDeals: clearDetail ? const [] : (detailDeals ?? this.detailDeals),
      detailLoyalty: clearDetail
          ? const []
          : (detailLoyalty ?? this.detailLoyalty),
      detailLoading: detailLoading ?? this.detailLoading,
      churnAdvice: clearChurnAdvice ? null : (churnAdvice ?? this.churnAdvice),
      churnAnalyzing: churnAnalyzing ?? this.churnAnalyzing,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      successMessage: clearSuccess
          ? null
          : (successMessage ?? this.successMessage),
      isRefreshing: isRefreshing ?? this.isRefreshing,
    );
  }

  @override
  List<Object?> get props => [
    clients,
    clientsTotal,
    clientsPage,
    clientsSize,
    clientFilters.query,
    clientFilters.level,
    clientFilters.page,
    deals,
    stats,
    loyaltySummary,
    reactivation,
    churn,
    birthdays,
    pickClients,
    loyaltyTxns,
    loyaltyFilterClientId,
    loyaltyTxnsLoading,
    loyaltyTxnPage,
    loyaltyTxnTotal,
    loyaltyTxnsLoadingMore,
    detailClient,
    detailDeals,
    detailLoyalty,
    detailLoading,
    churnAdvice,
    churnAnalyzing,
    errorMessage,
    successMessage,
    isRefreshing,
  ];
}

class CrmError extends CrmState {
  final String message;

  const CrmError(this.message);

  @override
  List<Object?> get props => [message];
}
