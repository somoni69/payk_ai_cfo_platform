import '../../../core/network/api_client.dart';
import '../../../core/network/user_facing_error.dart';
import '../domain/assistant_models.dart';
import '../domain/assistant_repository.dart';

class ApiAssistantRepository implements AssistantRepository {
  final ApiClient _apiClient;

  ApiAssistantRepository({ApiClient? apiClient})
    : _apiClient = apiClient ?? ApiClient();

  String _normalizeModule(String module) {
    return kAssistantModules.contains(module)
        ? module
        : kAssistantGeneralModule;
  }

  @override
  Future<List<AssistantMessage>> getHistory(
    String module, {
    int limit = 50,
  }) async {
    try {
      final response = await _apiClient.dio.get<dynamic>(
        '/assistant/history',
        queryParameters: {'module': _normalizeModule(module), 'limit': limit},
      );
      final list = response.data is List
          ? response.data as List
          : const <dynamic>[];
      return list.map(_messageFromJson).whereType<AssistantMessage>().toList();
    } catch (e) {
      throw Exception(userFacingError(e, fallback: ErrorKeys.loadFailed));
    }
  }

  @override
  Future<String> ask({required String question, required String module}) async {
    try {
      final response = await _apiClient.dio.post<dynamic>(
        '/assistant/ask',
        data: {'question': question.trim(), 'module': _normalizeModule(module)},
        options: ApiClient.longRunningOptions(
          receiveTimeout: const Duration(seconds: 90),
        ),
      );
      final body = response.data is Map ? response.data as Map : null;
      final answer = body?['answer'];
      if (answer is! String || answer.trim().isEmpty) {
        throw Exception(ErrorKeys.invalidResponse);
      }
      return answer.trim();
    } catch (e) {
      throw Exception(userFacingError(e, fallback: ErrorKeys.generic));
    }
  }

  @override
  Future<AdviceResponse> getAdvice(
    String module, {
    required String lang,
  }) async {
    try {
      final response = await _apiClient.dio.get<dynamic>(
        '/assistant/advice',
        queryParameters: {
          'module': _normalizeModule(module),
          'lang': assistantAdviceLang(lang),
        },
      );
      return _adviceFromJson(response.data);
    } catch (e) {
      throw Exception(userFacingError(e, fallback: ErrorKeys.loadFailed));
    }
  }

  @override
  Future<AdviceResponse> generateAdvice(
    String module, {
    required String lang,
  }) async {
    try {
      final response = await _apiClient.dio.post<dynamic>(
        '/assistant/advice/generate',
        data: {
          'module': _normalizeModule(module),
          'lang': assistantAdviceLang(lang),
        },
        options: ApiClient.longRunningOptions(
          receiveTimeout: const Duration(seconds: 90),
        ),
      );
      return _adviceFromJson(response.data);
    } catch (e) {
      throw Exception(userFacingError(e, fallback: ErrorKeys.generic));
    }
  }

  AdviceResponse _adviceFromJson(dynamic raw) {
    if (raw is! Map) {
      return const AdviceResponse(status: 'empty');
    }
    final map = Map<String, dynamic>.from(raw);
    final status = (map['status'] ?? 'empty').toString();
    final generatedRaw = map['generated_at'] ?? map['generatedAt'];
    DateTime? generatedAt;
    if (generatedRaw is String) {
      generatedAt = DateTime.tryParse(generatedRaw)?.toLocal();
    }
    return AdviceResponse(
      status: status,
      content: _contentFromJson(map['content']),
      generatedAt: generatedAt,
    );
  }

  AdviceContent? _contentFromJson(dynamic raw) {
    if (raw is! Map) return null;
    final map = Map<String, dynamic>.from(raw);
    AdviceGoal? goal;
    final goalRaw = map['goal'];
    if (goalRaw is Map) {
      final g = Map<String, dynamic>.from(goalRaw);
      goal = AdviceGoal(
        title: (g['title'] ?? '').toString(),
        value: (g['value'] ?? '').toString(),
        text: (g['text'] ?? '').toString(),
      );
      if (goal.title.isEmpty && goal.value.isEmpty && goal.text.isEmpty) {
        goal = null;
      }
    }
    final prioritiesRaw = map['priorities'];
    final priorities = <AdvicePriority>[];
    if (prioritiesRaw is List) {
      for (final item in prioritiesRaw) {
        if (item is! Map) continue;
        final p = Map<String, dynamic>.from(item);
        final title = (p['title'] ?? '').toString();
        if (title.isEmpty) continue;
        priorities.add(
          AdvicePriority(title: title, text: (p['text'] ?? '').toString()),
        );
      }
    }
    return AdviceContent(
      goal: goal,
      priorities: priorities,
      analysis: (map['analysis'] ?? '').toString(),
    );
  }

  @override
  Future<void> clearHistory(String module) async {
    try {
      await _apiClient.dio.delete<dynamic>(
        '/assistant/history',
        queryParameters: {'module': _normalizeModule(module)},
      );
    } catch (e) {
      throw Exception(userFacingError(e, fallback: ErrorKeys.saveFailed));
    }
  }

  AssistantMessage? _messageFromJson(dynamic raw) {
    if (raw is! Map) return null;
    final map = Map<String, dynamic>.from(raw);
    final idRaw = map['id'];
    final id = switch (idRaw) {
      int v => v,
      num v => v.toInt(),
      String v => int.tryParse(v) ?? 0,
      _ => 0,
    };
    final role = (map['role'] ?? 'assistant').toString();
    final text = (map['text'] ?? '').toString();
    if (text.isEmpty) return null;
    final createdRaw = map['created_at'] ?? map['createdAt'];
    final createdAt = createdRaw is String
        ? (DateTime.tryParse(createdRaw) ?? DateTime.now())
        : DateTime.now();
    return AssistantMessage(
      id: id,
      role: role,
      text: text,
      createdAt: createdAt.toLocal(),
    );
  }
}
