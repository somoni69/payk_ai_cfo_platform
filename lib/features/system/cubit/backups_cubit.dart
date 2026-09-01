import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/network/user_facing_error.dart';
import '../domain/system_repository.dart';
import 'backups_state.dart';

export 'backups_state.dart';

class BackupsCubit extends Cubit<BackupsState> {
  final SystemRepository _repository;

  BackupsCubit(this._repository) : super(BackupsState.initial);

  Future<void> loadBackups() async {
    emit(state.copyWith(isLoading: true, clearError: true));
    try {
      final files = await _repository.listBackups();
      if (isClosed) return;
      emit(state.copyWith(files: files, isLoading: false));
    } catch (e) {
      if (isClosed) return;
      emit(
        state.copyWith(
          isLoading: false,
          error: userFacingError(e, fallback: ErrorKeys.loadFailed),
        ),
      );
    }
  }

  Future<String?> createBackup() async {
    if (state.isCreating) return null;
    emit(
      state.copyWith(
        isCreating: true,
        clearError: true,
        clearCreatedFileName: true,
      ),
    );
    try {
      final name = await _repository.createBackup();
      if (isClosed) return name;
      final files = await _repository.listBackups();
      if (isClosed) return name;
      emit(
        state.copyWith(files: files, isCreating: false, createdFileName: name),
      );
      return name;
    } catch (e) {
      if (isClosed) return null;
      emit(
        state.copyWith(
          isCreating: false,
          error: userFacingError(e, fallback: ErrorKeys.saveFailed),
        ),
      );
      return null;
    }
  }
}
