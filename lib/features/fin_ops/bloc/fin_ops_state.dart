import 'package:equatable/equatable.dart';
import '../domain/fin_ops_models.dart';

abstract class FinOpsState extends Equatable {
  const FinOpsState();

  @override
  List<Object?> get props => [];
}

class FinOpsInitial extends FinOpsState {}

class FinOpsLoading extends FinOpsState {}

class FinOpsLoaded extends FinOpsState {
  final List<BankAccount> bankAccounts;
  final List<Encashment> encashments;
  final List<StoreTransfer> storeTransfers;
  final List<FinancialAid> financialAids;
  final String? message;

  const FinOpsLoaded({
    required this.bankAccounts,
    required this.encashments,
    required this.storeTransfers,
    required this.financialAids,
    this.message,
  });

  @override
  List<Object?> get props => [
        bankAccounts,
        encashments,
        storeTransfers,
        financialAids,
        message,
      ];
}

class FinOpsError extends FinOpsState {
  final String message;
  const FinOpsError(this.message);

  @override
  List<Object?> get props => [message];
}
