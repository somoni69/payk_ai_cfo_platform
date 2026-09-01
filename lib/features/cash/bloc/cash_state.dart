import 'package:equatable/equatable.dart';
import '../../../core/models/ui_feedback.dart';
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
  final String paymentMethod;
  final String registerId;
  final String cashierId;
  final DateTime? dateFrom;
  final DateTime? dateTo;
  final bool isSubmitting;
  final UiFeedback? feedback;
  final String? errorMessage;

  const CashLoaded({
    required this.transactions,
    required this.filteredTransactions,
    this.activeShift,
    this.summaries = const [],
    this.shifts = const [],
    this.registers = const [],
    required this.query,
    required this.filterType,
    this.paymentMethod = 'all',
    this.registerId = 'all',
    this.cashierId = 'all',
    this.dateFrom,
    this.dateTo,
    this.isSubmitting = false,
    this.feedback,
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
    String? paymentMethod,
    String? registerId,
    String? cashierId,
    DateTime? dateFrom,
    DateTime? dateTo,
    bool clearDateFrom = false,
    bool clearDateTo = false,
    bool? isSubmitting,
    UiFeedback? feedback,
    bool clearFeedback = false,
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
      paymentMethod: paymentMethod ?? this.paymentMethod,
      registerId: registerId ?? this.registerId,
      cashierId: cashierId ?? this.cashierId,
      dateFrom: clearDateFrom ? null : (dateFrom ?? this.dateFrom),
      dateTo: clearDateTo ? null : (dateTo ?? this.dateTo),
      isSubmitting: isSubmitting ?? this.isSubmitting,
      feedback: clearFeedback ? null : (feedback ?? this.feedback),
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
    paymentMethod,
    registerId,
    cashierId,
    dateFrom,
    dateTo,
    isSubmitting,
    feedback,
    errorMessage,
  ];
}

class CashError extends CashState {
  final String message;

  const CashError(this.message);

  @override
  List<Object?> get props => [message];
}
