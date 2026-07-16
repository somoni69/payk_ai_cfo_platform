import 'package:equatable/equatable.dart';
import '../domain/task_model.dart';

abstract class TasksEvent extends Equatable {
  const TasksEvent();

  @override
  List<Object?> get props => [];
}

class LoadTasks extends TasksEvent {}

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
