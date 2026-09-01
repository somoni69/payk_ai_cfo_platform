import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:stream_transform/stream_transform.dart';

import '../../../core/models/ui_feedback.dart';
import '../../../core/network/user_facing_error.dart';
import '../domain/cash_repository.dart';
import '../domain/transaction_model.dart';
import 'cash_event.dart';
import 'cash_state.dart';

EventTransformer<E> _debounceTransformer<E>(Duration duration) {
  return (events, mapper) => events.debounce(duration).switchMap(mapper);
}

class CashBloc extends Bloc<CashEvent, CashState> {
  final CashRepository _repository;

  CashBloc(this._repository) : super(CashLoading()) {
    on<LoadCashData>(_onLoadCashData, transformer: droppable());
    on<AddTransactionRequested>(
      _onAddTransactionRequested,
      transformer: droppable(),
    );
    on<UpdateTransactionRequested>(
      _onUpdateTransactionRequested,
      transformer: droppable(),
    );
    on<DeleteTransactionRequested>(_onDeleteTransactionRequested);
    on<OpenShiftRequested>(_onOpenShiftRequested, transformer: droppable());
    on<CloseShiftRequested>(_onCloseShiftRequested, transformer: droppable());
    on<SearchFilterChanged>(
      _onSearchFilterChanged,
      transformer: _debounceTransformer(const Duration(milliseconds: 300)),
    );
  }

  Future<void> _onLoadCashData(
    LoadCashData event,
    Emitter<CashState> emit,
  ) async {
    final currentLoaded = state is CashLoaded ? state as CashLoaded : null;

    if (currentLoaded == null) {
      emit(CashLoading());
    }

    try {
      final filters = currentLoaded != null
          ? _filtersFromState(currentLoaded)
          : null;

      final results = await Future.wait<Object>([
        _repository.getTransactions(
          filters: filters ?? const CashOperationFilters(),
        ),
        _repository.getSummary(),
        _repository.getShifts(),
        _repository.getRegisters(),
      ]);

      final transactions = (results[0] as List).cast<Transaction>();
      final summaries = (results[1] as List).cast<CashSummary>();
      final shifts = (results[2] as List).cast<CashShift>();
      final registers = (results[3] as List).cast<CashRegister>();

      CashShift? activeShift;
      for (final shift in shifts) {
        if (shift.isOpen) {
          activeShift = shift;
          break;
        }
      }

      final query = currentLoaded?.query ?? '';
      final filterType = currentLoaded?.filterType ?? 'all';
      final paymentMethod = currentLoaded?.paymentMethod ?? 'all';
      final registerId = currentLoaded?.registerId ?? 'all';
      final cashierId = currentLoaded?.cashierId ?? 'all';
      final dateFrom = currentLoaded?.dateFrom;
      final dateTo = currentLoaded?.dateTo;

      final filtered = _filterTransactions(
        transactions: transactions,
        query: query,
        filterType: filterType,
        paymentMethod: paymentMethod,
        registerId: registerId,
        dateFrom: dateFrom,
        dateTo: dateTo,
      );

      emit(
        CashLoaded(
          transactions: transactions,
          filteredTransactions: filtered,
          activeShift: activeShift,
          summaries: summaries,
          shifts: shifts,
          registers: registers,
          query: query,
          filterType: filterType,
          paymentMethod: paymentMethod,
          registerId: registerId,
          cashierId: cashierId,
          dateFrom: dateFrom,
          dateTo: dateTo,
        ),
      );
    } catch (e) {
      final message = userFacingError(e, fallback: ErrorKeys.loadFailed);
      if (currentLoaded != null) {
        emit(currentLoaded.copyWith(errorMessage: message));
      } else {
        emit(CashError(message));
      }
    }
  }

  Future<void> _onSearchFilterChanged(
    SearchFilterChanged event,
    Emitter<CashState> emit,
  ) async {
    if (state is! CashLoaded) return;
    final current = state as CashLoaded;

    final filtersChanged =
        event.filterType != current.filterType ||
        event.paymentMethod != current.paymentMethod ||
        event.registerId != current.registerId ||
        event.cashierId != current.cashierId ||
        event.dateFrom != current.dateFrom ||
        event.dateTo != current.dateTo;

    List<Transaction> transactions = current.transactions;

    if (filtersChanged) {
      try {
        final filters = CashOperationFilters(
          registerId: event.registerId == 'all'
              ? null
              : int.tryParse(event.registerId),
          type: event.filterType == 'all' ? null : event.filterType,
          paymentMethod: event.paymentMethod == 'all'
              ? null
              : event.paymentMethod,
          cashierId: event.cashierId == 'all'
              ? null
              : int.tryParse(event.cashierId),
          dateFrom: event.dateFrom,
          dateTo: event.dateTo,
          query: event.query,
        );
        transactions = await _repository.getTransactions(filters: filters);
      } catch (_) {}
    }

    final filtered = _filterTransactions(
      transactions: transactions,
      query: event.query,
      filterType: event.filterType,
      paymentMethod: event.paymentMethod,
      registerId: event.registerId,
      dateFrom: event.dateFrom,
      dateTo: event.dateTo,
    );

    emit(
      current.copyWith(
        transactions: transactions,
        filteredTransactions: filtered,
        query: event.query,
        filterType: event.filterType,
        paymentMethod: event.paymentMethod,
        registerId: event.registerId,
        cashierId: event.cashierId,
        dateFrom: event.dateFrom,
        dateTo: event.dateTo,
      ),
    );
  }

