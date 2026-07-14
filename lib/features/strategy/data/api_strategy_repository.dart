import '../../../core/network/api_client.dart';
import '../domain/strategy_models.dart';
import '../domain/strategy_repository.dart';

/// Конкретная реализация репозитория стратегических AI функций для бэкенда PAYK.
class ApiStrategyRepository implements StrategyRepository {
  final ApiClient _apiClient = ApiClient();

  @override
  Future<WhatIfResponseData> askWhatIf(String question) async {
    try {
      final payload = {'question': question};
      final response = await _apiClient.dio.post('/strategy/what-if', data: payload);
      final map = response.data as Map<String, dynamic>;

      return WhatIfResponseData(
        answer: map['answer'] ?? 'Нет ответа от AI',
      );
    } catch (e) {
      throw Exception('Не удалось выполнить What-if симуляцию: ${e.toString()}');
    }
  }

  @override
  Future<AiIdeasResponseData> generateAiIdeas(String prompt) async {
    try {
      final payload = {'prompt': prompt};
      final response = await _apiClient.dio.post('/marketing/ai-ideas', data: payload);
      final map = response.data as Map<String, dynamic>;
      final list = (map['ideas'] ?? []) as List<dynamic>;

      return AiIdeasResponseData(
        ideas: list.map((e) => e.toString()).toList(),
      );
    } catch (e) {
      throw Exception('Не удалось сгенерировать идеи: ${e.toString()}');
    }
  }

  @override
  Future<List<StrategicAnalysis>> getAnalyses(String type) async {
    try {
      final response = await _apiClient.dio.get('/strategy/analyses', queryParameters: {'type': type});
      final dynamic responseData = response.data;
      final List<dynamic> list = responseData is Map<String, dynamic>
          ? (responseData['items'] as List<dynamic>? ?? [])
          : (responseData as List<dynamic>? ?? []);

      return list.map((item) {
        final map = item as Map<String, dynamic>;
        return StrategicAnalysis(
          id: (map['id'] ?? '').toString(),
          type: map['type'] ?? type,
          period: map['period'] ?? '',
          data: map['data'] ?? {},
          generatedByAi: map['generated_by_ai'] ?? true,
          createdAt: DateTime.parse(map['created_at'] ?? DateTime.now().toIso8601String()),
        );
      }).toList();
    } catch (e) {
      throw Exception('Не удалось загрузить стратегические матрицы: ${e.toString()}');
    }
  }

  @override
  Future<StrategicAnalysis> generateAnalysis(String type, String period) async {
    try {
      final response = await _apiClient.dio.post(
        '/strategy/analyses/generate',
        data: {
          'type': type,
          'period': period,
        },
      );
      final map = response.data as Map<String, dynamic>;

      return StrategicAnalysis(
        id: (map['id'] ?? '').toString(),
        type: map['type'] ?? type,
        period: map['period'] ?? period,
        data: map['data'] ?? {},
        generatedByAi: map['generated_by_ai'] ?? true,
        createdAt: DateTime.parse(map['created_at'] ?? DateTime.now().toIso8601String()),
      );
    } catch (e) {
      throw Exception('Не удалось сгенерировать стратегический анализ: ${e.toString()}');
    }
  }
}
