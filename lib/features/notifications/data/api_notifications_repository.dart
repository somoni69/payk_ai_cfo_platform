import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import '../../../core/localization/locale_date_time_format.dart';
import '../../../core/localization/locale_number_format.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/expiring_request_cache.dart';
import '../domain/notification_model.dart';
import '../domain/notifications_repository.dart';

/// Реализация репозитория аудита и AI-предупреждений (AUD-*, FIN-12, LEG-*).
class ApiNotificationsRepository implements NotificationsRepository {
  ApiNotificationsRepository({Dio? dio}) : _dio = dio ?? ApiClient().dio;

  final Dio _dio;
  static const _cacheTtl = Duration(seconds: 30);

  final _notificationsCache = ExpiringRequestCache<List<AppNotification>>(
    ttl: _cacheTtl,
  );

  @override
  Future<List<AppNotification>> getNotifications() => _load(force: false);

  @override
  Future<List<AppNotification>> refreshNotifications() => _load(force: true);

  Future<List<AppNotification>> _load({required bool force}) =>
      _notificationsCache.get(
        () async =>
            List<AppNotification>.unmodifiable(await _fetchNotifications()),
        forceRefresh: force,
      );

  Future<List<AppNotification>> _fetchNotifications() async {
    try {
      Future<Response<dynamic>> optionalGet(String path) async {
        try {
          return await _dio.get(path);
        } catch (_) {
          return Response<dynamic>(
            requestOptions: RequestOptions(path: path),
            data: <String, dynamic>{'items': <dynamic>[]},
          );
        }
      }

      final auditFuture = _dio.get('/audit/logs');
      final cashFuture = optionalGet('/cash/operations');
      final tasksFuture = optionalGet('/tasks');

      // 1. Загрузка реальных логов аудита пользователей с /audit/logs
      final response = await auditFuture;
      final body = response.data as Map<String, dynamic>;
      final list = body['items'] as List<dynamic>? ?? [];

      List<AppNotification> notifications = list.map((item) {
        final map = item as Map<String, dynamic>;
        final action = map['action'] ?? 'action';
        final username = map['user_name'] ?? map['username'] ?? 'Система';
        final entity = map['entity'] ?? '';
        final ip = map['ip_address'] ?? 'unknown';

        return AppNotification(
          id: 'audit_${map['id']}',
          title: 'Аудит системы: $action',
          description:
              'Пользователь $username совершил действие "$action" для сущности "$entity". IP-адрес устройства: $ip.',
          type: NotificationType
              .legalCalendar, // Налоговый и юр. календарь / к сведению
          severity: NotificationSeverity.info,
          dateTime: DateTime.parse(
            map['created_at'] ?? DateTime.now().toIso8601String(),
          ),
          isRead: false,
        );
      }).toList();

      // 2. Локальный аудит на лету (Проверка на ночные кассовые операции AUD-05)
      try {
        final cashRes = await cashFuture;
        final Map<String, dynamic> cashBody =
            cashRes.data as Map<String, dynamic>;
        final cashList = cashBody['items'] as List<dynamic>? ?? [];

        for (final item in cashList) {
          final map = item as Map<String, dynamic>;
          final dtStr = map['occurred_at'] ?? map['created_at'];
          if (dtStr != null) {
            final dt = DateTime.parse(dtStr).toLocal();
            // Считаем ночной операцией интервал с 23:00 вечера до 05:00 утра
            if (dt.hour >= 23 || dt.hour <= 5) {
              final amount = _formatAmount(map['amount']);
              final time = formatLocalizedDateTimeForLocale(
                dt,
                const Locale('ru'),
                style: LocalizedDateTimeStyle.time,
              );
              notifications.add(
                AppNotification(
                  id: 'anomaly_night_${map['id']}',
                  title: 'Проведение операции в ночное время (AUD-05)',
                  description:
                      'Кассир #${map['created_by'] ?? "Система"} провел операцию на сумму $amount TJS в ночное время ($time). Рекомендуется проверить видеокамеры.',
                  type: NotificationType.audit,
                  severity: NotificationSeverity.critical,
                  dateTime: dt,
                ),
              );
            }
          }
        }
      } catch (_) {}

      // 3. Локальный аудит на лету (Поиск просроченных задач TASK-04)
      try {
        final tasksRes = await tasksFuture;
        final Map<String, dynamic> tasksBody =
            tasksRes.data as Map<String, dynamic>;
        final tasksList = tasksBody['items'] as List<dynamic>? ?? [];

        for (final item in tasksList) {
          final map = item as Map<String, dynamic>;
          final statusStr = map['status'] as String?;
          final dueStr = map['due_date'] ?? map['dueDate'];
          if (statusStr != 'done' && dueStr != null) {
            final due = DateTime.parse(dueStr);
            if (due.isBefore(DateTime.now())) {
              final formattedDue = formatLocalizedDateTimeForLocale(
                due,
                const Locale('ru'),
                style: LocalizedDateTimeStyle.date,
                convertToLocal: false,
              );
              notifications.add(
                AppNotification(
                  id: 'anomaly_task_overdue_${map['id']}',
                  title: 'Срыв сроков задачи (TASK-04)',
                  description:
                      'Задача "${map['title']}" просрочена. Дедлайн: $formattedDue. Срочно завершите ее или перенесите сроки.',
                  type: NotificationType.audit,
                  severity: NotificationSeverity.critical,
                  dateTime: due,
                ),
              );
            }
          }
        }
      } catch (_) {}

      // Сортируем предупреждения по дате (самые свежие сверху)
      notifications.sort((a, b) => b.dateTime.compareTo(a.dateTime));
      return notifications;
    } catch (e) {
      throw Exception('Не удалось загрузить аудит: ${e.toString()}');
    }
  }

  String _formatAmount(Object? rawAmount) {
    final amount = rawAmount is num
        ? rawAmount
        : num.tryParse(rawAmount?.toString() ?? '');
    if (amount == null || !amount.isFinite) {
      return rawAmount?.toString() ?? '0';
    }
    return formatLocalizedNumberForLocale(
      amount,
      const Locale('ru'),
      maximumFractionDigits: 2,
    );
  }

  @override
  Future<void> markAsRead(String id) async {
    try {
      // Игнорируем для локально генерируемых аномалий
      if (id.startsWith('anomaly_')) return;

      final cleanId = id.replaceFirst('audit_', '');
      try {
        await _dio.post('/notifications/$cleanId/read');
      } on DioException catch (error) {
        final status = error.response?.statusCode;
        if (status != 404 && status != 405) rethrow;
        await _dio.patch('/notifications/$cleanId', data: {'is_read': true});
      }
      final cached = _notificationsCache.valueOrNull;
      if (cached != null) {
        _notificationsCache.set(
          List<AppNotification>.unmodifiable(
            cached.map(
              (item) => item.id == id ? item.copyWith(isRead: true) : item,
            ),
          ),
        );
      }
    } catch (e) {
      throw Exception(
        'Не удалось обновить статус уведомления: ${e.toString()}',
      );
    }
  }
}
