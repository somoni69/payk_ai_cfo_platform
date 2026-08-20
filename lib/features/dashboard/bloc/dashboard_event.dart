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
  clients,
  aiInsights,
}

class CreatePlanRequested extends DashboardEvent {
  final String period;
  final String category;
  final String type;
  final double plannedAmount;

  const CreatePlanRequested({
    required this.period,
    required this.category,
    required this.type,
    required this.plannedAmount,
  });

  @override
  List<Object?> get props => [period, category, type, plannedAmount];
}

class CreateAccountRequested extends DashboardEvent {
  final String name;
  final String? bank;
  final String? number;
  final String currency;
  final double balance;

  const CreateAccountRequested({
    required this.name,
    this.bank,
    this.number,
    this.currency = 'TJS',
    this.balance = 0,
  });

  @override
  List<Object?> get props => [name, bank, number, currency, balance];
}

class DeleteAccountRequested extends DashboardEvent {
  final String id;

  const DeleteAccountRequested(this.id);

  @override
  List<Object?> get props => [id];
}

class ZeroOutAccountRequested extends DashboardEvent {
  final String id;

  const ZeroOutAccountRequested(this.id);

  @override
  List<Object?> get props => [id];
}

class RefreshRatesRequested extends DashboardEvent {
  const RefreshRatesRequested();
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
  final String dimension; // 'category' or 'counterparty' (legacy: 'client')

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
