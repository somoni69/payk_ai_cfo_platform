import '../domain/task_model.dart';
import '../domain/tasks_repository.dart';

/// Моковый репозиторий задач для локального тестирования.
class MockTasksRepository implements TasksRepository {
  static final List<Task> _tasks = [
    Task(
      id: '1',
      title: 'Составить реестр платежей на июль',
      description: 'Необходимо собрать счета от арендодателя, интернет-провайдеров и коммунальных служб.',
      status: TaskStatus.inProgress,
      dueDate: DateTime.now().add(const Duration(days: 4)),
      priority: TaskPriority.high,
    ),
    Task(
      id: '2',
      title: 'Сдать отчет P&L по филиалу Худжанд',
      description: 'Проверить розничную выручку в iiko за прошлую неделю и сопоставить с выпиской из банка.',
      status: TaskStatus.review,
      dueDate: DateTime.now().add(const Duration(hours: 3)),
      priority: TaskPriority.urgent,
    ),
    Task(
      id: '3',
      title: 'Подписать договор с поставщиком «Алиф»',
      description: 'Шаблон готов и согласован юристами. Ждем подписи директора.',
      status: TaskStatus.todo,
      dueDate: DateTime.now().add(const Duration(days: 9)),
      priority: TaskPriority.medium,
    ),
    Task(
      id: '4',
      title: 'Сверить остатки на транзитном счете',
      description: 'Выписка по транзитным счетам сомони и долларов США.',
      status: TaskStatus.done,
      dueDate: DateTime.now().subtract(const Duration(days: 1)),
      priority: TaskPriority.low,
    ),
  ];

  @override
  Future<List<Task>> getTasks() async {
    await Future.delayed(const Duration(milliseconds: 150));
    return List.from(_tasks);
  }

  @override
  Future<Task> updateTaskStatus(String taskId, TaskStatus status) async {
    await Future.delayed(const Duration(milliseconds: 100));
    final index = _tasks.indexWhere((t) => t.id == taskId);
    if (index == -1) {
      throw Exception('Задача не найдена');
    }
    
    final updatedTask = _tasks[index].copyWith(status: status);
    _tasks[index] = updatedTask;
    return updatedTask;
  }

  @override
  Future<Task> createTask(Task task) async {
    await Future.delayed(const Duration(milliseconds: 200));
    final newTask = Task(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: task.title,
      description: task.description,
      status: TaskStatus.todo,
      dueDate: task.dueDate,
      priority: task.priority,
    );
    _tasks.add(newTask);
    return newTask;
  }

  @override
  Future<List<TaskOverload>> getOverloadedAssignees() async {
    return [
      const TaskOverload(
        assigneeId: '1',
        assigneeName: 'Шерзод Азимов',
        activeCount: 6,
        overdueCount: 2,
      ),
      const TaskOverload(
        assigneeId: '2',
        assigneeName: 'Дильноза Саидова',
        activeCount: 5,
        overdueCount: 0,
      ),
    ];
  }

  @override
  Future<List<TaskCriticalPath>> getCriticalPath() async {
    return [
      TaskCriticalPath(
        id: '10',
        title: 'Утвердить бюджет закупок сырья',
        status: 'in_progress',
        blocksCount: 3,
        dueDate: DateTime.now().add(const Duration(days: 2)),
      ),
      TaskCriticalPath(
        id: '11',
        title: 'Согласовать трудовой договор директора',
        status: 'new',
        blocksCount: 1,
        dueDate: DateTime.now().add(const Duration(days: 5)),
      ),
    ];
  }
}
