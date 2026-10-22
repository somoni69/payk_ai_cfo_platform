import 'package:dio/dio.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/user_facing_error.dart';
import '../domain/audit_models.dart';
import '../domain/audit_repository.dart';
import '../../../core/error/app_failure.dart';

/// Audit repository: `/audit/*`. Failures reach the bloc; no offline stand-ins.
class ApiAuditRepository implements AuditRepository {
  final Dio _dio;

  ApiAuditRepository({ApiClient? client, Dio? dio})
    : _dio = dio ?? (client ?? ApiClient()).dio;

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
      final response = await _dio.get(
        '/audit/logs',
        queryParameters: {
          if (entity != null && entity.isNotEmpty) 'entity': entity,
          if (action != null && action.isNotEmpty) 'action': action,
          if (dateFrom != null) 'date_from': dateFrom.toIso8601String(),
          if (dateTo != null) 'date_to': dateTo.toIso8601String(),
          'size': 100,
        },
      );
      return _parsePage(response.data, AuditLog.fromJson);
    } catch (e) {
      throw RepositoryFailure(
        userFacingError(e, fallback: ErrorKeys.loadFailed),
      );
    }
  }

  @override
  Future<List<AuditAlert>> getAuditAlerts({bool? resolved}) async {
    try {
      final response = await _dio.get(
        '/audit/alerts',
        queryParameters: {'resolved': ?resolved, 'size': 100},
      );
      return _parsePage(response.data, AuditAlert.fromJson);
    } catch (e) {
      throw RepositoryFailure(
        userFacingError(e, fallback: ErrorKeys.loadFailed),
      );
    }
  }

  @override
  Future<List<AuditAlert>> runAnomalyDetectors() async {
    try {
      await _dio.post('/audit/run-detectors');
    } catch (e) {
      throw RepositoryFailure(userFacingError(e, fallback: ErrorKeys.generic));
    }
    return getAuditAlerts();
  }

  @override
  Future<AuditAlert> resolveAlert(String id, {bool isResolved = true}) async {
    final response = await _dio.patch(
      '/audit/alerts/$id/resolve',
      data: {'is_resolved': isResolved},
    );
    if (response.data is! Map) {
      throw RepositoryFailure(ErrorKeys.invalidResponse);
    }
    return AuditAlert.fromJson(Map<String, dynamic>.from(response.data as Map));
  }

  @override
  Future<WeeklyAuditReport> getWeeklyReport({int weeksAgo = 0}) async {
    final response = await _dio.get(
      '/audit/weekly-report',
      queryParameters: {'weeks_ago': weeksAgo},
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
  Future<List<int>> exportWeeklyReport({
    String format = 'pdf',
    int weeksAgo = 0,
  }) async {
    final response = await _dio.get<List<int>>(
      '/audit/weekly-report/export',
      queryParameters: {'fmt': format, 'weeks_ago': weeksAgo},
      options: Options(responseType: ResponseType.bytes),
    );
    return response.data ?? <int>[];
  }

  @override
  Future<List<EntityHistoryItem>> getEntityHistory(
    String entity,
    String id,
  ) async {
    final response = await _dio.get('/history/$entity/$id');
    return _parsePage(response.data, EntityHistoryItem.fromJson);
  }
}
