import 'package:equatable/equatable.dart';
import '../domain/transaction_model.dart';

abstract class CashEvent extends Equatable {
  const CashEvent();

  @override
  List<Object?> get props => [];
}

class LoadCashData extends CashEvent {
  const LoadCashData();

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
  final String? registerId;

  const OpenShiftRequested(this.startingBalance, {this.registerId});

  @override
  List<Object?> get props => [startingBalance, registerId];
}

class CloseShiftRequested extends CashEvent {
  final double endingBalance;
  final String? shiftId;
  final String? note;

  const CloseShiftRequested(this.endingBalance, {this.shiftId, this.note});

  @override
  List<Object?> get props => [endingBalance, shiftId, note];
}

class UpdateTransactionRequested extends CashEvent {
  final Transaction transaction;

  const UpdateTransactionRequested(this.transaction);

  @override
  List<Object?> get props => [transaction];
}

class DeleteTransactionRequested extends CashEvent {
  final String id;

  const DeleteTransactionRequested(this.id);

  @override
  List<Object?> get props => [id];
}

class SearchFilterChanged extends CashEvent {
  final String query;
  final String filterType; // 'all', 'income', 'expense'
  final String paymentMethod; // 'all' | PaymentMethod.name
  final String registerId; // 'all' | register id
  final String cashierId; // 'all' | user id
  final DateTime? dateFrom;
  final DateTime? dateTo;

  const SearchFilterChanged({
    required this.query,
    required this.filterType,
    this.paymentMethod = 'all',
    this.registerId = 'all',
    this.cashierId = 'all',
    this.dateFrom,
    this.dateTo,
  });

  @override
  List<Object?> get props => [
    query,
    filterType,
    paymentMethod,
    registerId,
    cashierId,
    dateFrom,
    dateTo,
  ];
}
