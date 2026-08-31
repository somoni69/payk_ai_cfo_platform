import '../../../core/network/api_client.dart';
import '../domain/fin_ops_models.dart';
import '../domain/fin_ops_repository.dart';

class ApiFinOpsRepository implements FinOpsRepository {
  final ApiClient _client;

  ApiFinOpsRepository({ApiClient? client}) : _client = client ?? ApiClient();

  final List<BankAccount> _mockBanks = [
    const BankAccount(
      id: 'bnk-1',
      bankName: 'mock_bank_oriyon',
      accountNumber: '20202810400000123456',
      balance: 145000.0,
    ),
    const BankAccount(
      id: 'bnk-2',
      bankName: 'mock_bank_alif',
      accountNumber: '20202810900000789012',
      balance: 89000.0,
    ),
    const BankAccount(
      id: 'bnk-3',
      bankName: 'mock_bank_eskhata',
      accountNumber: '20202810100000345678',
      balance: 62000.0,
    ),
  ];

  final List<Encashment> _mockEncashments = [
    Encashment(
      id: 'enc-1',
      bankName: 'mock_bank_oriyon',
      amount: 25000.0,
      responsiblePerson: 'mock_person_sayfiddinov',
      date: DateTime.now().subtract(const Duration(hours: 4)),
    ),
    Encashment(
      id: 'enc-2',
      bankName: 'mock_bank_alif',
      amount: 15000.0,
      responsiblePerson: 'mock_user_alisher',
      date: DateTime.now().subtract(const Duration(days: 1)),
    ),
  ];

  final List<StoreTransfer> _mockTransfers = [
    StoreTransfer(
      id: 'tr-1',
      fromBranch: 'mock_branch_central',
      toBranch: 'mock_branch_somoni',
      amount: 5000.0,
      status: 'pending',
      date: DateTime.now().subtract(const Duration(hours: 2)),
    ),
    StoreTransfer(
      id: 'tr-2',
      fromBranch: 'mock_branch_khujand',
      toBranch: 'mock_branch_central',
      amount: 12000.0,
      status: 'received',
      date: DateTime.now().subtract(const Duration(days: 2)),
    ),
  ];

  final List<FinancialAid> _mockAids = [
    FinancialAid(
      id: 'aid-1',
      employeeName: 'mock_user_parviz',
      amount: 4000.0,
      repaidAmount: 2000.0,
      status: 'active',
      date: DateTime.now().subtract(const Duration(days: 10)),
    ),
    FinancialAid(
      id: 'aid-2',
      employeeName: 'mock_person_munojot',
      amount: 1500.0,
      repaidAmount: 1500.0,
      status: 'repaid',
      date: DateTime.now().subtract(const Duration(days: 25)),
    ),
  ];

  @override
  Future<List<BankAccount>> getBankAccounts() async {
    try {
      final response = await _client.dio.get('/finance-ops/banks');
      if (response.statusCode == 200 && response.data is List) {
        return (response.data as List)
            .map((e) => BankAccount.fromJson(e as Map<String, dynamic>))
            .toList();
      }
    } catch (_) {}
    return List.from(_mockBanks);
  }

  @override
  Future<List<Encashment>> getEncashments() async {
    try {
      final response = await _client.dio.get('/finance-ops/encashments');
      if (response.statusCode == 200 && response.data is List) {
        return (response.data as List)
            .map((e) => Encashment.fromJson(e as Map<String, dynamic>))
            .toList();
      }
    } catch (_) {}
    return List.from(_mockEncashments);
  }

  @override
  Future<List<StoreTransfer>> getStoreTransfers() async {
    try {
      final response = await _client.dio.get('/finance-ops/store-transfers');
      if (response.statusCode == 200 && response.data is List) {
        return (response.data as List)
            .map((e) => StoreTransfer.fromJson(e as Map<String, dynamic>))
            .toList();
      }
    } catch (_) {}
    return List.from(_mockTransfers);
  }

