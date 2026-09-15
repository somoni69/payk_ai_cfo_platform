import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:payk_ai_cfo_platform/features/cash/bloc/cash_bloc.dart';
import 'package:payk_ai_cfo_platform/features/cash/bloc/cash_event.dart';
import 'package:payk_ai_cfo_platform/features/cash/bloc/cash_state.dart';
import 'package:payk_ai_cfo_platform/features/cash/domain/cash_repository.dart';
import 'package:payk_ai_cfo_platform/features/cash/domain/transaction_model.dart';

class E2ECashRepository implements CashRepository {
  List<Transaction> transactions = [];
  CashShift? activeShift;
  List<CashSummary> summaries = [];
  List<CashShift> shiftHistory = [];

  @override
  Future<List<Transaction>> getTransactions({
    CashOperationFilters filters = const CashOperationFilters(),
  }) async {
    var list = List<Transaction>.from(transactions);
    if (filters.type != null && filters.type != 'all') {
      final isIncome = filters.type == 'income';
      list = list.where((t) => t.isIncome == isIncome).toList();
    }
    return list;
  }

  @override
  Future<Transaction> addTransaction(Transaction transaction) async {
    transactions.insert(0, transaction);
    return transaction;
  }

  @override
  Future<CashShift?> getActiveShift() async => activeShift;

  @override
  Future<CashShift> openShift(double startingBalance) async {
    final newShift = CashShift(
      openedAt: DateTime.now().toUtc(),
      startingBalance: startingBalance,
      isOpen: true,
    );
    activeShift = newShift;
    shiftHistory.add(newShift);
    return newShift;
  }

