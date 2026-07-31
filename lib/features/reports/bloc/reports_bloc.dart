import 'package:flutter_bloc/flutter_bloc.dart';
import '../domain/reports_repository.dart';
import 'reports_event.dart';
import 'reports_state.dart';

class ReportsBloc extends Bloc<ReportsEvent, ReportsState> {
  final ReportsRepository _repository;

  ReportsBloc(this._repository) : super(ReportsInitial()) {
    on<LoadReportsData>(_onLoadReportsData);
    on<CreateDailyReportRequested>(_onCreateDailyReportRequested);
    on<DeleteDailyReportRequested>(_onDeleteDailyReportRequested);
  }

  Future<void> _onLoadReportsData(
    LoadReportsData event,
    Emitter<ReportsState> emit,
  ) async {
    if (state is! ReportsLoaded || event.forceRefresh) {
      emit(ReportsLoading());
    }
    try {
      final reports = await _repository.getDailyReports();
      emit(ReportsLoaded(dailyReports: reports));
    } catch (e) {
      emit(ReportsError(e.toString()));
    }
  }

  Future<void> _onCreateDailyReportRequested(
    CreateDailyReportRequested event,
    Emitter<ReportsState> emit,
  ) async {
    try {
      await _repository.createDailyReport(
        branchName: event.branchName,
        revenue: event.revenue,
        expenses: event.expenses,
        cashEndBalance: event.cashEndBalance,
        bankEndBalance: event.bankEndBalance,
        comments: event.comments,
      );
      add(const LoadReportsData(forceRefresh: true));
    } catch (e) {
      emit(ReportsError(e.toString()));
    }
  }

  Future<void> _onDeleteDailyReportRequested(
    DeleteDailyReportRequested event,
    Emitter<ReportsState> emit,
  ) async {
    try {
      await _repository.deleteDailyReport(event.id);
      add(const LoadReportsData(forceRefresh: true));
    } catch (e) {
      emit(ReportsError(e.toString()));
    }
  }
}
