import '../../../core/network/api_client.dart';
import '../../../core/network/user_facing_error.dart';
import '../domain/checklist_models.dart';
import '../domain/checklists_repository.dart';
import '../../../core/error/app_failure.dart';

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
      throw RepositoryFailure(
        userFacingError(e, fallback: ErrorKeys.loadFailed),
      );
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
      throw RepositoryFailure(
        userFacingError(e, fallback: ErrorKeys.loadFailed),
      );
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
      throw RepositoryFailure(
        userFacingError(e, fallback: ErrorKeys.saveFailed),
      );
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
      throw RepositoryFailure(
        userFacingError(e, fallback: ErrorKeys.saveFailed),
      );
    }
  }

  @override
  Future<void> updateTemplate({
    required String id,
    required String name,
    String? regulationText,
    String? regulationUrl,
    String? branchId,
  }) async {
    try {
      await _client.dio.patch(
        '/checklists/${_positiveId(id)}',
        data: checklistTemplatePatchBody(
          name: name,
          regulationText: regulationText,
          regulationUrl: regulationUrl,
          branchId: branchId,
        ),
      );
    } catch (e) {
      throw RepositoryFailure(
        userFacingError(e, fallback: ErrorKeys.saveFailed),
      );
    }
  }

  @override
  Future<void> addTemplateItem({
    required String templateId,
    required String text,
    required int position,
  }) async {
    try {
      await _client.dio.post(
        '/checklists/${_positiveId(templateId)}/items',
        data: {'text': text, 'position': position},
      );
    } catch (e) {
      throw RepositoryFailure(
        userFacingError(e, fallback: ErrorKeys.saveFailed),
      );
    }
  }

  @override
  Future<void> deleteTemplateItem(String itemId) async {
    try {
      await _client.dio.delete('/checklists/items/${_positiveId(itemId)}');
    } catch (e) {
      throw RepositoryFailure(
        userFacingError(e, fallback: ErrorKeys.saveFailed),
      );
    }
  }

  int _positiveId(String id) {
    final parsed = int.tryParse(id);
    if (parsed == null || parsed <= 0) throw StateError(ErrorKeys.invalidId);
    return parsed;
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
      throw RepositoryFailure(
        userFacingError(e, fallback: ErrorKeys.loadFailed),
      );
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
      throw RepositoryFailure(
        userFacingError(e, fallback: ErrorKeys.saveFailed),
      );
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
      throw RepositoryFailure(
        userFacingError(e, fallback: ErrorKeys.saveFailed),
      );
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
      throw RepositoryFailure(
        userFacingError(e, fallback: ErrorKeys.saveFailed),
      );
    }
  }
}

/// PATCH body for a template. Empty regulation fields are sent as null so
/// clearing them in the form clears them on the server; `branch_id: null`
/// means «all branches», like the web form.
Map<String, dynamic> checklistTemplatePatchBody({
  required String name,
  String? regulationText,
  String? regulationUrl,
  String? branchId,
}) {
  String? clean(String? v) => v == null || v.trim().isEmpty ? null : v.trim();
  return {
    'name': name.trim(),
    'regulation_text': clean(regulationText),
    'regulation_url': clean(regulationUrl),
    'branch_id': int.tryParse(branchId ?? ''),
  };
}

/// What to send so the server item list matches the form: ids to delete and
/// new texts to add with their position in the edited order.
({List<String> remove, List<({String text, int position})> add})
checklistItemsDiff(
  List<ChecklistTemplateItem> before,
  List<({String? id, String text})> after,
) {
  final keep = {
    for (final i in after)
      if (i.id != null) i.id!,
  };
  return (
    remove: [
      for (final i in before)
        if (!keep.contains(i.id)) i.id,
    ],
    add: [
      for (var p = 0; p < after.length; p++)
        if (after[p].id == null) (text: after[p].text, position: p),
    ],
  );
}
