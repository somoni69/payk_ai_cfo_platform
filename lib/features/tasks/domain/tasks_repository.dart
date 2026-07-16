import 'task_model.dart';

/// Репозиторий для управления задачами.
abstract class TasksRepository {
  /// Получить список всех задач
  Future<List<Task>> getTasks();

  /// Изменить статус задачи (Канбан-переходы и выполнение)
  Future<Task> updateTaskStatus(String taskId, TaskStatus status);

  /// Создать новую задачу
  Future<Task> createTask(Task task);

  /// Обновить полностью задачу
  Future<Task> updateTask(Task task);

  /// Получить список всех проектов для задач
  Future<List<TaskProject>> getProjects();

  /// Получить список исполнителей (GET /users?size=200, как в веб-клиенте)
  Future<List<TaskAssignee>> getAssignees();

  /// Получить список перегруженных сотрудников
  Future<List<TaskOverload>> getOverloadedAssignees();

  /// Получить критический путь задач
  Future<List<TaskCriticalPath>> getCriticalPath();
}
