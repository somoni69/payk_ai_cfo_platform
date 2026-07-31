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

class CreateChecklistRunRequested extends ChecklistsEvent {
  final String title;
  final String branchName;
  final String responsiblePerson;
  final List<String> items;

  const CreateChecklistRunRequested({
    required this.title,
    required this.branchName,
    required this.responsiblePerson,
    required this.items,
  });

  @override
  List<Object?> get props => [title, branchName, responsiblePerson, items];
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
