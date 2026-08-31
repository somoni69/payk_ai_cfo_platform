import 'strategy_models.dart';

/// Абстрактный контракт для репозитория стратегического моделирования и AI-Маркетинга.
abstract class StrategyRepository {
  /// Отправить финансовый What-if сценарий на симуляцию ИИ
  Future<WhatIfResponseData> askWhatIf(String question);

  /// Сгенерировать ИИ-идеи для маркетингового продвижения
  Future<AiIdeasResponseData> generateAiIdeas(String prompt);

  /// Получить список стратегических анализов по типу (swot, bcg, pestel)
  Future<List<StrategicAnalysis>> getAnalyses(
    String type, {
    bool forceRefresh = false,
  });

  /// Запустить AI-генерацию анализа
  Future<StrategicAnalysis> generateAnalysis(String type, String period);

  Future<void> deleteAnalysis(String id);

  Future<List<MacroIndicator>> getMacroIndicators();

  Future<MacroIndicator> createMacroIndicator({
    required String name,
    required double value,
    String? unit,
  });

  Future<void> deleteMacroIndicator(String id);

  Future<List<StrategyScenario>> getScenarios({String? quarter});

  Future<List<StrategyScenario>> generateScenarios(String quarter);

  Future<void> deleteScenario(String id);

  Future<DailySummary> getDailySummary();

  Future<List<NewsSource>> getNews();
}

/// Optional lifecycle contract for repositories with long-running requests.
abstract interface class CancellableStrategyRepository {
  void cancelPendingRequests();
}
