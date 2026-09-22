import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/network/user_facing_error.dart';
import '../domain/task_model.dart';
import '../domain/tasks_repository.dart';
import 'tasks_event.dart';
import 'tasks_state.dart';

class TasksBloc extends Bloc<TasksEvent, TasksState> {
  final TasksRepository _repository;

  TasksBloc(this._repository) : super(TasksLoading()) {
    on<LoadTasks>(_onLoadTasks, transformer: droppable());
    on<LoadTaskAnalytics>(_onLoadTaskAnalytics);
    on<UpdateTaskStatusRequested>(_onUpdateTaskStatusRequested);
    on<CreateTaskRequested>(_onCreateTaskRequested);
    on<UpdateTaskRequested>(_onUpdateTaskRequested);
    on<DeleteTaskRequested>(_onDeleteTaskRequested);
    on<LoadMyTasks>(_onLoadMyTasks, transformer: droppable());
    on<CreatePersonalTaskRequested>(_onCreatePersonalTask);
    on<UpdatePersonalTaskRequested>(_onUpdatePersonalTask);
    on<DeletePersonalTaskRequested>(_onDeletePersonalTask);
    on<AcknowledgeTaskRequested>(_onAcknowledgeTask);
    on<SubmitTaskRequested>(_onSubmitTask);
    on<AcceptTaskRequested>(_onAcceptTask);
    on<RejectTaskRequested>(_onRejectTask);
    on<CreateProjectRequested>(_onCreateProject);
    on<UpdateProjectRequested>(_onUpdateProject);
    on<DeleteProjectRequested>(_onDeleteProject);
  }

  Future<void> _onLoadTasks(LoadTasks event, Emitter<TasksState> emit) async {
    final current = state is TasksLoaded ? state as TasksLoaded : null;
    if (current != null) {
      emit(current.copyWith(isRefreshing: true, clearLoadError: true));
    } else {
      emit(TasksLoading());
    }

    try {
      final Future<List<Task>> tasksFuture = _repository.getTasks();
      final Future<List<TaskProject>> projectsFuture = current != null
          ? Future.value(current.projects)
          : _repository.getProjects();
      final Future<List<TaskAssignee>> assigneesFuture = current != null
          ? Future.value(current.assignees)
          : _repository.getAssignees();

      final results = await Future.wait<Object>([
        tasksFuture,
        projectsFuture,
        assigneesFuture,
      ]);

      final tasks = (results[0] as List).cast<Task>();
      final projects = (results[1] as List).cast<TaskProject>();
      final assignees = (results[2] as List).cast<TaskAssignee>();

      emit(
        TasksLoaded(
          tasks: tasks,
          projects: projects,
          assignees: assignees,
          overloaded: current?.overloaded ?? const [],
          criticalPath: current?.criticalPath ?? const [],
          myTasks: current?.myTasks ?? const [],
          assignedToMe: current?.assignedToMe ?? const [],
          myTasksLoaded: current?.myTasksLoaded ?? false,
          isMyTasksLoading: current?.isMyTasksLoading ?? false,
          pendingStatusTaskIds: current?.pendingStatusTaskIds ?? const {},
          lastStatusUpdateResult: current?.lastStatusUpdateResult,
          isAnalyticsLoading: current?.isAnalyticsLoading ?? false,
          analyticsLoaded: current?.analyticsLoaded ?? false,
          analyticsError: current?.analyticsError,
        ),
      );
    } catch (e) {
      final message = userFacingError(
        e,
        fallback: 'Не удалось загрузить список задач. Проверьте соединение.',
      );
      if (current != null) {
        emit(current.copyWith(isRefreshing: false, loadError: message));
      } else {
        emit(TasksError(message));
      }
    }
  }

