import 'package:equatable/equatable.dart';

abstract class DashboardEvent extends Equatable {
  const DashboardEvent();

  @override
  List<Object?> get props => [];
}

class LoadDashboardData extends DashboardEvent {}

class ChangeCurrency extends DashboardEvent {
  final String currency; // 'TJS', 'USD', 'RUB', 'EUR'

  const ChangeCurrency(this.currency);

  @override
  List<Object?> get props => [currency];
}

class ChangeAbcDimension extends DashboardEvent {
  final String dimension; // 'category' or 'client'

  const ChangeAbcDimension(this.dimension);

  @override
  List<Object?> get props => [dimension];
}
