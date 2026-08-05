import 'package:equatable/equatable.dart';

import '../domain/report_models.dart';

abstract class ReportsEvent extends Equatable {
  const ReportsEvent();

  @override
  List<Object?> get props => [];
}

class LoadReportsData extends ReportsEvent {
  final DailyReportFilters filters;
  final bool forceRefresh;

  const LoadReportsData({
    this.filters = const DailyReportFilters(),
    this.forceRefresh = false,
  });

  @override
  List<Object?> get props => [filters, forceRefresh];
}

class CreateDailyReportRequested extends ReportsEvent {
  final DailyReportInput input;

  const CreateDailyReportRequested(this.input);

  @override
  List<Object?> get props => [input];
}

class UpdateDailyReportRequested extends ReportsEvent {
  final int id;
  final DailyReportInput input;

  const UpdateDailyReportRequested({required this.id, required this.input});

  @override
  List<Object?> get props => [id, input];
}

class DeleteDailyReportRequested extends ReportsEvent {
  final int id;

  const DeleteDailyReportRequested(this.id);

  @override
  List<Object?> get props => [id];
}
