import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/network/user_facing_error.dart';
import '../domain/integrations_models.dart';
import '../domain/integrations_repository.dart';
import 'integrations_event.dart';
import 'integrations_state.dart';

class IntegrationsBloc extends Bloc<IntegrationsEvent, IntegrationsState> {
  IntegrationsBloc(this._repository) : super(const IntegrationsState()) {
    on<LoadIntegrationsData>(_onLoadIntegrationsData);
    on<TriggerSyncRequested>(_onTriggerSyncRequested);
  }

  final IntegrationsRepository _repository;
  Future<List<Object>>? _dataRequest;
  Completer<void>? _reloadCompleter;

  Future<void> reload() {
    final active = _reloadCompleter;
    if (active != null) return active.future;

    final completer = Completer<void>();
    _reloadCompleter = completer;
    add(const LoadIntegrationsData(forceRefresh: true));
    return completer.future;
  }

  Future<void> _onLoadIntegrationsData(
    LoadIntegrationsData event,
    Emitter<IntegrationsState> emit,
  ) async {
    emit(state.copyWith(isLoading: true, clearError: true));

    var request = _dataRequest;
    if (request == null) {
      request = Future.wait<Object>([
        _repository.getIntegrationsStatus(forceRefresh: event.forceRefresh),
        _repository.getSyncLogs(forceRefresh: event.forceRefresh),
      ]);
      _dataRequest = request;
    }

    try {
      final results = await request;
      if (emit.isDone) return;
      emit(
        state.copyWith(
          isLoading: false,
          integrations: (results[0] as List).cast<IntegrationInfo>(),
          logs: (results[1] as List).cast<SyncLog>(),
        ),
      );
    } catch (error) {
      if (emit.isDone) return;
      emit(
        state.copyWith(
          isLoading: false,
          errorMessage: userFacingError(
            error,
            fallback: 'Не удалось обновить интеграции. Проверьте соединение.',
          ),
        ),
      );
    } finally {
      if (identical(_dataRequest, request)) _dataRequest = null;
      final completer = _reloadCompleter;
      _reloadCompleter = null;
      if (completer != null && !completer.isCompleted) {
        completer.complete();
      }
    }
  }

  Future<void> _onTriggerSyncRequested(
    TriggerSyncRequested event,
    Emitter<IntegrationsState> emit,
  ) async {
    emit(
      state.copyWith(isSyncing: true, clearError: true, clearSyncMessage: true),
    );
    try {
      final result = await _repository.triggerSync(event.system);
      final updatedLogs = await _repository.getSyncLogs(forceRefresh: true);
      emit(
        state.copyWith(
          isSyncing: false,
          syncMessage: result.message,
          logs: updatedLogs,
        ),
      );
    } catch (error) {
      emit(
        state.copyWith(
          isSyncing: false,
          errorMessage: userFacingError(
            error,
            fallback: 'Не удалось завершить синхронизацию. Повторите попытку.',
          ),
        ),
      );
    }
  }
}
