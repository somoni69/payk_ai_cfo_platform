import 'package:flutter_bloc/flutter_bloc.dart';
import '../domain/task_model.dart';
import '../domain/tasks_repository.dart';
import 'tasks_event.dart';
import 'tasks_state.dart';

class TasksBloc extends Bloc<TasksEvent, TasksState> {
  final TasksRepository _repository;

  TasksBloc(this._repository) : super(TasksLoading()) {
    on<LoadTasks>(_onLoadTasks);
    on<UpdateTaskStatusRequested>(_onUpdateTaskStatusRequested);
    on<CreateTaskRequested>(_onCreateTaskRequested);
  }

  void _onLoadTasks(LoadTasks event, Emitter<TasksState> emit) async {
    emit(TasksLoading());
    try {
      final results = await Future.wait([
        _repository.getTasks(),
        _repository.getOverloadedAssignees(),
        _repository.getCriticalPath(),
      ]);
      emit(TasksLoaded(
        tasks: results[0] as List<Task>,
        overloaded: results[1] as List<TaskOverload>,
        criticalPath: results[2] as List<TaskCriticalPath>,
      ));
    } catch (e) {
      emit(TasksError('Не удалось загрузить список задач: ${e.toString()}'));
    }
  }

  void _onUpdateTaskStatusRequested(UpdateTaskStatusRequested event, Emitter<TasksState> emit) async {
    if (state is! TasksLoaded) return;
    final currentState = state as TasksLoaded;
    final currentTasks = currentState.tasks;
    final originalOverloaded = currentState.overloaded;
    final originalCritical = currentState.criticalPath;

    final index = currentTasks.indexWhere((t) => t.id == event.taskId);
    if (index == -1) return;
    final originalTask = currentTasks[index];

    // Оптимистично меняем статус локально для моментального отклика UI
    final optimisticTasks = currentTasks.map((t) {
      return t.id == event.taskId ? t.copyWith(status: event.status) : t;
    }).toList();

    emit(TasksLoaded(
      tasks: optimisticTasks,
      overloaded: originalOverloaded,
      criticalPath: originalCritical,
    ));

    try {
      final updatedTask = await _repository.updateTaskStatus(event.taskId, event.status);
      
      // Обновляем финальными данными с сервера
      if (state is TasksLoaded) {
        final currentLoaded = (state as TasksLoaded).tasks;
        final finalTasks = currentLoaded.map((t) {
          return t.id == event.taskId ? updatedTask : t;
        }).toList();
        emit(TasksLoaded(
          tasks: finalTasks,
          overloaded: originalOverloaded,
          criticalPath: originalCritical,
        ));
      }
    } catch (e) {
      // При ошибке возвращаем исходное состояние конкретной задачи
      if (state is TasksLoaded) {
        final currentLoaded = (state as TasksLoaded).tasks;
        final revertedTasks = currentLoaded.map((t) {
          return t.id == event.taskId ? originalTask : t;
        }).toList();
        emit(TasksLoaded(
          tasks: revertedTasks,
          overloaded: originalOverloaded,
          criticalPath: originalCritical,
        ));
      }
    }
  }

  void _onCreateTaskRequested(CreateTaskRequested event, Emitter<TasksState> emit) async {
    if (state is! TasksLoaded) return;
    final currentState = state as TasksLoaded;
    final currentTasks = currentState.tasks;
    final originalOverloaded = currentState.overloaded;
    final originalCritical = currentState.criticalPath;

    try {
      final created = await _repository.createTask(event.task);
      final updatedList = List<Task>.from(currentTasks)..add(created);
      emit(TasksLoaded(
        tasks: updatedList,
        overloaded: originalOverloaded,
        criticalPath: originalCritical,
      ));
    } catch (e) {
      emit(TasksError('Не удалось создать задачу: ${e.toString()}'));
    }
  }
}
