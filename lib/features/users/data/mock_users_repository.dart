import '../domain/user_models.dart';
import '../domain/users_repository.dart';

class MockUsersRepository implements UsersRepository {
  final List<UserProfile> _users = [
    UserProfile(
      id: '1',
      fullName: 'Директор Компании',
      username: 'director',
      email: 'director@payk.tj',
      phone: '+992 93 123 4567',
      role: 'director',
      active: true,
      twoFactor: true,
      createdAt: DateTime(2026, 1, 1),
    ),
    UserProfile(
      id: '2',
      fullName: 'Главный Бухгалтер',
      username: 'accountant',
      email: 'accountant@payk.tj',
      phone: '+992 90 777 8888',
      role: 'accountant',
      active: true,
      twoFactor: false,
      createdAt: DateTime(2026, 2, 15),
    ),
    UserProfile(
      id: '3',
      fullName: 'Менеджер Продаж',
      username: 'sales',
      email: 'sales@payk.tj',
      phone: '+992 91 888 9999',
      role: 'seller',
      active: false,
      twoFactor: false,
      createdAt: DateTime(2026, 3, 10),
    ),
  ];

  @override
  Future<List<UserProfile>> getUsers({String? search}) async {
    await Future.delayed(const Duration(milliseconds: 200));
    if (search != null && search.isNotEmpty) {
      final term = search.toLowerCase();
      return _users
          .where(
            (u) =>
                u.fullName.toLowerCase().contains(term) ||
                u.username.toLowerCase().contains(term),
          )
          .toList();
    }
    return _users;
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
    await Future.delayed(const Duration(milliseconds: 200));
    final user = UserProfile(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      fullName: fullName,
      username: username,
      email: email,
      phone: phone,
      role: role,
      active: active,
      twoFactor: twoFactor,
      createdAt: DateTime.now(),
    );
    _users.add(user);
    return user;
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
    await Future.delayed(const Duration(milliseconds: 200));
    final idx = _users.indexWhere((u) => u.id == id);
    if (idx != -1) {
      final existing = _users[idx];
      final updated = UserProfile(
        id: existing.id,
        fullName: fullName ?? existing.fullName,
        username: existing.username,
        email: email ?? existing.email,
        phone: phone ?? existing.phone,
        role: role ?? existing.role,
        active: active ?? existing.active,
        twoFactor: twoFactor ?? existing.twoFactor,
        createdAt: existing.createdAt,
      );
      _users[idx] = updated;
      return updated;
    }
    throw Exception('Пользователь не найден');
  }

  @override
  Future<void> deleteUser(String id) async {
    await Future.delayed(const Duration(milliseconds: 200));
    _users.removeWhere((u) => u.id == id);
  }
}
