import 'package:equatable/equatable.dart';

abstract class ReportsEvent extends Equatable {
  const ReportsEvent();

  @override
  List<Object?> get props => [];
}

class LoadReportsData extends ReportsEvent {
  final bool forceRefresh;
  const LoadReportsData({this.forceRefresh = false});

  @override
  List<Object?> get props => [forceRefresh];
}

class CreateDailyReportRequested extends ReportsEvent {
  final String branchName;
  final double revenue;
  final double expenses;
  final double cashEndBalance;
  final double bankEndBalance;
  final String? comments;

  const CreateDailyReportRequested({
    required this.branchName,
    required this.revenue,
    required this.expenses,
    required this.cashEndBalance,
    required this.bankEndBalance,
    this.comments,
  });

  @override
  List<Object?> get props => [
        branchName,
        revenue,
        expenses,
        cashEndBalance,
        bankEndBalance,
        comments,
      ];
}

class DeleteDailyReportRequested extends ReportsEvent {
  final String id;
  const DeleteDailyReportRequested(this.id);

  @override
  List<Object?> get props => [id];
}
