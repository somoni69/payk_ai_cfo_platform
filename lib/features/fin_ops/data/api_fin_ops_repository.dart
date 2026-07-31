import '../../../core/network/api_client.dart';
import '../domain/fin_ops_models.dart';
import '../domain/fin_ops_repository.dart';

class ApiFinOpsRepository implements FinOpsRepository {
  final ApiClient _client;

  ApiFinOpsRepository({ApiClient? client}) : _client = client ?? ApiClient();

  final List<BankAccount> _mockBanks = [
    const BankAccount(
      id: 'bnk-1',
      bankName: 'Ориёнбанк',
      accountNumber: '20202810400000123456',
      balance: 145000.0,
    ),
    const BankAccount(
      id: 'bnk-2',
      bankName: 'Алиф Банк',
      accountNumber: '20202810900000789012',
      balance: 89000.0,
    ),
    const BankAccount(
      id: 'bnk-3',
      bankName: 'Банк Эсхата',
      accountNumber: '20202810100000345678',
      balance: 62000.0,
    ),
  ];

  final List<Encashment> _mockEncashments = [
    Encashment(
      id: 'enc-1',
      bankName: 'Ориёнбанк',
      amount: 25000.0,
      responsiblePerson: 'Сайфиддинов Б.',
      date: DateTime.now().subtract(const Duration(hours: 4)),
    ),
    Encashment(
      id: 'enc-2',
      bankName: 'Алиф Банк',
      amount: 15000.0,
      responsiblePerson: 'Алишер Рахимов',
      date: DateTime.now().subtract(const Duration(days: 1)),
    ),
  ];

  final List<StoreTransfer> _mockTransfers = [
    StoreTransfer(
      id: 'tr-1',
      fromBranch: 'Филиал «Центральный»',
      toBranch: 'Филиал «Сомони»',
      amount: 5000.0,
      status: 'pending',
      date: DateTime.now().subtract(const Duration(hours: 2)),
    ),
    StoreTransfer(
      id: 'tr-2',
      fromBranch: 'Точка «Худжанд»',
      toBranch: 'Филиал «Центральный»',
      amount: 12000.0,
      status: 'received',
      date: DateTime.now().subtract(const Duration(days: 2)),
    ),
  ];

  final List<FinancialAid> _mockAids = [
    FinancialAid(
      id: 'aid-1',
      employeeName: 'Парвиз Назаров',
      amount: 4000.0,
      repaidAmount: 2000.0,
      status: 'active',
      date: DateTime.now().subtract(const Duration(days: 10)),
    ),
    FinancialAid(
      id: 'aid-2',
      employeeName: 'Муножот К.',
      amount: 1500.0,
      repaidAmount: 1500.0,
      status: 'repaid',
      date: DateTime.now().subtract(const Duration(days: 25)),
    ),
  ];

  @override
  Future<List<BankAccount>> getBankAccounts() async {
    try {
      final response = await _client.dio.get('/api/v1/finance-ops/banks');
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
      final response = await _client.dio.get('/api/v1/finance-ops/encashments');
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
      final response = await _client.dio.get('/api/v1/finance-ops/store-transfers');
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
      final response = await _client.dio.get('/api/v1/finance-ops/financial-aid');
      if (response.statusCode == 200 && response.data is List) {
        return (response.data as List)
            .map((e) => FinancialAid.fromJson(e as Map<String, dynamic>))
            .toList();
      }
    } catch (_) {}
    return List.from(_mockAids);
  }

  @override
  Future<Encashment> createEncashment({
    required String bankName,
    required double amount,
    required String responsiblePerson,
  }) async {
    final enc = Encashment(
      id: 'enc-${DateTime.now().millisecondsSinceEpoch}',
      bankName: bankName,
      amount: amount,
      responsiblePerson: responsiblePerson,
      date: DateTime.now(),
    );
    try {
      await _client.dio.post(
        '/api/v1/finance-ops/encashments',
        data: enc.toJson(),
      );
    } catch (_) {}

    _mockEncashments.insert(0, enc);
    return enc;
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
    try {
      await _client.dio.post(
        '/api/v1/finance-ops/store-transfers',
        data: tr.toJson(),
      );
    } catch (_) {}

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
        '/api/v1/finance-ops/store-transfers/$transferId/$status',
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
    required String employeeName,
    required double amount,
  }) async {
    final aid = FinancialAid(
      id: 'aid-${DateTime.now().millisecondsSinceEpoch}',
      employeeName: employeeName,
      amount: amount,
      repaidAmount: 0.0,
      status: 'active',
      date: DateTime.now(),
    );
    try {
      await _client.dio.post(
        '/api/v1/finance-ops/financial-aid',
        data: aid.toJson(),
      );
    } catch (_) {}

    _mockAids.insert(0, aid);
    return aid;
  }

  @override
  Future<void> repayFinancialAid({
    required String aidId,
    required double amount,
  }) async {
    try {
      await _client.dio.post(
        '/api/v1/finance-ops/financial-aid/$aidId/repay',
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
}
