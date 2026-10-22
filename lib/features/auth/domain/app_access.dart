import '../../permissions/domain/my_permissions.dart';
import 'user_role.dart';

/// Application modules that can be protected at navigation boundaries.
enum AppCapability {
  network,
  dashboard,
  cash,
  tasks,
  warehouse,
  notifications,
  hr,
  crm,
  strategy,
  legal,
  marketing,
  integrations,
  users,
  branches,
  checklists,
  playroom,
  finOps,
  reports,
  audit,
  backups,
}

/// Central client-side role matrix.
///
/// The backend remains the authority for every read and mutation. This matrix
/// prevents accidental navigation and hides unavailable entry points; it must
/// never be treated as a replacement for server-side RBAC.
extension UserRoleAccess on UserRole {
  Set<AppCapability> get capabilities => switch (this) {
    UserRole.owner ||
    UserRole.director => const <AppCapability>{...AppCapability.values},
    UserRole.manager => const <AppCapability>{
      AppCapability.network,
      AppCapability.dashboard,
      AppCapability.cash,
      AppCapability.tasks,
      AppCapability.warehouse,
      AppCapability.notifications,
      AppCapability.hr,
      AppCapability.crm,
      AppCapability.strategy,
      AppCapability.legal,
      AppCapability.marketing,
      AppCapability.branches,
      AppCapability.checklists,
      AppCapability.playroom,
      AppCapability.finOps,
      AppCapability.reports,
    },
    UserRole.accountant => const <AppCapability>{
      AppCapability.network,
      AppCapability.dashboard,
      AppCapability.cash,
      AppCapability.playroom,
      AppCapability.finOps,
      AppCapability.reports,
    },
    UserRole.cashier => const <AppCapability>{
      AppCapability.network,
      AppCapability.cash,
      AppCapability.checklists,
      AppCapability.playroom,
      AppCapability.reports,
    },
    UserRole.hr => const <AppCapability>{
      AppCapability.network,
      AppCapability.tasks,
      AppCapability.hr,
    },
    // No company finance summary (dashboard/cash/finOps/reports) — web parity.
    UserRole.marketer => const <AppCapability>{
      AppCapability.network,
      AppCapability.tasks,
      AppCapability.crm,
      AppCapability.marketing,
      AppCapability.strategy,
      AppCapability.notifications,
      AppCapability.checklists,
    },
    UserRole.viewer => const <AppCapability>{
      AppCapability.network,
      AppCapability.dashboard,
      AppCapability.cash,
      AppCapability.tasks,
      AppCapability.warehouse,
      AppCapability.notifications,
      AppCapability.hr,
      AppCapability.crm,
      AppCapability.strategy,
      AppCapability.legal,
      AppCapability.marketing,
      AppCapability.branches,
      AppCapability.checklists,
      AppCapability.playroom,
      AppCapability.finOps,
      AppCapability.reports,
    },
  };

  bool can(AppCapability capability) => capabilities.contains(capability);

  /// Whether this role may perform mutations inside an accessible module.
  /// The backend still validates every operation independently.
  bool canManage(AppCapability capability) {
    if (!can(capability)) return false;
    return switch (this) {
      UserRole.owner || UserRole.director || UserRole.manager => true,
      UserRole.accountant =>
        capability == AppCapability.cash ||
            capability == AppCapability.finOps ||
            capability == AppCapability.reports,
      UserRole.cashier =>
        capability == AppCapability.cash ||
            capability == AppCapability.reports ||
            capability == AppCapability.checklists ||
            capability == AppCapability.playroom,
      UserRole.hr =>
        capability == AppCapability.tasks || capability == AppCapability.hr,
      UserRole.marketer =>
        capability == AppCapability.marketing ||
            capability == AppCapability.crm ||
            capability == AppCapability.strategy ||
            capability == AppCapability.tasks ||
            capability == AppCapability.checklists,
      UserRole.viewer => false,
    };
  }

  /// Create/update (web `can(module, "create"|"update")` until matrix is wired).
  bool canWrite(AppCapability capability) => canManage(capability);

  /// Destructive delete (web `can(module, "delete")`).
  /// Same role set as [canManage] for now; director/manager for CRM.
  bool canDelete(AppCapability capability) => canManage(capability);

  String get landingLocation => switch (this) {
    // Owner starts in the network root — store modules are empty until enter.
    UserRole.owner => '/network',
    UserRole.cashier => '/cash',
    UserRole.hr => '/tasks',
    // Dashboard shows revenue — marketer starts in marketing (web parity).
    UserRole.marketer => '/marketing',
    UserRole.director ||
    UserRole.manager ||
    UserRole.accountant ||
    UserRole.viewer => '/dashboard',
  };
}

