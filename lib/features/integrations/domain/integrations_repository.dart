import 'integrations_models.dart';

abstract class IntegrationsRepository {
  Future<List<IntegrationInfo>> getIntegrationsStatus();
  Future<List<SyncLog>> getSyncLogs();
  Future<SyncResult> triggerSync(String system);
}
