import 'package:equatable/equatable.dart';
import '../domain/assistant_models.dart';

class AssistantState extends Equatable {
  final Map<String, AdviceResponse> adviceByModule;
  final Map<String, List<AssistantMessage>> historyByModule;
  final bool isLoading;
  final bool isGeneratingAdvice;
  final bool isSendingMessage;
  final String? error;

  const AssistantState({
    this.adviceByModule = const {},
    this.historyByModule = const {},
    this.isLoading = false,
    this.isGeneratingAdvice = false,
    this.isSendingMessage = false,
    this.error,
  });

  static const initial = AssistantState();

  AdviceResponse? adviceFor(String module) => adviceByModule[module];
  List<AssistantMessage> historyFor(String module) =>
      historyByModule[module] ?? const [];

  AssistantState copyWith({
    Map<String, AdviceResponse>? adviceByModule,
    Map<String, List<AssistantMessage>>? historyByModule,
    bool? isLoading,
    bool? isGeneratingAdvice,
    bool? isSendingMessage,
    String? error,
    bool clearError = false,
  }) {
    return AssistantState(
      adviceByModule: adviceByModule ?? this.adviceByModule,
      historyByModule: historyByModule ?? this.historyByModule,
      isLoading: isLoading ?? this.isLoading,
      isGeneratingAdvice: isGeneratingAdvice ?? this.isGeneratingAdvice,
      isSendingMessage: isSendingMessage ?? this.isSendingMessage,
      error: clearError ? null : (error ?? this.error),
    );
  }

  @override
  List<Object?> get props => [
    adviceByModule,
    historyByModule,
    isLoading,
    isGeneratingAdvice,
    isSendingMessage,
    error,
  ];
}
