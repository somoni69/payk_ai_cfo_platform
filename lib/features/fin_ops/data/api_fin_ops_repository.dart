import 'package:dio/dio.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/user_facing_error.dart';
import '../domain/fin_ops_models.dart';
import '../domain/fin_ops_repository.dart';

/// Finance operations: `/finance-ops/*`.
///
/// Failures reach the bloc as error keys; nothing is invented offline.
class ApiFinOpsRepository implements FinOpsRepository {
  final Dio _dio;

  ApiFinOpsRepository({ApiClient? client, Dio? dio})
    : _dio = dio ?? (client ?? ApiClient()).dio;

  Future<List<T>> _list<T>(
    String path,
    T Function(Map<String, dynamic>) map,
  ) async {
    try {
      final response = await _dio.get(path);
      final data = response.data;
      if (data is! List) throw Exception(ErrorKeys.invalidResponse);
      return data
          .whereType<Map>()
          .map((e) => map(Map<String, dynamic>.from(e)))
          .toList();
    } catch (e) {
      throw Exception(userFacingError(e, fallback: ErrorKeys.loadFailed));
    }
  }

  Future<T> _write<T>(Future<T> Function() action) async {
    try {
      return await action();
    } catch (e) {
      throw Exception(userFacingError(e, fallback: ErrorKeys.saveFailed));
    }
  }

  static Map<String, dynamic> _map(Object? data) {
    if (data is! Map) throw Exception(ErrorKeys.invalidResponse);
    return Map<String, dynamic>.from(data);
  }

  @override
  Future<List<BankAccount>> getBankAccounts() =>
      _list('/finance-ops/banks', BankAccount.fromJson);

  @override
  Future<List<Encashment>> getEncashments() =>
      _list('/finance-ops/encashments', Encashment.fromJson);

  @override
  Future<List<StoreTransfer>> getStoreTransfers() =>
      _list('/finance-ops/store-transfers', StoreTransfer.fromJson);

  @override
  Future<List<FinancialAid>> getFinancialAids() =>
      _list('/finance-ops/financial-aid', FinancialAid.fromJson);

  @override
  Future<List<BranchBalance>> getBranchBalances() =>
      _list('/finance-ops/branch-balances', BranchBalance.fromJson);

  @override
  Future<List<ResponsibleOption>> getResponsibleOptions() =>
      _list('/finance-ops/responsible-options', ResponsibleOption.fromJson);

  @override
  Future<Encashment> createEncashment({
    required String registerId,
    required String responsibleEmployeeId,
    required double amount,
    String? bankId,
    String? note,
  }) => _write(() async {
    final response = await _dio.post(
      '/finance-ops/encashments',
      data: {
        'register_id': int.tryParse(registerId),
        'responsible_employee_id': int.tryParse(responsibleEmployeeId),
        'amount': amount,
        'bank_id': ?int.tryParse(bankId ?? ''),
        if (note != null && note.isNotEmpty) 'note': note,
      },
    );
    return Encashment.fromJson(_map(response.data));
  });

  @override
  Future<StoreTransfer> createStoreTransfer({
    required String fromBranch,
    required String toBranch,
    required double amount,
  }) => _write(() async {
    final response = await _dio.post(
      '/finance-ops/store-transfers',
      data: {
        'from_branch_id': int.tryParse(fromBranch),
        'to_branch_id': int.tryParse(toBranch),
        'amount': amount,
      },
    );
    return StoreTransfer.fromJson(_map(response.data));
  });

  @override
  Future<void> updateTransferStatus({
    required String transferId,
    required String status,
  }) => _write(() async {
    await _dio.post('/finance-ops/store-transfers/$transferId/$status');
  });

  @override
  Future<FinancialAid> createFinancialAid({
    required String employeeId,
    required double amount,
    bool deductFromSalary = true,
    String? registerId,
    String? note,
  }) => _write(() async {
    final response = await _dio.post(
      '/finance-ops/financial-aid',
      data: {
        'employee_id': int.tryParse(employeeId),
        'amount': amount,
        'deduct_from_salary': deductFromSalary,
        'register_id': ?int.tryParse(registerId ?? ''),
        if (note != null && note.isNotEmpty) 'note': note,
      },
    );
    return FinancialAid.fromJson(_map(response.data));
  });

  @override
  Future<void> repayFinancialAid({
    required String aidId,
    required double amount,
  }) => _write(() async {
    await _dio.post(
      '/finance-ops/financial-aid/$aidId/repay',
      data: {'amount': amount},
    );
  });

  @override
  Future<BankAccount> createBank({required String name}) => _write(() async {
    final response = await _dio.post(
      '/finance-ops/banks',
      data: {'name': name},
    );
    return BankAccount.fromJson(_map(response.data));
  });

  @override
  Future<BankAccount> updateBank({
    required String id,
    String? name,
    bool? isActive,
  }) => _write(() async {
    final response = await _dio.patch(
      '/finance-ops/banks/$id',
      data: {'name': ?name, 'is_active': ?isActive},
    );
    return BankAccount.fromJson(_map(response.data));
  });

  @override
  Future<void> deleteBank(String id) => _write(() async {
    await _dio.delete('/finance-ops/banks/$id');
  });

  @override
  Future<void> cancelStoreTransfer(String transferId) => _write(() async {
    await _dio.post('/finance-ops/store-transfers/$transferId/cancel');
  });
}
