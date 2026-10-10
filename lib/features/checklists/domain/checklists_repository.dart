import 'checklist_models.dart';

abstract class ChecklistsRepository {
  Future<List<ChecklistRun>> getTodayRuns();

  Future<List<ChecklistTemplate>> getTemplates({bool activeOnly = false});

  Future<ChecklistTemplate> createTemplate({
    required String name,
    String? description,
    String? regulationText,
    String? regulationUrl,
    String? branchId,
    List<String> items = const [],
  });

  Future<void> deleteTemplate(String id);

  /// `PATCH /checklists/{id}`: name, regulation and branch (null = all).
  Future<void> updateTemplate({
    required String id,
    required String name,
    String? regulationText,
    String? regulationUrl,
    String? branchId,
  });

  /// `POST /checklists/{id}/items`.
  Future<void> addTemplateItem({
    required String templateId,
    required String text,
    required int position,
  });

  /// `DELETE /checklists/items/{id}`.
  Future<void> deleteTemplateItem(String itemId);

  Future<List<ChecklistSummaryRow>> getSummary();

  Future<void> toggleEntry({
    required String runId,
    required String entryId,
    required bool isDone,
  });

  Future<ChecklistEntry> addRunEntry({
    required String runId,
    required String text,
  });

  Future<void> deleteRunEntry({required String runId, required String entryId});
}
