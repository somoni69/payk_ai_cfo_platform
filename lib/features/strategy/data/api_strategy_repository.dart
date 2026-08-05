import '../../../core/network/user_facing_error.dart';
import 'package:dio/dio.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/expiring_request_cache.dart';
import '../domain/strategy_models.dart';
import '../domain/strategy_repository.dart';

/// Конкретная реализация репозитория стратегических AI функций для бэкенда PAYK.
class ApiStrategyRepository
    implements StrategyRepository, CancellableStrategyRepository {
  final ApiClient _apiClient = ApiClient();
  final Map<String, ExpiringRequestCache<List<StrategicAnalysis>>>
  _analysisCaches = {};

  CancelToken? _whatIfCancelToken;
  CancelToken? _ideasCancelToken;
  CancelToken? _generationCancelToken;

  @override
  Future<WhatIfResponseData> askWhatIf(String question) async {
    _whatIfCancelToken?.cancel('Запрос заменён новым');
    final cancelToken = CancelToken();
    _whatIfCancelToken = cancelToken;

    try {
      final response = await _apiClient.dio.post(
        '/strategy/what-if',
        data: {'question': question},
        options: ApiClient.longRunningOptions(),
        cancelToken: cancelToken,
      );
      final map = response.data as Map<String, dynamic>;
      return WhatIfResponseData(answer: map['answer'] ?? 'Нет ответа от AI');
    } catch (error) {
      if (error is DioException && CancelToken.isCancel(error)) rethrow;
      throw Exception(ErrorKeys.loadFailed);
    } finally {
      if (identical(_whatIfCancelToken, cancelToken)) {
        _whatIfCancelToken = null;
      }
    }
  }

  @override
  Future<AiIdeasResponseData> generateAiIdeas(String prompt) async {
    _ideasCancelToken?.cancel('Запрос заменён новым');
    final cancelToken = CancelToken();
    _ideasCancelToken = cancelToken;

    try {
      final response = await _apiClient.dio.post(
        '/marketing/ai-ideas',
        data: {'prompt': prompt},
        options: ApiClient.longRunningOptions(),
        cancelToken: cancelToken,
      );
      final map = response.data as Map<String, dynamic>;
      final list = (map['ideas'] ?? []) as List<dynamic>;
      return AiIdeasResponseData(ideas: list.map((e) => e.toString()).toList());
    } catch (error) {
      if (error is DioException && CancelToken.isCancel(error)) rethrow;
      throw Exception(ErrorKeys.loadFailed);
    } finally {
      if (identical(_ideasCancelToken, cancelToken)) {
        _ideasCancelToken = null;
      }
    }
  }

  @override
  Future<List<StrategicAnalysis>> getAnalyses(
    String type, {
    bool forceRefresh = false,
  }) => _analysisCaches
      .putIfAbsent(type, ExpiringRequestCache<List<StrategicAnalysis>>.new)
      .get(() => _fetchAnalyses(type), forceRefresh: forceRefresh);

  Future<List<StrategicAnalysis>> _fetchAnalyses(String type) async {
    try {
      final response = await _apiClient.dio.get(
        '/strategy/analyses',
        queryParameters: {'type': type},
      );
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
          createdAt: DateTime.parse(
            map['created_at'] ?? DateTime.now().toIso8601String(),
          ),
        );
      }).toList();
    } catch (_) {
      throw Exception(ErrorKeys.loadFailed);
    }
  }

  @override
  Future<StrategicAnalysis> generateAnalysis(String type, String period) async {
    _generationCancelToken?.cancel('Запрос заменён новым');
    final cancelToken = CancelToken();
    _generationCancelToken = cancelToken;

    try {
      final response = await _apiClient.dio.post(
        '/strategy/analyses/generate',
        data: {'type': type, 'period': period},
        options: ApiClient.longRunningOptions(),
        cancelToken: cancelToken,
      );
      final map = response.data as Map<String, dynamic>;
      _analysisCaches[type]?.invalidate();

      return StrategicAnalysis(
        id: (map['id'] ?? '').toString(),
        type: map['type'] ?? type,
        period: map['period'] ?? period,
        data: map['data'] ?? {},
        generatedByAi: map['generated_by_ai'] ?? true,
        createdAt: DateTime.parse(
          map['created_at'] ?? DateTime.now().toIso8601String(),
        ),
      );
    } catch (error) {
      if (error is DioException && CancelToken.isCancel(error)) rethrow;
      throw Exception(ErrorKeys.loadFailed);
    } finally {
      if (identical(_generationCancelToken, cancelToken)) {
        _generationCancelToken = null;
      }
    }
  }

  @override
  Future<List<MacroIndicator>> getMacroIndicators() async {
    try {
      final response = await _apiClient.dio.get('/strategy/macro');
      final list = response.data as List<dynamic>? ?? [];
      return list.whereType<Map>().map((item) {
        final map = Map<String, dynamic>.from(item);
        return MacroIndicator(
          id: (map['id'] ?? '').toString(),
          name: map['name']?.toString() ?? '',
          value: (map['value'] as num?)?.toDouble() ??
              double.tryParse('${map['value']}') ??
              0,
          unit: map['unit']?.toString(),
          indicatorDate: DateTime.tryParse(
                map['indicator_date']?.toString() ?? '',
              ) ??
              DateTime.now(),
        );
      }).toList();
    } catch (_) {
      throw Exception(ErrorKeys.loadFailed);
    }
  }

  @override
  Future<List<StrategyScenario>> getScenarios({String? quarter}) async {
    try {
      final response = await _apiClient.dio.get(
        '/strategy/scenarios',
        queryParameters: quarter != null ? {'quarter': quarter} : null,
      );
      final list = response.data as List<dynamic>? ?? [];
      return list.whereType<Map>().map((item) {
        final map = Map<String, dynamic>.from(item);
        return StrategyScenario(
          id: (map['id'] ?? '').toString(),
          quarter: map['quarter']?.toString() ?? '',
          title: map['title']?.toString() ?? '',
          content: map['content']?.toString() ?? '',
        );
      }).toList();
    } catch (_) {
      throw Exception(ErrorKeys.loadFailed);
    }
  }

  @override
  Future<List<StrategyScenario>> generateScenarios(String quarter) async {
    try {
      final response = await _apiClient.dio.post(
        '/strategy/scenarios/generate',
        data: {'quarter': quarter},
        options: ApiClient.longRunningOptions(),
      );
      final list = response.data as List<dynamic>? ?? [];
      return list.whereType<Map>().map((item) {
        final map = Map<String, dynamic>.from(item);
        return StrategyScenario(
          id: (map['id'] ?? '').toString(),
          quarter: map['quarter']?.toString() ?? quarter,
          title: map['title']?.toString() ?? '',
          content: map['content']?.toString() ?? '',
        );
      }).toList();
    } catch (_) {
      throw Exception(ErrorKeys.loadFailed);
    }
  }

  @override
  Future<DailySummary> getDailySummary() async {
    try {
      final response = await _apiClient.dio.get('/strategy/daily-summary');
      final map = response.data as Map<String, dynamic>;
      return DailySummary(
        date: map['date']?.toString() ?? '',
        summary: map['summary']?.toString() ?? '',
        generatedByAi: map['generated_by_ai'] == true,
      );
    } catch (_) {
      throw Exception(ErrorKeys.loadFailed);
    }
  }

  @override
  Future<List<NewsSource>> getNews() async {
    try {
      final response = await _apiClient.dio.get('/strategy/news');
      final map = response.data as Map<String, dynamic>;
      final sources = map['sources'] as List<dynamic>? ?? [];
      return sources.whereType<Map>().map((item) {
        final s = Map<String, dynamic>.from(item);
        final items = (s['items'] as List<dynamic>? ?? [])
            .whereType<Map>()
            .map((n) {
              final nm = Map<String, dynamic>.from(n);
              return NewsItem(
                title: nm['title']?.toString() ?? '',
                url: nm['url']?.toString() ?? '',
                source: nm['source']?.toString() ?? s['name']?.toString() ?? '',
                published: nm['published']?.toString(),
              );
            })
            .toList();
        return NewsSource(
          code: s['code']?.toString() ?? '',
          name: s['name']?.toString() ?? '',
          items: items,
        );
      }).toList();
    } catch (_) {
      throw Exception(ErrorKeys.loadFailed);
    }
  }

  @override
  void cancelPendingRequests() {
    _whatIfCancelToken?.cancel('Экран закрыт');
    _ideasCancelToken?.cancel('Экран закрыт');
    _generationCancelToken?.cancel('Экран закрыт');
    _whatIfCancelToken = null;
    _ideasCancelToken = null;
    _generationCancelToken = null;
  }
}
