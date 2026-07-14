import '../../../core/network/api_client.dart';
import '../domain/legal_models.dart';
import '../domain/legal_repository.dart';

class ApiLegalRepository implements LegalRepository {
  final ApiClient _apiClient = ApiClient();

  int _toInt(dynamic val) {
    if (val == null) return 0;
    if (val is num) return val.toInt();
    if (val is String) return int.tryParse(val) ?? 0;
    return 0;
  }

  @override
  Future<List<ContractTemplate>> getTemplates() async {
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
      throw Exception('Не удалось загрузить шаблоны договоров: ${e.toString()}');
    }
  }

  @override
  Future<GeneratedContract> generateContract(String templateId, Map<String, String> data) async {
    try {
      final response = await _apiClient.dio.post(
        '/legal/generate',
        data: {
          'template_id': _toInt(templateId),
          'data': data,
        },
      );
      final map = response.data as Map<String, dynamic>;

      return GeneratedContract(
        id: (map['id'] ?? '').toString(),
        title: map['title'] ?? 'Договор',
        body: map['body'] ?? '',
        createdAt: DateTime.parse(map['created_at'] ?? DateTime.now().toIso8601String()),
      );
    } catch (e) {
      throw Exception('Не удалось сгенерировать договор: ${e.toString()}');
    }
  }

  @override
  Future<List<Law>> getLaws() async {
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
          createdAt: DateTime.parse(map['created_at'] ?? DateTime.now().toIso8601String()),
        );
      }).toList();
    } catch (e) {
      throw Exception('Не удалось загрузить законы: ${e.toString()}');
    }
  }

  @override
  Future<List<LegalDeadline>> getDeadlines() async {
    try {
      final response = await _apiClient.dio.get('/legal/deadlines');
      final list = response.data as List<dynamic>;

      return list.map((item) {
        final map = item as Map<String, dynamic>;
        return LegalDeadline(
          id: (map['id'] ?? '').toString(),
          title: map['title'] ?? '',
          type: map['type'] ?? 'OTHER',
          dueDate: DateTime.parse(map['due_date'] ?? DateTime.now().toIso8601String()),
          amount: map['amount'],
          note: map['note'],
          isDone: map['is_done'] ?? false,
          daysLeft: map['days_left'],
        );
      }).toList();
    } catch (e) {
      throw Exception('Не удалось загрузить календарь сроков: ${e.toString()}');
    }
  }

  @override
  Future<LegalDeadline> updateDeadlineStatus(String deadlineId, bool isDone) async {
    try {
      final response = await _apiClient.dio.patch(
        '/legal/deadlines/${_toInt(deadlineId)}',
        data: {'is_done': isDone},
      );
      final map = response.data as Map<String, dynamic>;

      return LegalDeadline(
        id: (map['id'] ?? '').toString(),
        title: map['title'] ?? '',
        type: map['type'] ?? 'OTHER',
        dueDate: DateTime.parse(map['due_date'] ?? DateTime.now().toIso8601String()),
        amount: map['amount'],
        note: map['note'],
        isDone: map['is_done'] ?? false,
        daysLeft: map['days_left'],
      );
    } catch (e) {
      throw Exception('Не удалось обновить статус срока: ${e.toString()}');
    }
  }

  @override
  Future<String> askAiLawyer(String question) async {
    try {
      final response = await _apiClient.dio.post(
        '/legal/ask',
        data: {'question': question},
      );
      final map = response.data as Map<String, dynamic>;
      return map['answer'] ?? 'Ответ от ИИ пуст.';
    } catch (e) {
      throw Exception('Не удалось получить ответ ИИ: ${e.toString()}');
    }
  }
}
