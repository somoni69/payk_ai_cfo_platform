import 'dart:typed_data';

import '../domain/transaction_model.dart';
import '../domain/cash_repository.dart';

/// Внутриигровая/моковая база данных кассовых смен и операций.
class MockCashRepository implements CashRepository {
  @override
  Future<CashShift> openShiftForRegister(
    double startingBalance, {
    String? registerId,
  }) => openShift(startingBalance);

  @override
  Future<CashShift> closeShiftById(
    double endingBalance, {
    String? shiftId,
    String? note,
  }) => closeShift(endingBalance, note: note);

  // Статический массив для сохранения данных во время сессии приложения
  static final List<Transaction> _transactions = [
    Transaction(
      id: '1',
      title: 'Поставщик кофе «Алмосӣ»',
      category: 'Закупка сырья',
      amount: 4500.0,
      isIncome: false,
      paymentMethod: PaymentMethod.cash,
      dateTime: DateTime.now().subtract(const Duration(hours: 2)),
      cashierName: 'Салихов С.',
    ),
    Transaction(
      id: '2',
      title: 'Розничная выручка: Касса А',
      category: 'Выручка',
      amount: 12800.0,
      isIncome: true,
      paymentMethod: PaymentMethod.card,
      dateTime: DateTime.now().subtract(const Duration(hours: 4)),
      cashierName: 'Салихов С.',
    ),
    Transaction(
      id: '3',
      title: 'Аренда склада Душанбе',
      category: 'Регулярный расход',
      amount: 8000.0,
      isIncome: false,
      paymentMethod: PaymentMethod.alif,
      dateTime: DateTime.now().subtract(const Duration(days: 1)),
      cashierName: 'Система',
    ),
  ];

  static CashShift? _activeShift = CashShift(
    id: '103',
    openedAt: DateTime.now().subtract(const Duration(hours: 6)),
    startingBalance: 5000.0,
    isOpen: true,
    cashierName: 'Салихов С.',
    registerName: 'Главная касса',
    status: 'open',
  );

  static final List<CashShift> _mockShifts = [
    CashShift(
      id: '101',
      openedAt: DateTime.now().subtract(const Duration(days: 2, hours: 4)),
      closedAt: DateTime.now().subtract(const Duration(days: 2)),
      startingBalance: 3000.0,
      endingBalance: 3000.0,
      isOpen: false,
      cashierName: 'Салихов С.',
      registerName: 'Главная касса',
      difference: 0.0,
      status: 'closed',
      note: 'Все сошлось',
    ),
    CashShift(
      id: '102',
      openedAt: DateTime.now().subtract(const Duration(days: 1, hours: 8)),
      closedAt: DateTime.now().subtract(const Duration(days: 1)),
      startingBalance: 4000.0,
      endingBalance: 4050.0,
      isOpen: false,
      cashierName: 'Салихов С.',
      registerName: 'Главная касса',
      difference: 50.0,
      status: 'closed',
      note: 'Излишек 50 TJS',
    ),
  ];

  @override
  Future<List<Transaction>> getTransactions({
    CashOperationFilters filters = const CashOperationFilters(),
  }) async {
    await Future.delayed(const Duration(milliseconds: 150));
    return List.from(_transactions);
  }

  @override
  Future<List<CashierLookup>> lookupCashiers() async => const [];

  @override
  Future<OneCKkmOverview> getOneCKkmShifts({
    DateTime? dateFrom,
    DateTime? dateTo,
    bool refresh = true,
  }) async => const OneCKkmOverview();

  @override
  Future<void> saveOneCKkmLink({
    required String scope,
    required String onecName,
    int? targetId,
  }) async {}

  @override
  Future<List<SaleProduct>> getSaleProducts({String? search}) async {
    return const [];
  }

  @override
  Future<SaleProduct> getSaleProductByBarcode(String code) async {
    throw Exception('not found');
  }

  @override
  Future<SalesProfit> getSalesProfit({
    DateTime? dateFrom,
    DateTime? dateTo,
  }) async {
    return const SalesProfit(revenue: 0, cost: 0, profit: 0);
  }

