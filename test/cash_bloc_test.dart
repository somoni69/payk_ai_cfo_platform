import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:payk_ai_cfo_platform/features/cash/bloc/cash_bloc.dart';
import 'package:payk_ai_cfo_platform/features/cash/bloc/cash_event.dart';
import 'package:payk_ai_cfo_platform/features/cash/bloc/cash_state.dart';
import 'package:payk_ai_cfo_platform/features/cash/domain/transaction_model.dart';
import 'package:payk_ai_cfo_platform/features/cash/domain/cash_repository.dart';

class MockCashTestRepository implements CashRepository {
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

  List<Transaction> transactions = [];
  CashShift? activeShift;
  List<CashSummary> summaries = [];

  bool shouldFail = false;
  bool failSummary = false;
  Completer<List<Transaction>>? transactionGate;
  int activeShiftReads = 0;
  int transactionReads = 0;
  int summaryReads = 0;
  int shiftReads = 0;
  int registerReads = 0;

  @override
  Future<List<Transaction>> getTransactions({
    CashOperationFilters filters = const CashOperationFilters(),
  }) async {
    transactionReads++;
    if (shouldFail) throw Exception('Get tx error');
    final gate = transactionGate;
    if (gate != null) return gate.future;
    var list = List<Transaction>.from(transactions);
    if (filters.type != null && filters.type != 'all') {
      final isIncome = filters.type == 'income';
      list = list.where((t) => t.isIncome == isIncome).toList();
    }
    if (filters.query != null && filters.query!.isNotEmpty) {
      final q = filters.query!.toLowerCase();
      list = list.where((t) => t.title.toLowerCase().contains(q)).toList();
    }
    return list;
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
    return transactions.firstWhere((t) => t.id == id);
  }

  @override
  Future<Transaction> updateTransaction(Transaction transaction) async {
    if (shouldFail) throw Exception('Update tx error');
    final index = transactions.indexWhere((t) => t.id == transaction.id);
    if (index >= 0) transactions[index] = transaction;
    return transaction;
  }

  @override
  Future<void> deleteTransaction(String id) async {
    if (shouldFail) throw Exception('Delete tx error');
    transactions.removeWhere((t) => t.id == id);
  }

  @override
  Future<Transaction> addTransaction(Transaction transaction) async {
    if (shouldFail) throw Exception('Add tx error');
    transactions.insert(0, transaction);
    return transaction;
  }

  @override
  Future<CashShift?> getActiveShift() async {
    activeShiftReads++;
    if (shouldFail) throw Exception('Get shift error');
    return activeShift;
  }

  @override
  Future<CashShift> openShift(double startingBalance) async {
    if (shouldFail) throw Exception('Open shift error');
    activeShift = CashShift(
      openedAt: DateTime.now(),
      startingBalance: startingBalance,
      isOpen: true,
    );
    return activeShift!;
  }

  @override
  Future<CashShift> closeShift(double endingBalance, {String? note}) async {
    if (shouldFail) throw Exception('Close shift error');
    final closed = CashShift(
      openedAt: activeShift!.openedAt,
      closedAt: DateTime.now(),
      startingBalance: activeShift!.startingBalance,
      endingBalance: endingBalance,
      isOpen: false,
    );
    activeShift = null;
    return closed;
  }

  @override
  Future<List<CashSummary>> getSummary() async {
    summaryReads++;
    if (shouldFail || failSummary) throw Exception('Get summary error');
    return List.from(summaries);
  }

  @override
  Future<List<CashShift>> getShifts() async {
    shiftReads++;
    if (shouldFail) throw Exception('Get shifts error');
    return activeShift == null ? [] : [activeShift!];
  }

  @override
  Future<List<CashRegister>> getRegisters() async {
    registerReads++;
    if (shouldFail) throw Exception('Get registers error');
    return [];
  }

  @override
  Future<Uint8List> exportOperations({
    required String format,
    CashOperationFilters filters = const CashOperationFilters(),
  }) async {
    if (shouldFail) throw Exception('Export error');
    return Uint8List.fromList([1, 2, 3]);
  }

  @override
  Future<int> importOperations({
    required int registerId,
    required String filename,
    required Uint8List bytes,
  }) async {
    if (shouldFail) throw Exception('Import error');
    return 0;
  }

  @override
  Future<bool> getPosPinStatus() async => false;

  @override
  Future<void> savePosPin(String pin) async {}

  @override
  Future<PosPinCheck> verifyPosPin(String pin, {PosEditAction? action}) async =>
      const PosPinCheck(ok: true);

  @override
  Future<PosEditsPage> getPosEdits({int page = 1, int size = 50}) async =>
      const PosEditsPage();
}

