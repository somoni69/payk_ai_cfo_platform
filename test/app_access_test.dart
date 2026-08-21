import 'package:flutter_test/flutter_test.dart';
import 'package:payk_ai_cfo_platform/features/auth/bloc/auth_state.dart';
import 'package:payk_ai_cfo_platform/features/auth/domain/app_access.dart';

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
    expect(UserRole.cashier.canManage(AppCapability.dashboard), isFalse);
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
