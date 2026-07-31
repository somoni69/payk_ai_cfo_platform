import 'checklist_models.dart';

abstract class ChecklistsRepository {
  Future<List<ChecklistRun>> getTodayRuns();
  Future<ChecklistRun> createRun({
    required String title,
    required String branchName,
    required String responsiblePerson,
    required List<String> items,
  });
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
