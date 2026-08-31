import 'package:equatable/equatable.dart';

abstract class FinOpsEvent extends Equatable {
  const FinOpsEvent();

  @override
  List<Object?> get props => [];
}

class LoadFinOpsData extends FinOpsEvent {
  final bool forceRefresh;
  const LoadFinOpsData({this.forceRefresh = false});

  @override
  List<Object?> get props => [forceRefresh];
}

class CreateEncashmentRequested extends FinOpsEvent {
  final String registerId;
  final String responsibleEmployeeId;
  final double amount;
  final String? bankId;
  final String? note;

  const CreateEncashmentRequested({
    required this.registerId,
    required this.responsibleEmployeeId,
    required this.amount,
    this.bankId,
    this.note,
  });

  @override
  List<Object?> get props => [
    registerId,
    responsibleEmployeeId,
    amount,
    bankId,
    note,
  ];
}

class CreateStoreTransferRequested extends FinOpsEvent {
  final String fromBranch;
  final String toBranch;
  final double amount;

  const CreateStoreTransferRequested({
    required this.fromBranch,
    required this.toBranch,
    required this.amount,
  });

  @override
  List<Object?> get props => [fromBranch, toBranch, amount];
}

class UpdateTransferStatusRequested extends FinOpsEvent {
  final String transferId;
  final String status;

  const UpdateTransferStatusRequested({
    required this.transferId,
    required this.status,
  });

  @override
  List<Object?> get props => [transferId, status];
}

class CreateFinancialAidRequested extends FinOpsEvent {
  final String employeeId;
  final double amount;
  final bool deductFromSalary;
  final String? registerId;

  const CreateFinancialAidRequested({
    required this.employeeId,
    required this.amount,
    this.deductFromSalary = true,
    this.registerId,
  });

  @override
  List<Object?> get props => [employeeId, amount, deductFromSalary, registerId];
}

class RepayFinancialAidRequested extends FinOpsEvent {
  final String aidId;
  final double amount;

  const RepayFinancialAidRequested({required this.aidId, required this.amount});

  @override
  List<Object?> get props => [aidId, amount];
}

class CreateBankRequested extends FinOpsEvent {
  final String name;

  const CreateBankRequested(this.name);

  @override
  List<Object?> get props => [name];
}

class DeleteBankRequested extends FinOpsEvent {
  final String id;

  const DeleteBankRequested(this.id);

  @override
  List<Object?> get props => [id];
}

class CancelStoreTransferRequested extends FinOpsEvent {
  final String transferId;

  const CancelStoreTransferRequested(this.transferId);

  @override
  List<Object?> get props => [transferId];
}
