import 'dart:typed_data';

import 'transaction_model.dart';

/// Filters for cash operations list / export (web parity).
class CashOperationFilters {
  final int? registerId;
  final String? type; // income | expense
  final DateTime? dateFrom;
  final DateTime? dateTo;

  const CashOperationFilters({
    this.registerId,
    this.type,
    this.dateFrom,
    this.dateTo,
  });

  Map<String, dynamic> toQuery() {
    final q = <String, dynamic>{};
    if (registerId != null) q['register_id'] = registerId;
    if (type != null && type!.isNotEmpty && type != 'all') q['type'] = type;
    if (dateFrom != null) q['date_from'] = dateFrom!.toUtc().toIso8601String();
    if (dateTo != null) q['date_to'] = dateTo!.toUtc().toIso8601String();
    return q;
  }
}

/// Интерфейс репозитория кассовых операций и смен.
abstract class CashRepository {
  /// Получить список всех кассовых транзакций
  Future<List<Transaction>> getTransactions();

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
