import 'user_models.dart';

abstract class UsersRepository {
  Future<List<UserProfile>> getUsers({String? search});

  Future<UserProfile> createUser({
    required String fullName,
    required String username,
    String? email,
    String? phone,
    required String role,
    required String password,
    required bool active,
    required bool twoFactor,
  });

  Future<UserProfile> updateUser(
    String id, {
    String? fullName,
    String? email,
    String? phone,
    String? role,
    String? password,
    bool? active,
    bool? twoFactor,
  });

  Future<void> deleteUser(String id);

  /// Full permission matrix (`GET /permissions`) — director only.
  Future<PermissionMatrix> getPermissionMatrix();

  /// Auto-save one or more cells (`PUT /permissions`).
  Future<PermissionMatrix> updatePermissions(List<PermissionCell> cells);
}
