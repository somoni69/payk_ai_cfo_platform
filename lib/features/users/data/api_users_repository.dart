import '../../../core/network/api_client.dart';
import '../domain/user_models.dart';
import '../domain/users_repository.dart';

class ApiUsersRepository implements UsersRepository {
  final ApiClient _apiClient = ApiClient();

  @override
  Future<List<UserProfile>> getUsers({String? search}) async {
    try {
      final queryParams = <String, dynamic>{};
      if (search != null && search.isNotEmpty) {
        queryParams['search'] = search;
      }

      final response = await _apiClient.dio.get(
        '/users',
        queryParameters: queryParams,
      );
      final dynamic responseData = response.data;
      final List<dynamic> list = responseData is Map<String, dynamic>
          ? (responseData['items'] as List<dynamic>? ?? [])
          : (responseData as List<dynamic>? ?? []);

      return list.map((item) {
        final map = item as Map<String, dynamic>;
        return UserProfile(
          id: (map['id'] ?? '').toString(),
          fullName: map['full_name'] ?? '',
          username: map['username'] ?? '',
          email: map['email'],
          phone: map['phone'],
          role: map['role'] ?? 'viewer',
          active: map['active'] ?? true,
          twoFactor: map['two_factor'] ?? false,
          createdAt: DateTime.parse(
            map['created_at'] ?? DateTime.now().toIso8601String(),
          ),
        );
      }).toList();
    } catch (e) {
      throw Exception('Не удалось загрузить пользователей: ${e.toString()}');
    }
  }

  @override
  Future<UserProfile> createUser({
    required String fullName,
    required String username,
    String? email,
    String? phone,
    required String role,
    required String password,
    required bool active,
    required bool twoFactor,
  }) async {
    try {
      final payload = {
        'full_name': fullName,
        'username': username,
        'email': email,
        'phone': phone,
        'role': role,
        'password': password,
        'active': active,
        'two_factor': twoFactor,
      };

      final response = await _apiClient.dio.post('/users', data: payload);
      final map = response.data as Map<String, dynamic>;

      return UserProfile(
        id: (map['id'] ?? '').toString(),
        fullName: map['full_name'] ?? '',
        username: map['username'] ?? '',
        email: map['email'],
        phone: map['phone'],
        role: map['role'] ?? role,
        active: map['active'] ?? active,
        twoFactor: map['two_factor'] ?? twoFactor,
        createdAt: DateTime.parse(
          map['created_at'] ?? DateTime.now().toIso8601String(),
        ),
      );
    } catch (e) {
      throw Exception('Не удалось создать пользователя: ${e.toString()}');
    }
  }

  @override
  Future<UserProfile> updateUser(
    String id, {
    String? fullName,
    String? email,
    String? phone,
    String? role,
    String? password,
    bool? active,
    bool? twoFactor,
  }) async {
    try {
      final payload = <String, dynamic>{};
      if (fullName != null) payload['full_name'] = fullName;
      if (email != null) payload['email'] = email;
      if (phone != null) payload['phone'] = phone;
      if (role != null) payload['role'] = role;
      if (password != null && password.isNotEmpty) {
        payload['password'] = password;
      }
      if (active != null) payload['active'] = active;
      if (twoFactor != null) payload['two_factor'] = twoFactor;

      final response = await _apiClient.dio.patch('/users/$id', data: payload);
      final map = response.data as Map<String, dynamic>;

      return UserProfile(
        id: (map['id'] ?? '').toString(),
        fullName: map['full_name'] ?? '',
        username: map['username'] ?? '',
        email: map['email'],
        phone: map['phone'],
        role: map['role'] ?? 'viewer',
        active: map['active'] ?? true,
        twoFactor: map['two_factor'] ?? false,
        createdAt: DateTime.parse(
          map['created_at'] ?? DateTime.now().toIso8601String(),
        ),
      );
    } catch (e) {
      throw Exception('Не удалось обновить пользователя: ${e.toString()}');
    }
  }

  @override
  Future<void> deleteUser(String id) async {
    try {
      await _apiClient.dio.delete('/users/$id');
    } catch (e) {
      throw Exception('Не удалось удалить пользователя: ${e.toString()}');
    }
  }
}
