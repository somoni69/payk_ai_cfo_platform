import 'package:equatable/equatable.dart';
import '../domain/integrations_models.dart';

class IntegrationsState extends Equatable {
  final List<IntegrationInfo> integrations;
  final List<SyncLog> logs;
  final bool isLoading;
  final bool isSyncing;
  final String? syncMessage;
  final String? errorMessage;

  const IntegrationsState({
    this.integrations = const [],
    this.logs = const [],
    this.isLoading = false,
    this.isSyncing = false,
    this.syncMessage,
    this.errorMessage,
  });

  IntegrationsState copyWith({
    List<IntegrationInfo>? integrations,
    List<SyncLog>? logs,
    bool? isLoading,
    bool? isSyncing,
    String? syncMessage,
    String? errorMessage,
    bool clearSyncMessage = false,
    bool clearError = false,
  }) {
    return IntegrationsState(
      integrations: integrations ?? this.integrations,
      logs: logs ?? this.logs,
      isLoading: isLoading ?? this.isLoading,
      isSyncing: isSyncing ?? this.isSyncing,
      syncMessage: clearSyncMessage ? null : (syncMessage ?? this.syncMessage),
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }

  @override
  List<Object?> get props => [
        integrations,
        logs,
        isLoading,
        isSyncing,
        syncMessage,
        errorMessage,
      ];
}
