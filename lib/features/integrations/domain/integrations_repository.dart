import 'integrations_models.dart';

abstract class IntegrationsRepository {
  Future<List<IntegrationInfo>> getIntegrationsStatus({
    bool forceRefresh = false,
  });
  Future<List<SyncLog>> getSyncLogs({bool forceRefresh = false});
  Future<SyncResult> triggerSync(String system);
}