  Future<void> _onLoadTaskAnalytics(
    LoadTaskAnalytics event,
    Emitter<TasksState> emit,
  ) async {
    if (state is! TasksLoaded) return;
    final current = state as TasksLoaded;
    emit(current.copyWith(isAnalyticsLoading: true, clearAnalyticsError: true));

    try {
      final results = await Future.wait<Object>([
        _repository.getOverloadedAssignees(),
        _repository.getCriticalPath(),
      ]);

      emit(
        current.copyWith(
          overloaded: (results[0] as List).cast<TaskOverload>(),
          criticalPath: (results[1] as List).cast<TaskCriticalPath>(),
          isAnalyticsLoading: false,
          analyticsLoaded: true,
        ),
      );
    } catch (e) {
      emit(
        current.copyWith(
          isAnalyticsLoading: false,
          analyticsError: userFacingError(e, fallback: ErrorKeys.loadFailed),
        ),
      );
    }
  }

  Future<void> _onUpdateTaskStatusRequested(
    UpdateTaskStatusRequested event,
    Emitter<TasksState> emit,
  ) async {
    if (state is! TasksLoaded) return;
    final current = state as TasksLoaded;

    final targetIndex = current.tasks.indexWhere((t) => t.id == event.taskId);
    if (targetIndex == -1) return;
    final previousStatus = current.tasks[targetIndex].status;

    final pending = Set<String>.from(current.pendingStatusTaskIds)
      ..add(event.taskId);
    final optimisticTasks = List<Task>.from(current.tasks)
      ..[targetIndex] = current.tasks[targetIndex].copyWith(
        status: event.status,
      );

    emit(
      current.copyWith(tasks: optimisticTasks, pendingStatusTaskIds: pending),
    );

    try {
      final updated = await _repository.updateTaskStatus(
        event.taskId,
        event.status,
      );
      final finalTasks = List<Task>.from(current.tasks)
        ..[targetIndex] = updated;
      final finalPending = Set<String>.from(pending)..remove(event.taskId);

      emit(
        current.copyWith(
          tasks: finalTasks,
          pendingStatusTaskIds: finalPending,
          lastStatusUpdateResult: TaskStatusUpdateResult(
            operationId: DateTime.now().millisecondsSinceEpoch.toString(),
            taskId: event.taskId,
            previousStatus: previousStatus,
            newStatus: event.status,
          ),
        ),
      );
    } catch (e) {
      final rollbackPending = Set<String>.from(pending)..remove(event.taskId);
      emit(
        current.copyWith(
          tasks: current.tasks,
          pendingStatusTaskIds: rollbackPending,
          actionMessage: userFacingError(e, fallback: ErrorKeys.saveFailed),
        ),
      );
    }
  }

  Future<void> _onCreateTaskRequested(
    CreateTaskRequested event,
    Emitter<TasksState> emit,
  ) async {
    if (state is! TasksLoaded) return;
    final current = state as TasksLoaded;
    try {
      final created = await _repository.createTask(event.task);
      final latest = state is TasksLoaded ? state as TasksLoaded : current;
      final existingIndex = latest.tasks.indexWhere((t) => t.id == created.id);
      final updatedTasks = existingIndex >= 0
          ? (List<Task>.from(latest.tasks)..[existingIndex] = created)
          : [created, ...latest.tasks];
      emit(
        latest.copyWith(tasks: updatedTasks, actionMessage: 'tasks_created'),
      );
    } catch (e) {
      final latest = state is TasksLoaded ? state as TasksLoaded : current;
      emit(
        latest.copyWith(
          actionMessage: userFacingError(e, fallback: ErrorKeys.saveFailed),
        ),
      );
    }
  }

  Future<void> _onUpdateTaskRequested(
    UpdateTaskRequested event,
    Emitter<TasksState> emit,
  ) async {
    if (state is! TasksLoaded) return;
    final current = state as TasksLoaded;
    try {
      final updated = await _repository.updateTask(event.task);
      final tasks = [
        for (final t in current.tasks) t.id == updated.id ? updated : t,
      ];
      emit(current.copyWith(tasks: tasks, actionMessage: 'tasks_saved'));
    } catch (e) {
      emit(
        current.copyWith(
          actionMessage: userFacingError(e, fallback: ErrorKeys.saveFailed),
        ),
      );
    }
  }

