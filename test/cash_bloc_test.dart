import 'package:flutter_test/flutter_test.dart';
import 'package:payk_ai_cfo_platform/features/cash/bloc/cash_bloc.dart';
import 'package:payk_ai_cfo_platform/features/cash/bloc/cash_event.dart';
import 'package:payk_ai_cfo_platform/features/cash/bloc/cash_state.dart';
import 'package:payk_ai_cfo_platform/features/cash/domain/transaction_model.dart';
import 'package:payk_ai_cfo_platform/features/cash/domain/cash_repository.dart';

class MockCashTestRepository implements CashRepository {
  List<Transaction> transactions = [];
  CashShift? activeShift;
  List<CashSummary> summaries = [];

  bool shouldFail = false;

  @override
  Future<List<Transaction>> getTransactions() async {
    if (shouldFail) throw Exception('Get tx error');
    return List.from(transactions);
  }

  @override
  Future<Transaction> addTransaction(Transaction transaction) async {
    if (shouldFail) throw Exception('Add tx error');
    transactions.insert(0, transaction);
    return transaction;
  }

  @override
  Future<CashShift?> getActiveShift() async {
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
  Future<CashShift> closeShift(double endingBalance) async {
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
    if (shouldFail) throw Exception('Get summary error');
    return List.from(summaries);
  }

  @override
  Future<List<CashShift>> getShifts() async {
    if (shouldFail) throw Exception('Get shifts error');
    return [];
  }

  @override
  Future<List<CashRegister>> getRegisters() async {
    if (shouldFail) throw Exception('Get registers error');
    return [];
  }
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
        )
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
        )
      ];
      bloc = CashBloc(repository);
    });

    tearDown(() {
      bloc.close();
    });

    test('Initial state is CashLoading', () {
      expect(bloc.state, isA<CashLoading>());
    });

    test('LoadCashData emits loaded state with summaries and transactions', () async {
      final expected = [
        isA<CashLoading>(),
        isA<CashLoaded>()
            .having((s) => s.transactions.length, 'transactions count', 1)
            .having((s) => s.summaries.length, 'summaries count', 1)
            .having((s) => s.activeShift?.startingBalance, 'starting balance', 1000.0),
      ];

      expectLater(bloc.stream, emitsInOrder(expected));
      bloc.add(LoadCashData());
    });

    test('AddTransactionRequested adds transaction to cache when shift is open', () async {
      bloc.add(LoadCashData());
      await bloc.stream.firstWhere((s) => s is CashLoaded);

      bloc.add(AddTransactionRequested(
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
      ));

      final List<CashState> emitted = [];
      final sub = bloc.stream.listen(emitted.add);

      await Future.delayed(const Duration(milliseconds: 50));
      sub.cancel();

      expect(emitted, isNotEmpty);
      final loaded = emitted.first as CashLoaded;
      expect(loaded.transactions.length, 2);
      expect(loaded.transactions.first.title, 'Продажа сэндвича');
    });

    test('AddTransactionRequested returns error when shift is closed', () async {
      repository.activeShift = null;
      bloc.add(LoadCashData());
      await bloc.stream.firstWhere((s) => s is CashLoaded);

      bloc.add(AddTransactionRequested(
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
      ));

      final List<CashState> emitted = [];
      final sub = bloc.stream.listen(emitted.add);

      await Future.delayed(const Duration(milliseconds: 50));
      sub.cancel();

      expect(emitted, isNotEmpty);
      final loaded = emitted.first as CashLoaded;
      expect(loaded.errorMessage, contains('кассовая смена закрыта'));
    });
  });
}
