import 'package:dio/dio.dart';

import '../../../core/network/api_client.dart';
import '../domain/audit_models.dart';
import '../domain/audit_repository.dart';

/// Audit repository. Offline fallbacks use localization keys (not raw RU).
class ApiAuditRepository implements AuditRepository {
  final ApiClient _client;

  ApiAuditRepository({ApiClient? client}) : _client = client ?? ApiClient();

  final List<AuditLog> _mockLogs = [
    AuditLog(
      id: 'log-1',
      timestamp: DateTime.now().subtract(const Duration(minutes: 15)),
      userName: 'mock_user_alisher',
      action: 'mock_action_encashment_create',
      entityType: 'Encashment',
      details: 'mock_detail_encashment_oriyon',
    ),
    AuditLog(
      id: 'log-2',
      timestamp: DateTime.now().subtract(const Duration(hours: 1)),
      userName: 'mock_user_zarina',
      action: 'mock_action_shift_close',
      entityType: 'Shift',
      details: 'mock_detail_z_report',
    ),
    AuditLog(
      id: 'log-3',
      timestamp: DateTime.now().subtract(const Duration(hours: 3)),
      userName: 'mock_user_parviz',
      action: 'mock_action_role_change',
      entityType: 'UserRole',
      details: 'mock_detail_cashier_role',
    ),
  ];

  final List<AuditAlert> _mockAlerts = [
    AuditAlert(
      id: 'alt-1',
      type: 'mock_alert_large_expense',
      severity: 'high',
      message: 'mock_msg_encashment_limit',
      timestamp: DateTime.now().subtract(const Duration(minutes: 15)),
    ),
    AuditAlert(
      id: 'alt-2',
      type: 'mock_alert_multi_login',
      severity: 'medium',
      message: 'mock_msg_parallel_login',
      timestamp: DateTime.now().subtract(const Duration(hours: 5)),
    ),
  ];

  List<T> _parsePage<T>(dynamic data, T Function(Map<String, dynamic>) map) {
    if (data is List) {
      return data
          .whereType<Map>()
          .map((e) => map(Map<String, dynamic>.from(e)))
          .toList();
    }
    if (data is Map && data['items'] is List) {
      return (data['items'] as List)
          .whereType<Map>()
          .map((e) => map(Map<String, dynamic>.from(e)))
          .toList();
    }
    return const [];
  }

  @override
  Future<List<AuditLog>> getAuditLogs({
    String? entity,
    String? action,
    DateTime? dateFrom,
    DateTime? dateTo,
  }) async {
    try {
      final response = await _client.dio.get(
        '/audit/logs',
        queryParameters: {
          if (entity != null && entity.isNotEmpty) 'entity': entity,
          if (action != null && action.isNotEmpty) 'action': action,
          if (dateFrom != null) 'date_from': dateFrom.toIso8601String(),
          if (dateTo != null) 'date_to': dateTo.toIso8601String(),
          'size': 100,
        },
      );
      if (response.statusCode == 200) {
        final parsed = _parsePage(response.data, AuditLog.fromJson);
        if (parsed.isNotEmpty) return parsed;
      }
    } catch (_) {}
    return List.from(_mockLogs);
  }

  @override
  Future<List<AuditAlert>> getAuditAlerts({bool? resolved}) async {
    try {
      final response = await _client.dio.get(
        '/audit/alerts',
        queryParameters: {'resolved': ?resolved, 'size': 100},
      );
      if (response.statusCode == 200) {
        final parsed = _parsePage(response.data, AuditAlert.fromJson);
        if (parsed.isNotEmpty) return parsed;
      }
    } catch (_) {}
    return List.from(_mockAlerts);
  }

  @override
  Future<List<AuditAlert>> runAnomalyDetectors() async {
    try {
      await _client.dio.post('/audit/run-detectors');
      return await getAuditAlerts();
    } catch (_) {}
    final newAlert = AuditAlert(
      id: 'alt-${DateTime.now().millisecondsSinceEpoch}',
      type: 'mock_alert_scan_done',
      severity: 'low',
      message: 'mock_msg_no_anomalies',
      timestamp: DateTime.now(),
    );
    _mockAlerts.insert(0, newAlert);
    return List.from(_mockAlerts);
  }

  @override
  Future<AuditAlert> resolveAlert(String id, {bool isResolved = true}) async {
    final response = await _client.dio.patch(
      '/audit/alerts/$id/resolve',
      data: {'is_resolved': isResolved},
    );
    if (response.data is Map) {
      return AuditAlert.fromJson(
        Map<String, dynamic>.from(response.data as Map),
      );
    }
    return AuditAlert(
      id: id,
      type: '',
      severity: 'low',
      message: '',
      timestamp: DateTime.now(),
      isResolved: isResolved,
    );
  }

  @override
  Future<WeeklyAuditReport> getWeeklyReport({DateTime? weekStart}) async {
    final response = await _client.dio.get(
      '/audit/weekly-report',
      queryParameters: {
        if (weekStart != null)
          'week_start': weekStart.toIso8601String().substring(0, 10),
      },
    );
    final data = response.data is Map
        ? Map<String, dynamic>.from(response.data as Map)
        : <String, dynamic>{};
    final bySev = <String, int>{};
    final rawSev = data['alerts_by_severity'];
    if (rawSev is Map) {
      rawSev.forEach((k, v) {
        bySev[k.toString()] = (v as num?)?.toInt() ?? 0;
      });
    }
    return WeeklyAuditReport(
      periodFrom:
          DateTime.tryParse((data['period_from'] ?? '').toString()) ??
          DateTime.now(),
      periodTo:
          DateTime.tryParse((data['period_to'] ?? '').toString()) ??
          DateTime.now(),
      operationsCount: (data['operations_count'] as num?)?.toInt() ?? 0,
      incomeTotal: (data['income_total'] as num?)?.toDouble() ?? 0,
      expenseTotal: (data['expense_total'] as num?)?.toDouble() ?? 0,
      netTotal: (data['net_total'] as num?)?.toDouble() ?? 0,
      alertsCount: (data['alerts_count'] as num?)?.toInt() ?? 0,
      alertsBySeverity: bySev,
    );
  }

  @override
  Future<List<int>> exportWeeklyReport({String format = 'pdf'}) async {
    final response = await _client.dio.get<List<int>>(
      '/audit/weekly-report/export',
      queryParameters: {'fmt': format},
      options: Options(responseType: ResponseType.bytes),
    );
    return response.data ?? <int>[];
  }

  @override
  Future<List<EntityHistoryItem>> getEntityHistory(
    String entity,
    String id,
  ) async {
    final response = await _client.dio.get('/history/$entity/$id');
    return _parsePage(response.data, EntityHistoryItem.fromJson);
  }
}
