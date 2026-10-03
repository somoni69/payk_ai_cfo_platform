import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/network/user_facing_error.dart';
import '../../auth/domain/app_access.dart';
import '../../auth/domain/user_role.dart';
import '../domain/my_permissions.dart';
import '../domain/permissions_repository.dart';
import 'permissions_state.dart';

export 'permissions_state.dart';

class PermissionsCubit extends Cubit<PermissionsState> {
  final PermissionsRepository _repository;
  Timer? _pollTimer;

  PermissionsCubit(this._repository) : super(PermissionsState.initial);

  /// Load / refresh effective rights. Web also refetches ~every 30s.
  Future<void> load({bool silent = false}) async {
    if (!silent) {
      emit(state.copyWith(loading: true, clearError: true));
    }
    try {
      final data = await _repository.getMyPermissions();
      if (isClosed) return;
      if (silent && data == state.data) return;
      emit(PermissionsState(data: data, loading: false));
    } catch (e) {
      if (isClosed) return;
      emit(
        state.copyWith(
          loading: false,
          error: userFacingError(e, fallback: ErrorKeys.loadFailed),
        ),
      );
    }
  }

  void startPolling({Duration interval = const Duration(seconds: 30)}) {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(interval, (_) {
      if (!isClosed) unawaited(load(silent: true));
    });
  }

  void stopPolling() {
    _pollTimer?.cancel();
    _pollTimer = null;
  }

  void clear() {
    stopPolling();
    emit(PermissionsState.initial);
  }

  bool can(
    AppCapability capability, {
    PermAction action = PermAction.view,
    required UserRole fallbackRole,
  }) {
    final data = state.data;
    if (data == null) {
      return switch (action) {
        PermAction.view => fallbackRole.can(capability),
        PermAction.create ||
        PermAction.edit ||
        PermAction.action => fallbackRole.canManage(capability),
        PermAction.delete => fallbackRole.canDelete(capability),
      };
    }
    if (!data.capabilitySectionOn(capability)) return false;
    if (data.isDirector) return true;
    if (capability == AppCapability.users) return data.isDirector;
    if (capability == AppCapability.backups) return data.isDirector;
    if (capability == AppCapability.notifications) return true;

    final key = PermissionModules.keyFor(capability);
    if (key == null) return true;
    return data.can(key, action);
  }

  bool get hidesMoney => state.data?.hidesMoney ?? false;

  @override
  Future<void> close() {
    stopPolling();
    return super.close();
  }
}
