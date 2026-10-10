import 'package:dio/dio.dart';
import '../../../core/observability/app_error_reporter.dart';
import '../../../core/network/user_facing_error.dart';
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
        final username = map['user_name'] ?? map['username'] ?? '—';
        final entity = map['entity'] ?? '';
        final ip = map['ip_address'] ?? 'unknown';

        return AppNotification(
          id: 'audit_${map['id']}',
          title: 'notif_audit_title',
          description: 'notif_audit_desc',
          params: {
            'action': '$action',
            'user': '$username',
            'entity': '$entity',
            'ip': '$ip',
          },
          type: NotificationType
              .legalCalendar, // Налоговый и юр. календарь / к сведению
          severity: NotificationSeverity.info,
          dateTime: DateTime.parse(
            map['created_at'] ?? DateTime.now().toIso8601String(),
          ),
          isRead: false,
          link: '/audit',
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
                  title: 'notif_night_op_title',
                  description: 'notif_night_op_desc',
                  params: {
                    'cashier': '${map['created_by'] ?? '—'}',
                    'amount': amount,
                    'time': time,
                  },
                  type: NotificationType.audit,
                  severity: NotificationSeverity.critical,
                  dateTime: dt,
                  link: '/cash',
                ),
              );
            }
          }
        }
      } catch (e, st) {
        // Derived night-operation hints are extra; real notifications stay.
        AppErrorReporter.reportOptional(
          e,
          st,
          context: 'notifications_night_ops',
        );
      }

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
                  title: 'notif_task_overdue_title',
                  description: 'notif_task_overdue_desc',
                  params: {'title': '${map['title']}', 'due': formattedDue},
                  type: NotificationType.audit,
                  severity: NotificationSeverity.critical,
                  dateTime: due,
                  link: '/tasks',
                ),
              );
            }
          }
        }
      } catch (e, st) {
        // Derived overdue-task hints are extra; real notifications stay.
        AppErrorReporter.reportOptional(
          e,
          st,
          context: 'notifications_overdue',
        );
      }

      // Сортируем предупреждения по дате (самые свежие сверху)
      notifications.sort((a, b) => b.dateTime.compareTo(a.dateTime));
      return notifications;
    } catch (e) {
      throw Exception(userFacingError(e, fallback: ErrorKeys.loadFailed));
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
  Future<List<AppNotification>> getInbox({int limit = 30}) async {
    try {
      final response = await _dio.get(
        '/notifications',
        queryParameters: {'limit': limit},
      );
      final list = response.data is List
          ? response.data as List
          : const <dynamic>[];
      return list
          .map(_inboxFromJson)
          .whereType<AppNotification>()
          .toList(growable: false);
    } catch (e) {
      throw Exception(userFacingError(e, fallback: ErrorKeys.loadFailed));
    }
  }

  @override
  Future<int> getUnreadCount() async {
    try {
      final response = await _dio.get('/notifications/unread-count');
      final body = response.data;
      if (body is Map) {
        final raw = body['count'];
        if (raw is int) return raw;
        if (raw is num) return raw.toInt();
        return int.tryParse(raw?.toString() ?? '') ?? 0;
      }
      return 0;
    } catch (_) {
      return 0;
    }
  }

  @override
  Future<void> markAllRead() async {
    try {
      await _dio.post('/notifications/read-all');
    } catch (e) {
      throw Exception(userFacingError(e, fallback: ErrorKeys.saveFailed));
    }
  }

  AppNotification? _inboxFromJson(dynamic raw) {
    if (raw is! Map) return null;
    final map = Map<String, dynamic>.from(raw);
    final id = (map['id'] ?? '').toString();
    if (id.isEmpty) return null;
    final createdRaw = map['created_at'] ?? map['createdAt'];
    final createdAt = createdRaw is String
        ? (DateTime.tryParse(createdRaw) ?? DateTime.now())
        : DateTime.now();
    final typeRaw = (map['type'] ?? '').toString().toLowerCase();
    final type = switch (typeRaw) {
      'audit' => NotificationType.audit,
      'forecast' || 'ai_forecast' => NotificationType.aiForecast,
      'advice' || 'ai_advice' => NotificationType.aiAdvice,
      'legal' || 'legal_calendar' => NotificationType.legalCalendar,
      _ => NotificationType.aiAdvice,
    };
    return AppNotification(
      id: id,
      title: (map['title'] ?? '').toString(),
      description: (map['message'] ?? map['description'] ?? '').toString(),
      type: type,
      severity: NotificationSeverity.info,
      dateTime: createdAt.toLocal(),
      isRead: map['is_read'] == true || map['isRead'] == true,
      link: map['link']?.toString(),
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
      throw Exception(userFacingError(e, fallback: ErrorKeys.loadFailed));
    }
  }
}
