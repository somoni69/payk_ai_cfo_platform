import 'audit_models.dart';

abstract class AuditRepository {
  Future<List<AuditLog>> getAuditLogs({
    String? entity,
    String? action,
    DateTime? dateFrom,
    DateTime? dateTo,
  });
  Future<List<AuditAlert>> getAuditAlerts({bool? resolved});
  Future<List<AuditAlert>> runAnomalyDetectors();
  Future<AuditAlert> resolveAlert(String id, {bool isResolved = true});
  Future<WeeklyAuditReport> getWeeklyReport({DateTime? weekStart});
  Future<List<int>> exportWeeklyReport({String format = 'pdf'});
  Future<List<EntityHistoryItem>> getEntityHistory(String entity, String id);
}