abstract final class AppAccess {
  static const Map<String, AppCapability> _pathCapabilities = {
    '/network': AppCapability.network,
    '/dashboard': AppCapability.dashboard,
    '/cash': AppCapability.cash,
    '/tasks': AppCapability.tasks,
    '/warehouse': AppCapability.warehouse,
    '/notifications': AppCapability.notifications,
    '/inbox': AppCapability.notifications,
    '/hr': AppCapability.hr,
    '/crm': AppCapability.crm,
    // Meta chats share CRM rights (web MODULE_NAV).
    '/meta': AppCapability.crm,
    '/strategy': AppCapability.strategy,
    '/legal': AppCapability.legal,
    '/marketing': AppCapability.marketing,
    '/integrations': AppCapability.integrations,
    '/users': AppCapability.users,
    '/branches': AppCapability.branches,
    '/checklists': AppCapability.checklists,
    '/playroom': AppCapability.playroom,
    '/fin-ops': AppCapability.finOps,
    '/reports': AppCapability.reports,
    '/audit': AppCapability.audit,
    '/backups': AppCapability.backups,
  };

  static AppCapability? capabilityForLocation(String location) {
    final path = _screenPath(location);
    for (final entry in _pathCapabilities.entries) {
      if (path == entry.key || path.startsWith('${entry.key}/')) {
        return entry.value;
      }
    }
    return null;
  }

  static bool _isLeads(String location) {
    final path = _screenPath(location);
    return path == '/leads' || path.startsWith('/leads/');
  }

  static bool _isModules(String location) {
    final path = _screenPath(location);
    return path == '/modules' || path.startsWith('/modules/');
  }

  static String _pathOf(String location) {
    return Uri.tryParse(location)?.path ?? location;
  }

  /// «Ещё» держит сеть, заявки и модули своими дочерними экранами,
  /// чтобы жест назад возвращал в меню, а не закрывал приложение.
  static String _screenPath(String location) {
    final path = _pathOf(location);
    const names = ['network', 'leads', 'modules'];
    for (final name in names) {
      final prefix = '/more/$name';
      if (path == prefix || path.startsWith('$prefix/')) {
        return '/$name${path.substring(prefix.length)}';
      }
    }
    return path;
  }

  /// «Сеть», «Заявки», «Модули» и настройки работают без выбранного магазина.
  /// Вкладка «Ещё» в корне сети не раздел: язык и выход открываются с «Настроек».
  static bool isOwnerNetworkPath(String location) {
    final path = _screenPath(location);
    return path == '/network' ||
        path.startsWith('/network/') ||
        path == '/leads' ||
        path.startsWith('/leads/') ||
        path == '/modules' ||
        path.startsWith('/modules/') ||
        path == '/settings' ||
        path.startsWith('/settings/') ||
        path.startsWith('/more/');
  }

  /// Куда увести, если текущий раздел магазину не подключён.
  static String deniedTarget(
    UserRole role,
    MyPermissions? effective, {
    bool permissionsUnavailable = false,
  }) {
    if (permissionsUnavailable) return '/more';
    const order = ['/dashboard', '/cash', '/tasks', '/warehouse', '/more'];
    for (final path in order) {
      if (canOpenEffective(role, path, effective: effective)) return path;
    }
    return '/more';
  }

  static bool _sectionAllows(
    MyPermissions effective,
    String location,
    AppCapability? capability,
  ) {
    final sections = effective.sections;
    if (sections == null) return true;
    final path = _screenPath(location);
    if (path == '/tasks' || path.startsWith('/tasks/')) {
      return sections.contains('tasks') || sections.contains('my-tasks');
    }
    if (path == '/meta' || path.startsWith('/meta/')) {
      return sections.contains('meta');
    }
    if (capability == null ||
        capability == AppCapability.users ||
        capability == AppCapability.notifications ||
        capability == AppCapability.network ||
        capability == AppCapability.backups) {
      return true;
    }
    final key = PermissionModules.keyFor(capability);
    if (key == null || key == 'users') return true;
    return sections.contains(key);
  }

  /// Владелец в корне сети: разделы магазина пустые, возвращаем на «Сеть».
  static String? ownerRootRedirect(
    UserRole role,
    int? storeId,
    String location,
  ) {
    if (role != UserRole.owner || storeId != null) return null;
    final path = _pathOf(location);
    if (path == '/login' || path == '/splash' || isOwnerNetworkPath(location)) {
      return null;
    }
    return '/network';
  }

  static bool canOpen(UserRole role, String location) {
    if (_isLeads(location) || _isModules(location)) {
      return role == UserRole.owner;
    }
    final capability = capabilityForLocation(location);
    return capability == null || role.can(capability);
  }

  /// Prefer server [MyPermissions] when loaded; otherwise static [role] matrix.
  static bool canOpenEffective(
    UserRole role,
    String location, {
    MyPermissions? effective,
    bool permissionsUnavailable = false,
  }) {
    if (_isLeads(location) || _isModules(location)) {
      return role == UserRole.owner;
    }
    final capability = capabilityForLocation(location);
    if (effective != null && !_sectionAllows(effective, location, capability)) {
      return false;
    }
    if (capability == null) return true;
    if (capability == AppCapability.notifications ||
        capability == AppCapability.network) {
      return true;
    }
    if (permissionsUnavailable) return false;
    if (effective == null) return role.can(capability);
    if (effective.isDirector) return true;
    if (capability == AppCapability.users ||
        capability == AppCapability.backups) {
      return effective.isDirector;
    }
    final key = PermissionModules.keyFor(capability);
    if (key == null) return true;
    return effective.can(key, PermAction.view);
  }
}
