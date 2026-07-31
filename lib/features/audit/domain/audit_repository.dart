import 'audit_models.dart';

abstract class AuditRepository {
  Future<List<AuditLog>> getAuditLogs();
  Future<List<AuditAlert>> getAuditAlerts();
  Future<List<AuditAlert>> runAnomalyDetectors();
}
