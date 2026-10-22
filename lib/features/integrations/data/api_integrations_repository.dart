import '../../../core/network/api_client.dart';
import '../../../core/network/user_facing_error.dart';
import '../../../core/network/expiring_request_cache.dart';
import '../domain/integrations_models.dart';
import '../domain/integrations_repository.dart';
import '../../../core/error/app_failure.dart';

class ApiIntegrationsRepository implements IntegrationsRepository {
  final ApiClient _apiClient = ApiClient();
  final _statusCache = ExpiringRequestCache<List<IntegrationInfo>>();
  final _logsCache = ExpiringRequestCache<List<SyncLog>>();

  @override
  Future<List<IntegrationInfo>> getIntegrationsStatus({
    bool forceRefresh = false,
  }) => _statusCache.get(_fetchStatus, forceRefresh: forceRefresh);

  Future<List<IntegrationInfo>> _fetchStatus() async {
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
      throw RepositoryFailure(
        userFacingError(e, fallback: ErrorKeys.loadFailed),
      );
    }
  }

  @override
  Future<List<SyncLog>> getSyncLogs({bool forceRefresh = false}) =>
      _logsCache.get(_fetchLogs, forceRefresh: forceRefresh);

  Future<List<SyncLog>> _fetchLogs() async {
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
          finishedAt: map['finished_at'] != null
              ? DateTime.parse(map['finished_at'])
              : null,
          createdAt: DateTime.parse(
            map['created_at'] ?? DateTime.now().toIso8601String(),
          ),
        );
      }).toList();
    } catch (e) {
      throw RepositoryFailure(
        userFacingError(e, fallback: ErrorKeys.loadFailed),
      );
    }
  }

  @override
  Future<SyncResult> triggerSync(String system) async {
    try {
      final response = await _apiClient.dio.post('/integrations/sync/$system');
      final map = response.data as Map<String, dynamic>;
      _statusCache.invalidate();
      _logsCache.invalidate();

      return SyncResult(
        system: map['system'] ?? system,
        success: map['success'] ?? false,
        records: (map['records'] ?? 0) as int,
        message: map['message'] ?? '',
      );
    } catch (e) {
      throw RepositoryFailure(userFacingError(e, fallback: ErrorKeys.generic));
    }
  }

  @override
  Future<SmsTestResult> testSms(String phone) async {
    try {
      final response = await _apiClient.dio.post(
        '/integrations/sms/test',
        queryParameters: {'phone': phone},
      );
      final map = response.data as Map<String, dynamic>;
      return SmsTestResult.fromJson(map, phone);
    } catch (e) {
      throw RepositoryFailure(userFacingError(e, fallback: ErrorKeys.generic));
    }
  }

  @override
  Future<AiProbeResult> testAi() async {
    try {
      final response = await _apiClient.dio.post('/integrations/ai/test');
      final map = response.data as Map<String, dynamic>;
      return AiProbeResult.fromJson(map);
    } catch (e) {
      throw RepositoryFailure(userFacingError(e, fallback: ErrorKeys.generic));
    }
  }

  @override
  Future<TelegramLinkInfo> getTelegramLink() async {
    try {
      final response = await _apiClient.dio.get(
        '/integrations/telegram/link/me',
      );
      final map = response.data as Map<String, dynamic>;
      return TelegramLinkInfo.fromJson(map);
    } catch (e) {
      throw RepositoryFailure(
        userFacingError(e, fallback: ErrorKeys.loadFailed),
      );
    }
  }
}
