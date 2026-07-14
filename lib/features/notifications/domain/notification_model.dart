/// Типы уведомлений согласно ТЗ.
enum NotificationType {
  audit,         // Критический аудит / Нарушение (AUD-02, AUD-05)
  aiForecast,    // ИИ-прогнозы (FIN-12, CRM-07)
  aiAdvice,      // ИИ-рекомендации / Советы дня (FIN-11, STR-08)
  legalCalendar; // Налоговый и юридический календарь (LEG-04, LEG-05)
}

/// Степени важности уведомлений для группировки согласно ТЗ (AUD-06).
enum NotificationSeverity {
  critical,  // Срочно
  important, // Важно
  info;      // К сведению
}

/// Модель уведомления / аудита в системе PAYK.
class AppNotification {
  final String id;
  final String title;
  final String description;
  final NotificationType type;
  final NotificationSeverity severity;
  final DateTime dateTime;
  final bool isRead;

  const AppNotification({
    required this.id,
    required this.title,
    required this.description,
    required this.type,
    required this.severity,
    required this.dateTime,
    this.isRead = false,
  });

  AppNotification copyWith({
    String? id,
    String? title,
    String? description,
    NotificationType? type,
    NotificationSeverity? severity,
    DateTime? dateTime,
    bool? isRead,
  }) {
    return AppNotification(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      type: type ?? this.type,
      severity: severity ?? this.severity,
      dateTime: dateTime ?? this.dateTime,
      isRead: isRead ?? this.isRead,
    );
  }
}
