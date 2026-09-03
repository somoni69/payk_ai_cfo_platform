import 'package:equatable/equatable.dart';
import '../domain/network_models.dart';
import 'network_event.dart';

abstract class NetworkState extends Equatable {
  const NetworkState();

  @override
  List<Object?> get props => [];
}

class NetworkLoading extends NetworkState {
  const NetworkLoading();
}

class NetworkLoaded extends NetworkState {
  final List<NetworkStore> stores;
  final List<StoreSummaryRow> summary;
  final NetworkPeriod period;
  final ActingStore? actingStore;
  final String? actionMessage;
  final bool isSubmitting;
  final bool isSummaryLoading;

  const NetworkLoaded({
    required this.stores,
    required this.summary,
    this.period = NetworkPeriod.month,
    this.actingStore,
    this.actionMessage,
    this.isSubmitting = false,
    this.isSummaryLoading = false,
  });

  double get totalRevenue => summary.fold(0.0, (sum, row) => sum + row.revenue);

  double get totalExpenses =>
      summary.fold(0.0, (sum, row) => sum + row.expenses);

  double get totalProfit => summary.fold(0.0, (sum, row) => sum + row.profit);

  int get totalOperations =>
      summary.fold(0, (sum, row) => sum + row.operationsCount);

  NetworkLoaded copyWith({
    List<NetworkStore>? stores,
    List<StoreSummaryRow>? summary,
    NetworkPeriod? period,
    ActingStore? Function()? actingStore,
    String? Function()? actionMessage,
    bool? isSubmitting,
    bool? isSummaryLoading,
  }) {
    return NetworkLoaded(
      stores: stores ?? this.stores,
      summary: summary ?? this.summary,
      period: period ?? this.period,
      actingStore: actingStore != null ? actingStore() : this.actingStore,
      actionMessage: actionMessage != null
          ? actionMessage()
          : this.actionMessage,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      isSummaryLoading: isSummaryLoading ?? this.isSummaryLoading,
    );
  }

  @override
  List<Object?> get props => [
    stores,
    summary,
    period,
    actingStore,
    actionMessage,
    isSubmitting,
    isSummaryLoading,
  ];
}

class NetworkError extends NetworkState {
  final String message;

  const NetworkError(this.message);

  @override
  List<Object?> get props => [message];
}
