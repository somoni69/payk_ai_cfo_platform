import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:payk_ai_cfo_platform/features/auth/domain/app_access.dart';
import 'package:payk_ai_cfo_platform/features/auth/domain/user_role.dart';
import 'package:payk_ai_cfo_platform/features/permissions/cubit/permissions_cubit.dart';
import 'package:payk_ai_cfo_platform/features/permissions/domain/my_permissions.dart';
import 'package:payk_ai_cfo_platform/features/permissions/domain/permissions_repository.dart';

class MockPermissionsRepository implements PermissionsRepository {
  MyPermissions? permissionsToReturn;
  bool shouldThrow = false;
  int getMyPermissionsCallCount = 0;

  @override
  Future<MyPermissions> getMyPermissions() async {
    getMyPermissionsCallCount++;
    if (shouldThrow) {
      throw Exception('Ошибка загрузки матрицы прав доступа');
    }
    return permissionsToReturn ??
        const MyPermissions(
          role: 'cashier',
          isDirector: false,
          hidesMoney: false,
          modules: {
            'cash': ModulePerm(
              view: true,
              create: true,
              edit: false,
              delete: false,
              canAction: true,
            ),
          },
        );
  }
}

void main() {
  group('PermissionsCubit & Domain Matrix Unit Tests (R1-09, R1-11)', () {
    late MockPermissionsRepository mockRepository;
    late PermissionsCubit cubit;

    final standardCashierPerms = const MyPermissions(
      role: 'cashier',
      isDirector: false,
      hidesMoney: false,
      modules: {
        'cash': ModulePerm(
          view: true,
          create: true,
          edit: false,
          delete: false,
          canAction: true,
        ),
        'warehouse': ModulePerm(view: true),
        'tasks': ModulePerm(view: true, create: true, edit: true),
      },
    );

    final directorPerms = const MyPermissions(
      role: 'director',
      isDirector: true,
      hidesMoney: false,
      modules: {},
    );

    final marketerPerms = const MyPermissions(
      role: 'marketer',
      isDirector: false,
      hidesMoney: true,
      modules: {
        'marketing': ModulePerm(
          view: true,
          create: true,
          edit: true,
          delete: false,
          canAction: true,
        ),
        'crm': ModulePerm(view: true),
      },
    );

    setUp(() {
      mockRepository = MockPermissionsRepository();
      cubit = PermissionsCubit(mockRepository);
    });

    tearDown(() {
      cubit.close();
    });

    test(
      'Initial state is PermissionsState.initial (null data, not loading)',
      () {
        expect(cubit.state.data, isNull);
        expect(cubit.state.loading, isFalse);
        expect(cubit.state.error, isNull);
      },
    );

    group('load() method', () {
      test(
        'emits [loading: true] then [loading: false, data: perms] on success',
        () async {
          mockRepository.permissionsToReturn = standardCashierPerms;

          final expected = [
            isA<PermissionsState>()
                .having((s) => s.loading, 'loading', isTrue)
                .having((s) => s.error, 'error', isNull),
            isA<PermissionsState>()
                .having((s) => s.loading, 'loading', isFalse)
                .having((s) => s.data?.role, 'data.role', 'cashier')
                .having(
                  (s) => s.data?.modules.containsKey('cash'),
                  'has cash module',
                  isTrue,
                ),
          ];

          expectLater(cubit.stream, emitsInOrder(expected));
          await cubit.load();
        },
      );

      test(
        'emits [loading: true] then [loading: false, error: msg] on failure',
        () async {
          mockRepository.shouldThrow = true;

          final expected = [
            isA<PermissionsState>().having((s) => s.loading, 'loading', isTrue),
            isA<PermissionsState>()
                .having((s) => s.loading, 'loading', isFalse)
                .having((s) => s.error, 'error', isNotEmpty),
          ];

          expectLater(cubit.stream, emitsInOrder(expected));
          await cubit.load();
        },
      );

      test(
        'silent: true does not emit loading state and updates only on changed data',
        () async {
          mockRepository.permissionsToReturn = standardCashierPerms;
          await cubit.load(); // initial loaded state

          // Same data silent load -> no state emission
          var emitted = false;
          final sub = cubit.stream.listen((_) => emitted = true);

          await cubit.load(silent: true);
          expect(emitted, isFalse);
          await sub.cancel();

          // Changed data silent load -> emits new state with loading: false
          mockRepository.permissionsToReturn = marketerPerms;
          final expected = [
            isA<PermissionsState>()
                .having((s) => s.loading, 'loading', isFalse)
                .having((s) => s.data?.role, 'data.role', 'marketer')
                .having((s) => s.data?.hidesMoney, 'hidesMoney', isTrue),
          ];

          expectLater(cubit.stream, emitsInOrder(expected));
          await cubit.load(silent: true);
        },
      );
    });

    group('Polling & Clear Lifecycle', () {
      test('startPolling() triggers periodic refresh', () async {
        mockRepository.permissionsToReturn = standardCashierPerms;
        cubit.startPolling(interval: const Duration(milliseconds: 50));

        await untilCalled(() => mockRepository.getMyPermissionsCallCount >= 2);
        expect(
          mockRepository.getMyPermissionsCallCount,
          greaterThanOrEqualTo(2),
        );

        cubit.stopPolling();
        final countAfterStop = mockRepository.getMyPermissionsCallCount;
        await Future<void>.delayed(const Duration(milliseconds: 100));
        expect(mockRepository.getMyPermissionsCallCount, countAfterStop);
      });

      test('clear() resets state to initial and stops polling', () async {
        mockRepository.permissionsToReturn = standardCashierPerms;
        await cubit.load();
        expect(cubit.state.data, isNotNull);

        cubit.startPolling(interval: const Duration(milliseconds: 50));
        cubit.clear();

        expect(cubit.state.data, isNull);
        expect(cubit.state.loading, isFalse);
        expect(cubit.state.error, isNull);
      });
    });

    group(
      'can() capability evaluation with offline fallback (data == null)',
      () {
        test('director fallback has full rights', () {
          expect(
            cubit.can(
              AppCapability.cash,
              action: PermAction.view,
              fallbackRole: UserRole.director,
            ),
            isTrue,
          );
          expect(
            cubit.can(
              AppCapability.cash,
              action: PermAction.delete,
              fallbackRole: UserRole.director,
            ),
            isTrue,
          );
          expect(
            cubit.can(
              AppCapability.users,
              action: PermAction.edit,
              fallbackRole: UserRole.director,
            ),
            isTrue,
          );
          expect(
            cubit.can(
              AppCapability.backups,
              action: PermAction.action,
              fallbackRole: UserRole.director,
            ),
            isTrue,
          );
        });

        test('cashier fallback has restricted rights', () {
          expect(
            cubit.can(
              AppCapability.cash,
              action: PermAction.view,
              fallbackRole: UserRole.cashier,
            ),
            isTrue,
          );
          expect(
            cubit.can(
              AppCapability.cash,
              action: PermAction.create,
              fallbackRole: UserRole.cashier,
            ),
            isTrue,
          );
          expect(
            cubit.can(
              AppCapability.users,
              action: PermAction.view,
              fallbackRole: UserRole.cashier,
            ),
            isFalse,
          );
          expect(
            cubit.can(
              AppCapability.strategy,
              action: PermAction.view,
              fallbackRole: UserRole.cashier,
            ),
            isFalse,
          );
          expect(
            cubit.can(
              AppCapability.hr,
              action: PermAction.view,
              fallbackRole: UserRole.cashier,
            ),
            isFalse,
          );
          expect(
            cubit.can(
              AppCapability.warehouse,
              action: PermAction.view,
              fallbackRole: UserRole.cashier,
            ),
            isFalse,
          );
        });

        test('marketer fallback hides financial capabilities', () {
          expect(
            cubit.can(
              AppCapability.marketing,
              action: PermAction.view,
              fallbackRole: UserRole.marketer,
            ),
            isTrue,
          );
          expect(
            cubit.can(
              AppCapability.crm,
              action: PermAction.view,
              fallbackRole: UserRole.marketer,
            ),
            isTrue,
          );
          expect(
            cubit.can(
              AppCapability.cash,
              action: PermAction.view,
              fallbackRole: UserRole.marketer,
            ),
            isFalse,
          );
          expect(
            cubit.can(
              AppCapability.finOps,
              action: PermAction.view,
              fallbackRole: UserRole.marketer,
            ),
            isFalse,
          );
        });
      },
    );

    group('can() capability evaluation with server matrix (data != null)', () {
      test(
        'director role bypasses matrix and has unrestricted access',
        () async {
          mockRepository.permissionsToReturn = directorPerms;
          await cubit.load();

          expect(
            cubit.can(
              AppCapability.cash,
              action: PermAction.delete,
              fallbackRole: UserRole.cashier,
            ),
            isTrue,
          );
          expect(
            cubit.can(
              AppCapability.users,
              action: PermAction.delete,
              fallbackRole: UserRole.cashier,
            ),
            isTrue,
          );
          expect(
            cubit.can(
              AppCapability.backups,
              action: PermAction.action,
              fallbackRole: UserRole.cashier,
            ),
            isTrue,
          );
          expect(
            cubit.can(
              AppCapability.audit,
              action: PermAction.view,
              fallbackRole: UserRole.cashier,
            ),
            isTrue,
          );
        },
      );

      test(
        'cashier matrix grants granular permissions and restricts delete',
        () async {
          mockRepository.permissionsToReturn = standardCashierPerms;
          await cubit.load();

          // Cash permissions
          expect(
            cubit.can(
              AppCapability.cash,
              action: PermAction.view,
              fallbackRole: UserRole.viewer,
            ),
            isTrue,
          );
          expect(
            cubit.can(
              AppCapability.cash,
              action: PermAction.create,
              fallbackRole: UserRole.viewer,
            ),
            isTrue,
          );
          expect(
            cubit.can(
              AppCapability.cash,
              action: PermAction.action,
              fallbackRole: UserRole.viewer,
            ),
            isTrue,
          );
          expect(
            cubit.can(
              AppCapability.cash,
              action: PermAction.edit,
              fallbackRole: UserRole.viewer,
            ),
            isFalse,
          );
          expect(
            cubit.can(
              AppCapability.cash,
              action: PermAction.delete,
              fallbackRole: UserRole.viewer,
            ),
            isFalse,
          );

          // Director-only modules remain closed for non-director
          expect(
            cubit.can(
              AppCapability.users,
              action: PermAction.view,
              fallbackRole: UserRole.director,
            ),
            isFalse,
          );
          expect(
            cubit.can(
              AppCapability.backups,
              action: PermAction.view,
              fallbackRole: UserRole.director,
            ),
            isFalse,
          );

          // Always available modules
          expect(
            cubit.can(
              AppCapability.notifications,
              action: PermAction.view,
              fallbackRole: UserRole.viewer,
            ),
            isTrue,
          );
          expect(
            cubit.can(
              AppCapability.network,
              action: PermAction.view,
              fallbackRole: UserRole.viewer,
            ),
            isTrue,
          );
        },
      );

      test('hidesMoney getter reflects backend payload correctly', () async {
        mockRepository.permissionsToReturn = standardCashierPerms;
        await cubit.load();
        expect(cubit.hidesMoney, isFalse);

        mockRepository.permissionsToReturn = marketerPerms;
        await cubit.load();
        expect(cubit.hidesMoney, isTrue);
      });
    });

    group('Domain Models & Value Equality', () {
      test('ModulePerm allows all 5 PermActions correctly', () {
        const fullPerm = ModulePerm(
          view: true,
          create: true,
          edit: true,
          delete: true,
          canAction: true,
        );

        expect(fullPerm.allows(PermAction.view), isTrue);
        expect(fullPerm.allows(PermAction.create), isTrue);
        expect(fullPerm.allows(PermAction.edit), isTrue);
        expect(fullPerm.allows(PermAction.delete), isTrue);
        expect(fullPerm.allows(PermAction.action), isTrue);

        const readOnlyPerm = ModulePerm(view: true);
        expect(readOnlyPerm.allows(PermAction.view), isTrue);
        expect(readOnlyPerm.allows(PermAction.create), isFalse);
        expect(readOnlyPerm.allows(PermAction.edit), isFalse);
        expect(readOnlyPerm.allows(PermAction.delete), isFalse);
        expect(readOnlyPerm.allows(PermAction.action), isFalse);
      });

      test(
        'MyPermissions JSON parsing handles snake_case and camelCase keys',
        () {
          final json = {
            'role': 'custom_admin',
            'is_director': true,
            'hides_money': false,
            'modules': {
              'cash': {
                'view': true,
                'create': true,
                'edit': false,
                'delete': false,
                'action': true,
              },
            },
          };

          final parsed = MyPermissions.fromJson(json);
          expect(parsed.role, 'custom_admin');
          expect(parsed.isDirector, isTrue);
          expect(parsed.hidesMoney, isFalse);
          expect(parsed.modules['cash']?.canAction, isTrue);
        },
      );

      test('MyPermissions value equality and hashCode integrity', () {
        const p1 = MyPermissions(
          role: 'accountant',
          isDirector: false,
          hidesMoney: false,
          modules: {'cash': ModulePerm(view: true, create: true)},
        );
        const p2 = MyPermissions(
          role: 'accountant',
          isDirector: false,
          hidesMoney: false,
          modules: {'cash': ModulePerm(view: true, create: true)},
        );
        const p3 = MyPermissions(
          role: 'accountant',
          isDirector: false,
          hidesMoney: true,
          modules: {'cash': ModulePerm(view: true, create: true)},
        );

        expect(p1, equals(p2));
        expect(p1.hashCode, equals(p2.hashCode));
        expect(p1, isNot(equals(p3)));
      });

      test('PermissionModules mapping covers all major app capabilities', () {
        expect(PermissionModules.keyFor(AppCapability.dashboard), 'dashboard');
        expect(PermissionModules.keyFor(AppCapability.cash), 'cash');
        expect(PermissionModules.keyFor(AppCapability.tasks), 'tasks');
        expect(PermissionModules.keyFor(AppCapability.warehouse), 'warehouse');
        expect(PermissionModules.keyFor(AppCapability.hr), 'hr');
        expect(PermissionModules.keyFor(AppCapability.crm), 'crm');
        expect(PermissionModules.keyFor(AppCapability.strategy), 'strategy');
        expect(PermissionModules.keyFor(AppCapability.legal), 'legal');
        expect(PermissionModules.keyFor(AppCapability.marketing), 'marketing');
        expect(
          PermissionModules.keyFor(AppCapability.integrations),
          'integrations',
        );
        expect(PermissionModules.keyFor(AppCapability.users), 'users');
        expect(PermissionModules.keyFor(AppCapability.branches), 'branches');
        expect(
          PermissionModules.keyFor(AppCapability.checklists),
          'checklists',
        );
        expect(PermissionModules.keyFor(AppCapability.finOps), 'finance-ops');
        expect(PermissionModules.keyFor(AppCapability.reports), 'reports');
        expect(PermissionModules.keyFor(AppCapability.audit), 'audit');
        expect(PermissionModules.keyFor(AppCapability.network), isNull);
        expect(PermissionModules.keyFor(AppCapability.notifications), isNull);
        expect(PermissionModules.keyFor(AppCapability.backups), isNull);
      });
    });
  });
}

Future<void> untilCalled(
  bool Function() condition, {
  Duration timeout = const Duration(seconds: 2),
}) async {
  final end = DateTime.now().add(timeout);
  while (!condition()) {
    if (DateTime.now().isAfter(end)) {
      throw TimeoutException('Condition not met within $timeout');
    }
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
}
