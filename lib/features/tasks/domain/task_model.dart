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
        return 'Срочно';
    }
  }
}

/// Модель задачи в PAYK Platform.
class Task {
  final String id;
  final String title;
  final String description;
  final TaskStatus status;
  final DateTime dueDate;
  final TaskPriority priority;

  const Task({
    required this.id,
    required this.title,
    required this.description,
    required this.status,
    required this.dueDate,
    required this.priority,
  });

  Task copyWith({
    String? id,
    String? title,
    String? description,
    TaskStatus? status,
    DateTime? dueDate,
    TaskPriority? priority,
  }) {
    return Task(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      status: status ?? this.status,
      dueDate: dueDate ?? this.dueDate,
      priority: priority ?? this.priority,
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
