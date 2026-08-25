import 'package:equatable/equatable.dart';
import '../domain/integrations_models.dart';

class IntegrationsState extends Equatable {
  final List<IntegrationInfo> integrations;
  final List<SyncLog> logs;
  final bool isLoading;
  final bool isSyncing;
  final String? syncMessage;
  final String? errorMessage;
  final bool isTestingSms;
  final SmsTestResult? smsResult;
  final bool isTestingAi;
  final AiProbeResult? aiResult;
  final bool isLoadingTelegramLink;
  final TelegramLinkInfo? telegramLink;

  const IntegrationsState({
    this.integrations = const [],
    this.logs = const [],
    this.isLoading = false,
    this.isSyncing = false,
    this.syncMessage,
    this.errorMessage,
    this.isTestingSms = false,
    this.smsResult,
    this.isTestingAi = false,
    this.aiResult,
    this.isLoadingTelegramLink = false,
    this.telegramLink,
  });

  IntegrationsState copyWith({
    List<IntegrationInfo>? integrations,
    List<SyncLog>? logs,
    bool? isLoading,
    bool? isSyncing,
    String? syncMessage,
    String? errorMessage,
    bool? isTestingSms,
    SmsTestResult? smsResult,
    bool? isTestingAi,
    AiProbeResult? aiResult,
    bool? isLoadingTelegramLink,
    TelegramLinkInfo? telegramLink,
    bool clearSyncMessage = false,
    bool clearError = false,
    bool clearSmsResult = false,
    bool clearAiResult = false,
  }) {
    return IntegrationsState(
      integrations: integrations ?? this.integrations,
      logs: logs ?? this.logs,
      isLoading: isLoading ?? this.isLoading,
      isSyncing: isSyncing ?? this.isSyncing,
      syncMessage: clearSyncMessage ? null : (syncMessage ?? this.syncMessage),
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      isTestingSms: isTestingSms ?? this.isTestingSms,
      smsResult: clearSmsResult ? null : (smsResult ?? this.smsResult),
      isTestingAi: isTestingAi ?? this.isTestingAi,
      aiResult: clearAiResult ? null : (aiResult ?? this.aiResult),
      isLoadingTelegramLink:
          isLoadingTelegramLink ?? this.isLoadingTelegramLink,
      telegramLink: telegramLink ?? this.telegramLink,
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
    isTestingSms,
    smsResult,
    isTestingAi,
    aiResult,
    isLoadingTelegramLink,
    telegramLink,
  ];
}
