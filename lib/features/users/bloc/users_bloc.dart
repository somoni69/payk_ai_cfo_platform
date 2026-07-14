import 'package:flutter_bloc/flutter_bloc.dart';
import '../domain/user_models.dart';
import '../domain/users_repository.dart';
import 'users_event.dart';
import 'users_state.dart';

class UsersBloc extends Bloc<UsersEvent, UsersState> {
  final UsersRepository _repository;

  UsersBloc(this._repository) : super(const UsersState()) {
    on<LoadUsersData>(_onLoadUsersData);
    on<CreateUserRequested>(_onCreateUserRequested);
    on<UpdateUserRequested>(_onUpdateUserRequested);
    on<DeleteUserRequested>(_onDeleteUserRequested);
  }

  void _onLoadUsersData(LoadUsersData event, Emitter<UsersState> emit) async {
    emit(state.copyWith(isLoading: true, clearError: true, clearSuccess: true));
    try {
      final users = await _repository.getUsers(search: event.search);
      emit(state.copyWith(
        isLoading: false,
        users: users,
      ));
    } catch (e) {
      emit(state.copyWith(
        isLoading: false,
        errorMessage: 'Не удалось загрузить пользователей: ${e.toString()}',
      ));
    }
  }

  void _onCreateUserRequested(CreateUserRequested event, Emitter<UsersState> emit) async {
    emit(state.copyWith(isSubmitting: true, clearError: true, clearSuccess: true));
    try {
      final user = await _repository.createUser(
        fullName: event.fullName,
        username: event.username,
        email: event.email,
        phone: event.phone,
        role: event.role,
        password: event.password,
        active: event.active,
        twoFactor: event.twoFactor,
      );

      final updated = List<UserProfile>.from(state.users)..add(user);
      emit(state.copyWith(
        isSubmitting: false,
        users: updated,
        successMessage: 'Пользователь успешно создан',
      ));
    } catch (e) {
      emit(state.copyWith(
        isSubmitting: false,
        errorMessage: 'Не удалось создать пользователя: ${e.toString()}',
      ));
    }
  }

  void _onUpdateUserRequested(UpdateUserRequested event, Emitter<UsersState> emit) async {
    emit(state.copyWith(isSubmitting: true, clearError: true, clearSuccess: true));
    try {
      final user = await _repository.updateUser(
        event.id,
        fullName: event.fullName,
        email: event.email,
        phone: event.phone,
        role: event.role,
        password: event.password,
        active: event.active,
        twoFactor: event.twoFactor,
      );

      final updated = state.users.map((u) => u.id == event.id ? user : u).toList();
      emit(state.copyWith(
        isSubmitting: false,
        users: updated,
        successMessage: 'Данные пользователя сохранены',
      ));
    } catch (e) {
      emit(state.copyWith(
        isSubmitting: false,
        errorMessage: 'Не удалось обновить пользователя: ${e.toString()}',
      ));
    }
  }

  void _onDeleteUserRequested(DeleteUserRequested event, Emitter<UsersState> emit) async {
    emit(state.copyWith(clearError: true, clearSuccess: true));
    try {
      await _repository.deleteUser(event.id);
      final updated = state.users.where((u) => u.id != event.id).toList();
      
      emit(state.copyWith(
        users: updated,
        successMessage: 'Пользователь удален',
      ));
    } catch (e) {
      emit(state.copyWith(
        errorMessage: 'Не удалось удалить пользователя: ${e.toString()}',
      ));
    }
  }
}
