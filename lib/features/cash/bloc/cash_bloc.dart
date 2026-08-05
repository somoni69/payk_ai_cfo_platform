import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/network/user_facing_error.dart';
import '../domain/transaction_model.dart';
import '../domain/cash_repository.dart';
import 'cash_event.dart';
import 'cash_state.dart';

class CashBloc extends Bloc<CashEvent, CashState> {
  final CashRepository _repository;

  List<Transaction> _cachedTransactions = [];
  CashShift? _cachedActiveShift;
  List<CashSummary> _cachedSummaries = [];
  List<CashShift> _cachedShifts = [];
  List<CashRegister> _cachedRegisters = [];
  String _currentQuery = '';
  String _currentFilterType = 'all';
  String _currentPaymentMethod = 'all';
  String _currentRegisterId = 'all';
  DateTime? _currentDateFrom;
  DateTime? _currentDateTo;
  Future<List<Object>>? _loadRequest;
  int _searchRevision = 0;

  CashBloc(this._repository) : super(CashLoading()) {
    on<LoadCashData>(_onLoadCashData);
    on<AddTransactionRequested>(_onAddTransactionRequested);
    on<OpenShiftRequested>(_onOpenShiftRequested);
    on<CloseShiftRequested>(_onCloseShiftRequested);
    on<SearchFilterChanged>(_onSearchFilterChanged);
  }

  Future<void> _onLoadCashData(
    LoadCashData event,
    Emitter<CashState> emit,
  ) async {
    final previous = state is CashLoaded ? state as CashLoaded : null;
    var request = _loadRequest;
    final ownsRequest = request == null;

    if (ownsRequest) {
      if (previous == null) {
        emit(CashLoading());
      }
      request = Future.wait<Object>([
        _repository.getTransactions(),
        _repository.getSummary(),
        _repository.getShifts(),
        _repository.getRegisters(),
      ]);
      _loadRequest = request;
    }

    try {
      final results = await request;
      if (!ownsRequest || emit.isDone) return;

      _cachedTransactions = (results[0] as List).cast<Transaction>();
      _cachedSummaries = (results[1] as List).cast<CashSummary>();
      _cachedShifts = (results[2] as List).cast<CashShift>();
      _cachedRegisters = (results[3] as List).cast<CashRegister>();
      _cachedActiveShift = null;
      for (final shift in _cachedShifts) {
        if (shift.isOpen) {
          _cachedActiveShift = shift;
          break;
        }
      }
      _emitCurrentState(emit);
    } catch (_) {
      if (!ownsRequest || emit.isDone) return;
      const message =
          'Не удалось загрузить данные кассы. Проверьте соединение.';
      if (previous != null) {
        _emitCurrentState(emit, errorMessage: message);
      } else {
        emit(const CashError(message));
      }
    } finally {
      if (ownsRequest && identical(_loadRequest, request)) {
        _loadRequest = null;
      }
      final completion = event.completion;
      if (completion != null && !completion.isCompleted) {
        completion.complete();
      }
    }
  }

  Future<void> _onSearchFilterChanged(
    SearchFilterChanged event,
    Emitter<CashState> emit,
  ) async {
    final revision = ++_searchRevision;
    final onlyQueryChanged =
        event.filterType == _currentFilterType &&
        event.paymentMethod == _currentPaymentMethod &&
        event.registerId == _currentRegisterId &&
        event.dateFrom == _currentDateFrom &&
        event.dateTo == _currentDateTo &&
        event.query != _currentQuery;
    if (onlyQueryChanged) {
      await Future<void>.delayed(const Duration(milliseconds: 300));
      if (revision != _searchRevision) return;
    }
    _currentQuery = event.query;
    _currentFilterType = event.filterType;
    _currentPaymentMethod = event.paymentMethod;
    _currentRegisterId = event.registerId;
    _currentDateFrom = event.dateFrom;
    _currentDateTo = event.dateTo;
    _emitCurrentState(emit);
  }

  void _onAddTransactionRequested(
    AddTransactionRequested event,
    Emitter<CashState> emit,
  ) async {
    if (state is! CashLoaded) return;
    final currentState = state as CashLoaded;

    // Валидация: Нельзя провести операцию без открытой смены (CASH-05)
    if (_cachedActiveShift == null) {
      emit(currentState.copyWith(errorMessage: 'cash_err_need_open_shift'));
      return;
    }

    late final Transaction newTx;
    try {
      newTx = await _repository.addTransaction(event.transaction);
    } catch (e) {
      if (emit.isDone) return;
      _emitCurrentState(emit, errorMessage: ErrorKeys.saveFailed);
      return;
    }

    _cachedTransactions = List<Transaction>.from(_cachedTransactions)
      ..removeWhere((transaction) => transaction.id == newTx.id)
      ..insert(0, newTx);

    String? refreshWarning;
    try {
      _cachedSummaries = await _repository.getSummary();
    } catch (e) {
      refreshWarning = 'cash_tx_saved_summary_failed';
    }

    if (emit.isDone) return;
    _emitCurrentState(emit, errorMessage: refreshWarning);
  }

