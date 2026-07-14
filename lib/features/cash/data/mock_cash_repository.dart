import '../domain/transaction_model.dart';
import '../domain/cash_repository.dart';

/// Внутриигровая/моковая база данных кассовых смен и операций.
class MockCashRepository implements CashRepository {
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
    openedAt: DateTime.now().subtract(const Duration(hours: 6)),
    startingBalance: 5000.0,
    isOpen: true,
  );

  @override
  Future<List<Transaction>> getTransactions() async {
    await Future.delayed(const Duration(milliseconds: 150));
    return List.from(_transactions);
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
      openedAt: DateTime.now(),
      startingBalance: startingBalance,
      isOpen: true,
    );
    return _activeShift!;
  }

  @override
  Future<CashShift> closeShift(double endingBalance) async {
    await Future.delayed(const Duration(milliseconds: 250));
    if (_activeShift == null) {
      throw Exception('Нет активной смены для закрытия');
    }

    final closedShift = CashShift(
      openedAt: _activeShift!.openedAt,
      closedAt: DateTime.now(),
      startingBalance: _activeShift!.startingBalance,
      endingBalance: endingBalance,
      isOpen: false,
    );

    // Сбрасываем смену
    _activeShift = null;
    return closedShift;
  }

  @override
  Future<List<CashSummary>> getSummary() async {
    await Future.delayed(const Duration(milliseconds: 100));
    return [
      const CashSummary(
        registerId: '1',
        registerName: 'Основная касса (Душанбе)',
        hasOpenShift: true,
        income: 12800.0,
        expense: 4500.0,
        net: 8300.0,
      ),
      const CashSummary(
        registerId: '2',
        registerName: 'Касса самообслуживания Худжанд',
        hasOpenShift: false,
        income: 0.0,
        expense: 0.0,
        net: 0.0,
      ),
    ];
  }
}
