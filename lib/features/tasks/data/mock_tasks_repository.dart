import '../domain/task_model.dart';
import '../domain/tasks_repository.dart';

/// Моковый репозиторий задач для локального тестирования.
class MockTasksRepository implements TasksRepository {
  static final List<TaskProject> _projects = [
    const TaskProject(
      id: '1',
      name: 'Автоматизация оплат',
      description: 'Оптимизация платежных процессов',
    ),
    const TaskProject(
      id: '2',
      name: 'Отчетность регионов',
      description: 'Формирование P&L для филиалов',
    ),
    const TaskProject(
      id: '3',
      name: 'Договоры и контрагенты',
      description: 'Работа с партнерами и поставщиками',
    ),
  ];

  static final List<Task> _tasks = [
    Task(
      id: '1',
      title: 'Составить реестр платежей на июль',
      description:
          'Необходимо собрать счета от арендодателя, интернет-провайдеров и коммунальных служб.',
      status: TaskStatus.inProgress,
      dueDate: DateTime.now().add(const Duration(days: 4)),
      priority: TaskPriority.high,
      projectId: '1',
      projectName: 'Автоматизация оплат',
      assigneeId: '1',
      assigneeName: 'Шерзод Азимов',
      startDate: DateTime.now(),
    ),
    Task(
      id: '2',
      title: 'Сдать отчет P&L по филиалу Худжанд',
      description:
          'Проверить розничную выручку в iiko за прошлую неделю и сопоставить с выпиской из банка.',
      status: TaskStatus.review,
      dueDate: DateTime.now().add(const Duration(hours: 3)),
      priority: TaskPriority.urgent,
      projectId: '2',
      projectName: 'Отчетность регионов',
      assigneeId: '2',
      assigneeName: 'Дильноза Саидова',
      startDate: DateTime.now().subtract(const Duration(days: 2)),
    ),
    Task(
      id: '3',
      title: 'Подписать договор с поставщиком «Алиф»',
      description:
          'Шаблон готов и согласован юристами. Ждем подписи директора.',
      status: TaskStatus.todo,
      dueDate: DateTime.now().add(const Duration(days: 9)),
      priority: TaskPriority.medium,
      projectId: '3',
      projectName: 'Договоры и контрагенты',
      startDate: DateTime.now().add(const Duration(days: 1)),
    ),
    Task(
      id: '4',
      title: 'Сверить остатки на транзитном счете',
      description: 'Выписка по транзитным счетам сомони и долларов США.',
      status: TaskStatus.done,
      dueDate: DateTime.now().subtract(const Duration(days: 1)),
      priority: TaskPriority.low,
      projectId: '1',
      projectName: 'Автоматизация оплат',
      assigneeId: '1',
      assigneeName: 'Шерзод Азимов',
      startDate: DateTime.now().subtract(const Duration(days: 4)),
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
    String? pName;
    if (task.projectId != null) {
      try {
        pName = _projects.firstWhere((p) => p.id == task.projectId).name;
      } catch (_) {}
    }

    final newTask = Task(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: task.title,
      description: task.description,
      status: TaskStatus.todo,
      dueDate: task.dueDate,
      priority: task.priority,
      projectId: task.projectId,
      projectName: pName,
      assigneeId: task.assigneeId,
      assigneeName: task.assigneeName,
      startDate: task.startDate,
      dependsOnId: task.dependsOnId,
      position: task.position,
    );
    _tasks.add(newTask);
    return newTask;
  }

  @override
  Future<Task> updateTask(Task task) async {
    await Future.delayed(const Duration(milliseconds: 100));
    final index = _tasks.indexWhere((t) => t.id == task.id);
    if (index == -1) {
      throw Exception('Задача не найдена');
    }

    String? pName = task.projectName;
    if (task.projectId != null) {
      try {
        pName = _projects.firstWhere((p) => p.id == task.projectId).name;
      } catch (_) {}
    }

    final updated = task.copyWith(projectName: pName);
    _tasks[index] = updated;
    return updated;
  }

  @override
  Future<List<TaskProject>> getProjects() async {
    await Future.delayed(const Duration(milliseconds: 100));
    return List.from(_projects);
  }

  @override
  Future<List<TaskAssignee>> getAssignees() async {
    await Future.delayed(const Duration(milliseconds: 80));
    return const [
      TaskAssignee(id: '1', fullName: 'Шерзод Азимов'),
      TaskAssignee(id: '2', fullName: 'Дильноза Саидова'),
    ];
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
