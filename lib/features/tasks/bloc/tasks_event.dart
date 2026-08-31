import 'dart:async';

import 'package:equatable/equatable.dart';
import '../domain/task_model.dart';

abstract class TasksEvent extends Equatable {
  const TasksEvent();

  @override
  List<Object?> get props => [];
}

class LoadTasks extends TasksEvent {
  final bool forceRefresh;
  final Completer<void>? completion;

  const LoadTasks({this.forceRefresh = false, this.completion});

  @override
  List<Object?> get props => [forceRefresh];
}

class LoadTaskAnalytics extends TasksEvent {
  final bool forceRefresh;
  final Completer<void>? completion;

  const LoadTaskAnalytics({this.forceRefresh = false, this.completion});

  @override
  List<Object?> get props => [forceRefresh];
}

class UpdateTaskStatusRequested extends TasksEvent {
  final String taskId;
  final TaskStatus status;

  const UpdateTaskStatusRequested({required this.taskId, required this.status});

  @override
  List<Object?> get props => [taskId, status];
}

class CreateTaskRequested extends TasksEvent {
  final Task task;

  const CreateTaskRequested(this.task);

  @override
  List<Object?> get props => [task];
}

class UpdateTaskRequested extends TasksEvent {
  final Task task;

  const UpdateTaskRequested(this.task);

  @override
  List<Object?> get props => [task];
}

class LoadMyTasks extends TasksEvent {
  final bool forceRefresh;
  final Completer<void>? completion;

  const LoadMyTasks({this.forceRefresh = false, this.completion});

  @override
  List<Object?> get props => [forceRefresh];
}

class CreatePersonalTaskRequested extends TasksEvent {
  final PersonalTaskInput input;

  const CreatePersonalTaskRequested(this.input);

  @override
  List<Object?> get props => [input];
}

class UpdatePersonalTaskRequested extends TasksEvent {
  final String taskId;
  final PersonalTaskInput input;

  const UpdatePersonalTaskRequested({
    required this.taskId,
    required this.input,
  });

  @override
  List<Object?> get props => [taskId, input];
}

class DeleteTaskRequested extends TasksEvent {
  final String taskId;

  const DeleteTaskRequested(this.taskId);

  @override
  List<Object?> get props => [taskId];
}

class DeletePersonalTaskRequested extends TasksEvent {
  final String taskId;

  const DeletePersonalTaskRequested(this.taskId);

  @override
  List<Object?> get props => [taskId];
}

class AcknowledgeTaskRequested extends TasksEvent {
  final String taskId;

  const AcknowledgeTaskRequested(this.taskId);

  @override
  List<Object?> get props => [taskId];
}

class SubmitTaskRequested extends TasksEvent {
  final String taskId;

  const SubmitTaskRequested(this.taskId);

  @override
  List<Object?> get props => [taskId];
}

class AcceptTaskRequested extends TasksEvent {
  final String taskId;

  const AcceptTaskRequested(this.taskId);

  @override
  List<Object?> get props => [taskId];
}

class RejectTaskRequested extends TasksEvent {
  final String taskId;
  final String? reason;

  const RejectTaskRequested({required this.taskId, this.reason});

  @override
  List<Object?> get props => [taskId, reason];
}

class CreateProjectRequested extends TasksEvent {
  final String name;
  final String? description;

  const CreateProjectRequested({required this.name, this.description});

  @override
  List<Object?> get props => [name, description];
}

class UpdateProjectRequested extends TasksEvent {
  final String projectId;
  final String name;
  final String? description;

  const UpdateProjectRequested({
    required this.projectId,
    required this.name,
    this.description,
  });

  @override
  List<Object?> get props => [projectId, name, description];
}

class DeleteProjectRequested extends TasksEvent {
  final String projectId;

  const DeleteProjectRequested(this.projectId);

  @override
  List<Object?> get props => [projectId];
}
