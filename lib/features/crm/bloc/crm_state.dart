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
  final List<CrmDeal> deals;
  final CrmStatsData stats;
  final String? errorMessage;
  final String? successMessage;

  const CrmLoaded({
    required this.clients,
    required this.deals,
    required this.stats,
    this.errorMessage,
    this.successMessage,
  });

  CrmLoaded copyWith({
    List<CrmClient>? clients,
    List<CrmDeal>? deals,
    CrmStatsData? stats,
    String? errorMessage,
    String? successMessage,
    bool clearError = false,
    bool clearSuccess = false,
  }) {
    return CrmLoaded(
      clients: clients ?? this.clients,
      deals: deals ?? this.deals,
      stats: stats ?? this.stats,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      successMessage: clearSuccess ? null : (successMessage ?? this.successMessage),
    );
  }

  @override
  List<Object?> get props => [
        clients,
        deals,
        stats,
        errorMessage,
        successMessage,
      ];
}

class CrmError extends CrmState {
  final String message;

  const CrmError(this.message);

  @override
  List<Object?> get props => [message];
}
