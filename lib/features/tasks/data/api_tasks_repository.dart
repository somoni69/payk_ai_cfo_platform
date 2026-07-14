import 'package:intl/intl.dart';
import '../../../core/network/api_client.dart';
import '../domain/task_model.dart';
import '../domain/tasks_repository.dart';

/// Реализация репозитория задач, получающая данные с бэкенда (TASK-*).
class ApiTasksRepository implements TasksRepository {
  final ApiClient _apiClient = ApiClient();

  @override
  Future<List<Task>> getTasks() async {
    try {
      final response = await _apiClient.dio.get('/tasks');
      final body = response.data as Map<String, dynamic>;
      final list = body['items'] as List<dynamic>? ?? [];

      return list.map((item) {
        final map = item as Map<String, dynamic>;
        return Task(
          id: (map['id'] ?? '').toString(),
          title: map['title'] ?? '',
          description: map['description'] ?? '',
          status: _parseStatus(map['status']),
          dueDate: DateTime.parse(map['due_date'] ?? map['dueDate'] ?? DateTime.now().toIso8601String()),
          priority: _parsePriority(map['priority']),
        );
      }).toList();
    } catch (e) {
      throw Exception('Не удалось загрузить задачи: ${e.toString()}');
    }
  }

  @override
  Future<Task> updateTaskStatus(String taskId, TaskStatus status) async {
    try {
      final response = await _apiClient.dio.patch(
        '/tasks/$taskId',
        data: {'status': _statusToName(status)},
      );
      final map = response.data as Map<String, dynamic>;

      return Task(
        id: (map['id'] ?? '').toString(),
        title: map['title'] ?? '',
        description: map['description'] ?? '',
        status: _parseStatus(map['status']),
        dueDate: DateTime.parse(map['due_date'] ?? map['dueDate'] ?? DateTime.now().toIso8601String()),
        priority: _parsePriority(map['priority']),
      );
    } catch (e) {
      throw Exception('Не удалось обновить статус задачи: ${e.toString()}');
    }
  }

  @override
  Future<Task> createTask(Task task) async {
    try {
      final payload = {
        'title': task.title,
        'description': task.description,
        'due_date': DateFormat('yyyy-MM-dd').format(task.dueDate),
        'priority': _priorityToName(task.priority),
      };

      final response = await _apiClient.dio.post('/tasks', data: payload);
      final map = response.data as Map<String, dynamic>;

      return Task(
        id: (map['id'] ?? '').toString(),
        title: map['title'] ?? '',
        description: map['description'] ?? '',
        status: _parseStatus(map['status']),
        dueDate: DateTime.parse(map['due_date'] ?? map['dueDate'] ?? DateTime.now().toIso8601String()),
        priority: _parsePriority(map['priority']),
      );
    } catch (e) {
      throw Exception('Не удалось создать задачу: ${e.toString()}');
    }
  }

  String _statusToName(TaskStatus status) {
    switch (status) {
      case TaskStatus.inProgress:
        return 'in_progress';
      case TaskStatus.review:
        return 'review';
      case TaskStatus.done:
        return 'done';
      case TaskStatus.todo:
        return 'new';
    }
  }

  String _priorityToName(TaskPriority priority) {
    switch (priority) {
      case TaskPriority.low:
        return 'low';
      case TaskPriority.medium:
        return 'medium';
      case TaskPriority.high:
        return 'high';
      case TaskPriority.urgent:
        return 'critical';
    }
  }

  TaskStatus _parseStatus(String? statusStr) {
    switch (statusStr?.toLowerCase()) {
      case 'inprogress':
      case 'in_progress':
      case 'in work':
      case 'в работе':
        return TaskStatus.inProgress;
      case 'review':
      case 'на проверке':
        return TaskStatus.review;
      case 'done':
      case 'готово':
        return TaskStatus.done;
      case 'todo':
      case 'new':
      case 'новая':
      default:
        return TaskStatus.todo;
    }
  }

  TaskPriority _parsePriority(String? priorityStr) {
    switch (priorityStr?.toLowerCase()) {
      case 'low':
      case 'низкий':
        return TaskPriority.low;
      case 'high':
      case 'высокий':
        return TaskPriority.high;
      case 'urgent':
      case 'срочно':
      case 'критично':
      case 'critical':
        return TaskPriority.urgent;
      case 'medium':
      case 'средний':
      default:
        return TaskPriority.medium;
    }
  }

  @override
  Future<List<TaskOverload>> getOverloadedAssignees() async {
    try {
      final response = await _apiClient.dio.get('/tasks/overloaded');
      final list = response.data as List<dynamic>;

      return list.map((item) {
        final map = item as Map<String, dynamic>;
        return TaskOverload(
          assigneeId: (map['assignee_id'] ?? '').toString(),
          assigneeName: map['assignee_name'] ?? 'Неизвестный',
          activeCount: map['active_count'] ?? 0,
          overdueCount: map['overdue_count'] ?? 0,
        );
      }).toList();
    } catch (e) {
      throw Exception('Не удалось загрузить перегрузку сотрудников: ${e.toString()}');
    }
  }

  @override
  Future<List<TaskCriticalPath>> getCriticalPath() async {
    try {
      final response = await _apiClient.dio.get('/tasks/critical-path');
      final list = response.data as List<dynamic>;

      return list.map((item) {
        final map = item as Map<String, dynamic>;
        return TaskCriticalPath(
          id: (map['id'] ?? '').toString(),
          title: map['title'] ?? '',
          status: map['status'] ?? 'new',
          blocksCount: map['blocks_count'] ?? 0,
          dueDate: map['due_date'] != null ? DateTime.parse(map['due_date']) : null,
        );
      }).toList();
    } catch (e) {
      throw Exception('Не удалось загрузить критический путь: ${e.toString()}');
    }
  }
}
