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
  final String bankName;
  final double amount;
  final String responsiblePerson;

  const CreateEncashmentRequested({
    required this.bankName,
    required this.amount,
    required this.responsiblePerson,
  });

  @override
  List<Object?> get props => [bankName, amount, responsiblePerson];
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
  final String employeeName;
  final double amount;

  const CreateFinancialAidRequested({
    required this.employeeName,
    required this.amount,
  });

  @override
  List<Object?> get props => [employeeName, amount];
}

class RepayFinancialAidRequested extends FinOpsEvent {
  final String aidId;
  final double amount;

  const RepayFinancialAidRequested({required this.aidId, required this.amount});

  @override
  List<Object?> get props => [aidId, amount];
}
