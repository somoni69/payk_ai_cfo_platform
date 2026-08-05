import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import '../domain/user_models.dart';
import '../domain/users_repository.dart';
import 'users_event.dart';
import 'users_state.dart';

class UsersBloc extends Bloc<UsersEvent, UsersState> {
  static const searchDebounce = Duration(milliseconds: 350);

  final UsersRepository _repository;
  Timer? _searchTimer;
  String? _scheduledSearch;
  int _latestRequestId = 0;
  final Map<String, Future<List<UserProfile>>> _loadRequests = {};
  Completer<void>? _refreshCompleter;

  UsersBloc(this._repository) : super(const UsersState()) {
    on<LoadUsersData>(_onLoadUsersData);
    on<UsersSearchChanged>(_onUsersSearchChanged);
    on<_DebouncedUsersSearch>(_onDebouncedUsersSearch);
    on<_RefreshUsers>(_onRefreshUsers);
    on<CreateUserRequested>(_onCreateUserRequested);
    on<UpdateUserRequested>(_onUpdateUserRequested);
    on<DeleteUserRequested>(_onDeleteUserRequested);
    on<LoadPermissionsMatrix>(_onLoadPermissionsMatrix);
    on<TogglePermissionRequested>(_onTogglePermission);
  }

  Future<void> refresh({String? search}) {
    final activeRefresh = _refreshCompleter;
    if (activeRefresh != null) return activeRefresh.future;

    final completer = Completer<void>();
    _refreshCompleter = completer;
    _searchTimer?.cancel();
    add(_RefreshUsers(search?.trim()));
    return completer.future;
  }

  void _onUsersSearchChanged(
    UsersSearchChanged event,
    Emitter<UsersState> emit,
  ) {
    final query = event.query.trim();
    if (query == _scheduledSearch) return;

    _scheduledSearch = query;
    _searchTimer?.cancel();
    _searchTimer = Timer(searchDebounce, () {
      if (!isClosed) add(_DebouncedUsersSearch(query));
    });
  }

  Future<void> _onLoadUsersData(
    LoadUsersData event,
    Emitter<UsersState> emit,
  ) => _loadUsers(event.search?.trim(), emit, initial: true);

  Future<void> _onDebouncedUsersSearch(
    _DebouncedUsersSearch event,
    Emitter<UsersState> emit,
  ) => _loadUsers(event.search, emit, searching: true);

  Future<void> _onRefreshUsers(
    _RefreshUsers event,
    Emitter<UsersState> emit,
  ) async {
    try {
      await _loadUsers(event.search, emit, refreshing: true);
    } finally {
      final completer = _refreshCompleter;
      _refreshCompleter = null;
      if (completer != null && !completer.isCompleted) completer.complete();
    }
  }

  Future<void> _loadUsers(
    String? search,
    Emitter<UsersState> emit, {
    bool initial = false,
    bool searching = false,
    bool refreshing = false,
  }) async {
    final requestId = ++_latestRequestId;
    final showInitialLoader = initial && state.users.isEmpty;
    emit(
      state.copyWith(
        isLoading: showInitialLoader,
        isSearching: searching,
        isRefreshing: refreshing,
        clearError: true,
        clearSuccess: true,
      ),
    );

    final requestKey = search ?? '';
    var request = _loadRequests[requestKey];
    if (request == null) {
      request = _repository.getUsers(search: search);
      _loadRequests[requestKey] = request;
    }

    try {
      final users = await request;
      if (requestId != _latestRequestId || emit.isDone) return;
      emit(
        state.copyWith(
          isLoading: false,
          isSearching: false,
          isRefreshing: false,
          users: users,
        ),
      );
    } catch (e) {
      if (requestId != _latestRequestId || emit.isDone) return;
      emit(
        state.copyWith(
          isLoading: false,
          isSearching: false,
          isRefreshing: false,
          errorMessage:
              'Не удалось загрузить пользователей. Проверьте соединение.',
        ),
      );
    } finally {
      if (identical(_loadRequests[requestKey], request)) {
        _loadRequests.remove(requestKey);
      }
    }
  }

