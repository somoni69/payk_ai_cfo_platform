import 'package:equatable/equatable.dart';
import '../domain/legal_models.dart';

abstract class LegalState extends Equatable {
  const LegalState();

  @override
  List<Object?> get props => [];
}

class LegalLoading extends LegalState {}

class LegalLoaded extends LegalState {
  final List<ContractTemplate> templates;
  final List<Law> laws;
  final List<LegalDeadline> deadlines;
  final List<Map<String, String>>
  chatHistory; // sender: 'user'/'ai', text: '...'
  final bool isAskingAi;
  final bool isGenerating;
  final bool isMutating;
  final GeneratedContract? generatedContract;
  final String? errorMessage;
  final String? successMessage;

  const LegalLoaded({
    required this.templates,
    required this.laws,
    required this.deadlines,
    required this.chatHistory,
    this.isAskingAi = false,
    this.isGenerating = false,
    this.isMutating = false,
    this.generatedContract,
    this.errorMessage,
    this.successMessage,
  });

  LegalLoaded copyWith({
    List<ContractTemplate>? templates,
    List<Law>? laws,
    List<LegalDeadline>? deadlines,
    List<Map<String, String>>? chatHistory,
    bool? isAskingAi,
    bool? isGenerating,
    bool? isMutating,
    GeneratedContract? generatedContract,
    String? errorMessage,
    String? successMessage,
    bool clearGeneratedContract = false,
    bool clearError = false,
    bool clearSuccess = false,
  }) {
    return LegalLoaded(
      templates: templates ?? this.templates,
      laws: laws ?? this.laws,
      deadlines: deadlines ?? this.deadlines,
      chatHistory: chatHistory ?? this.chatHistory,
      isAskingAi: isAskingAi ?? this.isAskingAi,
      isGenerating: isGenerating ?? this.isGenerating,
      isMutating: isMutating ?? this.isMutating,
      generatedContract: clearGeneratedContract
          ? null
          : (generatedContract ?? this.generatedContract),
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      successMessage: clearSuccess
          ? null
          : (successMessage ?? this.successMessage),
    );
  }

  @override
  List<Object?> get props => [
    templates,
    laws,
    deadlines,
    chatHistory,
    isAskingAi,
    isGenerating,
    isMutating,
    generatedContract,
    errorMessage,
    successMessage,
  ];
}

class LegalError extends LegalState {
  final String message;

  const LegalError(this.message);

  @override
  List<Object?> get props => [message];
}
