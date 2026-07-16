/// Статусы задач согласно ТЗ (TASK-01).
enum TaskStatus {
  todo,       // Новая
  inProgress, // В работе
  review,     // На проверке
  done;       // Готово

  String get label {
    switch (this) {
      case TaskStatus.todo:
        return 'Новая';
      case TaskStatus.inProgress:
        return 'В работе';
      case TaskStatus.review:
        return 'На проверке';
      case TaskStatus.done:
        return 'Готово';
    }
  }
}

/// Приоритеты задач.
enum TaskPriority {
  low,
  medium,
  high,
  urgent;

  String get label {
    switch (this) {
      case TaskPriority.low:
        return 'Низкий';
      case TaskPriority.medium:
        return 'Средний';
      case TaskPriority.high:
        return 'Высокий';
      case TaskPriority.urgent:
        return 'Критический';
    }
  }
}

/// Модель проекта в модуле задач.
class TaskProject {
  final String id;
  final String name;
  final String? description;

  const TaskProject({
    required this.id,
    required this.name,
    this.description,
  });
}

/// Исполнитель задачи (сотрудник из /users).
class TaskAssignee {
  final String id;
  final String fullName;

  const TaskAssignee({
    required this.id,
    required this.fullName,
  });
}

/// Модель задачи в PAYK Platform.
class Task {
  final String id;
  final String title;
  final String description;
  final TaskStatus status;
  final DateTime dueDate;
  final TaskPriority priority;
  final String? projectId;
  final String? projectName;
  final String? assigneeId;
  final String? assigneeName;
  final DateTime? startDate;
  final String? dependsOnId;
  final int? position;

  const Task({
    required this.id,
    required this.title,
    required this.description,
    required this.status,
    required this.dueDate,
    required this.priority,
    this.projectId,
    this.projectName,
    this.assigneeId,
    this.assigneeName,
    this.startDate,
    this.dependsOnId,
    this.position,
  });

  Task copyWith({
    String? id,
    String? title,
    String? description,
    TaskStatus? status,
    DateTime? dueDate,
    TaskPriority? priority,
    String? projectId,
    String? projectName,
    String? assigneeId,
    String? assigneeName,
    DateTime? startDate,
    String? dependsOnId,
    int? position,
  }) {
    return Task(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      status: status ?? this.status,
      dueDate: dueDate ?? this.dueDate,
      priority: priority ?? this.priority,
      projectId: projectId ?? this.projectId,
      projectName: projectName ?? this.projectName,
      assigneeId: assigneeId ?? this.assigneeId,
      assigneeName: assigneeName ?? this.assigneeName,
      startDate: startDate ?? this.startDate,
      dependsOnId: dependsOnId ?? this.dependsOnId,
      position: position ?? this.position,
    );
  }
}

/// Модель сотрудника с перегрузкой по задачам (TASK-05).
class TaskOverload {
  final String assigneeId;
  final String assigneeName;
  final int activeCount;
  final int overdueCount;

  const TaskOverload({
    required this.assigneeId,
    required this.assigneeName,
    required this.activeCount,
    required this.overdueCount,
  });
}

/// Модель задачи критического пути (TASK-06).
class TaskCriticalPath {
  final String id;
  final String title;
  final String status;
  final int blocksCount;
  final DateTime? dueDate;

  const TaskCriticalPath({
    required this.id,
    required this.title,
    required this.status,
    required this.blocksCount,
    this.dueDate,
  });
}
