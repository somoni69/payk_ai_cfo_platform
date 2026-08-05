import 'package:equatable/equatable.dart';

abstract class ChecklistsEvent extends Equatable {
  const ChecklistsEvent();

  @override
  List<Object?> get props => [];
}

class LoadChecklists extends ChecklistsEvent {
  final bool forceRefresh;
  const LoadChecklists({this.forceRefresh = false});

  @override
  List<Object?> get props => [forceRefresh];
}

class ToggleEntryRequested extends ChecklistsEvent {
  final String runId;
  final String entryId;
  final bool isDone;

  const ToggleEntryRequested({
    required this.runId,
    required this.entryId,
    required this.isDone,
  });

  @override
  List<Object?> get props => [runId, entryId, isDone];
}

class AddEntryRequested extends ChecklistsEvent {
  final String runId;
  final String text;

  const AddEntryRequested({required this.runId, required this.text});

  @override
  List<Object?> get props => [runId, text];
}

class DeleteEntryRequested extends ChecklistsEvent {
  final String runId;
  final String entryId;

  const DeleteEntryRequested({required this.runId, required this.entryId});

  @override
  List<Object?> get props => [runId, entryId];
}

class CreateTemplateRequested extends ChecklistsEvent {
  final String name;
  final String? description;
  final String? regulationText;
  final List<String> items;

  const CreateTemplateRequested({
    required this.name,
    this.description,
    this.regulationText,
    this.items = const [],
  });

  @override
  List<Object?> get props => [name, description, regulationText, items];
}

class DeleteTemplateRequested extends ChecklistsEvent {
  final String id;

  const DeleteTemplateRequested(this.id);

  @override
  List<Object?> get props => [id];
}
