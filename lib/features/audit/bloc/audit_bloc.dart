import 'package:flutter_bloc/flutter_bloc.dart';
import '../domain/audit_models.dart';
import '../domain/audit_repository.dart';
import 'audit_event.dart';
import 'audit_state.dart';

class AuditBloc extends Bloc<AuditEvent, AuditState> {
  final AuditRepository _repository;

  AuditBloc(this._repository) : super(AuditInitial()) {
    on<LoadAuditData>(_onLoadAuditData);
    on<RunAnomalyDetectorsRequested>(_onRunAnomalyDetectorsRequested);
    on<ResolveAlertRequested>(_onResolveAlert);
  }

  Future<void> _onLoadAuditData(
    LoadAuditData event,
    Emitter<AuditState> emit,
  ) async {
    if (state is! AuditLoaded || event.forceRefresh) {
      emit(AuditLoading());
    }
    try {
      final logs = await _repository.getAuditLogs();
      final alerts = await _repository.getAuditAlerts();
      WeeklyAuditReport? weekly;
      try {
        weekly = await _repository.getWeeklyReport();
      } catch (_) {}
      emit(AuditLoaded(logs: logs, alerts: alerts, weekly: weekly));
    } catch (e) {
      emit(AuditError(e.toString()));
    }
  }

  Future<void> _onRunAnomalyDetectorsRequested(
    RunAnomalyDetectorsRequested event,
    Emitter<AuditState> emit,
  ) async {
    if (state is AuditLoaded) {
      final curState = state as AuditLoaded;
      emit(
        AuditLoaded(
          logs: curState.logs,
          alerts: curState.alerts,
          isRunningDetectors: true,
        ),
      );
    }
    try {
      final alerts = await _repository.runAnomalyDetectors();
      final logs = await _repository.getAuditLogs();
      emit(
        AuditLoaded(
          logs: logs,
          alerts: alerts,
          isRunningDetectors: false,
          message: 'AI-проверка безопасности успешно выполнена',
        ),
      );
    } catch (e) {
      emit(AuditError(e.toString()));
    }
  }

  Future<void> _onResolveAlert(
    ResolveAlertRequested event,
    Emitter<AuditState> emit,
  ) async {
    if (state is! AuditLoaded) return;
    try {
      final updated = await _repository.resolveAlert(
        event.id,
        isResolved: event.isResolved,
      );
      final current = state as AuditLoaded;
      emit(
        current.copyWith(
          alerts: current.alerts
              .map((a) => a.id == updated.id ? updated : a)
              .toList(),
        ),
      );
    } catch (e) {
      emit(AuditError(e.toString()));
    }
  }
}
