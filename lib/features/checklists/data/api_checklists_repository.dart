import '../../../core/network/api_client.dart';
import '../../../core/network/user_facing_error.dart';
import '../domain/checklist_models.dart';
import '../domain/checklists_repository.dart';

class ApiChecklistsRepository implements ChecklistsRepository {
  final ApiClient _client;

  ApiChecklistsRepository({ApiClient? client})
    : _client = client ?? ApiClient();

  @override
  Future<List<ChecklistRun>> getTodayRuns() async {
    try {
      final response = await _client.dio.get('/checklists/today');
      final data = response.data;
      if (data is! List) {
        throw const FormatException(ErrorKeys.invalidResponse);
      }
      return data
          .whereType<Map>()
          .map((e) => ChecklistRun.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    } catch (e) {
      throw Exception(userFacingError(e, fallback: ErrorKeys.loadFailed));
    }
  }

  @override
  Future<List<ChecklistTemplate>> getTemplates({
    bool activeOnly = false,
  }) async {
    try {
      final response = await _client.dio.get(
        '/checklists',
        queryParameters: activeOnly ? {'active_only': true} : null,
      );
      final data = response.data;
      if (data is! List) {
        throw const FormatException(ErrorKeys.invalidResponse);
      }
      return data
          .whereType<Map>()
          .map((e) => ChecklistTemplate.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    } catch (e) {
      throw Exception(userFacingError(e, fallback: ErrorKeys.loadFailed));
    }
  }

  @override
  Future<ChecklistTemplate> createTemplate({
    required String name,
    String? description,
    String? regulationText,
    String? regulationUrl,
    String? branchId,
    List<String> items = const [],
  }) async {
    try {
      final response = await _client.dio.post(
        '/checklists',
        data: {
          'name': name,
          'description': description,
          'regulation_text': regulationText,
          if (regulationUrl != null && regulationUrl.isNotEmpty)
            'regulation_url': regulationUrl,
          'branch_id': ?int.tryParse(branchId ?? ''),
          'items': [
            for (var i = 0; i < items.length; i++)
              {'text': items[i], 'position': i},
          ],
        },
      );
      return ChecklistTemplate.fromJson(
        Map<String, dynamic>.from(response.data as Map),
      );
    } catch (e) {
      throw Exception(userFacingError(e, fallback: ErrorKeys.saveFailed));
    }
  }

  @override
  Future<void> deleteTemplate(String id) async {
    try {
      final parsed = int.tryParse(id);
      if (parsed == null || parsed <= 0) {
        throw StateError(ErrorKeys.invalidId);
      }
      await _client.dio.delete('/checklists/$parsed');
    } catch (e) {
      throw Exception(userFacingError(e, fallback: ErrorKeys.saveFailed));
    }
  }

  @override
  Future<List<ChecklistSummaryRow>> getSummary() async {
    try {
      final response = await _client.dio.get('/checklists/summary');
      final data = response.data;
      if (data is! List) {
        throw const FormatException(ErrorKeys.invalidResponse);
      }
      return data
          .whereType<Map>()
          .map(
            (e) => ChecklistSummaryRow.fromJson(Map<String, dynamic>.from(e)),
          )
          .toList();
    } catch (e) {
      throw Exception(userFacingError(e, fallback: ErrorKeys.loadFailed));
    }
  }

  @override
  Future<void> toggleEntry({
    required String runId,
    required String entryId,
    required bool isDone,
  }) async {
    try {
      final id = int.tryParse(entryId);
      if (id == null || id <= 0) throw StateError(ErrorKeys.invalidId);
      await _client.dio.post('/checklists/entries/$id/toggle');
    } catch (e) {
      throw Exception(userFacingError(e, fallback: ErrorKeys.saveFailed));
    }
  }

  @override
  Future<ChecklistEntry> addRunEntry({
    required String runId,
    required String text,
  }) async {
    try {
      final id = int.tryParse(runId);
      if (id == null || id <= 0) throw StateError(ErrorKeys.invalidId);
      final response = await _client.dio.post(
        '/checklists/runs/$id/entries',
        data: {'text': text},
      );
      // API returns full RunRead — take last entry matching text
      final data = response.data;
      if (data is Map) {
        final run = ChecklistRun.fromJson(Map<String, dynamic>.from(data));
        final match = run.entries.where((e) => e.text == text).toList();
        if (match.isNotEmpty) return match.last;
        if (run.entries.isNotEmpty) return run.entries.last;
      }
      return ChecklistEntry(id: '', runId: runId, text: text);
    } catch (e) {
      throw Exception(userFacingError(e, fallback: ErrorKeys.saveFailed));
    }
  }

  @override
  Future<void> deleteRunEntry({
    required String runId,
    required String entryId,
  }) async {
    try {
      final eId = int.tryParse(entryId);
      if (eId == null || eId <= 0) throw StateError(ErrorKeys.invalidId);
      await _client.dio.delete('/checklists/entries/$eId');
    } catch (e) {
      throw Exception(userFacingError(e, fallback: ErrorKeys.saveFailed));
    }
  }
}