  Future<void> _onAddTransactionRequested(
    AddTransactionRequested event,
    Emitter<CashState> emit,
  ) async {
    if (state is! CashLoaded) return;
    final current = state as CashLoaded;

    // Валидация: Нельзя провести операцию без открытой смены (CASH-05)
    if (current.activeShift == null) {
      emit(
        current.copyWith(
          errorMessage: 'cash_err_need_open_shift',
          feedback: const LocalizedFeedback('cash_err_need_open_shift'),
        ),
      );
      return;
    }

    emit(
      current.copyWith(
        isSubmitting: true,
        clearError: true,
        clearFeedback: true,
      ),
    );

    try {
      final newTx = await _repository.addTransaction(event.transaction);
      final updatedList = List<Transaction>.from(current.transactions)
        ..removeWhere((t) => t.id == newTx.id)
        ..insert(0, newTx);

      List<CashSummary> summaries = current.summaries;
      String? summaryError;
      try {
        summaries = await _repository.getSummary();
      } catch (_) {
        summaryError = 'cash_tx_saved_summary_failed';
      }

      final filtered = _filterTransactions(
        transactions: updatedList,
        query: current.query,
        filterType: current.filterType,
        paymentMethod: current.paymentMethod,
        registerId: current.registerId,
        dateFrom: current.dateFrom,
        dateTo: current.dateTo,
      );

      emit(
        current.copyWith(
          transactions: updatedList,
          filteredTransactions: filtered,
          summaries: summaries,
          isSubmitting: false,
          errorMessage: summaryError,
          feedback: summaryError != null
              ? LocalizedFeedback(summaryError, isError: true)
              : const LocalizedFeedback('cash_tx_saved_success'),
        ),
      );
    } catch (e) {
      final msg = userFacingError(e, fallback: ErrorKeys.saveFailed);
      emit(
        current.copyWith(
          isSubmitting: false,
          errorMessage: msg,
          feedback: LocalizedFeedback(msg),
        ),
      );
    }
  }

  Future<void> _onUpdateTransactionRequested(
    UpdateTransactionRequested event,
    Emitter<CashState> emit,
  ) async {
    if (state is! CashLoaded) return;
    final current = state as CashLoaded;
    emit(
      current.copyWith(
        isSubmitting: true,
        clearError: true,
        clearFeedback: true,
      ),
    );

    try {
      final updated = await _repository.updateTransaction(event.transaction);
      final updatedList = [
        for (final tx in current.transactions)
          tx.id == updated.id ? updated : tx,
      ];

      final filtered = _filterTransactions(
        transactions: updatedList,
        query: current.query,
        filterType: current.filterType,
        paymentMethod: current.paymentMethod,
        registerId: current.registerId,
        dateFrom: current.dateFrom,
        dateTo: current.dateTo,
      );

      emit(
        current.copyWith(
          transactions: updatedList,
          filteredTransactions: filtered,
          isSubmitting: false,
          feedback: const LocalizedFeedback('cash_tx_saved_success'),
        ),
      );
    } catch (e) {
      final msg = userFacingError(e, fallback: ErrorKeys.saveFailed);
      emit(
        current.copyWith(
          isSubmitting: false,
          errorMessage: msg,
          feedback: LocalizedFeedback(msg),
        ),
      );
    }
  }

  Future<void> _onDeleteTransactionRequested(
    DeleteTransactionRequested event,
    Emitter<CashState> emit,
  ) async {
    if (state is! CashLoaded) return;
    final current = state as CashLoaded;

    try {
      await _repository.deleteTransaction(event.id);
      final updatedList = current.transactions
          .where((tx) => tx.id != event.id)
          .toList(growable: false);

      List<CashSummary> summaries = current.summaries;
      try {
        summaries = await _repository.getSummary();
      } catch (_) {}

      final filtered = _filterTransactions(
        transactions: updatedList,
        query: current.query,
        filterType: current.filterType,
        paymentMethod: current.paymentMethod,
        registerId: current.registerId,
        dateFrom: current.dateFrom,
        dateTo: current.dateTo,
      );

      emit(
        current.copyWith(
          transactions: updatedList,
          filteredTransactions: filtered,
          summaries: summaries,
        ),
      );
    } catch (e) {
      emit(
        current.copyWith(
          errorMessage: userFacingError(e, fallback: ErrorKeys.saveFailed),
        ),
      );
    }
  }

