import '../bloc/auth_state.dart';

/// Application modules that can be protected at navigation boundaries.
enum AppCapability {
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
  backups,
}

/// Central client-side role matrix.
///
/// The backend remains the authority for every read and mutation. This matrix
/// prevents accidental navigation and hides unavailable entry points; it must
/// never be treated as a replacement for server-side RBAC.
extension UserRoleAccess on UserRole {
  Set<AppCapability> get capabilities => switch (this) {
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
    },
    UserRole.accountant => const <AppCapability>{
      AppCapability.dashboard,
      AppCapability.cash,
    },
    UserRole.cashier => const <AppCapability>{AppCapability.cash},
    UserRole.hr => const <AppCapability>{AppCapability.tasks, AppCapability.hr},
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
    },
  };

  bool can(AppCapability capability) => capabilities.contains(capability);

  /// Whether this role may perform mutations inside an accessible module.
  /// The backend still validates every operation independently.
  bool canManage(AppCapability capability) {
    if (!can(capability)) return false;
    return switch (this) {
      UserRole.director || UserRole.manager => true,
      UserRole.accountant ||
      UserRole.cashier => capability == AppCapability.cash,
      UserRole.hr =>
        capability == AppCapability.tasks || capability == AppCapability.hr,
      UserRole.viewer => false,
    };
  }

  String get landingLocation => switch (this) {
    UserRole.cashier => '/cash',
    UserRole.hr => '/tasks',
    UserRole.director ||
    UserRole.manager ||
    UserRole.accountant ||
    UserRole.viewer => '/dashboard',
  };
}

abstract final class AppAccess {
  static const Map<String, AppCapability> _pathCapabilities = {
    '/dashboard': AppCapability.dashboard,
    '/cash': AppCapability.cash,
    '/tasks': AppCapability.tasks,
    '/warehouse': AppCapability.warehouse,
    '/notifications': AppCapability.notifications,
    '/hr': AppCapability.hr,
    '/crm': AppCapability.crm,
    '/strategy': AppCapability.strategy,
    '/legal': AppCapability.legal,
    '/marketing': AppCapability.marketing,
    '/integrations': AppCapability.integrations,
    '/users': AppCapability.users,
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
}
