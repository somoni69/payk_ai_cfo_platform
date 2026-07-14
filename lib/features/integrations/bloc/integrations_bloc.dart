import 'package:flutter_bloc/flutter_bloc.dart';
import '../domain/integrations_models.dart';
import '../domain/integrations_repository.dart';
import 'integrations_event.dart';
import 'integrations_state.dart';

class IntegrationsBloc extends Bloc<IntegrationsEvent, IntegrationsState> {
  final IntegrationsRepository _repository;

  IntegrationsBloc(this._repository) : super(const IntegrationsState()) {
    on<LoadIntegrationsData>(_onLoadIntegrationsData);
    on<TriggerSyncRequested>(_onTriggerSyncRequested);
  }

  void _onLoadIntegrationsData(LoadIntegrationsData event, Emitter<IntegrationsState> emit) async {
    Future<List<T>> safeList<T>(Future<List<T>> future) async {
      try {
        return await future;
      } catch (_) {
        return <T>[];
      }
    }

    emit(state.copyWith(isLoading: true, clearError: true));
    try {
      final results = await Future.wait([
        safeList(_repository.getIntegrationsStatus()),
        safeList(_repository.getSyncLogs()),
      ]);

      emit(state.copyWith(
        isLoading: false,
        integrations: results[0] as List<IntegrationInfo>,
        logs: results[1] as List<SyncLog>,
      ));
    } catch (e) {
      emit(state.copyWith(
        isLoading: false,
        errorMessage: 'Ошибка загрузки интеграций: ${e.toString()}',
      ));
    }
  }

  void _onTriggerSyncRequested(TriggerSyncRequested event, Emitter<IntegrationsState> emit) async {
    emit(state.copyWith(isSyncing: true, clearError: true, clearSyncMessage: true));
    try {
      final result = await _repository.triggerSync(event.system);
      
      // Reload logs after sync triggers
      final updatedLogs = await _repository.getSyncLogs();

      emit(state.copyWith(
        isSyncing: false,
        syncMessage: result.message,
        logs: updatedLogs,
      ));
    } catch (e) {
      emit(state.copyWith(
        isSyncing: false,
        errorMessage: 'Синхронизация завершилась ошибкой: ${e.toString()}',
      ));
    }
  }
}