  Future<void> _onOpenShiftRequested(
    OpenShiftRequested event,
    Emitter<CashState> emit,
  ) async {
    if (state is! CashLoaded) return;
    final current = state as CashLoaded;
    emit(
      current.copyWith(
        isSubmitting: true,
        clearError: true,
        clearFeedback: true,
      ),
    );

    try {
      final registerId =
          event.registerId ??
          (current.registers.isEmpty ? null : current.registers.first.id);

      final activeShift = await _repository.openShiftForRegister(
        event.startingBalance,
        registerId: registerId,
      );

      final refreshed = await Future.wait([
        _repository.getSummary(),
        _repository.getShifts(),
      ]);

      emit(
        current.copyWith(
          activeShift: activeShift,
          summaries: refreshed[0] as List<CashSummary>,
          shifts: refreshed[1] as List<CashShift>,
          isSubmitting: false,
          feedback: const LocalizedFeedback('cash_shift_opened_success'),
        ),
      );
    } catch (e) {
      emit(
        current.copyWith(
          isSubmitting: false,
          errorMessage: userFacingError(e, fallback: ErrorKeys.saveFailed),
        ),
      );
    }
  }

  Future<void> _onCloseShiftRequested(
    CloseShiftRequested event,
    Emitter<CashState> emit,
  ) async {
    if (state is! CashLoaded) return;
    final current = state as CashLoaded;

    CashShift? targetShift = current.activeShift;
    if (event.shiftId != null) {
      for (final shift in current.shifts) {
        if (shift.id == event.shiftId) {
          targetShift = shift;
          break;
        }
      }
    }

    if (targetShift == null) return;
    emit(
      current.copyWith(
        isSubmitting: true,
        clearError: true,
        clearFeedback: true,
      ),
    );

    try {
      final closedShift = await _repository.closeShiftById(
        event.endingBalance,
        shiftId: targetShift.id,
        note: event.note,
      );

      // CASH-06: Автоматический подсчет разницы
      final double netFlow = current.transactions
          .where((t) => t.dateTime.isAfter(closedShift.openedAt))
          .fold(0.0, (sum, t) => sum + (t.isIncome ? t.amount : -t.amount));

      final expectedBalance = targetShift.startingBalance + netFlow;
      final diff = event.endingBalance - expectedBalance;

      final feedback = diff.abs() < 0.01
          ? const LocalizedFeedback('cash_shift_closed_balanced')
          : ShiftClosedFeedback(diff: diff, expectedBalance: expectedBalance);

      final refreshed = await Future.wait([
        _repository.getSummary(),
        _repository.getShifts(),
      ]);

      emit(
        current.copyWith(
          clearActiveShift: true,
          summaries: refreshed[0] as List<CashSummary>,
          shifts: refreshed[1] as List<CashShift>,
          isSubmitting: false,
          feedback: feedback,
          errorMessage: feedback.translationKey,
        ),
      );
    } catch (e) {
      emit(
        current.copyWith(
          isSubmitting: false,
          errorMessage: userFacingError(e, fallback: ErrorKeys.saveFailed),
        ),
      );
    }
  }

  static CashOperationFilters _filtersFromState(CashLoaded state) {
    return CashOperationFilters(
      registerId: state.registerId == 'all'
          ? null
          : int.tryParse(state.registerId),
      type: state.filterType == 'all' ? null : state.filterType,
      paymentMethod: state.paymentMethod == 'all' ? null : state.paymentMethod,
      cashierId: state.cashierId == 'all'
          ? null
          : int.tryParse(state.cashierId),
      dateFrom: state.dateFrom,
      dateTo: state.dateTo,
      query: state.query,
    );
  }

  static List<Transaction> _filterTransactions({
    required List<Transaction> transactions,
    required String query,
    required String filterType,
    required String paymentMethod,
    required String registerId,
    DateTime? dateFrom,
    DateTime? dateTo,
  }) {
    final normalizedQuery = query.trim().toLowerCase();
    return transactions.where((tx) {
      final matchesSearch =
          normalizedQuery.isEmpty ||
          tx.title.toLowerCase().contains(normalizedQuery) ||
          tx.category.toLowerCase().contains(normalizedQuery);

      final matchesFilter =
          filterType == 'all' ||
          (filterType == 'income' && tx.isIncome) ||
          (filterType == 'expense' && !tx.isIncome);

      final matchesPayment =
          paymentMethod == 'all' ||
          tx.paymentMethod.name == paymentMethod ||
          tx.paymentMethod.apiValue == paymentMethod;

      final matchesRegister =
          registerId == 'all' || tx.registerId == registerId;

      final txDay = DateTime(
        tx.dateTime.year,
        tx.dateTime.month,
        tx.dateTime.day,
      );

      final matchesFrom =
          dateFrom == null ||
          !txDay.isBefore(
            DateTime(dateFrom.year, dateFrom.month, dateFrom.day),
          );

      final matchesTo =
          dateTo == null ||
          !txDay.isAfter(DateTime(dateTo.year, dateTo.month, dateTo.day));

      return matchesSearch &&
          matchesFilter &&
          matchesPayment &&
          matchesRegister &&
          matchesFrom &&
          matchesTo;
    }).toList();
  }
}