  @override
  Future<Transaction> getOperation(String id) async {
    return _transactions.firstWhere((t) => t.id == id);
  }

  @override
  Future<Transaction> updateTransaction(Transaction transaction) async {
    final index = _transactions.indexWhere((t) => t.id == transaction.id);
    if (index >= 0) _transactions[index] = transaction;
    return transaction;
  }

  @override
  Future<void> deleteTransaction(String id) async {
    _transactions.removeWhere((t) => t.id == id);
  }

  @override
  Future<Transaction> addTransaction(Transaction transaction) async {
    await Future.delayed(const Duration(milliseconds: 200));
    final newTx = Transaction(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: transaction.title,
      category: transaction.category,
      amount: transaction.amount,
      isIncome: transaction.isIncome,
      paymentMethod: transaction.paymentMethod,
      dateTime: transaction.dateTime,
      cashierName: transaction.cashierName,
    );
    _transactions.insert(0, newTx);
    return newTx;
  }

  @override
  Future<CashShift?> getActiveShift() async {
    await Future.delayed(const Duration(milliseconds: 100));
    return _activeShift;
  }

  @override
  Future<CashShift> openShift(double startingBalance) async {
    await Future.delayed(const Duration(milliseconds: 200));
    _activeShift = CashShift(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      openedAt: DateTime.now(),
      startingBalance: startingBalance,
      isOpen: true,
      cashierName: 'Салихов С.',
      registerName: 'Главная касса',
      status: 'open',
    );
    return _activeShift!;
  }

  @override
  Future<CashShift> closeShift(double endingBalance, {String? note}) async {
    await Future.delayed(const Duration(milliseconds: 250));
    if (_activeShift == null) {
      throw Exception('Нет активной смены для закрытия');
    }

    final closedShift = CashShift(
      id: _activeShift!.id,
      openedAt: _activeShift!.openedAt,
      closedAt: DateTime.now(),
      startingBalance: _activeShift!.startingBalance,
      endingBalance: endingBalance,
      isOpen: false,
      cashierName: _activeShift!.cashierName,
      registerName: _activeShift!.registerName,
      difference: endingBalance - (_activeShift!.startingBalance + 8300.0),
      status: 'closed',
      note: note ?? 'Закрыто с мобильного устройства',
    );

    _mockShifts.insert(0, closedShift);
    _activeShift = null;
    return closedShift;
  }

  @override
  Future<List<CashSummary>> getSummary() async {
    await Future.delayed(const Duration(milliseconds: 100));
    return [
      const CashSummary(
        registerId: '1',
        registerName: 'Главная касса',
        hasOpenShift: true,
        income: 12800.0,
        expense: 4500.0,
        net: 8300.0,
      ),
      const CashSummary(
        registerId: '2',
        registerName: 'Касса №2',
        hasOpenShift: false,
        income: 0.0,
        expense: 0.0,
        net: 0.0,
      ),
      const CashSummary(
        registerId: '3',
        registerName: 'iiko',
        hasOpenShift: false,
        income: 0.0,
        expense: 0.0,
        net: 0.0,
      ),
    ];
  }

  @override
  Future<List<CashShift>> getShifts() async {
    await Future.delayed(const Duration(milliseconds: 100));
    final List<CashShift> all = [];
    if (_activeShift != null) {
      all.add(_activeShift!);
    }
    all.addAll(_mockShifts);
    return all;
  }

  @override
  Future<List<CashRegister>> getRegisters() async {
    await Future.delayed(const Duration(milliseconds: 100));
    return const [
      CashRegister(id: '1', name: 'Главная касса'),
      CashRegister(id: '2', name: 'Касса №2'),
      CashRegister(id: '3', name: 'iiko'),
    ];
  }

  @override
  Future<Uint8List> exportOperations({
    required String format,
    CashOperationFilters filters = const CashOperationFilters(),
  }) async {
    await Future.delayed(const Duration(milliseconds: 50));
    return Uint8List.fromList('mock-export'.codeUnits);
  }

  @override
  Future<int> importOperations({
    required int registerId,
    required String filename,
    required Uint8List bytes,
  }) async {
    await Future.delayed(const Duration(milliseconds: 50));
    return 0;
  }
}
