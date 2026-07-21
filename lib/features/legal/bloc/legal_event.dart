import 'dart:async';

import 'package:equatable/equatable.dart';

abstract class LegalEvent extends Equatable {
  const LegalEvent();

  @override
  List<Object?> get props => [];
}

class LoadLegalData extends LegalEvent {
  final bool forceRefresh;
  final Completer<void>? completion;

  const LoadLegalData({this.forceRefresh = false, this.completion});

  @override
  List<Object?> get props => [forceRefresh];
}

class ToggleDeadlineStatus extends LegalEvent {
  final String id;
  final bool isDone;

  const ToggleDeadlineStatus({required this.id, required this.isDone});

  @override
  List<Object?> get props => [id, isDone];
}

class AskLawyerQuestion extends LegalEvent {
  final String question;

  const AskLawyerQuestion(this.question);

  @override
  List<Object?> get props => [question];
}

class ClearLawyerHistory extends LegalEvent {}

class ClearGeneratedContract extends LegalEvent {
  const ClearGeneratedContract();
}

class GenerateContractFromTemplate extends LegalEvent {
  final String templateId;
  final Map<String, String> variables;

  const GenerateContractFromTemplate({
    required this.templateId,
    required this.variables,
  });

  @override
  List<Object?> get props => [templateId, variables];
}
