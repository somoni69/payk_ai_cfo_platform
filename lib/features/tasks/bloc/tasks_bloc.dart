import 'package:flutter_bloc/flutter_bloc.dart';
import '../domain/task_model.dart';
import '../domain/tasks_repository.dart';
import 'tasks_event.dart';
import 'tasks_state.dart';

class TasksBloc extends Bloc<TasksEvent, TasksState> {
  final TasksRepository _repository;

  final Set<String> _pendingStatusTaskIds = {};
  static const Duration _referenceDataTtl = Duration(minutes: 30);
  List<TaskProject>? _cachedProjects;
  List<TaskAssignee>? _cachedAssignees;
  DateTime? _referenceDataCachedAt;
  Future<List<Object>>? _referenceDataRequest;
  Future<List<Object>>? _tasksRequest;
  Future<List<Object>>? _analyticsRequest;
  int _tasksGeneration = 0;

  bool get _hasFreshReferenceData =>
      _referenceDataCachedAt != null &&
      DateTime.now().difference(_referenceDataCachedAt!) < _referenceDataTtl;

  TasksBloc(this._repository) : super(TasksLoading()) {
    on<LoadTasks>(_onLoadTasks);
    on<LoadTaskAnalytics>(_onLoadTaskAnalytics);
    on<UpdateTaskStatusRequested>(_onUpdateTaskStatusRequested);
    on<CreateTaskRequested>(_onCreateTaskRequested);
    on<UpdateTaskRequested>(_onUpdateTaskRequested);
    on<LoadMyTasks>(_onLoadMyTasks);
    on<CreatePersonalTaskRequested>(_onCreatePersonalTask);
    on<UpdatePersonalTaskRequested>(_onUpdatePersonalTask);
    on<DeletePersonalTaskRequested>(_onDeletePersonalTask);
    on<AcknowledgeTaskRequested>(_onAcknowledgeTask);
    on<SubmitTaskRequested>(_onSubmitTask);
    on<AcceptTaskRequested>(_onAcceptTask);
    on<RejectTaskRequested>(_onRejectTask);
  }

  Future<void> _onLoadTasks(LoadTasks event, Emitter<TasksState> emit) async {
    final generation = ++_tasksGeneration;
    final previous = state is TasksLoaded ? state as TasksLoaded : null;
    if (previous != null) {
      emit(previous.copyWith(isRefreshing: true, clearLoadError: true));
    } else {
      emit(TasksLoading());
    }

    var request = _tasksRequest;
    if (request == null) {
      request = Future.wait<Object>([
        _repository.getTasks(),
        _loadReferenceData(forceRefresh: event.forceRefresh),
      ]);
      _tasksRequest = request;
    }

    try {
      final results = await request;
      if (generation != _tasksGeneration || emit.isDone) return;
      final latest = state is TasksLoaded ? state as TasksLoaded : previous;
      final referenceData = results[1] as List<Object>;
      emit(
        TasksLoaded(
          tasks: (results[0] as List).cast<Task>(),
          projects: (referenceData[0] as List).cast<TaskProject>(),
          assignees: (referenceData[1] as List).cast<TaskAssignee>(),
          overloaded: latest?.overloaded ?? const [],
          criticalPath: latest?.criticalPath ?? const [],
          myTasks: latest?.myTasks ?? const [],
          assignedToMe: latest?.assignedToMe ?? const [],
          myTasksLoaded: latest?.myTasksLoaded ?? false,
          isMyTasksLoading: latest?.isMyTasksLoading ?? false,
          pendingStatusTaskIds: latest?.pendingStatusTaskIds ?? const {},
          lastStatusUpdateResult: latest?.lastStatusUpdateResult,
          isAnalyticsLoading: latest?.isAnalyticsLoading ?? false,
          analyticsLoaded: latest?.analyticsLoaded ?? false,
          analyticsError: latest?.analyticsError,
        ),
      );
    } catch (_) {
      if (generation != _tasksGeneration || emit.isDone) return;
      final latest = state is TasksLoaded ? state as TasksLoaded : previous;
      const message =
          'Не удалось загрузить список задач. Проверьте соединение.';
      if (latest != null) {
        emit(latest.copyWith(isRefreshing: false, loadError: message));
      } else {
        emit(const TasksError(message));
      }
    } finally {
      if (identical(_tasksRequest, request)) _tasksRequest = null;
      if (event.completion?.isCompleted == false) event.completion!.complete();
    }
  }