  void _onOpenShiftRequested(
    OpenShiftRequested event,
    Emitter<CashState> emit,
  ) async {
    if (state is! CashLoaded) return;
    final currentState = state as CashLoaded;

    try {
      _cachedActiveShift = await _repository.openShiftForRegister(
        event.startingBalance,
        registerId: _cachedRegisters.isEmpty ? null : _cachedRegisters.first.id,
      );
      final refreshed = await Future.wait([
        _repository.getSummary(),
        _repository.getShifts(),
      ]);
      _cachedSummaries = refreshed[0] as List<CashSummary>;
      _cachedShifts = refreshed[1] as List<CashShift>;
      _emitCurrentState(emit);
    } catch (e) {
      emit(currentState.copyWith(errorMessage: ErrorKeys.saveFailed));
    }
  }

  void _onCloseShiftRequested(
    CloseShiftRequested event,
    Emitter<CashState> emit,
  ) async {
    if (state is! CashLoaded) return;
    final currentState = state as CashLoaded;
    final currentShift = _cachedActiveShift;

    if (currentShift == null) return;

    try {
      final closedShift = await _repository.closeShiftById(
        event.endingBalance,
        shiftId: currentShift.id,
      );

      // CASH-06: Автоматический подсчет разницы
      final double netFlow = _cachedTransactions
          .where((t) => t.dateTime.isAfter(closedShift.openedAt))
          .fold(0.0, (sum, t) => sum + (t.isIncome ? t.amount : -t.amount));

      final expectedBalance = currentShift.startingBalance + netFlow;
      final diff = event.endingBalance - expectedBalance;

      final message = diff.abs() < 0.01
          ? 'cash_shift_closed_balanced'
          : 'cash_shift_closed_diff::${diff > 0 ? "+" : ""}${diff.toStringAsFixed(2)}::${expectedBalance.toStringAsFixed(2)}';

      _cachedActiveShift = null;
      final refreshed = await Future.wait([
        _repository.getSummary(),
        _repository.getShifts(),
      ]);
      _cachedSummaries = refreshed[0] as List<CashSummary>;
      _cachedShifts = refreshed[1] as List<CashShift>;

      emit(
        currentState.copyWith(
          activeShift: null,
          clearActiveShift: true,
          summaries: _cachedSummaries,
          shifts: _cachedShifts,
          errorMessage: message, // Выводим сообщение в виде алерта на UI
        ),
      );
    } catch (e) {
      emit(
        currentState.copyWith(
          errorMessage: 'Не удалось закрыть смену. Повторите попытку.',
        ),
      );
    }
  }

  void _emitCurrentState(Emitter<CashState> emit, {String? errorMessage}) {
    final normalizedQuery = _currentQuery.trim().toLowerCase();
    final filtered = _cachedTransactions.where((tx) {
      final matchesSearch =
          tx.title.toLowerCase().contains(normalizedQuery) ||
          tx.category.toLowerCase().contains(normalizedQuery);

      final matchesFilter =
          _currentFilterType == 'all' ||
          (_currentFilterType == 'income' && tx.isIncome) ||
          (_currentFilterType == 'expense' && !tx.isIncome);

      final matchesPayment =
          _currentPaymentMethod == 'all' ||
          tx.paymentMethod.name == _currentPaymentMethod ||
          tx.paymentMethod.apiValue == _currentPaymentMethod;

      final matchesRegister =
          _currentRegisterId == 'all' || tx.registerId == _currentRegisterId;

      final txDay = DateTime(
        tx.dateTime.year,
        tx.dateTime.month,
        tx.dateTime.day,
      );
      final matchesFrom =
          _currentDateFrom == null ||
          !txDay.isBefore(
            DateTime(
              _currentDateFrom!.year,
              _currentDateFrom!.month,
              _currentDateFrom!.day,
            ),
          );
      final matchesTo =
          _currentDateTo == null ||
          !txDay.isAfter(
            DateTime(
              _currentDateTo!.year,
              _currentDateTo!.month,
              _currentDateTo!.day,
            ),
          );

      return matchesSearch &&
          matchesFilter &&
          matchesPayment &&
          matchesRegister &&
          matchesFrom &&
          matchesTo;
    }).toList();

    emit(
      CashLoaded(
        transactions: _cachedTransactions,
        filteredTransactions: filtered,
        activeShift: _cachedActiveShift,
        summaries: _cachedSummaries,
        shifts: _cachedShifts,
        registers: _cachedRegisters,
        query: _currentQuery,
        filterType: _currentFilterType,
        paymentMethod: _currentPaymentMethod,
        registerId: _currentRegisterId,
        dateFrom: _currentDateFrom,
        dateTo: _currentDateTo,
        errorMessage: errorMessage,
      ),
    );
  }
}
