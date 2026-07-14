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

  @override
  Future<List<Task>> getTasks() async {
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
    if (shouldFailCreate) {
      throw Exception('Create error');
    }
    tasks.add(task);
    return task;
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

    test('LoadTasks emits TasksLoading and then TasksLoaded with tasks list', () async {
      final expectedStates = [
        isA<TasksLoading>(),
        isA<TasksLoaded>().having((s) => s.tasks.length, 'tasks length', 2),
      ];

      expectLater(bloc.stream, emitsInOrder(expectedStates));
      bloc.add(LoadTasks());
    });

    test('UpdateTaskStatusRequested optimistically emits TasksLoaded and handles success', () async {
      // 1. Сначала загружаем задачи, чтобы войти в состояние TasksLoaded
      bloc.add(LoadTasks());
      await bloc.stream.firstWhere((state) => state is TasksLoaded);

      // 2. Отправляем запрос на обновление статуса задачи 1 (с 'todo' на 'done')
      bloc.add(const UpdateTaskStatusRequested(taskId: '1', status: TaskStatus.done));

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
      expect(firstEmitted.tasks.firstWhere((t) => t.id == '1').status, TaskStatus.done);
    });

    test('UpdateTaskStatusRequested optimistically emits TasksLoaded and reverts on failure', () async {
      // 1. Загружаем
      bloc.add(LoadTasks());
      await bloc.stream.firstWhere((state) => state is TasksLoaded);

      // Устанавливаем флаг ошибки
      repository.shouldFailUpdate = true;

      // 2. Отправляем событие
      bloc.add(const UpdateTaskStatusRequested(taskId: '1', status: TaskStatus.done));

      final List<TasksState> emittedStates = [];
      final subscription = bloc.stream.listen((state) {
        emittedStates.add(state);
      });

      await Future.delayed(const Duration(milliseconds: 50));
      subscription.cancel();

      // Ожидаем, что в конечном итоге статус первой задачи вернулся к исходному (TaskStatus.todo)
      expect(emittedStates, isNotEmpty);
      final lastEmitted = emittedStates.last as TasksLoaded;
      expect(lastEmitted.tasks.firstWhere((t) => t.id == '1').status, TaskStatus.todo);
    });
  });
}
