import 'dart:typed_data';

import 'transaction_model.dart';

/// Filters for cash operations list / export (web parity).
class CashOperationFilters {
  final int? registerId;
  final String? type; // income | expense
  final String? paymentMethod;
  final int? cashierId;
  final DateTime? dateFrom;
  final DateTime? dateTo;
  final String? query;
  final int page;
  final int size;

  const CashOperationFilters({
    this.registerId,
    this.type,
    this.paymentMethod,
    this.cashierId,
    this.dateFrom,
    this.dateTo,
    this.query,
    this.page = 1,
    this.size = 200,
  });

  Map<String, dynamic> toQuery() {
    final q = <String, dynamic>{'page': page, 'size': size};
    if (registerId != null) q['register_id'] = registerId;
    if (type != null && type!.isNotEmpty && type != 'all') q['type'] = type;
    if (paymentMethod != null &&
        paymentMethod!.isNotEmpty &&
        paymentMethod != 'all') {
      q['payment_method'] = paymentMethod;
    }
    if (cashierId != null) q['cashier_id'] = cashierId;
    if (dateFrom != null) q['date_from'] = dateFrom!.toUtc().toIso8601String();
    if (dateTo != null) q['date_to'] = dateTo!.toUtc().toIso8601String();
    if (query != null && query!.trim().isNotEmpty) q['q'] = query!.trim();
    return q;
  }
}

class CashierLookup {
  final String id;
  final String name;

  const CashierLookup({required this.id, required this.name});
}

class OneCKkmMappingRow {
  final String onecName;
  final int? targetId;
  final String? targetName;
  final String? matchedBy;

  const OneCKkmMappingRow({
    required this.onecName,
    this.targetId,
    this.targetName,
    this.matchedBy,
  });
}

class OneCKkmTargetOption {
  final int id;
  final String name;

  const OneCKkmTargetOption({required this.id, required this.name});
}

class OneCKkmPayment {
  final String kind;
  final String card;
  final double amount;
  final String? bankName;

  const OneCKkmPayment({
    required this.kind,
    required this.card,
    this.amount = 0,
    this.bankName,
  });
}

class OneCKkmReconcileRow {
  final String docDate;
  final String onecRegister;
  final String? paykRegisterName;
  final int shiftsCount;
  final double onecTotal;
  final double? paykTotal;
  final double? diffTotal;

  const OneCKkmReconcileRow({
    required this.docDate,
    required this.onecRegister,
    this.paykRegisterName,
    this.shiftsCount = 0,
    this.onecTotal = 0,
    this.paykTotal,
    this.diffTotal,
  });
}

class OneCKkmOverview {
  final String source;
  final String? error;
  final String? syncedAt;
  final List<OneCKkmShift> shifts;
  final Map<String, dynamic> totals;
  final Map<String, dynamic> mapping;
  final Map<String, dynamic> targets;
  final List<OneCKkmMappingRow> mappingRegisters;
  final List<OneCKkmMappingRow> mappingDepartments;
  final List<OneCKkmMappingRow> mappingCards;
  final List<OneCKkmTargetOption> targetRegisters;
  final List<OneCKkmTargetOption> targetBranches;
  final List<OneCKkmTargetOption> targetBanks;
  final List<OneCKkmReconcileRow> reconcile;

  const OneCKkmOverview({
    this.source = 'live',
    this.error,
    this.syncedAt,
    this.shifts = const [],
    this.totals = const {},
    this.mapping = const {},
    this.targets = const {},
    this.mappingRegisters = const [],
    this.mappingDepartments = const [],
    this.mappingCards = const [],
    this.targetRegisters = const [],
    this.targetBranches = const [],
    this.targetBanks = const [],
    this.reconcile = const [],
  });
}

class OneCKkmShift {
  final String number;
  final String registerName;
  final String cashierName;
  final String? departmentName;
  final String? closedAt;
  final double total;
  final double cashTotal;
  final double cashlessTotal;
  final List<OneCKkmPayment> payments;
  final String? paykRegisterName;

  const OneCKkmShift({
    required this.number,
    required this.registerName,
    required this.cashierName,
    this.departmentName,
    this.closedAt,
    this.total = 0,
    this.cashTotal = 0,
    this.cashlessTotal = 0,
    this.payments = const [],
    this.paykRegisterName,
  });
}

/// Интерфейс репозитория кассовых операций и смен.
abstract class CashRepository {
  /// Получить список кассовых транзакций
  Future<List<Transaction>> getTransactions({
    CashOperationFilters filters = const CashOperationFilters(),
  });

  Future<List<CashierLookup>> lookupCashiers();

  Future<OneCKkmOverview> getOneCKkmShifts({
    DateTime? dateFrom,
    DateTime? dateTo,
    bool refresh = true,
  });

  Future<void> saveOneCKkmLink({
    required String scope,
    required String onecName,
    int? targetId,
  });

  /// Добавить новую транзакцию
  Future<Transaction> addTransaction(Transaction transaction);

  Future<Transaction> getOperation(String id) =>
      getTransactions().then((list) => list.firstWhere((t) => t.id == id));

  Future<Transaction> updateTransaction(Transaction transaction) =>
      addTransaction(transaction);

  Future<void> deleteTransaction(String id) async {}

  /// Каталог товаров для продажи без штрих-кода (`GET /cash/sale-products`).
  /// Кассиру доступен без права на модуль «Склад».
  Future<List<SaleProduct>> getSaleProducts({String? search});

  /// Товар по отсканированному штрих-коду (`GET /cash/sale-products/by-barcode/{code}`).
  Future<SaleProduct> getSaleProductByBarcode(String code);

  /// Чистая прибыль с продаж (выручка − закупка) за период.
  Future<SalesProfit> getSalesProfit({DateTime? dateFrom, DateTime? dateTo});

  /// Получить данные о текущей смене
  Future<CashShift?> getActiveShift();

  /// Открыть новую кассовую смену (CASH-05)
  Future<CashShift> openShift(double startingBalance);

  /// Opens a shift using an already loaded register when available.
  Future<CashShift> openShiftForRegister(
    double startingBalance, {
    String? registerId,
  }) => openShift(startingBalance);

  /// Closes a known active shift without reloading the shifts collection.
  Future<CashShift> closeShiftById(
    double endingBalance, {
    String? shiftId,
    String? note,
  }) => closeShift(endingBalance, note: note);

  /// Закрыть текущую смену с подсчетом разницы (CASH-06)
  Future<CashShift> closeShift(double endingBalance, {String? note});

  /// Получить сводные показатели касс
  Future<List<CashSummary>> getSummary();

  /// Получить историю всех смен
  Future<List<CashShift>> getShifts();

  /// Получить список всех касс (кассовых аппаратов)
  Future<List<CashRegister>> getRegisters();

  /// Export operations (`GET /cash/export`) — fmt: xlsx | csv | pdf.
  Future<Uint8List> exportOperations({
    required String format,
    CashOperationFilters filters = const CashOperationFilters(),
  });

  /// Import operations file (`POST /cash/import`).
  Future<int> importOperations({
    required int registerId,
    required String filename,
    required Uint8List bytes,
  });
}
