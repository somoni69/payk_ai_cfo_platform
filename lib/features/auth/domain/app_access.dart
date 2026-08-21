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
      AppCapability.finOps,
      AppCapability.reports,
    },
    UserRole.accountant => const <AppCapability>{
      AppCapability.dashboard,
      AppCapability.cash,
      AppCapability.finOps,
      AppCapability.reports,
    },
    UserRole.cashier => const <AppCapability>{
      AppCapability.cash,
      AppCapability.checklists,
      AppCapability.reports,
    },
    UserRole.hr => const <AppCapability>{AppCapability.tasks, AppCapability.hr},
    // No company finance summary (dashboard/cash/finOps/reports) — web parity.
    UserRole.marketer => const <AppCapability>{
      AppCapability.tasks,
      AppCapability.crm,
      AppCapability.marketing,
      AppCapability.strategy,
      AppCapability.notifications,
      AppCapability.checklists,
    },
    UserRole.viewer => const <AppCapability>{
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
            capability == AppCapability.checklists,
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
    '/fin-ops': AppCapability.finOps,
    '/reports': AppCapability.reports,
    '/audit': AppCapability.audit,
    '/backups': AppCapability.backups,
  };

  static AppCapability? capabilityForLocation(String location) {
    final path = Uri.tryParse(location)?.path ?? location;
    for (final entry in _pathCapabilities.entries) {
      if (path == entry.key || path.startsWith('${entry.key}/')) {
        return entry.value;
      }
    }
    return null;
  }

  static bool canOpen(UserRole role, String location) {
    final capability = capabilityForLocation(location);
    return capability == null || role.can(capability);
  }

  /// Prefer server [MyPermissions] when loaded; otherwise static [role] matrix.
  static bool canOpenEffective(
    UserRole role,
    String location, {
    MyPermissions? effective,
  }) {
    final capability = capabilityForLocation(location);
    if (capability == null) return true;
    if (effective == null) return role.can(capability);
    if (effective.isDirector) return true;
    if (capability == AppCapability.users ||
        capability == AppCapability.backups) {
      return effective.isDirector;
    }
    if (capability == AppCapability.notifications) return true;
    final key = PermissionModules.keyFor(capability);
    if (key == null) return true;
    return effective.can(key, PermAction.view);
  }
}
