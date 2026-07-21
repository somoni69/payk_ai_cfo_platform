import 'transaction_model.dart';

/// Интерфейс репозитория кассовых операций и смен.
abstract class CashRepository {
  /// Получить список всех кассовых транзакций
  Future<List<Transaction>> getTransactions();

  /// Добавить новую транзакцию
  Future<Transaction> addTransaction(Transaction transaction);

  /// Получить данные о текущей смене
  Future<CashShift?> getActiveShift();

  /// Открыть новую кассовую смену (CASH-05)
  Future<CashShift> openShift(double startingBalance);

  /// Opens a shift using an already loaded register when available.
  Future<CashShift> openShiftForRegister(
    double startingBalance, {
    String? registerId,
  }) => openShift(startingBalance);

  /// Закрыть текущую смену с подсчетом разницы (CASH-06)
  Future<CashShift> closeShift(double endingBalance);

  /// Closes a known active shift without reloading the shifts collection.
  Future<CashShift> closeShiftById(double endingBalance, {String? shiftId}) =>
      closeShift(endingBalance);

  /// Получить сводные показатели касс
  Future<List<CashSummary>> getSummary();

  /// Получить историю всех смен
  Future<List<CashShift>> getShifts();

  /// Получить список всех касс (кассовых аппаратов)
  Future<List<CashRegister>> getRegisters();
}
