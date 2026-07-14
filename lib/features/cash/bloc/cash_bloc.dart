import 'package:flutter_bloc/flutter_bloc.dart';
import '../domain/transaction_model.dart';
import '../domain/cash_repository.dart';
import 'cash_event.dart';
import 'cash_state.dart';

class CashBloc extends Bloc<CashEvent, CashState> {
  final CashRepository _repository;

  List<Transaction> _cachedTransactions = [];
  CashShift? _cachedActiveShift;
  List<CashSummary> _cachedSummaries = [];
  String _currentQuery = '';
  String _currentFilterType = 'all';

  CashBloc(this._repository) : super(CashLoading()) {
    on<LoadCashData>(_onLoadCashData);
    on<AddTransactionRequested>(_onAddTransactionRequested);
    on<OpenShiftRequested>(_onOpenShiftRequested);
    on<CloseShiftRequested>(_onCloseShiftRequested);
    on<SearchFilterChanged>(_onSearchFilterChanged);
  }

  void _onLoadCashData(LoadCashData event, Emitter<CashState> emit) async {
    if (_cachedTransactions.isNotEmpty) {
      _emitCurrentState(emit);
    } else {
      emit(CashLoading());
    }
    try {
      final results = await Future.wait([
        _repository.getTransactions(),
        _repository.getActiveShift(),
        _repository.getSummary(),
      ]);
      _cachedTransactions = results[0] as List<Transaction>;
      _cachedActiveShift = results[1] as CashShift?;
      _cachedSummaries = results[2] as List<CashSummary>;
      _emitCurrentState(emit);
    } catch (e) {
      emit(CashError('Не удалось загрузить данные кассы: ${e.toString()}'));
    }
  }

  void _onSearchFilterChanged(SearchFilterChanged event, Emitter<CashState> emit) {
    _currentQuery = event.query;
    _currentFilterType = event.filterType;
    _emitCurrentState(emit);
  }

  void _onAddTransactionRequested(AddTransactionRequested event, Emitter<CashState> emit) async {
    if (state is! CashLoaded) return;
    final currentState = state as CashLoaded;

    // Валидация: Нельзя провести операцию без открытой смены (CASH-05)
    if (_cachedActiveShift == null) {
      emit(currentState.copyWith(
        errorMessage: 'Ошибка: кассовая смена закрыта. Сначала откройте смену.',
      ));
      return;
    }

    try {
      final newTx = await _repository.addTransaction(event.transaction);
      _cachedTransactions = List<Transaction>.from(_cachedTransactions)..insert(0, newTx);
      _cachedSummaries = await _repository.getSummary();
      _emitCurrentState(emit);
    } catch (e) {
      emit(currentState.copyWith(
        errorMessage: 'Ошибка добавления транзакции: ${e.toString()}',
      ));
    }
  }

  void _onOpenShiftRequested(OpenShiftRequested event, Emitter<CashState> emit) async {
    if (state is! CashLoaded) return;
    final currentState = state as CashLoaded;

    try {
      _cachedActiveShift = await _repository.openShift(event.startingBalance);
      _cachedSummaries = await _repository.getSummary();
      _emitCurrentState(emit);
    } catch (e) {
      emit(currentState.copyWith(
        errorMessage: 'Не удалось открыть смену: ${e.toString()}',
      ));
    }
  }

  void _onCloseShiftRequested(CloseShiftRequested event, Emitter<CashState> emit) async {
    if (state is! CashLoaded) return;
    final currentState = state as CashLoaded;
    final currentShift = _cachedActiveShift;

    if (currentShift == null) return;

    try {
      final closedShift = await _repository.closeShift(event.endingBalance);

      // CASH-06: Автоматический подсчет разницы
      final double netFlow = _cachedTransactions
          .where((t) => t.dateTime.isAfter(closedShift.openedAt))
          .fold(0.0, (sum, t) => sum + (t.isIncome ? t.amount : -t.amount));

      final expectedBalance = currentShift.startingBalance + netFlow;
      final diff = event.endingBalance - expectedBalance;

      String message = 'Смена успешно закрыта. ';
      if (diff.abs() < 0.01) {
        message += 'Остаток сошелся (Разница: 0 TJS)';
      } else {
        message += 'Внимание! Расхождение: ${diff > 0 ? "+" : ""}${diff.toStringAsFixed(2)} TJS (Ожидалось в кассе: ${expectedBalance.toStringAsFixed(2)} TJS)';
      }

      _cachedActiveShift = null;
      _cachedSummaries = await _repository.getSummary();

      emit(currentState.copyWith(
        activeShift: null,
        clearActiveShift: true,
        summaries: _cachedSummaries,
        errorMessage: message, // Выводим сообщение в виде алерта на UI
      ));
    } catch (e) {
      emit(currentState.copyWith(
        errorMessage: 'Не удалось закрыть смену: ${e.toString()}',
      ));
    }
  }

  void _emitCurrentState(Emitter<CashState> emit) {
    final filtered = _cachedTransactions.where((tx) {
      final matchesSearch = tx.title.toLowerCase().contains(_currentQuery.toLowerCase()) ||
          tx.category.toLowerCase().contains(_currentQuery.toLowerCase());

      final matchesFilter = _currentFilterType == 'all' ||
          (_currentFilterType == 'income' && tx.isIncome) ||
          (_currentFilterType == 'expense' && !tx.isIncome);

      return matchesSearch && matchesFilter;
    }).toList();

    emit(CashLoaded(
      transactions: _cachedTransactions,
      filteredTransactions: filtered,
      activeShift: _cachedActiveShift,
      summaries: _cachedSummaries,
      query: _currentQuery,
      filterType: _currentFilterType,
    ));
  }
}
