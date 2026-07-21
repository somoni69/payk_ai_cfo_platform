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
  final GeneratedContract? generatedContract;
  final String? errorMessage;

  const LegalLoaded({
    required this.templates,
    required this.laws,
    required this.deadlines,
    required this.chatHistory,
    this.isAskingAi = false,
    this.isGenerating = false,
    this.generatedContract,
    this.errorMessage,
  });

  LegalLoaded copyWith({
    List<ContractTemplate>? templates,
    List<Law>? laws,
    List<LegalDeadline>? deadlines,
    List<Map<String, String>>? chatHistory,
    bool? isAskingAi,
    bool? isGenerating,
    GeneratedContract? generatedContract,
    String? errorMessage,
    bool clearGeneratedContract = false,
  }) {
    return LegalLoaded(
      templates: templates ?? this.templates,
      laws: laws ?? this.laws,
      deadlines: deadlines ?? this.deadlines,
      chatHistory: chatHistory ?? this.chatHistory,
      isAskingAi: isAskingAi ?? this.isAskingAi,
      isGenerating: isGenerating ?? this.isGenerating,
      generatedContract: clearGeneratedContract
          ? null
          : (generatedContract ?? this.generatedContract),
      errorMessage: errorMessage, // We reset error on update usually
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
    generatedContract,
    errorMessage,
  ];
}

class LegalError extends LegalState {
  final String message;

  const LegalError(this.message);

  @override
  List<Object?> get props => [message];
}
