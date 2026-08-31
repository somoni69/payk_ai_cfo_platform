import 'fin_ops_models.dart';

abstract class FinOpsRepository {
  Future<List<BankAccount>> getBankAccounts();
  Future<List<Encashment>> getEncashments();
  Future<List<StoreTransfer>> getStoreTransfers();
  Future<List<FinancialAid>> getFinancialAids();

  Future<BankAccount> createBank({required String name});
  Future<BankAccount> updateBank({
    required String id,
    String? name,
    bool? isActive,
  });
  Future<void> deleteBank(String id);

  Future<Encashment> createEncashment({
    required String registerId,
    required String responsibleEmployeeId,
    required double amount,
    String? bankId,
    String? note,
  });

  Future<List<BranchBalance>> getBranchBalances();

  Future<List<ResponsibleOption>> getResponsibleOptions();

  Future<StoreTransfer> createStoreTransfer({
    required String fromBranch,
    required String toBranch,
    required double amount,
  });

  Future<void> updateTransferStatus({
    required String transferId,
    required String status,
  });

  Future<void> cancelStoreTransfer(String transferId);

  Future<FinancialAid> createFinancialAid({
    required String employeeId,
    required double amount,
    bool deductFromSalary = true,
    String? registerId,
    String? note,
  });

  Future<void> repayFinancialAid({
    required String aidId,
    required double amount,
  });
}
