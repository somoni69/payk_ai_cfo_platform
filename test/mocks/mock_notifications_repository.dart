import 'package:payk_ai_cfo_platform/features/notifications/domain/notification_model.dart';
import 'package:payk_ai_cfo_platform/features/notifications/domain/notifications_repository.dart';

class MockNotificationsRepository implements NotificationsRepository {
  @override
  Future<List<AppNotification>> refreshNotifications() => getNotifications();

  static final List<AppNotification> _notifications = [
    AppNotification(
      id: '1',
      title: 'Подозрение на дробление платежей (AUD-02)',
      description:
          'Обнаружена серия из 4 транзакций по 2 000 TJS поставщику «Согдиана» за последние 2 часа. Возможно, платеж разделен для обхода лимита согласования.',
      type: NotificationType.audit,
      severity: NotificationSeverity.critical,
      dateTime: DateTime.now().subtract(const Duration(minutes: 10)),
    ),
    AppNotification(
      id: '2',
      title: 'Проведение операции в ночное время (AUD-05)',
      description:
          'Кассир Салихов С. провел ручной возврат в кассе А в 02:45 ночи на сумму 1 200 TJS. Рекомендуется проверить видеокамеры.',
      type: NotificationType.audit,
      severity: NotificationSeverity.critical,
      dateTime: DateTime.now().subtract(const Duration(hours: 3)),
    ),
    AppNotification(
      id: '3',
      title: 'Прогноз кассового разрыва',
      description:
          'С вероятностью 85% ожидается дефицит средств в размере 14 000 TJS через 7 дней в связи с задержкой оплаты по договору №14.',
      type: NotificationType.aiForecast,
      severity: NotificationSeverity.important,
      dateTime: DateTime.now().subtract(const Duration(hours: 5)),
    ),
    AppNotification(
      id: '4',
      title: 'Угроза оттока клиентов',
      description:
          'AI-модель прогнозирует высокую вероятность ухода клиента «Азиз-Торг» в течение 30 дней. Объем их закупок снизился на 25%.',
      type: NotificationType.aiForecast,
      severity: NotificationSeverity.important,
      dateTime: DateTime.now().subtract(const Duration(hours: 12)),
    ),
    AppNotification(
      id: '5',
      title: 'Ежедневные AI-рекомендации',
      description:
          'Рекомендация №1: Загрузка склада Худжанд превышает 90% — рассмотрите распродажу остатков.\nРекомендация №2: Переведите 15 000 TJS на депозит для минимизации инфляции.\nРекомендация №3: Проверьте просроченную задачу по сверке транзитных счетов.',
      type: NotificationType.aiAdvice,
      severity: NotificationSeverity.important,
      dateTime: DateTime.now().subtract(const Duration(hours: 18)),
    ),
    AppNotification(
      id: '6',
      title: 'Налоговый календарь РТ',
      description:
          'Приближается срок уплаты налога по упрощенной системе. Срок: до 15 Июля. Расчетная сумма: 18 450 TJS.',
      type: NotificationType.legalCalendar,
      severity: NotificationSeverity.info,
      dateTime: DateTime.now().subtract(const Duration(days: 1)),
    ),
    AppNotification(
      id: '7',
      title: 'Окончание лицензии 1С',
      description:
          'Внимание: срок действия корпоративной лицензии 1С:Бухгалтерия истекает через 14 дней (15 июля). Требуется продление.',
      type: NotificationType.legalCalendar,
      severity: NotificationSeverity.info,
      dateTime: DateTime.now().subtract(const Duration(days: 2)),
    ),
  ];

  @override
  Future<List<AppNotification>> getNotifications() async {
    return List.from(_notifications);
  }

  @override
  Future<List<AppNotification>> getInbox({int limit = 30}) =>
      getNotifications();

  @override
  Future<int> getUnreadCount() async {
    return _notifications.where((n) => !n.isRead).length;
  }

  @override
  Future<void> markAllRead() async {
    for (var i = 0; i < _notifications.length; i++) {
      _notifications[i] = _notifications[i].copyWith(isRead: true);
    }
  }

  @override
  Future<void> markAsRead(String id) async {
    final index = _notifications.indexWhere((n) => n.id == id);
    if (index != -1) {
      _notifications[index] = _notifications[index].copyWith(isRead: true);
    }
  }

  @override
  Future<void> registerFcmToken(String token, {String? platform}) async {}

  @override
  Future<void> unregisterFcmToken(String token) async {}
}
