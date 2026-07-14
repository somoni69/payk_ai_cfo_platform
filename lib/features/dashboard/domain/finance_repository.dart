import 'finance_model.dart';

/// Репозиторий для получения финансовых данных панели управления.
abstract class FinanceRepository {
  /// Получить 6 ключевых показателей компании
  Future<FinanceMetrics> getMetrics();

  /// Получить историю изменения кассового баланса за последние 30 дней
  Future<List<CashFlowPoint>> getCashFlowHistory();

  /// Получить отчет P&L за период
  Future<PnlReport> getPnlReport();

  /// Получить точку безубыточности
  Future<BreakEvenAnalysis> getBreakEvenAnalysis();

  /// Получить ABC-анализ по измерению
  Future<AbcAnalysis> getAbcAnalysis(String dimension);

  /// Получить счета компании
  Future<BankAccountsReport> getBankAccounts();

  /// Получить курсы валют НБТ
  Future<ExchangeRatesReport> getExchangeRates();

  /// Получить AI-рекомендации и прогноз кассового разрыва
  Future<AiInsightsReport> getAiInsights();

  /// Получить план-факт отчет за период
  Future<PlanFactReport> getPlanFactReport();
}
