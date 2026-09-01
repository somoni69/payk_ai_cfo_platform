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
    if (registerId case final rId?) q['register_id'] = rId;
    if (type case final t? when t.isNotEmpty && t != 'all') q['type'] = t;
    if (paymentMethod case final pm? when pm.isNotEmpty && pm != 'all') {
      q['payment_method'] = pm;
    }
    if (cashierId case final cId?) {
      q['cashier_id'] = cId;
    }
    if (dateFrom case final from?) {
      q['date_from'] = from.toUtc().toIso8601String();
    }
    if (dateTo case final to?) {
      q['date_to'] = to.toUtc().toIso8601String();
    }
    if (query?.trim() case final qText? when qText.isNotEmpty) {
      q['q'] = qText;
    }
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

class OneCKkmShiftSummary {
  final int id;
  final String number;
  final String registerName;
  final String cashierName;
  final String? departmentName;
  final String? paykRegisterName;
  final DateTime? openedAt;
  final String? closedAt;
  final double total;
  final double cashTotal;
  final double cashlessTotal;
  final double startingBalance;
  final double endingBalance;
  final double cashRevenue;
  final double nonCashRevenue;
  final double discrepancy;
  final String syncStatus;
  final String? onecDocNumber;
  final String? failureReason;
  final List<OneCKkmPayment> payments;

  const OneCKkmShiftSummary({
    this.id = 0,
    this.number = '',
    required this.registerName,
    required this.cashierName,
    this.departmentName,
    this.paykRegisterName,
    this.openedAt,
    this.closedAt,
    this.total = 0,
    this.cashTotal = 0,
    this.cashlessTotal = 0,
    this.startingBalance = 0,
    this.endingBalance = 0,
    this.cashRevenue = 0,
    this.nonCashRevenue = 0,
    this.discrepancy = 0,
    this.syncStatus = 'synced',
    this.onecDocNumber,
    this.failureReason,
    this.payments = const [],
  });
}

typedef OneCKkmShift = OneCKkmShiftSummary;

class OneCKkmOverview {
  final bool enabled;
  final String connectionStatus;
  final String? lastSuccessfulSync;
  final int unsyncedShiftsCount;
  final int autoSyncIntervalMinutes;
  final String source;
  final String? error;
  final String? syncedAt;
  final List<OneCKkmShiftSummary> shifts;
  final Map<String, dynamic> totals;
  final Map<String, dynamic> mapping;
  final Map<String, dynamic> targets;
  final List<OneCKkmMappingRow> registerMappings;
  final List<OneCKkmMappingRow> cashierMappings;
  final List<OneCKkmMappingRow> mappingRegisters;
  final List<OneCKkmMappingRow> mappingDepartments;
  final List<OneCKkmMappingRow> mappingCards;
  final List<OneCKkmTargetOption> available1CRegisters;
  final List<OneCKkmTargetOption> available1CCashiers;
  final List<OneCKkmTargetOption> targetRegisters;
  final List<OneCKkmTargetOption> targetBranches;
  final List<OneCKkmTargetOption> targetBanks;
  final List<OneCKkmReconcileRow> reconcile;

  const OneCKkmOverview({
    this.enabled = false,
    this.connectionStatus = 'offline',
    this.lastSuccessfulSync,
    this.unsyncedShiftsCount = 0,
    this.autoSyncIntervalMinutes = 15,
    this.source = 'live',
    this.error,
    this.syncedAt,
    this.shifts = const [],
    this.totals = const {},
    this.mapping = const {},
    this.targets = const {},
    this.registerMappings = const [],
    this.cashierMappings = const [],
    this.mappingRegisters = const [],
    this.mappingDepartments = const [],
    this.mappingCards = const [],
    this.available1CRegisters = const [],
    this.available1CCashiers = const [],
    this.targetRegisters = const [],
    this.targetBranches = const [],
    this.targetBanks = const [],
    this.reconcile = const [],
  });
}

/// Abstract contract for cash management operations (CASH-*).
abstract interface class CashRepository {
  /// Список транзакций (доходов и расходов)
  Future<List<Transaction>> getTransactions({
    CashOperationFilters filters = const CashOperationFilters(),
  });

  /// Получить операцию по идентификатору
  Future<Transaction> getOperation(String id);

  /// Добавить новую транзакцию
  Future<Transaction> addTransaction(Transaction transaction);

  /// Обновить существующую транзакцию
  Future<Transaction> updateTransaction(Transaction transaction);

  /// Удалить транзакцию по идентификатору
  Future<void> deleteTransaction(String id);

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
  });

  /// Closes a known active shift without reloading the shifts collection.
  Future<CashShift> closeShiftById(
    double endingBalance, {
    String? shiftId,
    String? note,
  });

  /// Закрыть текущую смену с подсчетом разницы (CASH-06)
  Future<CashShift> closeShift(double endingBalance, {String? note});

  /// Получить сводные показатели касс
  Future<List<CashSummary>> getSummary();

  /// Получить историю всех смен
  Future<List<CashShift>> getShifts();

  /// Получить список всех касс (кассовых аппаратов)
  Future<List<CashRegister>> getRegisters();

  /// Export operations as raw file bytes (xlsx | csv | pdf).
  Future<Uint8List> exportOperations({
    required String format,
    CashOperationFilters filters = const CashOperationFilters(),
  });

  /// Import bank/cash statement file (`POST /cash/import`).
  Future<int> importOperations({
    required int registerId,
    required String filename,
    required Uint8List bytes,
  });

  /// Cashier lookup for filter dropdown (`GET /cash/cashiers`).
  Future<List<CashierLookup>> lookupCashiers();

  /// 1C:KKM Integration Overview
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
}
