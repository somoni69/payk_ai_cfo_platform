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

class CreateLawRequested extends LegalEvent {
  final String title;
  final String body;
  final String? category;

  const CreateLawRequested({
    required this.title,
    required this.body,
    this.category,
  });

  @override
  List<Object?> get props => [title, body, category];
}

class DeleteLawRequested extends LegalEvent {
  final String id;

  const DeleteLawRequested(this.id);

  @override
  List<Object?> get props => [id];
}

class CreateDeadlineRequested extends LegalEvent {
  final String title;
  final String type;
  final DateTime dueDate;
  final String? amount;
  final String? note;

  const CreateDeadlineRequested({
    required this.title,
    required this.type,
    required this.dueDate,
    this.amount,
    this.note,
  });

  @override
  List<Object?> get props => [title, type, dueDate, amount, note];
}

class CreateTemplateRequested extends LegalEvent {
  final String name;
  final String body;
  final String? category;

  const CreateTemplateRequested({
    required this.name,
    required this.body,
    this.category,
  });

  @override
  List<Object?> get props => [name, body, category];
}
