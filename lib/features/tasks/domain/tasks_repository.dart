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

  /// Удалить корпоративную задачу (`DELETE /tasks/{id}`).
  Future<void> deleteTask(String taskId);

  /// Получить список всех проектов для задач
  Future<List<TaskProject>> getProjects();

  /// Создать проект
  Future<TaskProject> createProject(String name, {String? description});

  /// Обновить (переименовать) проект
  Future<TaskProject> updateProject(
    String projectId, {
    required String name,
    String? description,
  });

  /// Удалить проект
  Future<void> deleteProject(String projectId);

  /// Получить список исполнителей (GET /users?size=200, как в веб-клиенте)
  Future<List<TaskAssignee>> getAssignees();

  /// Получить список перегруженных сотрудников
  Future<List<TaskOverload>> getOverloadedAssignees();

  /// Получить критический путь задач
  Future<List<TaskCriticalPath>> getCriticalPath();

  // --- My tasks / acceptance (web parity) ---

  /// Tasks where current user is author or assignee (`GET /tasks/my`).
  Future<List<Task>> getMyTasks();

  /// Team tasks assigned to me (`GET /tasks/my/assigned`).
  Future<List<Task>> getAssignedToMe();

  Future<Task> createPersonalTask(PersonalTaskInput input);

  Future<Task> updatePersonalTask(String taskId, PersonalTaskInput input);

  Future<void> deletePersonalTask(String taskId);

  Future<Task> acknowledgeTask(String taskId);

  Future<Task> submitTask(String taskId);

  Future<Task> acceptTask(String taskId);

  Future<Task> rejectTask(String taskId, {String? reason});
}
