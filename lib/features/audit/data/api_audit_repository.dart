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

  @override
  Future<List<AuditLog>> getAuditLogs() async {
    try {
      final response = await _client.dio.get('/api/v1/audit/logs');
      if (response.statusCode == 200 && response.data is List) {
        return (response.data as List)
            .map((e) => AuditLog.fromJson(e as Map<String, dynamic>))
            .toList();
      }
    } catch (_) {}
    return List.from(_mockLogs);
  }

  @override
  Future<List<AuditAlert>> getAuditAlerts() async {
    try {
      final response = await _client.dio.get('/api/v1/audit/alerts');
      if (response.statusCode == 200 && response.data is List) {
        return (response.data as List)
            .map((e) => AuditAlert.fromJson(e as Map<String, dynamic>))
            .toList();
      }
    } catch (_) {}
    return List.from(_mockAlerts);
  }

  @override
  Future<List<AuditAlert>> runAnomalyDetectors() async {
    try {
      final response = await _client.dio.post('/api/v1/audit/detectors/run');
      if (response.statusCode == 200 && response.data is List) {
        return (response.data as List)
            .map((e) => AuditAlert.fromJson(e as Map<String, dynamic>))
            .toList();
      }
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
}
