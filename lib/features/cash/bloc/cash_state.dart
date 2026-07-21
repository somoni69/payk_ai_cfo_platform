import 'package:equatable/equatable.dart';
import '../domain/transaction_model.dart';

abstract class CashState extends Equatable {
  const CashState();

  @override
  List<Object?> get props => [];
}

class CashLoading extends CashState {}

class CashLoaded extends CashState {
  final List<Transaction> transactions;
  final List<Transaction> filteredTransactions;
  final CashShift? activeShift;
  final List<CashSummary> summaries;
  final List<CashShift> shifts;
  final List<CashRegister> registers;
  final String query;
  final String filterType;
  final String?
  errorMessage; // Для показа временных ошибок на UI (например, при валидации сумм)

  const CashLoaded({
    required this.transactions,
    required this.filteredTransactions,
    this.activeShift,
    this.summaries = const [],
    this.shifts = const [],
    this.registers = const [],
    required this.query,
    required this.filterType,
    this.errorMessage,
  });

  CashLoaded copyWith({
    List<Transaction>? transactions,
    List<Transaction>? filteredTransactions,
    CashShift? activeShift,
    bool clearActiveShift = false,
    List<CashSummary>? summaries,
    List<CashShift>? shifts,
    List<CashRegister>? registers,
    String? query,
    String? filterType,
    String? errorMessage,
    bool clearError = false,
  }) {
    return CashLoaded(
      transactions: transactions ?? this.transactions,
      filteredTransactions: filteredTransactions ?? this.filteredTransactions,
      activeShift: clearActiveShift ? null : (activeShift ?? this.activeShift),
      summaries: summaries ?? this.summaries,
      shifts: shifts ?? this.shifts,
      registers: registers ?? this.registers,
      query: query ?? this.query,
      filterType: filterType ?? this.filterType,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }

  @override
  List<Object?> get props => [
    transactions,
    filteredTransactions,
    activeShift,
    summaries,
    shifts,
    registers,
    query,
    filterType,
    errorMessage,
  ];
}

class CashError extends CashState {
  final String message;

  const CashError(this.message);

  @override
  List<Object?> get props => [message];
}