void main() {
  group('CashBloc Unit Tests', () {
    late MockCashTestRepository repository;
    late CashBloc bloc;

    setUp(() {
      repository = MockCashTestRepository();
      repository.transactions = [
        Transaction(
          id: '1',
          title: 'Покупка кофе',
          category: 'Сырье',
          amount: 50.0,
          isIncome: false,
          paymentMethod: PaymentMethod.cash,
          dateTime: DateTime.now(),
          cashierName: 'Кассир',
        ),
      ];
      repository.activeShift = CashShift(
        openedAt: DateTime.now().subtract(const Duration(hours: 1)),
        startingBalance: 1000.0,
        isOpen: true,
      );
      repository.summaries = [
        const CashSummary(
          registerId: '1',
          registerName: 'Main',
          hasOpenShift: true,
          income: 200,
          expense: 50,
          net: 150,
        ),
      ];
      bloc = CashBloc(repository);
    });

    tearDown(() {
      bloc.close();
    });

    test('Initial state is CashLoading', () {
      expect(bloc.state, isA<CashLoading>());
    });

    test(
      'LoadCashData emits loaded state with summaries and transactions',
      () async {
        final expected = [
          isA<CashLoading>(),
          isA<CashLoaded>()
              .having((s) => s.transactions.length, 'transactions count', 1)
              .having((s) => s.summaries.length, 'summaries count', 1)
              .having(
                (s) => s.activeShift?.startingBalance,
                'starting balance',
                1000.0,
              ),
        ];

        expectLater(bloc.stream, emitsInOrder(expected));
        bloc.add(LoadCashData());
      },
    );

    test('LoadCashData derives active shift from shifts response', () async {
      final loadedFuture = bloc.stream.firstWhere(
        (state) => state is CashLoaded,
      );
      bloc.add(const LoadCashData());
      await loadedFuture;

      expect(repository.activeShiftReads, 0);
    });

    test(
      'AddTransactionRequested adds transaction to cache when shift is open',
      () async {
        bloc.add(LoadCashData());
        await bloc.stream.firstWhere((s) => s is CashLoaded);

        bloc.add(
          AddTransactionRequested(
            Transaction(
              id: '2',
              title: 'Продажа сэндвича',
              category: 'Еда',
              amount: 80.0,
              isIncome: true,
              paymentMethod: PaymentMethod.card,
              dateTime: DateTime.now(),
              cashierName: 'Кассир',
            ),
          ),
        );

        final List<CashState> emitted = [];
        final sub = bloc.stream.listen(emitted.add);

        await Future.delayed(const Duration(milliseconds: 50));
        sub.cancel();

        expect(emitted, isNotEmpty);
        final loaded = emitted.last as CashLoaded;
        expect(loaded.transactions.length, 2);
        expect(loaded.transactions.first.title, 'Продажа сэндвича');
      },
    );

    test(
      'successful transaction remains visible when summary refresh fails',
      () async {
        bloc.add(const LoadCashData());
        await bloc.stream.firstWhere((state) => state is CashLoaded);

        repository.failSummary = true;
        final transaction = Transaction(
          id: '2',
          title: 'Sale',
          category: 'Food',
          amount: 80,
          isIncome: true,
          paymentMethod: PaymentMethod.card,
          dateTime: DateTime(2026, 7, 20),
          cashierName: 'Cashier',
        );
        final saved = bloc.stream.firstWhere(
          (state) =>
              state is CashLoaded &&
              state.transactions.any((item) => item.id == '2') &&
              state.errorMessage == 'cash_tx_saved_summary_failed',
        );
        bloc.add(AddTransactionRequested(transaction));
        final state = await saved as CashLoaded;

        expect(repository.transactions.map((item) => item.id), contains('2'));
        expect(state.transactions.map((item) => item.id), contains('2'));
        expect(state.errorMessage, isNot(contains('Повторите попытку')));
      },
    );

    test(
      'AddTransactionRequested returns error when shift is closed',
      () async {
        repository.activeShift = null;
        bloc.add(LoadCashData());
        await bloc.stream.firstWhere((s) => s is CashLoaded);

        bloc.add(
          AddTransactionRequested(
            Transaction(
              id: '2',
              title: 'Продажа сэндвича',
              category: 'Еда',
              amount: 80.0,
              isIncome: true,
              paymentMethod: PaymentMethod.card,
              dateTime: DateTime.now(),
              cashierName: 'Кассир',
            ),
          ),
        );

        final List<CashState> emitted = [];
        final sub = bloc.stream.listen(emitted.add);

        await Future.delayed(const Duration(milliseconds: 50));
        sub.cancel();

        expect(emitted, isNotEmpty);
        final loaded = emitted.first as CashLoaded;
        expect(loaded.errorMessage, 'cash_err_need_open_shift');
      },
    );
    test(
      'concurrent refreshes share one network request and both wait',
      () async {
        final gate = Completer<List<Transaction>>();
        repository.transactionGate = gate;

        final future = bloc.stream.firstWhere((s) => s is CashLoaded);

        bloc
          ..add(const LoadCashData())
          ..add(const LoadCashData());

        await Future<void>.delayed(const Duration(milliseconds: 20));
        expect(repository.transactionReads, 1);
        expect(repository.summaryReads, 1);
        expect(repository.shiftReads, 1);
        expect(repository.registerReads, 1);

        gate.complete(List<Transaction>.from(repository.transactions));
        await future;

        expect(bloc.state, isA<CashLoaded>());
      },
    );

    test(
      'OpenShiftRequested opens shift and updates active shift in state',
      () async {
        repository.activeShift = null;
        bloc.add(LoadCashData());
        await bloc.stream.firstWhere((s) => s is CashLoaded);

        bloc.add(const OpenShiftRequested(500.0));

        final state =
            await bloc.stream.firstWhere(
                  (s) =>
                      s is CashLoaded &&
                      s.activeShift != null &&
                      s.activeShift!.isOpen,
                )
                as CashLoaded;

        expect(state.activeShift?.startingBalance, 500.0);
        expect(state.activeShift?.isOpen, isTrue);
        expect(repository.activeShift?.startingBalance, 500.0);
      },
    );

    test('CloseShiftRequested closes shift and clears active shift', () async {
      bloc.add(LoadCashData());
      await bloc.stream.firstWhere((s) => s is CashLoaded);

      bloc.add(
        const CloseShiftRequested(
          1200.0,
          note: 'Смена завершена без расхождений',
        ),
      );

      final state =
          await bloc.stream.firstWhere(
                (s) =>
                    s is CashLoaded &&
                    (s.activeShift == null || !s.activeShift!.isOpen),
              )
              as CashLoaded;

      expect(state.activeShift, isNull);
      expect(repository.activeShift, isNull);
    });

    test(
      'UpdateTransactionRequested modifies transaction in state and repository',
      () async {
        bloc.add(LoadCashData());
        await bloc.stream.firstWhere((s) => s is CashLoaded);

        final updatedTx = Transaction(
          id: '1',
          title: 'Кофе латте XL (обновлено)',
          category: 'Напитки',
          amount: 25.0,
          isIncome: true,
          paymentMethod: PaymentMethod.cash,
          dateTime: DateTime(2026, 7, 18),
          cashierName: 'Кассир',
        );

        bloc.add(UpdateTransactionRequested(updatedTx));

        final state =
            await bloc.stream.firstWhere(
                  (s) =>
                      s is CashLoaded &&
                      s.transactions.any(
                        (t) => t.id == '1' && t.amount == 25.0,
                      ),
                )
                as CashLoaded;

        expect(
          state.transactions.firstWhere((t) => t.id == '1').title,
          'Кофе латте XL (обновлено)',
        );
        expect(
          repository.transactions.firstWhere((t) => t.id == '1').amount,
          25.0,
        );
      },
    );

    test(
      'DeleteTransactionRequested removes transaction from state and repository',
      () async {
        bloc.add(LoadCashData());
        await bloc.stream.firstWhere((s) => s is CashLoaded);

        expect((bloc.state as CashLoaded).transactions.length, 1);

        bloc.add(const DeleteTransactionRequested('1'));

        final state =
            await bloc.stream.firstWhere(
                  (s) => s is CashLoaded && s.transactions.isEmpty,
                )
                as CashLoaded;

        expect(state.transactions, isEmpty);
        expect(repository.transactions, isEmpty);
      },
    );

    test(
      'SearchFilterChanged filters transactions by type and query',
      () async {
        repository.transactions = [
          Transaction(
            id: '10',
            title: 'Оплата аренды',
            category: 'Аренда',
            amount: 500.0,
            isIncome: false,
            paymentMethod: PaymentMethod.card,
            dateTime: DateTime(2026, 7, 18),
            cashierName: 'Бухгалтер',
          ),
          Transaction(
            id: '11',
            title: 'Продажа десерта',
            category: 'Еда',
            amount: 35.0,
            isIncome: true,
            paymentMethod: PaymentMethod.cash,
            dateTime: DateTime(2026, 7, 18),
            cashierName: 'Кассир',
          ),
        ];

        bloc.add(LoadCashData());
        await bloc.stream.firstWhere((s) => s is CashLoaded);

        // Filter only income
        bloc.add(const SearchFilterChanged(query: '', filterType: 'income'));

        final incomeState =
            await bloc.stream.firstWhere(
                  (s) =>
                      s is CashLoaded &&
                      s.transactions.length == 1 &&
                      s.transactions.first.isIncome,
                )
                as CashLoaded;

        expect(incomeState.transactions.first.title, 'Продажа десерта');

        // Filter by search query
        bloc.add(const SearchFilterChanged(query: 'аренды', filterType: 'all'));

        final searchState =
            await bloc.stream.firstWhere(
                  (s) =>
                      s is CashLoaded &&
                      s.transactions.length == 1 &&
                      s.transactions.first.id == '10',
                )
                as CashLoaded;

        expect(searchState.transactions.first.title, 'Оплата аренды');
      },
    );
  });
}
