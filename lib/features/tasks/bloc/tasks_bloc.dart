import 'package:flutter_bloc/flutter_bloc.dart';
import '../domain/task_model.dart';
import '../domain/tasks_repository.dart';
import 'tasks_event.dart';
import 'tasks_state.dart';

class TasksBloc extends Bloc<TasksEvent, TasksState> {
  final TasksRepository _repository;

  final Set<String> _pendingStatusTaskIds = {};

  TasksBloc(this._repository) : super(TasksLoading()) {
    on<LoadTasks>(_onLoadTasks);
    on<UpdateTaskStatusRequested>(_onUpdateTaskStatusRequested);
    on<CreateTaskRequested>(_onCreateTaskRequested);
    on<UpdateTaskRequested>(_onUpdateTaskRequested);
  }

  void _onLoadTasks(LoadTasks event, Emitter<TasksState> emit) async {
    emit(TasksLoading());
    try {
      final results = await Future.wait([
        _repository.getTasks(),
        _repository.getProjects(),
        _repository.getAssignees(),
        _repository.getOverloadedAssignees(),
        _repository.getCriticalPath(),
      ]);
      emit(TasksLoaded(
        tasks: (results[0] as List).cast<Task>(),
        projects: (results[1] as List).cast<TaskProject>(),
        assignees: (results[2] as List).cast<TaskAssignee>(),
        overloaded: (results[3] as List).cast<TaskOverload>(),
        criticalPath: (results[4] as List).cast<TaskCriticalPath>(),
      ));
    } catch (e) {
      emit(TasksError('Не удалось загрузить список задач: ${e.toString()}'));
    }
  }

  void _onUpdateTaskStatusRequested(UpdateTaskStatusRequested event, Emitter<TasksState> emit) async {
    if (state is! TasksLoaded) return;
    if (_pendingStatusTaskIds.contains(event.taskId)) return;

    final currentState = state as TasksLoaded;
    final currentTasks = currentState.tasks;

    final index = currentTasks.indexWhere((t) => t.id == event.taskId);
    if (index == -1) return;
    final originalTask = currentTasks[index];

    _pendingStatusTaskIds.add(event.taskId);

    // Оптимистично меняем статус локально для моментального отклика UI
    final optimisticTasks = currentTasks.map((t) {
      return t.id == event.taskId ? t.copyWith(status: event.status) : t;
    }).toList();

    emit(currentState.copyWith(
      tasks: optimisticTasks,
      pendingStatusTaskIds: Set.from(_pendingStatusTaskIds),
      clearLastResult: true,
    ));

    try {
      final updatedTask = await _repository.updateTaskStatus(event.taskId, event.status);
      
      // Обновляем финальными данными с сервера
      if (state is TasksLoaded) {
        final latestState = state as TasksLoaded;
        final finalTasks = latestState.tasks.map((t) {
          return t.id == event.taskId ? updatedTask : t;
        }).toList();
        emit(latestState.copyWith(
          tasks: finalTasks,
          lastStatusUpdateResult: TaskStatusUpdateResult(
            operationId: DateTime.now().microsecondsSinceEpoch.toString(),
            taskId: event.taskId,
            previousStatus: originalTask.status,
            newStatus: event.status,
          ),
        ));
      }
    } catch (e) {
      // При ошибке возвращаем исходное состояние конкретной задачи
      if (state is TasksLoaded) {
        final latestState = state as TasksLoaded;
        final revertedTasks = latestState.tasks.map((t) {
          return t.id == event.taskId ? originalTask : t;
        }).toList();
        emit(latestState.copyWith(
          tasks: revertedTasks,
          clearLastResult: true,
        ));
      }
    } finally {
      _pendingStatusTaskIds.remove(event.taskId);
      if (state is TasksLoaded) {
        final latestState = state as TasksLoaded;
        emit(latestState.copyWith(
          pendingStatusTaskIds: Set.from(_pendingStatusTaskIds),
        ));
      }
    }
  }

  void _onCreateTaskRequested(CreateTaskRequested event, Emitter<TasksState> emit) async {
    if (state is! TasksLoaded) return;
    final currentState = state as TasksLoaded;
    final currentTasks = currentState.tasks;

    try {
      final created = await _repository.createTask(event.task);
      final updatedList = List<Task>.from(currentTasks)..add(created);
      emit(currentState.copyWith(tasks: updatedList));
    } catch (e) {
      emit(TasksError('Не удалось создать задачу: ${e.toString()}'));
    }
  }

  void _onUpdateTaskRequested(UpdateTaskRequested event, Emitter<TasksState> emit) async {
    if (state is! TasksLoaded) return;
    final currentState = state as TasksLoaded;
    final currentTasks = currentState.tasks;

    final index = currentTasks.indexWhere((t) => t.id == event.task.id);
    if (index == -1) return;
    final originalTask = currentTasks[index];

    final optimisticTasks = currentTasks.map((t) {
      return t.id == event.task.id ? event.task : t;
    }).toList();

    emit(currentState.copyWith(tasks: optimisticTasks));

    try {
      final updatedTask = await _repository.updateTask(event.task);
      if (state is TasksLoaded) {
        final latestState = state as TasksLoaded;
        final finalTasks = latestState.tasks.map((t) {
          return t.id == event.task.id ? updatedTask : t;
        }).toList();
        emit(latestState.copyWith(tasks: finalTasks));
      }
    } catch (e) {
      if (state is TasksLoaded) {
        final latestState = state as TasksLoaded;
        final revertedTasks = latestState.tasks.map((t) {
          return t.id == event.task.id ? originalTask : t;
        }).toList();
        emit(latestState.copyWith(tasks: revertedTasks));
      }
    }
  }
}
