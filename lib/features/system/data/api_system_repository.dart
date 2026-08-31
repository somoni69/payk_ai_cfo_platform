import '../../../core/network/api_client.dart';
import '../../../core/network/user_facing_error.dart';
import '../domain/system_repository.dart';

class ApiSystemRepository implements SystemRepository {
  ApiSystemRepository({ApiClient? client}) : _client = client ?? ApiClient();

  final ApiClient _client;

  @override
  Future<List<BackupFile>> listBackups() async {
    try {
      final response = await _client.dio.get('/system/backups');
      final list = response.data is List ? response.data as List : const [];
      return list.whereType<Map>().map((raw) {
        final m = Map<String, dynamic>.from(raw);
        return BackupFile(
          name: (m['name'] ?? '').toString(),
          size: (m['size'] as num?)?.toInt() ?? 0,
        );
      }).toList();
    } catch (e) {
      throw Exception(userFacingError(e, fallback: ErrorKeys.loadFailed));
    }
  }

  @override
  Future<String> createBackup() async {
    try {
      final response = await _client.dio.post(
        '/system/backup',
        options: ApiClient.longRunningOptions(),
      );
      final data = response.data is Map
          ? Map<String, dynamic>.from(response.data as Map)
          : const <String, dynamic>{};
      return (data['file'] ?? '').toString();
    } catch (e) {
      throw Exception(userFacingError(e, fallback: ErrorKeys.saveFailed));
    }
  }
}
