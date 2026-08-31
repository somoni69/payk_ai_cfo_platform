import 'package:dio/dio.dart';
import '../../../core/network/user_facing_error.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/expiring_request_cache.dart';
import '../domain/legal_models.dart';
import '../domain/legal_repository.dart';

class ApiLegalRepository
    implements LegalRepository, CancellableLegalRepository {
  final ApiClient _apiClient = ApiClient();
  final _templatesCache = ExpiringRequestCache<List<ContractTemplate>>(
    ttl: const Duration(minutes: 5),
  );
  final _lawsCache = ExpiringRequestCache<List<Law>>(
    ttl: const Duration(minutes: 5),
  );
  final _deadlinesCache = ExpiringRequestCache<List<LegalDeadline>>();
  CancelToken? _contractCancelToken;
  CancelToken? _lawyerCancelToken;

  int _requirePositiveId(String value, String fieldName) {
    final id = int.tryParse(value);
    if (id == null || id <= 0) {
      throw ArgumentError.value(value, fieldName, ErrorKeys.invalidId);
    }
    return id;
  }

  @override
  Future<List<ContractTemplate>> getTemplates({bool forceRefresh = false}) =>
      _templatesCache.get(_fetchTemplates, forceRefresh: forceRefresh);

  Future<List<ContractTemplate>> _fetchTemplates() async {
    try {
      final response = await _apiClient.dio.get('/legal/templates');
      final list = response.data as List<dynamic>;

      return list.map((item) {
        final map = item as Map<String, dynamic>;
        final vars = (map['variables'] as List<dynamic>? ?? []).map((v) {
          final vMap = v as Map<String, dynamic>;
          return TemplateVariable(
            key: vMap['key'] ?? '',
            label: vMap['label'] ?? '',
          );
        }).toList();

        return ContractTemplate(
          id: (map['id'] ?? '').toString(),
          name: map['name'] ?? '',
          category: map['category'],
          body: map['body'] ?? '',
          variables: vars,
        );
      }).toList();
    } catch (e) {
      throw Exception(userFacingError(e, fallback: ErrorKeys.loadFailed));
    }
  }

  @override
  Future<GeneratedContract> generateContract(
    String templateId,
    Map<String, String> data,
  ) async {
    _contractCancelToken?.cancel('Запрос заменён новым');
    final cancelToken = CancelToken();
    _contractCancelToken = cancelToken;

    try {
      final response = await _apiClient.dio.post(
        '/legal/generate',
        data: {
          'template_id': _requirePositiveId(templateId, 'templateId'),
          'data': data,
        },
        options: ApiClient.longRunningOptions(),
        cancelToken: cancelToken,
      );
      final map = response.data as Map<String, dynamic>;

      return GeneratedContract(
        id: (map['id'] ?? '').toString(),
        title: map['title'] ?? 'Договор',
        body: map['body'] ?? '',
        createdAt: DateTime.parse(
          map['created_at'] ?? DateTime.now().toIso8601String(),
        ),
      );
    } catch (error) {
      if (error is DioException && CancelToken.isCancel(error)) rethrow;
      throw Exception(ErrorKeys.saveFailed);
    } finally {
      if (identical(_contractCancelToken, cancelToken)) {
        _contractCancelToken = null;
      }
    }
  }

  @override
  Future<List<Law>> getLaws({bool forceRefresh = false}) =>
      _lawsCache.get(_fetchLaws, forceRefresh: forceRefresh);

  Future<List<Law>> _fetchLaws() async {
    try {
      final response = await _apiClient.dio.get('/legal/laws');
      // Ответ пагинирован (может быть в поле 'items')
      final dynamic responseData = response.data;
      final List<dynamic> list = responseData is Map<String, dynamic>
          ? (responseData['items'] as List<dynamic>? ?? [])
          : (responseData as List<dynamic>? ?? []);

      return list.map((item) {
        final map = item as Map<String, dynamic>;
        return Law(
          id: (map['id'] ?? '').toString(),
          title: map['title'] ?? '',
          category: map['category'],
          body: map['body'] ?? '',
          sourceUrl: map['source_url'] ?? map['sourceUrl'],
          createdAt: DateTime.parse(
            map['created_at'] ?? DateTime.now().toIso8601String(),
          ),
        );
      }).toList();
    } catch (e) {
      throw Exception(userFacingError(e, fallback: ErrorKeys.loadFailed));
    }
  }

  @override
  Future<List<LegalDeadline>> getDeadlines({bool forceRefresh = false}) =>
      _deadlinesCache.get(_fetchDeadlines, forceRefresh: forceRefresh);

  Future<List<LegalDeadline>> _fetchDeadlines() async {
    try {
      final response = await _apiClient.dio.get('/legal/deadlines');
      final list = response.data as List<dynamic>;

      return list.map((item) {
        final map = item as Map<String, dynamic>;
        return LegalDeadline(
          id: (map['id'] ?? '').toString(),
          title: map['title'] ?? '',
          type: map['type'] ?? 'OTHER',
          dueDate: DateTime.parse(
            map['due_date'] ?? DateTime.now().toIso8601String(),
          ),
          amount: map['amount'],
          note: map['note'],
          isDone: map['is_done'] ?? false,
          daysLeft: map['days_left'],
        );
      }).toList();
    } catch (e) {
      throw Exception(userFacingError(e, fallback: ErrorKeys.loadFailed));
    }
  }

  @override
  Future<LegalDeadline> updateDeadlineStatus(
    String deadlineId,
    bool isDone,
  ) async {
    try {
      final response = await _apiClient.dio.patch(
        '/legal/deadlines/${_requirePositiveId(deadlineId, 'deadlineId')}',
        data: {'is_done': isDone},
      );
      final map = response.data as Map<String, dynamic>;
      _deadlinesCache.invalidate();

      return LegalDeadline(
        id: (map['id'] ?? '').toString(),
        title: map['title'] ?? '',
        type: map['type'] ?? 'OTHER',
        dueDate: DateTime.parse(
          map['due_date'] ?? DateTime.now().toIso8601String(),
        ),
        amount: map['amount'],
        note: map['note'],
        isDone: map['is_done'] ?? false,
        daysLeft: map['days_left'],
      );
    } catch (e) {
      throw Exception(userFacingError(e, fallback: ErrorKeys.loadFailed));
    }
  }

  @override
  Future<String> askAiLawyer(String question) async {
    _lawyerCancelToken?.cancel('Запрос заменён новым');
    final cancelToken = CancelToken();
    _lawyerCancelToken = cancelToken;

    try {
      final response = await _apiClient.dio.post(
        '/legal/ask',
        data: {'question': question},
        options: ApiClient.longRunningOptions(),
        cancelToken: cancelToken,
      );
      final map = response.data as Map<String, dynamic>;
      return map['answer'] ?? 'Ответ от ИИ пуст.';
    } catch (error) {
      if (error is DioException && CancelToken.isCancel(error)) rethrow;
      throw Exception(ErrorKeys.loadFailed);
    } finally {
      if (identical(_lawyerCancelToken, cancelToken)) {
        _lawyerCancelToken = null;
      }
    }
  }

  Law _mapLaw(Map<String, dynamic> map) {
    return Law(
      id: (map['id'] ?? '').toString(),
      title: map['title'] ?? '',
      category: map['category'],
      body: map['body'] ?? '',
      sourceUrl: map['source_url'] ?? map['sourceUrl'],
      createdAt: DateTime.parse(
        map['created_at'] ?? DateTime.now().toIso8601String(),
      ),
    );
  }

  LegalDeadline _mapDeadline(Map<String, dynamic> map) {
    return LegalDeadline(
      id: (map['id'] ?? '').toString(),
      title: map['title'] ?? '',
      type: map['type'] ?? 'OTHER',
      dueDate: DateTime.parse(
        map['due_date'] ?? DateTime.now().toIso8601String(),
      ),
      amount: map['amount'],
      note: map['note'],
      isDone: map['is_done'] ?? false,
      daysLeft: map['days_left'],
    );
  }

  ContractTemplate _mapTemplate(Map<String, dynamic> map) {
    final vars = (map['variables'] as List<dynamic>? ?? []).map((v) {
      final vMap = v as Map<String, dynamic>;
      return TemplateVariable(
        key: vMap['key'] ?? '',
        label: vMap['label'] ?? '',
      );
    }).toList();

    return ContractTemplate(
      id: (map['id'] ?? '').toString(),
      name: map['name'] ?? '',
      category: map['category'],
      body: map['body'] ?? '',
      variables: vars,
    );
  }

  @override
  Future<Law> createLaw({
    required String title,
    required String body,
    String? category,
  }) async {
    try {
      final response = await _apiClient.dio.post(
        '/legal/laws',
        data: {
          'title': title,
          'body': body,
          if (category != null && category.isNotEmpty) 'category': category,
        },
      );
      _lawsCache.invalidate();
      return _mapLaw(response.data as Map<String, dynamic>);
    } catch (e) {
      throw Exception(userFacingError(e, fallback: ErrorKeys.saveFailed));
    }
  }

  @override
  Future<void> deleteLaw(String id) async {
    try {
      await _apiClient.dio.delete(
        '/legal/laws/${_requirePositiveId(id, 'id')}',
      );
      _lawsCache.invalidate();
    } catch (e) {
      throw Exception(userFacingError(e, fallback: ErrorKeys.saveFailed));
    }
  }

  @override
  Future<LegalDeadline> createDeadline({
    required String title,
    required String type,
    required DateTime dueDate,
    String? amount,
    String? note,
  }) async {
    try {
      final response = await _apiClient.dio.post(
        '/legal/deadlines',
        data: {
          'title': title,
          'type': type,
          'due_date': dueDate.toIso8601String().split('T').first,
          if (amount != null && amount.isNotEmpty) 'amount': amount,
          if (note != null && note.isNotEmpty) 'note': note,
        },
      );
      _deadlinesCache.invalidate();
      return _mapDeadline(response.data as Map<String, dynamic>);
    } catch (e) {
      throw Exception(userFacingError(e, fallback: ErrorKeys.saveFailed));
    }
  }

  @override
  Future<ContractTemplate> createTemplate({
    required String name,
    required String body,
    String? category,
  }) async {
    try {
      final response = await _apiClient.dio.post(
        '/legal/templates',
        data: {
          'name': name,
          'body': body,
          if (category != null && category.isNotEmpty) 'category': category,
        },
      );
      _templatesCache.invalidate();
      return _mapTemplate(response.data as Map<String, dynamic>);
    } catch (e) {
      throw Exception(userFacingError(e, fallback: ErrorKeys.saveFailed));
    }
  }

  @override
  Future<ContractTemplate> updateTemplate({
    required String id,
    String? name,
    String? body,
    String? category,
  }) async {
    final response = await _apiClient.dio.patch(
      '/legal/templates/$id',
      data: {'name': ?name, 'body': ?body, 'category': ?category},
    );
    _templatesCache.invalidate();
    return _mapTemplate(Map<String, dynamic>.from(response.data as Map));
  }

  @override
  Future<void> deleteTemplate(String id) async {
    await _apiClient.dio.delete('/legal/templates/$id');
    _templatesCache.invalidate();
  }

  @override
  Future<List<int>> exportGeneratedContract(String contractId) async {
    final response = await _apiClient.dio.get<List<int>>(
      '/legal/contracts/$contractId/export',
      options: Options(responseType: ResponseType.bytes),
    );
    return response.data ?? <int>[];
  }

  @override
  void cancelPendingRequests() {
    _contractCancelToken?.cancel('Экран закрыт');
    _lawyerCancelToken?.cancel('Экран закрыт');
    _contractCancelToken = null;
    _lawyerCancelToken = null;
  }
}
