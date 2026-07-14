import 'strategy_models.dart';

/// Абстрактный контракт для репозитория стратегического моделирования и AI-Маркетинга.
abstract class StrategyRepository {
  /// Отправить финансовый What-if сценарий на симуляцию ИИ
  Future<WhatIfResponseData> askWhatIf(String question);

  /// Сгенерировать ИИ-идеи для маркетингового продвижения
  Future<AiIdeasResponseData> generateAiIdeas(String prompt);

  /// Получить список стратегических анализов по типу (swot, bcg, pestel)
  Future<List<StrategicAnalysis>> getAnalyses(String type);

  /// Запустить AI-генерацию анализа
  Future<StrategicAnalysis> generateAnalysis(String type, String period);
}