  Future<void> _onLoadTaskAnalytics(
    LoadTaskAnalytics event,
    Emitter<TasksState> emit,
  ) async {
    if (state is! TasksLoaded) {
      if (event.completion?.isCompleted == false) event.completion!.complete();
      return;
    }

    final current = state as TasksLoaded;
    if (current.analyticsLoaded && !event.forceRefresh) {
      if (event.completion?.isCompleted == false) event.completion!.complete();
      return;
    }

    emit(current.copyWith(isAnalyticsLoading: true, clearAnalyticsError: true));

    var request = _analyticsRequest;
    if (request == null) {
      request = Future.wait<Object>([
        _repository.getOverloadedAssignees(),
        _repository.getCriticalPath(),
      ]);
      _analyticsRequest = request;
    }

    try {
      final results = await request;
      if (state is TasksLoaded) {
        emit(
          (state as TasksLoaded).copyWith(
            overloaded: (results[0] as List).cast<TaskOverload>(),
            criticalPath: (results[1] as List).cast<TaskCriticalPath>(),
            isAnalyticsLoading: false,
            analyticsLoaded: true,
            clearAnalyticsError: true,
          ),
        );
      }
    } catch (error) {
      if (state is TasksLoaded) {
        emit(
          (state as TasksLoaded).copyWith(
            isAnalyticsLoading: false,
            analyticsError:
                'Не удалось загрузить аналитику задач. Повторите попытку.',
          ),
        );
      }
    } finally {
      if (identical(_analyticsRequest, request)) _analyticsRequest = null;
      if (event.completion?.isCompleted == false) event.completion!.complete();
    }
  }

  Future<List<Object>> _loadReferenceData({bool forceRefresh = false}) async {
    final cachedProjects = _cachedProjects;
    final cachedAssignees = _cachedAssignees;
    if (!forceRefresh &&
        _hasFreshReferenceData &&
        cachedProjects != null &&
        cachedAssignees != null) {
      return <Object>[cachedProjects, cachedAssignees];
    }

    final inFlightRequest = _referenceDataRequest;
    if (inFlightRequest != null) return inFlightRequest;

    final request =
        Future.wait<dynamic>([
              _repository.getProjects(),
              _repository.getAssignees(),
            ])
            .then<List<Object>>((results) {
              final projects = (results[0] as List).cast<TaskProject>();
              final assignees = (results[1] as List).cast<TaskAssignee>();
              _cachedProjects = projects;
              _cachedAssignees = assignees;
              _referenceDataCachedAt = DateTime.now();
              return <Object>[projects, assignees];
            })
            .catchError((Object error) {
              if (cachedProjects != null && cachedAssignees != null) {
                return <Object>[cachedProjects, cachedAssignees];
              }
              throw error;
            });
    _referenceDataRequest = request;

    try {
      return await request;
    } finally {
      if (identical(_referenceDataRequest, request)) {
        _referenceDataRequest = null;
      }
    }
  }

