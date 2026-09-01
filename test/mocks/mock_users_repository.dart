import 'package:payk_ai_cfo_platform/features/users/domain/user_models.dart';
import 'package:payk_ai_cfo_platform/features/users/domain/users_repository.dart';

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
    _users.removeWhere((u) => u.id == id);
  }

  @override
  Future<PermissionMatrix> getPermissionMatrix() async {
    const modules = [
      'dashboard',
      'cash',
      'reports',
      'finance-ops',
      'finance',
      'warehouse',
      'crm',
      'hr',
      'tasks',
      'my-tasks',
      'checklists',
      'audit',
      'legal',
      'marketing',
      'strategy',
      'integrations',
      'branches',
    ];
    const roles = ['manager', 'accountant', 'cashier', 'hr', 'viewer'];
    final cells = <PermissionCell>[];
    for (final role in roles) {
      for (final module in modules) {
        cells.add(
          PermissionCell(
            role: role,
            module: module,
            canView: true,
            canCreate: role != 'viewer',
            canEdit: role != 'viewer',
            canDelete: role == 'manager' || role == 'accountant',
            canAction: role != 'viewer',
          ),
        );
      }
    }
    return PermissionMatrix(
      modules: modules,
      roles: roles,
      perms: const ['view', 'create', 'edit', 'delete', 'action'],
      cells: cells,
    );
  }

  @override
  Future<PermissionMatrix> updatePermissions(List<PermissionCell> cells) async {
    final base = await getPermissionMatrix();
    final map = base.cellMap;
    for (final c in cells) {
      map[PermissionCell.keyOf(c.role, c.module)] = c;
    }
    return PermissionMatrix(
      modules: base.modules,
      roles: base.roles,
      perms: base.perms,
      cells: map.values.toList(),
    );
  }
}
