import 'finance_model.dart';

/// Репозиторий для получения финансовых данных панели управления.
abstract class FinanceRepository {
  /// Returns the core dashboard data as one logical request.
  ///
  /// Existing repositories get a compatible parallel implementation. API
  /// repositories can override it to parse a single `/finance/overview`
  /// response.
  Future<FinanceOverview> getOverview({bool forceRefresh = false}) async {
    final results = await Future.wait([getMetrics(), getCashFlowHistory()]);
    return FinanceOverview(
      metrics: results[0] as FinanceMetrics,
      history: results[1] as List<CashFlowPoint>,
    );
  }

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

  /// Доска курсов: НБТ + покупка/продажа банков (`GET /finance/currency-board`).
  Future<CurrencyBoard> getCurrencyBoard();

  /// Получить AI-рекомендации и прогноз кассового разрыва
  Future<AiInsightsReport> getAiInsights();

  /// Получить план-факт отчет за период
  Future<PlanFactReport> getPlanFactReport();

  Future<ClientAnalysisReport> getClientAnalysis();

  Future<PlanItem> createPlan({
    required String period,
    required String category,
    required String type,
    required double plannedAmount,
  });

  Future<void> deletePlan(int planId);

  Future<BankAccountInfo> createAccount({
    required String name,
    String? bank,
    String? number,
    String currency = 'TJS',
    double balance = 0,
  });

  Future<void> deleteAccount(String accountId);

  Future<void> zeroOutAccount(String accountId);

  Future<ConvertResult> convertAmount(double amount, String base);

  Future<void> refreshRates();
}
