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
    on<LoadWeeklyReport>(_onLoadWeeklyReport);
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
      final weeksAgo = state is AuditLoaded
          ? (state as AuditLoaded).weeksAgo
          : 0;
      WeeklyAuditReport? weekly;
      try {
        weekly = await _repository.getWeeklyReport(weeksAgo: weeksAgo);
      } catch (_) {}
      emit(
        AuditLoaded(
          logs: logs,
          alerts: alerts,
          weekly: weekly,
          weeksAgo: weeksAgo,
        ),
      );
    } catch (e) {
      emit(AuditError(e.toString()));
    }
  }

  Future<void> _onRunAnomalyDetectorsRequested(
    RunAnomalyDetectorsRequested event,
    Emitter<AuditState> emit,
  ) async {
    final previous = state is AuditLoaded ? state as AuditLoaded : null;
    if (previous != null) {
      emit(previous.copyWith(isRunningDetectors: true, message: null));
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
          weekly: previous?.weekly,
          weeksAgo: previous?.weeksAgo ?? 0,
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

  Future<void> _onLoadWeeklyReport(
    LoadWeeklyReport event,
    Emitter<AuditState> emit,
  ) async {
    if (state is! AuditLoaded) return;
    final current = state as AuditLoaded;
    try {
      final weekly = await _repository.getWeeklyReport(
        weeksAgo: event.weeksAgo,
      );
      if (emit.isDone || state is! AuditLoaded) return;
      emit(
        (state as AuditLoaded).copyWith(
          weekly: weekly,
          weeksAgo: event.weeksAgo,
        ),
      );
    } catch (_) {
      if (emit.isDone || state is! AuditLoaded) return;
      emit(current.copyWith(weeksAgo: event.weeksAgo));
    }
  }
}