  void _onCreateUserRequested(
    CreateUserRequested event,
    Emitter<UsersState> emit,
  ) async {
    emit(
      state.copyWith(isSubmitting: true, clearError: true, clearSuccess: true),
    );
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
      emit(
        state.copyWith(
          isSubmitting: false,
          users: updated,
          successMessage: 'Пользователь успешно создан',
        ),
      );
    } catch (e) {
      emit(
        state.copyWith(
          isSubmitting: false,
          errorMessage: 'Не удалось создать пользователя. Проверьте данные.',
        ),
      );
    }
  }

  void _onUpdateUserRequested(
    UpdateUserRequested event,
    Emitter<UsersState> emit,
  ) async {
    emit(
      state.copyWith(isSubmitting: true, clearError: true, clearSuccess: true),
    );
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

      final updated = state.users
          .map((u) => u.id == event.id ? user : u)
          .toList();
      emit(
        state.copyWith(
          isSubmitting: false,
          users: updated,
          successMessage: 'Данные пользователя сохранены',
        ),
      );
    } catch (e) {
      emit(
        state.copyWith(
          isSubmitting: false,
          errorMessage: 'Не удалось обновить пользователя. Проверьте данные.',
        ),
      );
    }
  }

  void _onDeleteUserRequested(
    DeleteUserRequested event,
    Emitter<UsersState> emit,
  ) async {
    emit(state.copyWith(clearError: true, clearSuccess: true));
    try {
      await _repository.deleteUser(event.id);
      final updated = state.users.where((u) => u.id != event.id).toList();

      emit(
        state.copyWith(users: updated, successMessage: 'Пользователь удален'),
      );
    } catch (e) {
      emit(
        state.copyWith(
          errorMessage: 'Не удалось удалить пользователя. Повторите попытку.',
        ),
      );
    }
  }

  Future<void> _onLoadPermissionsMatrix(
    LoadPermissionsMatrix event,
    Emitter<UsersState> emit,
  ) async {
    if (state.permissionMatrix != null && !event.forceRefresh) return;
    emit(
      state.copyWith(isPermissionsLoading: true, clearPermissionsError: true),
    );
    try {
      final matrix = await _repository.getPermissionMatrix();
      emit(
        state.copyWith(permissionMatrix: matrix, isPermissionsLoading: false),
      );
    } catch (e) {
      emit(
        state.copyWith(
          isPermissionsLoading: false,
          permissionsError: e.toString(),
        ),
      );
    }
  }

  Future<void> _onTogglePermission(
    TogglePermissionRequested event,
    Emitter<UsersState> emit,
  ) async {
    final matrix = state.permissionMatrix;
    if (matrix == null) return;

    final key = PermissionCell.keyOf(event.role, event.module);
    final currentMap = Map<String, PermissionCell>.from(matrix.cellMap);
    final existing =
        currentMap[key] ??
        PermissionCell(
          role: event.role,
          module: event.module,
          canView: false,
          canCreate: false,
          canEdit: false,
          canDelete: false,
          canAction: false,
        );

    late PermissionCell next;
    switch (event.field) {
      case 'view':
        next = existing.copyWith(canView: event.value);
        if (!event.value) {
          next = next.copyWith(
            canCreate: false,
            canEdit: false,
            canDelete: false,
            canAction: false,
          );
        }
        break;
      case 'create':
        next = existing.copyWith(
          canCreate: event.value,
          canView: event.value ? true : existing.canView,
        );
        break;
      case 'edit':
        next = existing.copyWith(
          canEdit: event.value,
          canView: event.value ? true : existing.canView,
        );
        break;
      case 'delete':
        next = existing.copyWith(
          canDelete: event.value,
          canView: event.value ? true : existing.canView,
        );
        break;
      case 'action':
        next = existing.copyWith(
          canAction: event.value,
          canView: event.value ? true : existing.canView,
        );
        break;
      default:
        return;
    }

    // Optimistic UI
    currentMap[key] = next;
    final optimistic = PermissionMatrix(
      modules: matrix.modules,
      roles: matrix.roles,
      perms: matrix.perms,
      cells: currentMap.values.toList(),
    );
    emit(
      state.copyWith(
        permissionMatrix: optimistic,
        isPermissionSaving: true,
        clearPermissionsError: true,
      ),
    );

    try {
      final saved = await _repository.updatePermissions([next]);
      emit(state.copyWith(permissionMatrix: saved, isPermissionSaving: false));
    } catch (e) {
      // Revert by reloading from server
      try {
        final reloaded = await _repository.getPermissionMatrix();
        emit(
          state.copyWith(
            permissionMatrix: reloaded,
            isPermissionSaving: false,
            permissionsError: e.toString(),
          ),
        );
      } catch (_) {
        emit(
          state.copyWith(
            permissionMatrix: matrix,
            isPermissionSaving: false,
            permissionsError: e.toString(),
          ),
        );
      }
    }
  }

  @override
  Future<void> close() {
    _searchTimer?.cancel();
    final completer = _refreshCompleter;
    if (completer != null && !completer.isCompleted) completer.complete();
    return super.close();
  }
}

class _DebouncedUsersSearch extends UsersEvent {
  final String search;

  const _DebouncedUsersSearch(this.search);

  @override
  List<Object?> get props => [search];
}

class _RefreshUsers extends UsersEvent {
  final String? search;

  const _RefreshUsers(this.search);

  @override
  List<Object?> get props => [search];
}
