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

  const ReportsLoaded({required this.dailyReports});

  double get totalRevenue =>
      dailyReports.fold(0.0, (sum, r) => sum + r.revenue);
  double get totalExpenses =>
      dailyReports.fold(0.0, (sum, r) => sum + r.expenses);
  double get totalNetProfit =>
      dailyReports.fold(0.0, (sum, r) => sum + r.netProfit);

  @override
  List<Object?> get props => [dailyReports];
}

class ReportsError extends ReportsState {
  final String message;
  const ReportsError(this.message);

  @override
  List<Object?> get props => [message];
}
