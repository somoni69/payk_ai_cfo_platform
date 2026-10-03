import 'package:flutter_test/flutter_test.dart';
import 'package:payk_ai_cfo_platform/features/auth/bloc/auth_state.dart';
import 'package:payk_ai_cfo_platform/features/auth/domain/app_access.dart';
import 'package:payk_ai_cfo_platform/features/permissions/domain/my_permissions.dart';

void main() {
  test('every role has an accessible landing route', () {
    for (final role in UserRole.values) {
      expect(
        AppAccess.canOpen(role, role.landingLocation),
        isTrue,
        reason: '${role.name} must be able to open its landing route',
      );
    }
  });

  test('director and owner have system administration access', () {
    for (final role in UserRole.values) {
      final hasAccess = role == UserRole.director || role == UserRole.owner;
      expect(AppAccess.canOpen(role, '/users'), hasAccess);
      expect(AppAccess.canOpen(role, '/integrations'), hasAccess);
    }
  });

  test('cashier and accountant are restricted to their financial scope', () {
    expect(AppAccess.canOpen(UserRole.cashier, '/cash'), isTrue);
    expect(AppAccess.canOpen(UserRole.cashier, '/dashboard'), isFalse);
    expect(AppAccess.canOpen(UserRole.cashier, '/hr'), isFalse);

    expect(AppAccess.canOpen(UserRole.accountant, '/dashboard'), isTrue);
    expect(AppAccess.canOpen(UserRole.accountant, '/cash'), isTrue);
    expect(AppAccess.canOpen(UserRole.accountant, '/tasks'), isFalse);
  });

  test('HR role is restricted to HR and task modules', () {
    expect(AppAccess.canOpen(UserRole.hr, '/hr'), isTrue);
    expect(AppAccess.canOpen(UserRole.hr, '/tasks'), isTrue);
    expect(AppAccess.canOpen(UserRole.hr, '/cash'), isFalse);
    expect(AppAccess.canOpen(UserRole.hr, '/crm'), isFalse);
  });

  test('viewer can read business modules but not system settings', () {
    expect(AppAccess.canOpen(UserRole.viewer, '/dashboard'), isTrue);
    expect(AppAccess.canOpen(UserRole.viewer, '/warehouse'), isTrue);
    expect(AppAccess.canOpen(UserRole.viewer, '/marketing'), isTrue);
    expect(AppAccess.canOpen(UserRole.viewer, '/users'), isFalse);
  });

  test('mutation permissions are fail-closed for read-only roles', () {
    for (final capability in AppCapability.values) {
      expect(
        UserRole.viewer.canManage(capability),
        isFalse,
        reason: 'viewer must not mutate ${capability.name}',
      );
    }

    expect(UserRole.cashier.canManage(AppCapability.cash), isTrue);
    expect(UserRole.cashier.canManage(AppCapability.playroom), isTrue);
    expect(UserRole.cashier.canManage(AppCapability.dashboard), isFalse);
    expect(UserRole.accountant.can(AppCapability.playroom), isTrue);
    expect(UserRole.accountant.canManage(AppCapability.playroom), isFalse);
    expect(UserRole.viewer.can(AppCapability.playroom), isTrue);
    expect(UserRole.hr.can(AppCapability.playroom), isFalse);
    expect(UserRole.marketer.can(AppCapability.playroom), isFalse);
    expect(AppAccess.canOpen(UserRole.owner, '/leads'), isTrue);
    expect(AppAccess.canOpen(UserRole.owner, '/modules'), isTrue);
    expect(AppAccess.canOpen(UserRole.director, '/modules'), isFalse);
    expect(AppAccess.canOpen(UserRole.director, '/leads'), isFalse);
    expect(AppAccess.canOpen(UserRole.cashier, '/playroom'), isTrue);
    expect(AppAccess.canOpen(UserRole.hr, '/playroom'), isFalse);
    expect(
      AppAccess.canOpenEffective(
        UserRole.director,
        '/leads',
        effective: const MyPermissions(role: 'director', isDirector: true),
      ),
      isFalse,
    );
    expect(
      AppAccess.canOpenEffective(
        UserRole.owner,
        '/leads',
        effective: const MyPermissions(role: 'owner', isDirector: true),
      ),
      isTrue,
    );
    expect(
      AppAccess.ownerRootRedirect(UserRole.owner, null, '/cash'),
      '/network',
    );
    expect(
      AppAccess.ownerRootRedirect(UserRole.owner, null, '/dashboard'),
      '/network',
    );
    expect(AppAccess.ownerRootRedirect(UserRole.owner, null, '/leads'), isNull);
    expect(
      AppAccess.ownerRootRedirect(UserRole.owner, null, '/network'),
      isNull,
    );
    expect(AppAccess.ownerRootRedirect(UserRole.owner, null, '/more'), isNull);
    expect(AppAccess.ownerRootRedirect(UserRole.owner, 4, '/cash'), isNull);
    expect(
      AppAccess.ownerRootRedirect(UserRole.director, null, '/cash'),
      isNull,
    );
    expect(
      AppAccess.ownerRootRedirect(UserRole.owner, null, '/modules'),
      isNull,
    );
    const cashOnly = MyPermissions(
      role: 'director',
      isDirector: true,
      sections: ['cash'],
    );
    expect(
      AppAccess.canOpenEffective(UserRole.director, '/hr', effective: cashOnly),
      isFalse,
    );
    expect(
      AppAccess.canOpenEffective(UserRole.owner, '/cash', effective: cashOnly),
      isTrue,
    );
    expect(
      AppAccess.canOpenEffective(
        UserRole.director,
        '/meta',
        effective: cashOnly,
      ),
      isFalse,
    );
    expect(AppAccess.deniedTarget(UserRole.director, cashOnly), '/cash');
    expect(UserRole.accountant.canManage(AppCapability.cash), isTrue);
    expect(UserRole.hr.canManage(AppCapability.tasks), isTrue);
    expect(UserRole.hr.canManage(AppCapability.hr), isTrue);
    expect(UserRole.hr.canManage(AppCapability.crm), isFalse);
    expect(UserRole.manager.canManage(AppCapability.marketing), isTrue);
  });
  test('nested routes inherit the capability of their module', () {
    expect(
      AppAccess.capabilityForLocation('/users/42/edit?tab=permissions'),
      AppCapability.users,
    );
    expect(AppAccess.canOpen(UserRole.manager, '/users/42/edit'), isFalse);
    expect(AppAccess.capabilityForLocation('/more'), isNull);
  });
}
