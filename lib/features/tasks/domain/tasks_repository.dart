import 'task_model.dart';

/// Репозиторий для управления задачами.
abstract class TasksRepository {
  /// Получить список всех задач
  Future<List<Task>> getTasks();

  /// Изменить статус задачи (Канбан-переходы и выполнение)
  Future<Task> updateTaskStatus(String taskId, TaskStatus status);

  /// Создать новую задачу
  Future<Task> createTask(Task task);

  /// Получить список перегруженных сотрудников
  Future<List<TaskOverload>> getOverloadedAssignees();

  /// Получить критический путь задач
  Future<List<TaskCriticalPath>> getCriticalPath();
}