  @override
  Future<List<FinancialAid>> getFinancialAids() async {
    try {
      final response = await _client.dio.get('/finance-ops/financial-aid');
      if (response.statusCode == 200 && response.data is List) {
        return (response.data as List)
            .map((e) => FinancialAid.fromJson(e as Map<String, dynamic>))
            .toList();
      }
    } catch (_) {}
    return List.from(_mockAids);
  }

  @override
  Future<List<BranchBalance>> getBranchBalances() async {
    try {
      final response = await _client.dio.get('/finance-ops/branch-balances');
      final list = response.data is List ? response.data as List : const [];
      return list
          .whereType<Map>()
          .map((e) => BranchBalance.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    } catch (_) {
      return const [];
    }
  }

  @override
  Future<List<ResponsibleOption>> getResponsibleOptions() async {
    try {
      final response = await _client.dio.get(
        '/finance-ops/responsible-options',
      );
      final list = response.data is List ? response.data as List : const [];
      return list
          .whereType<Map>()
          .map((e) => ResponsibleOption.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    } catch (_) {
      return const [];
    }
  }

  @override
  Future<Encashment> createEncashment({
    required String registerId,
    required String responsibleEmployeeId,
    required double amount,
    String? bankId,
    String? note,
  }) async {
    final response = await _client.dio.post(
      '/finance-ops/encashments',
      data: {
        'register_id': int.tryParse(registerId),
        'responsible_employee_id': int.tryParse(responsibleEmployeeId),
        'amount': amount,
        'bank_id': ?int.tryParse(bankId ?? ''),
        if (note != null && note.isNotEmpty) 'note': note,
      },
    );
    if (response.data is Map) {
      final enc = Encashment.fromJson(
        Map<String, dynamic>.from(response.data as Map),
      );
      _mockEncashments.insert(0, enc);
      return enc;
    }
    throw Exception('error_save_failed');
  }

  @override
  Future<StoreTransfer> createStoreTransfer({
    required String fromBranch,
    required String toBranch,
    required double amount,
  }) async {
    final tr = StoreTransfer(
      id: 'tr-${DateTime.now().millisecondsSinceEpoch}',
      fromBranch: fromBranch,
      toBranch: toBranch,
      amount: amount,
      status: 'pending',
      date: DateTime.now(),
    );
    final response = await _client.dio.post(
      '/finance-ops/store-transfers',
      data: {
        'from_branch_id': int.tryParse(fromBranch),
        'to_branch_id': int.tryParse(toBranch),
        'amount': amount,
      },
    );
    if (response.data is Map) {
      final created = StoreTransfer.fromJson(
        Map<String, dynamic>.from(response.data as Map),
      );
      _mockTransfers.insert(0, created);
      return created;
    }
    _mockTransfers.insert(0, tr);
    return tr;
  }

  @override
  Future<void> updateTransferStatus({
    required String transferId,
    required String status,
  }) async {
    try {
      await _client.dio.post(
        '/finance-ops/store-transfers/$transferId/$status',
      );
    } catch (_) {}

    final idx = _mockTransfers.indexWhere((t) => t.id == transferId);
    if (idx != -1) {
      final t = _mockTransfers[idx];
      _mockTransfers[idx] = StoreTransfer(
        id: t.id,
        fromBranch: t.fromBranch,
        toBranch: t.toBranch,
        amount: t.amount,
        status: status,
        date: t.date,
      );
    }
  }

  @override
  Future<FinancialAid> createFinancialAid({
    required String employeeId,
    required double amount,
    bool deductFromSalary = true,
    String? registerId,
    String? note,
  }) async {
    final response = await _client.dio.post(
      '/finance-ops/financial-aid',
      data: {
        'employee_id': int.tryParse(employeeId),
        'amount': amount,
        'deduct_from_salary': deductFromSalary,
        'register_id': ?int.tryParse(registerId ?? ''),
        if (note != null && note.isNotEmpty) 'note': note,
      },
    );
    if (response.data is Map) {
      final aid = FinancialAid.fromJson(
        Map<String, dynamic>.from(response.data as Map),
      );
      _mockAids.insert(0, aid);
      return aid;
    }
    throw Exception('error_save_failed');
  }

  @override
  Future<void> repayFinancialAid({
    required String aidId,
    required double amount,
  }) async {
    try {
      await _client.dio.post(
        '/finance-ops/financial-aid/$aidId/repay',
        data: {'amount': amount},
      );
    } catch (_) {}

    final idx = _mockAids.indexWhere((a) => a.id == aidId);
    if (idx != -1) {
      final a = _mockAids[idx];
      final newRepaid = a.repaidAmount + amount;
      final newStatus = newRepaid >= a.amount ? 'repaid' : 'active';
      _mockAids[idx] = FinancialAid(
        id: a.id,
        employeeName: a.employeeName,
        amount: a.amount,
        repaidAmount: newRepaid,
        status: newStatus,
        date: a.date,
      );
    }
  }

  @override
  Future<BankAccount> createBank({required String name}) async {
    try {
      final response = await _client.dio.post(
        '/finance-ops/banks',
        data: {'name': name},
      );
      if (response.data is Map) {
        final bank = BankAccount.fromJson(
          Map<String, dynamic>.from(response.data as Map),
        );
        _mockBanks.insert(0, bank);
        return bank;
      }
    } catch (_) {}
    final bank = BankAccount(
      id: 'bnk-${DateTime.now().millisecondsSinceEpoch}',
      bankName: name,
    );
    _mockBanks.insert(0, bank);
    return bank;
  }

  @override
  Future<BankAccount> updateBank({
    required String id,
    String? name,
    bool? isActive,
  }) async {
    try {
      final response = await _client.dio.patch(
        '/finance-ops/banks/$id',
        data: {'name': ?name, 'is_active': ?isActive},
      );
      if (response.data is Map) {
        final bank = BankAccount.fromJson(
          Map<String, dynamic>.from(response.data as Map),
        );
        final idx = _mockBanks.indexWhere((b) => b.id == id);
        if (idx != -1) _mockBanks[idx] = bank;
        return bank;
      }
    } catch (_) {}
    final idx = _mockBanks.indexWhere((b) => b.id == id);
    if (idx != -1) {
      final old = _mockBanks[idx];
      final bank = BankAccount(
        id: old.id,
        bankName: name ?? old.bankName,
        isActive: isActive ?? old.isActive,
        accountNumber: old.accountNumber,
        balance: old.balance,
        currency: old.currency,
      );
      _mockBanks[idx] = bank;
      return bank;
    }
    throw Exception('error_no_resource');
  }

  @override
  Future<void> deleteBank(String id) async {
    try {
      await _client.dio.delete('/finance-ops/banks/$id');
    } catch (_) {}
    final idx = _mockBanks.indexWhere((b) => b.id == id);
    if (idx != -1) {
      final old = _mockBanks[idx];
      _mockBanks[idx] = BankAccount(
        id: old.id,
        bankName: old.bankName,
        isActive: false,
        accountNumber: old.accountNumber,
        balance: old.balance,
        currency: old.currency,
      );
    }
  }

  @override
  Future<void> cancelStoreTransfer(String transferId) async {
    try {
      await _client.dio.post('/finance-ops/store-transfers/$transferId/cancel');
    } catch (_) {}
    final idx = _mockTransfers.indexWhere((t) => t.id == transferId);
    if (idx != -1) {
      final t = _mockTransfers[idx];
      _mockTransfers[idx] = StoreTransfer(
        id: t.id,
        fromBranch: t.fromBranch,
        toBranch: t.toBranch,
        amount: t.amount,
        status: 'cancelled',
        date: t.date,
      );
    }
  }
}
