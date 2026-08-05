import 'package:flutter_bloc/flutter_bloc.dart';

import '../domain/report_models.dart';
import '../domain/reports_repository.dart';
import 'reports_event.dart';
import 'reports_state.dart';

class ReportsBloc extends Bloc<ReportsEvent, ReportsState> {
  final ReportsRepository _repository;
  DailyReportFilters _filters = const DailyReportFilters();

  ReportsBloc(this._repository) : super(ReportsInitial()) {
    on<LoadReportsData>(_onLoad);
    on<CreateDailyReportRequested>(_onCreate);
    on<UpdateDailyReportRequested>(_onUpdate);
    on<DeleteDailyReportRequested>(_onDelete);
  }

  DailyReportFilters get filters => _filters;

  Future<void> _onLoad(
    LoadReportsData event,
    Emitter<ReportsState> emit,
  ) async {
    _filters = event.filters;
    if (state is! ReportsLoaded || event.forceRefresh) {
      emit(ReportsLoading());
    }
    try {
      final reports = await _repository.getDailyReports(
        filters: _filters,
        forceRefresh: event.forceRefresh,
      );
      emit(ReportsLoaded(dailyReports: reports, filters: _filters));
    } catch (e) {
      emit(ReportsError(e.toString()));
    }
  }

  Future<void> _onCreate(
    CreateDailyReportRequested event,
    Emitter<ReportsState> emit,
  ) async {
    final current = state;
    if (current is ReportsLoaded) {
      emit(current.copyWith(actionInProgress: true, clearActionMessages: true));
    }
    try {
      await _repository.createDailyReport(event.input);
      final reports = await _repository.getDailyReports(filters: _filters);
      emit(
        ReportsLoaded(
          dailyReports: reports,
          filters: _filters,
          actionSuccess: 'reports_toast_created',
        ),
      );
    } catch (e) {
      if (current is ReportsLoaded) {
        emit(
          current.copyWith(actionInProgress: false, actionError: e.toString()),
        );
      } else {
        emit(ReportsError(e.toString()));
      }
    }
  }

  Future<void> _onUpdate(
    UpdateDailyReportRequested event,
    Emitter<ReportsState> emit,
  ) async {
    final current = state;
    if (current is ReportsLoaded) {
      emit(current.copyWith(actionInProgress: true, clearActionMessages: true));
    }
    try {
      await _repository.updateDailyReport(event.id, event.input);
      final reports = await _repository.getDailyReports(filters: _filters);
      emit(
        ReportsLoaded(
          dailyReports: reports,
          filters: _filters,
          actionSuccess: 'reports_toast_updated',
        ),
      );
    } catch (e) {
      if (current is ReportsLoaded) {
        emit(
          current.copyWith(actionInProgress: false, actionError: e.toString()),
        );
      } else {
        emit(ReportsError(e.toString()));
      }
    }
  }

  Future<void> _onDelete(
    DeleteDailyReportRequested event,
    Emitter<ReportsState> emit,
  ) async {
    final current = state;
    if (current is ReportsLoaded) {
      emit(current.copyWith(actionInProgress: true, clearActionMessages: true));
    }
    try {
      await _repository.deleteDailyReport(event.id);
      final reports = await _repository.getDailyReports(filters: _filters);
      emit(
        ReportsLoaded(
          dailyReports: reports,
          filters: _filters,
          actionSuccess: 'reports_toast_deleted',
        ),
      );
    } catch (e) {
      if (current is ReportsLoaded) {
        emit(
          current.copyWith(actionInProgress: false, actionError: e.toString()),
        );
      } else {
        emit(ReportsError(e.toString()));
      }
    }
  }
}
