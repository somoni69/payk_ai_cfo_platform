import 'package:intl/intl.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/user_facing_error.dart';
import '../domain/task_model.dart';
import '../domain/tasks_repository.dart';
import '../../../core/error/app_failure.dart';

/// Реализация репозитория задач, получающая данные с бэкенда (TASK-*).
class ApiTasksRepository implements TasksRepository {
  final ApiClient _apiClient = ApiClient();

  Task _mapTask(Map<String, dynamic> map) {
    final dueRaw = map['due_date'] ?? map['dueDate'];
    DateTime dueDate;
    if (dueRaw is String && dueRaw.isNotEmpty) {
      dueDate = DateTime.tryParse(dueRaw) ?? DateTime.now();
    } else {
      dueDate = DateTime.now();
    }

    DateTime? parseDt(dynamic v) {
      if (v == null) return null;
      if (v is DateTime) return v;
      if (v is String && v.isNotEmpty) return DateTime.tryParse(v);
      return null;
    }

    int? parseInt(dynamic v) {
      if (v == null) return null;
      if (v is int) return v;
      if (v is num) return v.toInt();
      return int.tryParse(v.toString());
    }

    return Task(
      id: (map['id'] ?? '').toString(),
      title: map['title']?.toString() ?? '',
      description: map['description']?.toString() ?? '',
      status: _parseStatus(map['status']?.toString()),
      dueDate: dueDate,
      priority: _parsePriority(map['priority']?.toString()),
      projectId: map['project_id']?.toString(),
      projectName: map['project_name']?.toString(),
      assigneeId: map['assignee_id']?.toString(),
      assigneeName: map['assignee_name']?.toString(),
      startDate: parseDt(map['start_date']),
      dependsOnId: map['depends_on_id']?.toString(),
      position: parseInt(map['position']),
      isPersonal: map['is_personal'] == true,
      createdBy: parseInt(map['created_by']),
      acknowledgedAt: parseDt(map['acknowledged_at']),
      acceptedAt: parseDt(map['accepted_at']),
      rejectReason: map['reject_reason']?.toString(),
    );
  }

  List<Task> _mapTaskList(dynamic data) {
    if (data is List) {
      return data
          .whereType<Map>()
          .map((e) => _mapTask(Map<String, dynamic>.from(e)))
          .toList();
    }
    if (data is Map) {
      final items = data['items'];
      if (items is List) {
        return items
            .whereType<Map>()
            .map((e) => _mapTask(Map<String, dynamic>.from(e)))
            .toList();
      }
    }
    return const [];
  }

  @override
  Future<List<Task>> getTasks() async {
    try {
      final response = await _apiClient.dio.get('/tasks');
      return _mapTaskList(response.data);
    } catch (e) {
      throw RepositoryFailure(
        userFacingError(e, fallback: ErrorKeys.loadFailed),
      );
    }
  }

