import 'dart:async';

import 'package:equatable/equatable.dart';

abstract class DashboardEvent extends Equatable {
  const DashboardEvent();

  @override
  List<Object?> get props => [];
}

enum DashboardSection {
  pnl,
  planFact,
  breakEven,
  abc,
  accountsRates,
  aiInsights,
}

class LoadDashboardData extends DashboardEvent {
  final bool forceRefresh;
  final Completer<void>? completion;

  const LoadDashboardData({this.forceRefresh = false, this.completion});

  @override
  List<Object?> get props => [forceRefresh];
}

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

class LoadDashboardSection extends DashboardEvent {
  final DashboardSection section;
  final bool forceRefresh;
  final Completer<void>? completion;

  const LoadDashboardSection(
    this.section, {
    this.forceRefresh = false,
    this.completion,
  });

  @override
  List<Object?> get props => [section, forceRefresh];
}
