import '../../../core/network/api_client.dart';
import '../../../core/network/user_facing_error.dart';
import '../domain/my_permissions.dart';
import '../domain/permissions_repository.dart';

class ApiPermissionsRepository implements PermissionsRepository {
  final ApiClient _apiClient;

  ApiPermissionsRepository({ApiClient? apiClient})
    : _apiClient = apiClient ?? ApiClient();

  @override
  Future<MyPermissions> getMyPermissions() async {
    try {
      final response = await _apiClient.dio.get<dynamic>('/permissions/me');
      final body = response.data is Map
          ? Map<String, dynamic>.from(response.data as Map)
          : <String, dynamic>{};
      return MyPermissions.fromJson(body);
    } catch (e) {
      throw Exception(userFacingError(e, fallback: ErrorKeys.loadFailed));
    }
  }
}
