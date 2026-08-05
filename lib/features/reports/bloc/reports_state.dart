import 'package:equatable/equatable.dart';

import '../domain/report_models.dart';

abstract class ReportsState extends Equatable {
  const ReportsState();

  @override
  List<Object?> get props => [];
}

class ReportsInitial extends ReportsState {}

class ReportsLoading extends ReportsState {}

class ReportsLoaded extends ReportsState {
  final List<DailyReport> dailyReports;
  final DailyReportFilters filters;
  final String? actionError;
  final String? actionSuccess;
  final bool actionInProgress;

  const ReportsLoaded({
    required this.dailyReports,
    this.filters = const DailyReportFilters(),
    this.actionError,
    this.actionSuccess,
    this.actionInProgress = false,
  });

  double get totalSales =>
      dailyReports.fold(0.0, (sum, r) => sum + r.totalSales);

  ReportsLoaded copyWith({
    List<DailyReport>? dailyReports,
    DailyReportFilters? filters,
    String? actionError,
    String? actionSuccess,
    bool? actionInProgress,
    bool clearActionMessages = false,
  }) {
    return ReportsLoaded(
      dailyReports: dailyReports ?? this.dailyReports,
      filters: filters ?? this.filters,
      actionError: clearActionMessages
          ? null
          : (actionError ?? this.actionError),
      actionSuccess: clearActionMessages
          ? null
          : (actionSuccess ?? this.actionSuccess),
      actionInProgress: actionInProgress ?? this.actionInProgress,
    );
  }

  @override
  List<Object?> get props => [
    dailyReports,
    filters,
    actionError,
    actionSuccess,
    actionInProgress,
  ];
}

class ReportsError extends ReportsState {
  final String message;

  const ReportsError(this.message);

  @override
  List<Object?> get props => [message];
}
