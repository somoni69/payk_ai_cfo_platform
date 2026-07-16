import 'package:equatable/equatable.dart';
import '../domain/task_model.dart';

abstract class TasksState extends Equatable {
  const TasksState();

  @override
  List<Object?> get props => [];
}

class TasksLoading extends TasksState {}

class TaskStatusUpdateResult extends Equatable {
  final String operationId;
  final String taskId;
  final TaskStatus previousStatus;
  final TaskStatus newStatus;

  const TaskStatusUpdateResult({
    required this.operationId,
    required this.taskId,
    required this.previousStatus,
    required this.newStatus,
  });

  @override
  List<Object?> get props => [operationId, taskId, previousStatus, newStatus];
}

class TasksLoaded extends TasksState {
  final List<Task> tasks;
  final List<TaskProject> projects;
  final List<TaskAssignee> assignees;
  final List<TaskOverload> overloaded;
  final List<TaskCriticalPath> criticalPath;
  final Set<String> pendingStatusTaskIds;
  final TaskStatusUpdateResult? lastStatusUpdateResult;

  const TasksLoaded({
    required this.tasks,
    this.projects = const [],
    this.assignees = const [],
    this.overloaded = const [],
    this.criticalPath = const [],
    this.pendingStatusTaskIds = const {},
    this.lastStatusUpdateResult,
  });

  TasksLoaded copyWith({
    List<Task>? tasks,
    List<TaskProject>? projects,
    List<TaskAssignee>? assignees,
    List<TaskOverload>? overloaded,
    List<TaskCriticalPath>? criticalPath,
    Set<String>? pendingStatusTaskIds,
    TaskStatusUpdateResult? lastStatusUpdateResult,
    bool clearLastResult = false,
  }) {
    return TasksLoaded(
      tasks: tasks ?? this.tasks,
      projects: projects ?? this.projects,
      assignees: assignees ?? this.assignees,
      overloaded: overloaded ?? this.overloaded,
      criticalPath: criticalPath ?? this.criticalPath,
      pendingStatusTaskIds: pendingStatusTaskIds ?? this.pendingStatusTaskIds,
      lastStatusUpdateResult: clearLastResult ? null : (lastStatusUpdateResult ?? this.lastStatusUpdateResult),
    );
  }

  @override
  List<Object?> get props => [
        tasks,
        projects,
        assignees,
        overloaded,
        criticalPath,
        pendingStatusTaskIds,
        lastStatusUpdateResult,
      ];
}

class TasksError extends TasksState {
  final String message;

  const TasksError(this.message);

  @override
  List<Object?> get props => [message];
}
