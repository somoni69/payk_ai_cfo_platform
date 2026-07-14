import 'package:equatable/equatable.dart';
import '../domain/task_model.dart';

abstract class TasksState extends Equatable {
  const TasksState();

  @override
  List<Object?> get props => [];
}

class TasksLoading extends TasksState {}

class TasksLoaded extends TasksState {
  final List<Task> tasks;
  final List<TaskOverload> overloaded;
  final List<TaskCriticalPath> criticalPath;

  const TasksLoaded({
    required this.tasks,
    this.overloaded = const [],
    this.criticalPath = const [],
  });

  @override
  List<Object?> get props => [tasks, overloaded, criticalPath];
}

class TasksError extends TasksState {
  final String message;

  const TasksError(this.message);

  @override
  List<Object?> get props => [message];
}
