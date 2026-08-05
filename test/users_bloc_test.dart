import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:payk_ai_cfo_platform/features/users/bloc/users_bloc.dart';
import 'package:payk_ai_cfo_platform/features/users/bloc/users_event.dart';
import 'package:payk_ai_cfo_platform/features/users/bloc/users_state.dart';
import 'package:payk_ai_cfo_platform/features/users/domain/user_models.dart';
import 'package:payk_ai_cfo_platform/features/users/domain/users_repository.dart';

class MockUsersTestRepository implements UsersRepository {
  bool shouldFail = false;
  final List<String?> searches = [];
  final Map<String?, Completer<List<UserProfile>>> pendingSearches = {};

  @override
  Future<List<UserProfile>> getUsers({String? search}) async {
    searches.add(search);
    if (shouldFail) throw Exception('Users list failed');
    final pending = pendingSearches[search];
    if (pending != null) return pending.future;
    return usersFor(search ?? 'User 1');
  }

  List<UserProfile> usersFor(String name) {
    return [
      UserProfile(
        id: name,
        fullName: name,
        username: name,
        role: 'director',
        active: true,
        twoFactor: true,
        createdAt: DateTime.now(),
      ),
    ];
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
    if (shouldFail) throw Exception('Create user failed');
    return UserProfile(
      id: '2',
      fullName: fullName,
      username: username,
      email: email,
      phone: phone,
      role: role,
      active: active,
      twoFactor: twoFactor,
      createdAt: DateTime.now(),
    );
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
    if (shouldFail) throw Exception('Update user failed');
    return UserProfile(
      id: id,
      fullName: fullName ?? 'User Updated',
      username: 'user1',
      email: email,
      phone: phone,
      role: role ?? 'director',
      active: active ?? true,
      twoFactor: twoFactor ?? true,
      createdAt: DateTime.now(),
    );
  }

  @override
  Future<void> deleteUser(String id) async {
    if (shouldFail) throw Exception('Delete user failed');
  }

  @override
  Future<PermissionMatrix> getPermissionMatrix() async {
    if (shouldFail) throw Exception('Permissions failed');
    return const PermissionMatrix(
      modules: ['cash'],
      roles: ['manager'],
      perms: ['view', 'create', 'edit', 'delete', 'action'],
      cells: [
        PermissionCell(
          role: 'manager',
          module: 'cash',
          canView: true,
          canCreate: true,
          canEdit: true,
          canDelete: false,
          canAction: true,
        ),
      ],
    );
  }

  @override
  Future<PermissionMatrix> updatePermissions(List<PermissionCell> cells) async {
    if (shouldFail) throw Exception('Update permissions failed');
    return getPermissionMatrix();
  }
}

void main() {
  group('UsersBloc Unit Tests', () {
    late MockUsersTestRepository repository;
    late UsersBloc bloc;

    setUp(() {
      repository = MockUsersTestRepository();
      bloc = UsersBloc(repository);
    });

    tearDown(() {
      bloc.close();
    });

    test('Initial state is empty UsersState', () {
      expect(bloc.state.users, isEmpty);
      expect(bloc.state.isLoading, false);
    });

    test('LoadUsersData emits loading state and populated lists', () async {
      final expected = [
        isA<UsersState>().having((s) => s.isLoading, 'loading', true),
        isA<UsersState>()
            .having((s) => s.isLoading, 'loading', false)
            .having((s) => s.users.first.fullName, 'first name', 'User 1'),
      ];

      expectLater(bloc.stream, emitsInOrder(expected));
      bloc.add(const LoadUsersData());
    });

    test(
      'search is debounced, distinct and only latest query is loaded',
      () async {
        bloc.add(const UsersSearchChanged('a'));
        await Future<void>.delayed(const Duration(milliseconds: 100));
        bloc.add(const UsersSearchChanged('ab'));
        await Future<void>.delayed(const Duration(milliseconds: 100));
        bloc.add(const UsersSearchChanged('abc'));
        bloc.add(const UsersSearchChanged('abc'));

        await Future<void>.delayed(
          UsersBloc.searchDebounce + const Duration(milliseconds: 100),
        );

        expect(repository.searches, ['abc']);
        expect(bloc.state.users.single.fullName, 'abc');
        expect(bloc.state.isSearching, false);
      },
    );

    test('a stale response cannot overwrite a newer users search', () async {
      final older = Completer<List<UserProfile>>();
      final newer = Completer<List<UserProfile>>();
      repository.pendingSearches['older'] = older;
      repository.pendingSearches['newer'] = newer;

      bloc.add(const LoadUsersData(search: 'older'));
      await Future<void>.delayed(Duration.zero);
      bloc.add(const LoadUsersData(search: 'newer'));
      await Future<void>.delayed(Duration.zero);

      final newerState = bloc.stream.firstWhere(
        (state) =>
            state.users.isNotEmpty && state.users.single.fullName == 'newer',
      );
      newer.complete(repository.usersFor('newer'));
      await newerState;

      older.complete(repository.usersFor('older'));
      await Future<void>.delayed(const Duration(milliseconds: 20));

      expect(bloc.state.users.single.fullName, 'newer');
    });

    test(
      'refresh during initial load reuses the same repository future',
      () async {
        final pending = Completer<List<UserProfile>>();
        repository.pendingSearches[null] = pending;
        bloc.add(const LoadUsersData());

        await Future<void>.delayed(Duration.zero);
        final refresh = bloc.refresh();
        await Future<void>.delayed(Duration.zero);

        expect(repository.searches, [null]);
        pending.complete(repository.usersFor('shared'));
        await refresh;

        expect(bloc.state.users.single.fullName, 'shared');
        expect(bloc.state.isRefreshing, false);
      },
    );
    test('parallel refresh gestures share one in-flight request', () async {
      final pending = Completer<List<UserProfile>>();
      repository.pendingSearches[null] = pending;

      final first = bloc.refresh();
      final second = bloc.refresh();
      expect(identical(first, second), true);

      await Future<void>.delayed(Duration.zero);
      expect(repository.searches, [null]);

      pending.complete(repository.usersFor('refreshed'));
      await Future.wait([first, second]);

      expect(bloc.state.users.single.fullName, 'refreshed');
      expect(bloc.state.isRefreshing, false);
    });

    test('CreateUserRequested appends user to state list', () async {
      final expected = [
        isA<UsersState>().having((s) => s.isSubmitting, 'submitting', true),
        isA<UsersState>()
            .having((s) => s.isSubmitting, 'submitting', false)
            .having((s) => s.users.first.fullName, 'new user name', 'User B'),
      ];

      expectLater(bloc.stream, emitsInOrder(expected));
      bloc.add(
        const CreateUserRequested(
          fullName: 'User B',
          username: 'userb',
          email: 'userb@payk.tj',
          role: 'accountant',
          password: 'password123',
          active: true,
          twoFactor: false,
        ),
      );
    });
  });
}
