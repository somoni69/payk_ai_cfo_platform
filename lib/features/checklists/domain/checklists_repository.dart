import 'checklist_models.dart';

abstract class ChecklistsRepository {
  Future<List<ChecklistRun>> getTodayRuns();

  Future<List<ChecklistTemplate>> getTemplates({bool activeOnly = false});

  Future<ChecklistTemplate> createTemplate({
    required String name,
    String? description,
    String? regulationText,
    List<String> items = const [],
  });

  Future<void> deleteTemplate(String id);

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