  Future<void> _onDeleteTaskRequested(
    DeleteTaskRequested event,
    Emitter<TasksState> emit,
  ) async {
    if (state is! TasksLoaded) return;
    final current = state as TasksLoaded;
    try {
      await _repository.deleteTask(event.taskId);
      final tasks = current.tasks
          .where((t) => t.id != event.taskId)
          .toList(growable: false);
      emit(current.copyWith(tasks: tasks, actionMessage: 'tasks_deleted'));
    } catch (e) {
      emit(
        current.copyWith(
          actionMessage: userFacingError(e, fallback: ErrorKeys.saveFailed),
        ),
      );
    }
  }

  Future<void> _onLoadMyTasks(
    LoadMyTasks event,
    Emitter<TasksState> emit,
  ) async {
    if (state is! TasksLoaded) return;
    final current = state as TasksLoaded;
    if (current.myTasksLoaded) return;
    emit(current.copyWith(isMyTasksLoading: true));

    try {
      final results = await Future.wait<Object>([
        _repository.getMyTasks(),
        _repository.getAssignedToMe(),
      ]);

      emit(
        current.copyWith(
          myTasks: (results[0] as List).cast<Task>(),
          assignedToMe: (results[1] as List).cast<Task>(),
          myTasksLoaded: true,
          isMyTasksLoading: false,
        ),
      );
    } catch (e) {
      emit(
        current.copyWith(
          isMyTasksLoading: false,
          actionMessage: userFacingError(e, fallback: ErrorKeys.loadFailed),
        ),
      );
    }
  }

  Future<void> _onCreatePersonalTask(
    CreatePersonalTaskRequested event,
    Emitter<TasksState> emit,
  ) async {
    if (state is! TasksLoaded) return;
    final current = state as TasksLoaded;
    try {
      final created = await _repository.createPersonalTask(event.input);
      emit(
        current.copyWith(
          myTasks: [created, ...current.myTasks],
          actionMessage: 'tasks_created',
        ),
      );
    } catch (e) {
      emit(
        current.copyWith(
          actionMessage: userFacingError(e, fallback: ErrorKeys.saveFailed),
        ),
      );
    }
  }

  Future<void> _onUpdatePersonalTask(
    UpdatePersonalTaskRequested event,
    Emitter<TasksState> emit,
  ) async {
    if (state is! TasksLoaded) return;
    final current = state as TasksLoaded;
    try {
      final updated = await _repository.updatePersonalTask(
        event.taskId,
        event.input,
      );
      final myTasks = [
        for (final t in current.myTasks) t.id == updated.id ? updated : t,
      ];
      emit(current.copyWith(myTasks: myTasks, actionMessage: 'tasks_saved'));
    } catch (e) {
      emit(
        current.copyWith(
          actionMessage: userFacingError(e, fallback: ErrorKeys.saveFailed),
        ),
      );
    }
  }

  Future<void> _onDeletePersonalTask(
    DeletePersonalTaskRequested event,
    Emitter<TasksState> emit,
  ) async {
    if (state is! TasksLoaded) return;
    final current = state as TasksLoaded;
    try {
      await _repository.deletePersonalTask(event.taskId);
      final myTasks = current.myTasks
          .where((t) => t.id != event.taskId)
          .toList(growable: false);
      emit(current.copyWith(myTasks: myTasks, actionMessage: 'tasks_deleted'));
    } catch (e) {
      emit(
        current.copyWith(
          actionMessage: userFacingError(e, fallback: ErrorKeys.saveFailed),
        ),
      );
    }
  }

  Future<void> _onAcknowledgeTask(
    AcknowledgeTaskRequested event,
    Emitter<TasksState> emit,
  ) async {
    if (state is! TasksLoaded) return;
    final current = state as TasksLoaded;
    try {
      final updated = await _repository.acknowledgeTask(event.taskId);
      emit(_updateSingleTask(current, updated));
    } catch (e) {
      emit(
        current.copyWith(
          actionMessage: userFacingError(e, fallback: ErrorKeys.saveFailed),
        ),
      );
    }
  }

