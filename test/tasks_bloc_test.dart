import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:payk_ai_cfo_platform/features/tasks/bloc/tasks_bloc.dart';
import 'package:payk_ai_cfo_platform/features/tasks/bloc/tasks_event.dart';
import 'package:payk_ai_cfo_platform/features/tasks/bloc/tasks_state.dart';
import 'package:payk_ai_cfo_platform/features/tasks/domain/task_model.dart';
import 'package:payk_ai_cfo_platform/features/tasks/domain/tasks_repository.dart';

// Ручной Mock для репозитория задач
class MockTasksRepository implements TasksRepository {
  List<Task> tasks = [];
  bool shouldFailUpdate = false;
  bool shouldFailCreate = false;
  bool shouldFailLoad = false;
  final Map<String, Completer<Task>> createGates = {};
  final Map<String, Completer<void>> createRequestsStarted = {};
  int projectRequestCount = 0;
  int assigneeRequestCount = 0;

  @override
  Future<List<Task>> getTasks() async {
    if (shouldFailLoad) throw Exception('private backend detail');
    return List.from(tasks);
  }

  @override
  Future<Task> updateTaskStatus(String taskId, TaskStatus status) async {
    if (shouldFailUpdate) {
      throw Exception('Network error');
    }
    final index = tasks.indexWhere((t) => t.id == taskId);
    if (index == -1) throw Exception('Task not found');
    final updated = tasks[index].copyWith(status: status);
    tasks[index] = updated;
    return updated;
  }

  @override
  Future<Task> createTask(Task task) async {
    final started = createRequestsStarted[task.id];
    if (started != null && !started.isCompleted) started.complete();
    if (shouldFailCreate) {
      throw Exception('Create error');
    }
    final gate = createGates[task.id];
    final created = gate == null ? task : await gate.future;
    tasks.add(created);
    return created;
  }

  @override
  Future<Task> updateTask(Task task) async {
    if (shouldFailUpdate) {
      throw Exception('Network error');
    }
    final index = tasks.indexWhere((t) => t.id == task.id);
    if (index == -1) throw Exception('Task not found');
    tasks[index] = task;
    return task;
  }

  @override
  Future<List<TaskProject>> getProjects() async {
    projectRequestCount++;
    return [];
  }

  @override
  Future<List<TaskAssignee>> getAssignees() async {
    assigneeRequestCount++;
    return [];
  }

  @override
  Future<List<TaskOverload>> getOverloadedAssignees() async {
    return [];
  }

  @override
  Future<List<TaskCriticalPath>> getCriticalPath() async {
    return [];
  }
}

