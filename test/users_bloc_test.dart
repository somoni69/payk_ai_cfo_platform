import 'package:flutter_test/flutter_test.dart';
import 'package:payk_ai_cfo_platform/features/users/bloc/users_bloc.dart';
import 'package:payk_ai_cfo_platform/features/users/bloc/users_event.dart';
import 'package:payk_ai_cfo_platform/features/users/bloc/users_state.dart';
import 'package:payk_ai_cfo_platform/features/users/domain/user_models.dart';
import 'package:payk_ai_cfo_platform/features/users/domain/users_repository.dart';

class MockUsersTestRepository implements UsersRepository {
  bool shouldFail = false;

  @override
  Future<List<UserProfile>> getUsers({String? search}) async {
    if (shouldFail) throw Exception('Users list failed');
    return [
      UserProfile(id: '1', fullName: 'User 1', username: 'user1', role: 'director', active: true, twoFactor: true, createdAt: DateTime.now()),
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
    return UserProfile(id: '2', fullName: fullName, username: username, email: email, phone: phone, role: role, active: active, twoFactor: twoFactor, createdAt: DateTime.now());
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

    test('CreateUserRequested appends user to state list', () async {
      final expected = [
        isA<UsersState>().having((s) => s.isSubmitting, 'submitting', true),
        isA<UsersState>()
            .having((s) => s.isSubmitting, 'submitting', false)
            .having((s) => s.users.first.fullName, 'new user name', 'User B'),
      ];

      expectLater(bloc.stream, emitsInOrder(expected));
      bloc.add(const CreateUserRequested(
        fullName: 'User B',
        username: 'userb',
        email: 'userb@payk.tj',
        role: 'accountant',
        password: 'password123',
        active: true,
        twoFactor: false,
      ));
    });
  });
}
