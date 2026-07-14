import '../../../core/network/api_client.dart';
import '../domain/integrations_models.dart';
import '../domain/integrations_repository.dart';

class ApiIntegrationsRepository implements IntegrationsRepository {
  final ApiClient _apiClient = ApiClient();

  @override
  Future<List<IntegrationInfo>> getIntegrationsStatus() async {
    try {
      final response = await _apiClient.dio.get('/integrations/status');
      final list = response.data as List<dynamic>;

      return list.map((item) {
        final map = item as Map<String, dynamic>;
        return IntegrationInfo(
          system: map['system'] ?? '',
          name: map['name'] ?? '',
          available: map['available'] ?? false,
          canSync: map['can_sync'] ?? false,
        );
      }).toList();
    } catch (e) {
      throw Exception('Не удалось загрузить статус интеграций: ${e.toString()}');
    }
  }

  @override
  Future<List<SyncLog>> getSyncLogs() async {
    try {
      final response = await _apiClient.dio.get('/integrations/logs');
      final dynamic responseData = response.data;
      final List<dynamic> list = responseData is Map<String, dynamic>
          ? (responseData['items'] as List<dynamic>? ?? [])
          : (responseData as List<dynamic>? ?? []);

      return list.map((item) {
        final map = item as Map<String, dynamic>;
        return SyncLog(
          id: (map['id'] ?? '').toString(),
          system: map['system'] ?? '',
          direction: map['direction'] ?? 'inflow',
          success: map['success'] ?? false,
          records: (map['records'] ?? 0) as int,
          message: map['message'],
          finishedAt: map['finished_at'] != null ? DateTime.parse(map['finished_at']) : null,
          createdAt: DateTime.parse(map['created_at'] ?? DateTime.now().toIso8601String()),
        );
      }).toList();
    } catch (e) {
      throw Exception('Не удалось загрузить логи синхронизации: ${e.toString()}');
    }
  }

  @override
  Future<SyncResult> triggerSync(String system) async {
    try {
      final response = await _apiClient.dio.post('/integrations/sync/$system');
      final map = response.data as Map<String, dynamic>;

      return SyncResult(
        system: map['system'] ?? system,
        success: map['success'] ?? false,
        records: (map['records'] ?? 0) as int,
        message: map['message'] ?? '',
      );
    } catch (e) {
      throw Exception('Ошибка синхронизации: ${e.toString()}');
    }
  }
}