  void _onUpdateTaskStatusRequested(
    UpdateTaskStatusRequested event,
    Emitter<TasksState> emit,
  ) async {
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

    emit(
      currentState.copyWith(
        tasks: optimisticTasks,
        pendingStatusTaskIds: Set.from(_pendingStatusTaskIds),
        clearLastResult: true,
      ),
    );

    try {
      final updatedTask = await _repository.updateTaskStatus(
        event.taskId,
        event.status,
      );

      // Обновляем финальными данными с сервера
      if (state is TasksLoaded) {
        final latestState = state as TasksLoaded;
        final finalTasks = latestState.tasks.map((t) {
          return t.id == event.taskId ? updatedTask : t;
        }).toList();
        emit(
          latestState.copyWith(
            tasks: finalTasks,
            lastStatusUpdateResult: TaskStatusUpdateResult(
              operationId: DateTime.now().microsecondsSinceEpoch.toString(),
              taskId: event.taskId,
              previousStatus: originalTask.status,
              newStatus: event.status,
            ),
          ),
        );
      }
    } catch (e) {
      // При ошибке возвращаем исходное состояние конкретной задачи
      if (state is TasksLoaded) {
        final latestState = state as TasksLoaded;
        final revertedTasks = latestState.tasks.map((t) {
          return t.id == event.taskId ? originalTask : t;
        }).toList();
        emit(latestState.copyWith(tasks: revertedTasks, clearLastResult: true));
      }
    } finally {
      _pendingStatusTaskIds.remove(event.taskId);
      if (state is TasksLoaded) {
        final latestState = state as TasksLoaded;
        emit(
          latestState.copyWith(
            pendingStatusTaskIds: Set.from(_pendingStatusTaskIds),
          ),
        );
      }
    }
  }

  void _onCreateTaskRequested(
    CreateTaskRequested event,
    Emitter<TasksState> emit,
  ) async {
    if (state is! TasksLoaded) return;

    try {
      final created = await _repository.createTask(event.task);
      if (emit.isDone || state is! TasksLoaded) return;

      final latestState = state as TasksLoaded;
      final updatedList = List<Task>.from(latestState.tasks)
        ..removeWhere((task) => task.id == created.id)
        ..add(created);
      emit(latestState.copyWith(tasks: updatedList, clearLoadError: true));
    } catch (e) {
      if (emit.isDone || state is! TasksLoaded) return;
      emit(
        (state as TasksLoaded).copyWith(
          loadError:
              'Не удалось создать задачу. Проверьте данные и соединение.',
        ),
      );
    }
  }

