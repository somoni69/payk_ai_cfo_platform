import 'notification_model.dart';

/// Интерфейс репозитория для управления уведомлениями и критическим аудитом.
abstract class NotificationsRepository {
  /// Получить список всех уведомлений
  Future<List<AppNotification>> getNotifications();

  /// Forces a network refresh when the implementation supports caching.
  Future<List<AppNotification>> refreshNotifications() => getNotifications();

  /// Отметить уведомление как прочитанное
  Future<void> markAsRead(String id);
}