  Future<void> _onSubmitTask(
    SubmitTaskRequested event,
    Emitter<TasksState> emit,
  ) async {
    if (state is! TasksLoaded) return;
    final current = state as TasksLoaded;
    try {
      final updated = await _repository.submitTask(event.taskId);
      emit(_updateSingleTask(current, updated));
    } catch (e) {
      emit(
        current.copyWith(
          actionMessage: userFacingError(e, fallback: ErrorKeys.saveFailed),
        ),
      );
    }
  }

  Future<void> _onAcceptTask(
    AcceptTaskRequested event,
    Emitter<TasksState> emit,
  ) async {
    if (state is! TasksLoaded) return;
    final current = state as TasksLoaded;
    try {
      final updated = await _repository.acceptTask(event.taskId);
      emit(_updateSingleTask(current, updated));
    } catch (e) {
      emit(
        current.copyWith(
          actionMessage: userFacingError(e, fallback: ErrorKeys.saveFailed),
        ),
      );
    }
  }

  Future<void> _onRejectTask(
    RejectTaskRequested event,
    Emitter<TasksState> emit,
  ) async {
    if (state is! TasksLoaded) return;
    final current = state as TasksLoaded;
    try {
      final updated = await _repository.rejectTask(
        event.taskId,
        reason: event.reason,
      );
      emit(_updateSingleTask(current, updated));
    } catch (e) {
      emit(
        current.copyWith(
          actionMessage: userFacingError(e, fallback: ErrorKeys.saveFailed),
        ),
      );
    }
  }

  Future<void> _onCreateProject(
    CreateProjectRequested event,
    Emitter<TasksState> emit,
  ) async {
    if (state is! TasksLoaded) return;
    final current = state as TasksLoaded;
    try {
      final project = await _repository.createProject(
        event.name,
        description: event.description,
      );
      emit(current.copyWith(projects: [...current.projects, project]));
    } catch (e) {
      emit(
        current.copyWith(
          actionMessage: userFacingError(e, fallback: ErrorKeys.saveFailed),
        ),
      );
    }
  }

  Future<void> _onUpdateProject(
    UpdateProjectRequested event,
    Emitter<TasksState> emit,
  ) async {
    if (state is! TasksLoaded) return;
    final current = state as TasksLoaded;
    try {
      final updated = await _repository.updateProject(
        event.projectId,
        name: event.name,
        description: event.description,
      );
      final projects = [
        for (final p in current.projects) p.id == updated.id ? updated : p,
      ];
      emit(current.copyWith(projects: projects));
    } catch (e) {
      emit(
        current.copyWith(
          actionMessage: userFacingError(e, fallback: ErrorKeys.saveFailed),
        ),
      );
    }
  }

  Future<void> _onDeleteProject(
    DeleteProjectRequested event,
    Emitter<TasksState> emit,
  ) async {
    if (state is! TasksLoaded) return;
    final current = state as TasksLoaded;
    try {
      await _repository.deleteProject(event.projectId);
      final projects = current.projects
          .where((p) => p.id != event.projectId)
          .toList(growable: false);
      emit(current.copyWith(projects: projects));
    } catch (e) {
      emit(
        current.copyWith(
          actionMessage: userFacingError(e, fallback: ErrorKeys.saveFailed),
        ),
      );
    }
  }

  TasksLoaded _updateSingleTask(TasksLoaded state, Task updated) {
    final tasks = [
      for (final t in state.tasks) t.id == updated.id ? updated : t,
    ];
    final myTasks = [
      for (final t in state.myTasks) t.id == updated.id ? updated : t,
    ];
    final assignedToMe = [
      for (final t in state.assignedToMe) t.id == updated.id ? updated : t,
    ];

    return state.copyWith(
      tasks: tasks,
      myTasks: myTasks,
      assignedToMe: assignedToMe,
    );
  }
}
