import 'dart:async';

import 'package:equatable/equatable.dart';
import '../domain/transaction_model.dart';

abstract class CashEvent extends Equatable {
  const CashEvent();

  @override
  List<Object?> get props => [];
}

class LoadCashData extends CashEvent {
  final Completer<void>? completion;

  const LoadCashData({this.completion});

  @override
  List<Object?> get props => const [];
}

class AddTransactionRequested extends CashEvent {
  final Transaction transaction;

  const AddTransactionRequested(this.transaction);

  @override
  List<Object?> get props => [transaction];
}

class OpenShiftRequested extends CashEvent {
  final double startingBalance;

  const OpenShiftRequested(this.startingBalance);

  @override
  List<Object?> get props => [startingBalance];
}

class CloseShiftRequested extends CashEvent {
  final double endingBalance;

  const CloseShiftRequested(this.endingBalance);

  @override
  List<Object?> get props => [endingBalance];
}

class SearchFilterChanged extends CashEvent {
  final String query;
  final String filterType; // 'all', 'income', 'expense'

  const SearchFilterChanged({required this.query, required this.filterType});

  @override
  List<Object?> get props => [query, filterType];
}