  void _onUpdateTaskRequested(
    UpdateTaskRequested event,
    Emitter<TasksState> emit,
  ) async {
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

  Future<void> _onLoadMyTasks(
    LoadMyTasks event,
    Emitter<TasksState> emit,
  ) async {
    if (state is! TasksLoaded) {
      // Ensure base board is loaded first so we have a shell state.
      await _onLoadTasks(const LoadTasks(), emit);
    }
    if (state is! TasksLoaded) {
      if (event.completion?.isCompleted == false) event.completion!.complete();
      return;
    }

    final current = state as TasksLoaded;
    if (current.myTasksLoaded && !event.forceRefresh) {
      if (event.completion?.isCompleted == false) event.completion!.complete();
      return;
    }

    emit(current.copyWith(isMyTasksLoading: true, clearActionMessage: true));

    try {
      final results = await Future.wait([
        _repository.getMyTasks(),
        _repository.getAssignedToMe(),
      ]);
      if (state is! TasksLoaded) return;
      emit(
        (state as TasksLoaded).copyWith(
          myTasks: results[0],
          assignedToMe: results[1],
          myTasksLoaded: true,
          isMyTasksLoading: false,
        ),
      );
    } catch (e) {
      if (state is TasksLoaded) {
        emit(
          (state as TasksLoaded).copyWith(
            isMyTasksLoading: false,
            actionMessage: e.toString(),
          ),
        );
      }
    } finally {
      if (event.completion?.isCompleted == false) event.completion!.complete();
    }
  }

  Future<void> _onCreatePersonalTask(
    CreatePersonalTaskRequested event,
    Emitter<TasksState> emit,
  ) async {
    if (state is! TasksLoaded) return;
    try {
      final created = await _repository.createPersonalTask(event.input);
      if (state is! TasksLoaded) return;
      final latest = state as TasksLoaded;
      emit(
        latest.copyWith(
          myTasks: [
            created,
            ...latest.myTasks.where((t) => t.id != created.id),
          ],
          actionMessage: 'tasks_my_toast_created',
        ),
      );
    } catch (e) {
      if (state is TasksLoaded) {
        emit((state as TasksLoaded).copyWith(actionMessage: e.toString()));
      }
    }
  }

  Future<void> _onUpdatePersonalTask(
    UpdatePersonalTaskRequested event,
    Emitter<TasksState> emit,
  ) async {
    if (state is! TasksLoaded) return;
    try {
      final updated = await _repository.updatePersonalTask(
        event.taskId,
        event.input,
      );
      if (state is! TasksLoaded) return;
      final latest = state as TasksLoaded;
      emit(
        latest.copyWith(
          myTasks: latest.myTasks
              .map((t) => t.id == event.taskId ? updated : t)
              .toList(),
          actionMessage: 'tasks_my_toast_updated',
        ),
      );
    } catch (e) {
      if (state is TasksLoaded) {
        emit((state as TasksLoaded).copyWith(actionMessage: e.toString()));
      }
    }
  }

  Future<void> _onDeletePersonalTask(
    DeletePersonalTaskRequested event,
    Emitter<TasksState> emit,
  ) async {
    if (state is! TasksLoaded) return;
    try {
      await _repository.deletePersonalTask(event.taskId);
      if (state is! TasksLoaded) return;
      final latest = state as TasksLoaded;
      emit(
        latest.copyWith(
          myTasks: latest.myTasks.where((t) => t.id != event.taskId).toList(),
          actionMessage: 'tasks_my_toast_deleted',
        ),
      );
    } catch (e) {
      if (state is TasksLoaded) {
        emit((state as TasksLoaded).copyWith(actionMessage: e.toString()));
      }
    }
  }

  List<Task> _upsertInList(List<Task> list, Task task) {
    final exists = list.any((t) => t.id == task.id);
    if (!exists) return [...list, task];
    return list.map((t) => t.id == task.id ? task : t).toList();
  }

  Future<void> _applyAcceptanceResult(
    Emitter<TasksState> emit,
    Task updated, {
    String? messageKey,
  }) async {
    if (state is! TasksLoaded) return;
    final latest = state as TasksLoaded;
    emit(
      latest.copyWith(
        assignedToMe: _upsertInList(latest.assignedToMe, updated),
        myTasks: _upsertInList(latest.myTasks, updated),
        tasks: _upsertInList(latest.tasks, updated),
        actionMessage: messageKey,
      ),
    );
  }

  Future<void> _onAcknowledgeTask(
    AcknowledgeTaskRequested event,
    Emitter<TasksState> emit,
  ) async {
    try {
      final updated = await _repository.acknowledgeTask(event.taskId);
      await _applyAcceptanceResult(
        emit,
        updated,
        messageKey: 'tasks_review_toast_acknowledged',
      );
    } catch (e) {
      if (state is TasksLoaded) {
        emit((state as TasksLoaded).copyWith(actionMessage: e.toString()));
      }
    }
  }

  Future<void> _onSubmitTask(
    SubmitTaskRequested event,
    Emitter<TasksState> emit,
  ) async {
    try {
      final updated = await _repository.submitTask(event.taskId);
      await _applyAcceptanceResult(
        emit,
        updated,
        messageKey: 'tasks_review_toast_submitted',
      );
    } catch (e) {
      if (state is TasksLoaded) {
        emit((state as TasksLoaded).copyWith(actionMessage: e.toString()));
      }
    }
  }

  Future<void> _onAcceptTask(
    AcceptTaskRequested event,
    Emitter<TasksState> emit,
  ) async {
    try {
      final updated = await _repository.acceptTask(event.taskId);
      await _applyAcceptanceResult(
        emit,
        updated,
        messageKey: 'tasks_review_toast_accepted',
      );
    } catch (e) {
      if (state is TasksLoaded) {
        emit((state as TasksLoaded).copyWith(actionMessage: e.toString()));
      }
    }
  }

  Future<void> _onRejectTask(
    RejectTaskRequested event,
    Emitter<TasksState> emit,
  ) async {
    try {
      final updated = await _repository.rejectTask(
        event.taskId,
        reason: event.reason,
      );
      await _applyAcceptanceResult(
        emit,
        updated,
        messageKey: 'tasks_review_toast_rejected',
      );
    } catch (e) {
      if (state is TasksLoaded) {
        emit((state as TasksLoaded).copyWith(actionMessage: e.toString()));
      }
    }
  }
}