  @override
  Future<Task> updateTaskStatus(String taskId, TaskStatus status) async {
    try {
      final response = await _apiClient.dio.post(
        '/tasks/$taskId/move',
        data: {'status': _statusToName(status), 'position': 0},
      );
      return _mapTask(Map<String, dynamic>.from(response.data as Map));
    } catch (e) {
      throw RepositoryFailure(
        userFacingError(e, fallback: ErrorKeys.saveFailed),
      );
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
        if (task.projectId != null) 'project_id': int.tryParse(task.projectId!),
        if (task.assigneeId != null)
          'assignee_id': int.tryParse(task.assigneeId!),
        if (task.startDate != null)
          'start_date': DateFormat('yyyy-MM-dd').format(task.startDate!),
        if (task.dependsOnId != null)
          'depends_on_id': int.tryParse(task.dependsOnId!),
      };

      final response = await _apiClient.dio.post('/tasks', data: payload);
      return _mapTask(Map<String, dynamic>.from(response.data as Map));
    } catch (e) {
      throw RepositoryFailure(
        userFacingError(e, fallback: ErrorKeys.loadFailed),
      );
    }
  }

  @override
  Future<Task> updateTask(Task task) async {
    try {
      final payload = {
        'title': task.title,
        'description': task.description,
        'status': _statusToName(task.status),
        'due_date': DateFormat('yyyy-MM-dd').format(task.dueDate),
        'priority': _priorityToName(task.priority),
        'project_id': task.projectId != null
            ? int.tryParse(task.projectId!)
            : null,
        'assignee_id': task.assigneeId != null
            ? int.tryParse(task.assigneeId!)
            : null,
        'start_date': task.startDate != null
            ? DateFormat('yyyy-MM-dd').format(task.startDate!)
            : null,
      };

      final response = await _apiClient.dio.patch(
        '/tasks/${task.id}',
        data: payload,
      );
      return _mapTask(Map<String, dynamic>.from(response.data as Map));
    } catch (e) {
      throw RepositoryFailure(
        userFacingError(e, fallback: ErrorKeys.loadFailed),
      );
    }
  }

  @override
  Future<List<TaskProject>> getProjects() async {
    try {
      final response = await _apiClient.dio.get('/tasks/projects');
      final list = response.data as List<dynamic>? ?? [];

      return list.map((item) {
        final map = item as Map<String, dynamic>;
        return TaskProject(
          id: (map['id'] ?? '').toString(),
          name: map['name'] ?? '',
          description: map['description'],
        );
      }).toList();
    } catch (e) {
      throw RepositoryFailure(
        userFacingError(e, fallback: ErrorKeys.loadFailed),
      );
    }
  }

  @override
  Future<TaskProject> createProject(String name, {String? description}) async {
    try {
      final response = await _apiClient.dio.post(
        '/tasks/projects',
        data: {'name': name.trim(), 'description': description?.trim()},
      );
      final map = Map<String, dynamic>.from(response.data as Map);
      return TaskProject(
        id: (map['id'] ?? '').toString(),
        name: map['name'] ?? '',
        description: map['description'],
      );
    } catch (e) {
      throw RepositoryFailure(
        userFacingError(e, fallback: ErrorKeys.loadFailed),
      );
    }
  }

  @override
  Future<TaskProject> updateProject(
    String projectId, {
    required String name,
    String? description,
  }) async {
    try {
      final response = await _apiClient.dio.patch(
        '/tasks/projects/$projectId',
        data: {'name': name.trim(), 'description': description?.trim()},
      );
      final map = Map<String, dynamic>.from(response.data as Map);
      return TaskProject(
        id: (map['id'] ?? '').toString(),
        name: map['name'] ?? '',
        description: map['description'],
      );
    } catch (e) {
      throw RepositoryFailure(
        userFacingError(e, fallback: ErrorKeys.loadFailed),
      );
    }
  }

  @override
  Future<void> deleteProject(String projectId) async {
    try {
      await _apiClient.dio.delete('/tasks/projects/$projectId');
    } catch (e) {
      throw RepositoryFailure(
        userFacingError(e, fallback: ErrorKeys.loadFailed),
      );
    }
  }

  @override
  Future<List<TaskAssignee>> getAssignees() async {
    try {
      final response = await _apiClient.dio.get(
        '/users',
        queryParameters: {'size': 200},
      );
      final dynamic responseData = response.data;
      final List<dynamic> list = responseData is Map<String, dynamic>
          ? (responseData['items'] as List<dynamic>? ?? [])
          : (responseData is List<dynamic> ? responseData : []);

      return list.map((item) {
        final map = item as Map<String, dynamic>;
        final fullName =
            (map['full_name'] ?? map['fullName'] ?? map['name'] ?? '')
                .toString()
                .trim();
        return TaskAssignee(
          id: (map['id'] ?? '').toString(),
          fullName: fullName.isNotEmpty ? fullName : 'Без имени',
        );
      }).toList();
    } catch (e) {
      return [];
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
      throw RepositoryFailure(
        userFacingError(e, fallback: ErrorKeys.loadFailed),
      );
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
          dueDate: map['due_date'] != null
              ? DateTime.parse(map['due_date'])
              : null,
        );
      }).toList();
    } catch (e) {
      throw RepositoryFailure(
        userFacingError(e, fallback: ErrorKeys.loadFailed),
      );
    }
  }

  @override
  Future<List<Task>> getMyTasks() async {
    try {
      final response = await _apiClient.dio.get('/tasks/my');
      return _mapTaskList(response.data);
    } catch (e) {
      throw RepositoryFailure(
        userFacingError(e, fallback: ErrorKeys.loadFailed),
      );
    }
  }

  @override
  Future<List<Task>> getAssignedToMe() async {
    try {
      final response = await _apiClient.dio.get('/tasks/my/assigned');
      return _mapTaskList(response.data);
    } catch (e) {
      throw RepositoryFailure(
        userFacingError(e, fallback: ErrorKeys.loadFailed),
      );
    }
  }

  @override
  Future<Task> createPersonalTask(PersonalTaskInput input) async {
    try {
      final payload = <String, dynamic>{
        'title': input.title,
        if (input.description != null) 'description': input.description,
        if (input.status != null) 'status': _statusToName(input.status!),
        if (input.priority != null)
          'priority': _priorityToName(input.priority!),
        if (input.dueDate != null)
          'due_date': DateFormat('yyyy-MM-dd').format(input.dueDate!),
        if (input.startDate != null)
          'start_date': DateFormat('yyyy-MM-dd').format(input.startDate!),
      };
      final response = await _apiClient.dio.post(
        '/tasks/personal',
        data: payload,
      );
      return _mapTask(Map<String, dynamic>.from(response.data as Map));
    } catch (e) {
      throw RepositoryFailure(
        userFacingError(e, fallback: ErrorKeys.saveFailed),
      );
    }
  }

  @override
  Future<Task> updatePersonalTask(
    String taskId,
    PersonalTaskInput input,
  ) async {
    try {
      final payload = <String, dynamic>{
        'title': input.title,
        if (input.description != null) 'description': input.description,
        if (input.status != null) 'status': _statusToName(input.status!),
        if (input.priority != null)
          'priority': _priorityToName(input.priority!),
        if (input.dueDate != null)
          'due_date': DateFormat('yyyy-MM-dd').format(input.dueDate!),
        if (input.startDate != null)
          'start_date': DateFormat('yyyy-MM-dd').format(input.startDate!),
      };
      final response = await _apiClient.dio.patch(
        '/tasks/personal/$taskId',
        data: payload,
      );
      return _mapTask(Map<String, dynamic>.from(response.data as Map));
    } catch (e) {
      throw RepositoryFailure(
        userFacingError(e, fallback: ErrorKeys.saveFailed),
      );
    }
  }

  @override
  Future<void> deleteTask(String taskId) async {
    try {
      await _apiClient.dio.delete('/tasks/$taskId');
    } catch (e) {
      throw RepositoryFailure(
        userFacingError(e, fallback: ErrorKeys.saveFailed),
      );
    }
  }

  @override
  Future<void> deletePersonalTask(String taskId) async {
    try {
      await _apiClient.dio.delete('/tasks/personal/$taskId');
    } catch (e) {
      throw RepositoryFailure(
        userFacingError(e, fallback: ErrorKeys.saveFailed),
      );
    }
  }

  @override
  Future<Task> acknowledgeTask(String taskId) async {
    try {
      final response = await _apiClient.dio.post(
        '/tasks/my/$taskId/acknowledge',
      );
      return _mapTask(Map<String, dynamic>.from(response.data as Map));
    } catch (e) {
      throw RepositoryFailure(
        userFacingError(e, fallback: ErrorKeys.saveFailed),
      );
    }
  }

  @override
  Future<Task> submitTask(String taskId) async {
    try {
      final response = await _apiClient.dio.post('/tasks/my/$taskId/submit');
      return _mapTask(Map<String, dynamic>.from(response.data as Map));
    } catch (e) {
      throw RepositoryFailure(
        userFacingError(e, fallback: ErrorKeys.saveFailed),
      );
    }
  }

  @override
  Future<Task> acceptTask(String taskId) async {
    try {
      final response = await _apiClient.dio.post('/tasks/$taskId/accept');
      return _mapTask(Map<String, dynamic>.from(response.data as Map));
    } catch (e) {
      throw RepositoryFailure(
        userFacingError(e, fallback: ErrorKeys.saveFailed),
      );
    }
  }

  @override
  Future<Task> rejectTask(String taskId, {String? reason}) async {
    try {
      final response = await _apiClient.dio.post(
        '/tasks/$taskId/reject',
        data: {'reason': reason},
      );
      return _mapTask(Map<String, dynamic>.from(response.data as Map));
    } catch (e) {
      throw RepositoryFailure(
        userFacingError(e, fallback: ErrorKeys.saveFailed),
      );
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
      case 'acknowledged':
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
      case 'критический':
      case 'critical':
        return TaskPriority.urgent;
      case 'medium':
      case 'средний':
      default:
        return TaskPriority.medium;
    }
  }
}
