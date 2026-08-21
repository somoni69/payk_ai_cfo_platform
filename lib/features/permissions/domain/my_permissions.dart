import '../../auth/domain/app_access.dart';

/// One module's effective rights from `GET /permissions/me`.
class ModulePerm {
  final bool view;
  final bool create;
  final bool edit;
  final bool delete;
  final bool canAction;

  const ModulePerm({
    this.view = false,
    this.create = false,
    this.edit = false,
    this.delete = false,
    this.canAction = false,
  });

  factory ModulePerm.fromJson(Map<String, dynamic> json) {
    return ModulePerm(
      view: json['view'] == true,
      create: json['create'] == true,
      edit: json['edit'] == true,
      delete: json['delete'] == true,
      canAction: json['action'] == true,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is ModulePerm &&
      view == other.view &&
      create == other.create &&
      edit == other.edit &&
      delete == other.delete &&
      canAction == other.canAction;

  @override
  int get hashCode => Object.hash(view, create, edit, delete, canAction);

  bool allows(PermAction requested) => switch (requested) {
    PermAction.view => view,
    PermAction.create => create,
    PermAction.edit => edit,
    PermAction.delete => delete,
    PermAction.action => canAction,
  };
}

enum PermAction { view, create, edit, delete, action }

/// Effective permissions for the signed-in user (web `MyPermissions` parity).
class MyPermissions {
  final String role;
  final bool isDirector;

  /// Marketer-style roles: hide money columns/tabs (backend zeros amounts).
  final bool hidesMoney;
  final Map<String, ModulePerm> modules;

  const MyPermissions({
    required this.role,
    required this.isDirector,
    this.hidesMoney = false,
    this.modules = const {},
  });

  factory MyPermissions.fromJson(Map<String, dynamic> json) {
    final rawModules = json['modules'];
    final modules = <String, ModulePerm>{};
    if (rawModules is Map) {
      rawModules.forEach((key, value) {
        if (value is Map) {
          modules[key.toString()] = ModulePerm.fromJson(
            Map<String, dynamic>.from(value),
          );
        }
      });
    }
    return MyPermissions(
      role: (json['role'] ?? '').toString(),
      isDirector: json['is_director'] == true || json['isDirector'] == true,
      hidesMoney: json['hides_money'] == true || json['hidesMoney'] == true,
      modules: modules,
    );
  }

  @override
  bool operator ==(Object other) {
    if (other is! MyPermissions) return false;
    if (role != other.role ||
        isDirector != other.isDirector ||
        hidesMoney != other.hidesMoney ||
        modules.length != other.modules.length) {
      return false;
    }
    for (final entry in modules.entries) {
      if (other.modules[entry.key] != entry.value) return false;
    }
    return true;
  }

  @override
  int get hashCode => Object.hash(
    role,
    isDirector,
    hidesMoney,
    Object.hashAll(
      modules.entries.map((entry) => Object.hash(entry.key, entry.value)),
    ),
  );

  bool can(String module, [PermAction action = PermAction.view]) {
    if (isDirector) return true;
    // Users module is director-only (web USERS_NAV).
    if (module == 'users') return isDirector;
    final cell = modules[module];
    if (cell == null) return false;
    return cell.allows(action);
  }
}

/// Maps app navigation capabilities ↔ backend matrix module keys.
abstract final class PermissionModules {
  static String? keyFor(AppCapability capability) => switch (capability) {
    AppCapability.network =>
      null, // Global multistore hub — always accessible when authenticated
    AppCapability.dashboard => 'dashboard',
    // Dashboard finance tabs share "finance" on backend.
    AppCapability.cash => 'cash',
    AppCapability.tasks => 'tasks',
    AppCapability.warehouse => 'warehouse',
    // No dedicated notifications module — treat as always open when authenticated.
    AppCapability.notifications => null,
    AppCapability.hr => 'hr',
    AppCapability.crm => 'crm',
    AppCapability.strategy => 'strategy',
    AppCapability.legal => 'legal',
    AppCapability.marketing => 'marketing',
    AppCapability.integrations => 'integrations',
    AppCapability.users => 'users',
    AppCapability.branches => 'branches',
    AppCapability.checklists => 'checklists',
    AppCapability.finOps => 'finance-ops',
    AppCapability.reports => 'reports',
    AppCapability.audit => 'audit',
    AppCapability.backups => null, // system — director via isDirector
  };
}