  @override
  Future<CashShift> closeShift(double endingBalance, {String? note}) async {
    final current = activeShift;
    if (current == null) throw Exception('No active shift');
    final closed = CashShift(
      openedAt: current.openedAt,
      closedAt: DateTime.now().toUtc(),
      startingBalance: current.startingBalance,
      endingBalance: endingBalance,
      isOpen: false,
    );
    activeShift = null;
    shiftHistory.add(closed);
    return closed;
  }

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
    List<ShiftTerminalFact> terminalFacts = const [],
    int? collectorId,
    int? chiefCashierId,
    int? auditorId,
  }) => closeShift(endingBalance, note: note);

  @override
  Future<List<ShiftClosingLine>> getClosingForm(String shiftId) async =>
      const [];

  @override
  Future<List<ShiftPersonOption>> lookupShiftPeople() async => const [];

  @override
  Future<CashShiftReport> getShiftReport(String shiftId) async =>
      CashShiftReport(shiftId: shiftId);

  @override
  Future<Uint8List> exportShiftReport(
    String shiftId, {
    required String format,
  }) async => Uint8List(0);

  @override
  Future<List<CashSummary>> getSummary() async {
    double totalIncome = 0;
    double totalExpense = 0;
    for (final t in transactions) {
      if (t.isIncome) {
        totalIncome += t.amount;
      } else {
        totalExpense += t.amount;
      }
    }
    return [
      CashSummary(
        registerId: 'all',
        registerName: 'Все кассы',
        hasOpenShift: activeShift != null,
        income: totalIncome,
        expense: totalExpense,
        net: totalIncome - totalExpense,
      ),
    ];
  }

  @override
  Future<List<CashShift>> getShifts() async => activeShift == null
      ? List.from(shiftHistory)
      : [activeShift!, ...shiftHistory];

  @override
  Future<List<CashRegister>> getRegisters() async => const [];

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
  Future<List<SaleProduct>> getSaleProducts({String? search}) async => const [];

  @override
  Future<SaleProduct> getSaleProductByBarcode(String code) async =>
      throw Exception('not found');

  @override
  Future<SalesProfit> getSalesProfit({
    DateTime? dateFrom,
    DateTime? dateTo,
  }) async => const SalesProfit(revenue: 0, cost: 0, profit: 0);

  @override
  Future<Transaction> getOperation(String id) async =>
      transactions.firstWhere((t) => t.id == id);

  @override
  Future<Transaction> updateTransaction(Transaction transaction) async {
    final idx = transactions.indexWhere((t) => t.id == transaction.id);
    if (idx >= 0) transactions[idx] = transaction;
    return transaction;
  }

  @override
  Future<void> deleteTransaction(String id) async {
    transactions.removeWhere((t) => t.id == id);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  group('Tier 4 Real-World E2E Scenario: Full Cash Shift Lifecycle', () {
    late E2ECashRepository repository;
    late CashBloc cashBloc;

    setUp(() {
      repository = E2ECashRepository();
      cashBloc = CashBloc(repository);
    });

    tearDown(() {
      cashBloc.close();
    });

    test(
      'E2E: Open Shift -> Multi-method Sales & Expenses -> Search -> Close Shift & Z-Report',
      () async {
        // Step 1: Initial Load
        cashBloc.add(LoadCashData());
        var state =
            await cashBloc.stream.firstWhere((s) => s is CashLoaded)
                as CashLoaded;
        expect(state.activeShift, isNull);
        expect(state.transactions, isEmpty);

        // Step 2: Attempting to add transaction when shift is closed is rejected with error
        cashBloc.add(
          AddTransactionRequested(
            Transaction(
              id: 'tx-0',
              title: 'Преждевременная продажа',
              category: 'Услуги',
              amount: 100.0,
              isIncome: true,
              paymentMethod: PaymentMethod.cash,
              dateTime: DateTime.now(),
              cashierName: 'Кассир',
            ),
          ),
        );
        state =
            await cashBloc.stream.firstWhere((s) => s is CashLoaded)
                as CashLoaded;
        expect(state.errorMessage, 'cash_err_need_open_shift');
        expect(state.transactions, isEmpty);

        // Step 3: Cashier opens shift with 500 TJS starting balance
        cashBloc.add(const OpenShiftRequested(500.0));
        state =
            await cashBloc.stream.firstWhere(
                  (s) =>
                      s is CashLoaded &&
                      s.activeShift != null &&
                      s.activeShift!.isOpen,
                )
                as CashLoaded;
        expect(state.activeShift?.startingBalance, 500.0);
        expect(state.activeShift?.isOpen, isTrue);

        // Step 4: Register Sale #1 (Cash: +120 TJS)
        cashBloc.add(
          AddTransactionRequested(
            Transaction(
              id: 'tx-1',
              title: 'Продажа: Строительные материалы',
              category: 'Продажи',
              amount: 120.0,
              isIncome: true,
              paymentMethod: PaymentMethod.cash,
              dateTime: DateTime.now(),
              cashierName: 'Кассир 1',
            ),
          ),
        );
        state =
            await cashBloc.stream.firstWhere(
                  (s) =>
                      s is CashLoaded &&
                      s.transactions.any((t) => t.id == 'tx-1'),
                )
                as CashLoaded;
        expect(state.transactions.length, 1);

        // Step 5: Register Sale #2 (Card: +250 TJS) & Sale #3 (Alif: +80 TJS)
        cashBloc.add(
          AddTransactionRequested(
            Transaction(
              id: 'tx-2',
              title: 'Продажа: Сантехника',
              category: 'Продажи',
              amount: 250.0,
              isIncome: true,
              paymentMethod: PaymentMethod.card,
              dateTime: DateTime.now(),
              cashierName: 'Кассир 1',
            ),
          ),
        );
        state =
            await cashBloc.stream.firstWhere(
                  (s) =>
                      s is CashLoaded &&
                      s.transactions.any((t) => t.id == 'tx-2'),
                )
                as CashLoaded;

        cashBloc.add(
          AddTransactionRequested(
            Transaction(
              id: 'tx-3',
              title: 'Продажа: Краска и лаки',
              category: 'Продажи',
              amount: 80.0,
              isIncome: true,
              paymentMethod: PaymentMethod.alif,
              dateTime: DateTime.now(),
              cashierName: 'Кассир 1',
            ),
          ),
        );
        state =
            await cashBloc.stream.firstWhere(
                  (s) =>
                      s is CashLoaded &&
                      s.transactions.any((t) => t.id == 'tx-3'),
                )
                as CashLoaded;
        expect(state.transactions.length, 3);

        // Step 6: Register Expense (Cash refund: -50 TJS)
        cashBloc.add(
          AddTransactionRequested(
            Transaction(
              id: 'tx-4',
              title: 'Возврат товара покупателем',
              category: 'Возвраты',
              amount: 50.0,
              isIncome: false,
              paymentMethod: PaymentMethod.cash,
              dateTime: DateTime.now(),
              cashierName: 'Кассир 1',
            ),
          ),
        );
        state =
            await cashBloc.stream.firstWhere(
                  (s) =>
                      s is CashLoaded &&
                      s.transactions.any((t) => t.id == 'tx-4'),
                )
                as CashLoaded;
        expect(state.transactions.length, 4);

        // Step 7: Filter by type
        cashBloc.add(
          const SearchFilterChanged(query: '', filterType: 'income'),
        );
        state =
            await cashBloc.stream.firstWhere(
                  (s) =>
                      s is CashLoaded &&
                      s.transactions.length == 3 &&
                      s.transactions.every((t) => t.isIncome),
                )
                as CashLoaded;
        expect(state.transactions.length, 3);

        // Reset filter
        cashBloc.add(const SearchFilterChanged(query: '', filterType: 'all'));
        state =
            await cashBloc.stream.firstWhere(
                  (s) => s is CashLoaded && s.transactions.length == 4,
                )
                as CashLoaded;

        // Step 8: Close shift with ending balance (500 start + 450 income - 50 expense = 900 TJS)
        cashBloc.add(
          const CloseShiftRequested(
            900.0,
            note: 'Z-отчет #1042 успешно закрыт',
          ),
        );
        state =
            await cashBloc.stream.firstWhere(
                  (s) =>
                      s is CashLoaded &&
                      (s.activeShift == null || !s.activeShift!.isOpen),
                )
                as CashLoaded;

        expect(state.activeShift, isNull);
        expect(repository.activeShift, isNull);
        expect(repository.shiftHistory.last.endingBalance, 900.0);
        expect(repository.shiftHistory.last.isOpen, isFalse);
      },
    );
  });
}
