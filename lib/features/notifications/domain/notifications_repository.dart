import 'notification_model.dart';

/// Интерфейс репозитория для управления уведомлениями и критическим аудитом.
abstract class NotificationsRepository {
  /// Получить список всех уведомлений
  Future<List<AppNotification>> getNotifications();

  /// Forces a network refresh when the implementation supports caching.
  Future<List<AppNotification>> refreshNotifications() => getNotifications();

  /// Отметить уведомление как прочитанное
  Future<void> markAsRead(String id);

  /// Personal inbox (`GET /notifications`).
  Future<List<AppNotification>> getInbox({int limit = 30}) =>
      getNotifications();

  Future<int> getUnreadCount() async {
    final items = await getInbox();
    return items.where((item) => !item.isRead).length;
  }

  Future<void> markAllRead() async {}
}