void main() {
  group('TasksBloc Unit Tests', () {
    late MockTasksRepository repository;
    late TasksBloc bloc;
    late List<Task> initialTasks;

    setUp(() {
      repository = MockTasksRepository();
      initialTasks = [
        Task(
          id: '1',
          title: 'Task 1',
          description: 'Desc 1',
          status: TaskStatus.todo,
          dueDate: DateTime(2026, 7, 16),
          priority: TaskPriority.high,
        ),
        Task(
          id: '2',
          title: 'Task 2',
          description: 'Desc 2',
          status: TaskStatus.inProgress,
          dueDate: DateTime(2026, 7, 17),
          priority: TaskPriority.low,
        ),
      ];
      repository.tasks = List.from(initialTasks);
      bloc = TasksBloc(repository);
    });

    tearDown(() {
      bloc.close();
    });

    test('Initial state is TasksLoading', () {
      expect(bloc.state, isA<TasksLoading>());
    });

    test(
      'LoadTasks emits TasksLoading and then TasksLoaded with tasks list',
      () async {
        final expectedStates = [
          isA<TasksLoading>(),
          isA<TasksLoaded>().having((s) => s.tasks.length, 'tasks length', 2),
        ];

        expectLater(bloc.stream, emitsInOrder(expectedStates));
        bloc.add(LoadTasks());
      },
    );

    test(
      'failed refresh keeps confirmed tasks and hides backend details',
      () async {
        final initial = bloc.stream.firstWhere((state) => state is TasksLoaded);
        bloc.add(const LoadTasks());
        await initial;

        repository.shouldFailLoad = true;
        final failed = bloc.stream.firstWhere(
          (state) => state is TasksLoaded && state.loadError != null,
        );
        bloc.add(const LoadTasks(forceRefresh: true));
        final state = await failed as TasksLoaded;

        expect(state.tasks, initialTasks);
        expect(state.isRefreshing, false);
        expect(state.loadError, contains('Проверьте соединение'));
        expect(state.loadError, isNot(contains('private backend detail')));
      },
    );
    test('LoadTasks reuses cached projects and assignees on refresh', () async {
      final firstLoad = bloc.stream.firstWhere((state) => state is TasksLoaded);
      bloc.add(LoadTasks());
      await firstLoad;

      final refreshStarted = bloc.stream.firstWhere(
        (state) => state is TasksLoaded && state.isRefreshing,
      );
      final refresh = bloc.stream.firstWhere(
        (state) => state is TasksLoaded && !state.isRefreshing,
      );
      bloc.add(LoadTasks());
      final refreshingState = await refreshStarted as TasksLoaded;
      expect(refreshingState.tasks, initialTasks);
      await refresh;

      expect(repository.projectRequestCount, 1);
      expect(repository.assigneeRequestCount, 1);
    });

    test('parallel task creations preserve both server results', () async {
      bloc.add(const LoadTasks());
      await bloc.stream.firstWhere((state) => state is TasksLoaded);

      final third = Task(
        id: '3',
        title: 'Task 3',
        description: 'Desc 3',
        status: TaskStatus.todo,
        dueDate: DateTime(2026, 7, 18),
        priority: TaskPriority.medium,
      );
      final fourth = Task(
        id: '4',
        title: 'Task 4',
        description: 'Desc 4',
        status: TaskStatus.todo,
        dueDate: DateTime(2026, 7, 19),
        priority: TaskPriority.medium,
      );
      final thirdGate = Completer<Task>();
      final fourthGate = Completer<Task>();
      repository
        ..createGates['3'] = thirdGate
        ..createGates['4'] = fourthGate
        ..createRequestsStarted['3'] = Completer<void>()
        ..createRequestsStarted['4'] = Completer<void>();

      bloc
        ..add(CreateTaskRequested(third))
        ..add(CreateTaskRequested(fourth));
      await Future.wait<void>([
        repository.createRequestsStarted['3']!.future,
        repository.createRequestsStarted['4']!.future,
      ]);

      final fourthCreated = bloc.stream.firstWhere(
        (state) =>
            state is TasksLoaded && state.tasks.any((task) => task.id == '4'),
      );
      fourthGate.complete(fourth);
      await fourthCreated;

      final bothCreated = bloc.stream.firstWhere(
        (state) =>
            state is TasksLoaded &&
            state.tasks.any((task) => task.id == '3') &&
            state.tasks.any((task) => task.id == '4'),
      );
      thirdGate.complete(third);
      final state = await bothCreated as TasksLoaded;

      expect(state.tasks.map((task) => task.id), containsAll(['3', '4']));
      expect(state.tasks, hasLength(4));
    });

    test(
      'UpdateTaskStatusRequested optimistically emits TasksLoaded and handles success',
      () async {
        // 1. Сначала загружаем задачи, чтобы войти в состояние TasksLoaded
        bloc.add(LoadTasks());
        await bloc.stream.firstWhere((state) => state is TasksLoaded);

        // 2. Отправляем запрос на обновление статуса задачи 1 (с 'todo' на 'done')
        bloc.add(
          const UpdateTaskStatusRequested(taskId: '1', status: TaskStatus.done),
        );

        // 3. Проверяем последовательность излучения состояний
        // Ожидаем:
        // - Состояние с измененным статусом (оптимистичное обновление)
        // - Состояние с финальным подтверждением с сервера
        final List<TasksState> emittedStates = [];
        final subscription = bloc.stream.listen((state) {
          emittedStates.add(state);
        });

        // Ждем завершения операции в блоке
        await Future.delayed(const Duration(milliseconds: 50));
        subscription.cancel();

        expect(emittedStates, isNotEmpty);
        final firstEmitted = emittedStates.first as TasksLoaded;
        expect(
          firstEmitted.tasks.firstWhere((t) => t.id == '1').status,
          TaskStatus.done,
        );
      },
    );

    test(
      'UpdateTaskStatusRequested optimistically emits TasksLoaded and reverts on failure',
      () async {
        // 1. Загружаем
        bloc.add(LoadTasks());
        await bloc.stream.firstWhere((state) => state is TasksLoaded);

        // Устанавливаем флаг ошибки
        repository.shouldFailUpdate = true;

        // 2. Отправляем событие
        bloc.add(
          const UpdateTaskStatusRequested(taskId: '1', status: TaskStatus.done),
        );

        final List<TasksState> emittedStates = [];
        final subscription = bloc.stream.listen((state) {
          emittedStates.add(state);
        });

        await Future.delayed(const Duration(milliseconds: 50));
        subscription.cancel();

        // Ожидаем, что в конечном итоге статус первой задачи вернулся к исходному (TaskStatus.todo)
        expect(emittedStates, isNotEmpty);
        final lastEmitted = emittedStates.last as TasksLoaded;
        expect(
          lastEmitted.tasks.firstWhere((t) => t.id == '1').status,
          TaskStatus.todo,
        );
      },
    );

    test(
      'Snackbar undo restores previous status after marking task done',
      () async {
        bloc.add(LoadTasks());
        await bloc.stream.firstWhere((state) => state is TasksLoaded);

        // Complete in-progress task (id: 2)
        bloc.add(
          const UpdateTaskStatusRequested(taskId: '2', status: TaskStatus.done),
        );

        final completed =
            await bloc.stream.firstWhere((state) {
                  return state is TasksLoaded &&
                      state.lastStatusUpdateResult != null &&
                      state.lastStatusUpdateResult!.taskId == '2' &&
                      state.lastStatusUpdateResult!.newStatus ==
                          TaskStatus.done;
                })
                as TasksLoaded;

        expect(
          completed.tasks.firstWhere((t) => t.id == '2').status,
          TaskStatus.done,
        );
        expect(
          completed.lastStatusUpdateResult!.previousStatus,
          TaskStatus.inProgress,
        );

        // Simulate Snackbar "Отменить"
        bloc.add(
          UpdateTaskStatusRequested(
            taskId: completed.lastStatusUpdateResult!.taskId,
            status: completed.lastStatusUpdateResult!.previousStatus,
          ),
        );

        final restored =
            await bloc.stream.firstWhere((state) {
                  return state is TasksLoaded &&
                      state.tasks.any(
                        (t) => t.id == '2' && t.status == TaskStatus.inProgress,
                      ) &&
                      state.pendingStatusTaskIds.isEmpty;
                })
                as TasksLoaded;

        expect(
          restored.tasks.firstWhere((t) => t.id == '2').status,
          TaskStatus.inProgress,
        );
        // Filters live in UI state; bloc only holds task data — list still complete.
        expect(restored.tasks.length, 2);
      },
    );

    test(
      'UpdateTaskRequested optimistically updates and handles success',
      () async {
        bloc.add(LoadTasks());
        await bloc.stream.firstWhere((state) => state is TasksLoaded);

        final updatedTask = initialTasks.first.copyWith(
          title: 'New Title',
          description: 'New Description',
        );
        bloc.add(UpdateTaskRequested(updatedTask));

        final List<TasksState> emittedStates = [];
        final subscription = bloc.stream.listen((state) {
          emittedStates.add(state);
        });

        await Future.delayed(const Duration(milliseconds: 50));
        subscription.cancel();

        expect(emittedStates, isNotEmpty);
        final firstEmitted = emittedStates.first as TasksLoaded;
        expect(
          firstEmitted.tasks.firstWhere((t) => t.id == '1').title,
          'New Title',
        );
      },
    );

    test('UpdateTaskRequested reverts on failure', () async {
      bloc.add(LoadTasks());
      await bloc.stream.firstWhere((state) => state is TasksLoaded);

      repository.shouldFailUpdate = true;
      final updatedTask = initialTasks.first.copyWith(title: 'New Title');
      bloc.add(UpdateTaskRequested(updatedTask));

      final List<TasksState> emittedStates = [];
      final subscription = bloc.stream.listen((state) {
        emittedStates.add(state);
      });

      await Future.delayed(const Duration(milliseconds: 50));
      subscription.cancel();

      expect(emittedStates, isNotEmpty);
      final lastEmitted = emittedStates.last as TasksLoaded;
      expect(lastEmitted.tasks.firstWhere((t) => t.id == '1').title, 'Task 1');
    });
  });
}
