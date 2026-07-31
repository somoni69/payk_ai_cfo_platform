import '../../../core/network/api_client.dart';
import '../domain/checklist_models.dart';
import '../domain/checklists_repository.dart';

class ApiChecklistsRepository implements ChecklistsRepository {
  final ApiClient _client;

  ApiChecklistsRepository({ApiClient? client})
      : _client = client ?? ApiClient();

  final List<ChecklistRun> _mockRuns = [
    ChecklistRun(
      id: 'chk-1',
      title: 'Утренняя инспекция смены',
      branchName: 'Филиал «Центральный»',
      responsiblePerson: 'Алишер Рахимов',
      entries: [
        const ChecklistEntry(
          id: 'e-1',
          runId: 'chk-1',
          text: 'Проверить пломбы кассового сейфа',
          isDone: true,
        ),
        const ChecklistEntry(
          id: 'e-2',
          runId: 'chk-1',
          text: 'Провести сверку стартового остатка кассы',
          isDone: true,
        ),
        const ChecklistEntry(
          id: 'e-3',
          runId: 'chk-1',
          text: 'Проверить работу терминалов ЭКВАЙРИНГ',
          isDone: false,
        ),
        const ChecklistEntry(
          id: 'e-4',
          runId: 'chk-1',
          text: 'Включить сканеры штрихкодов на кассе 2',
          isDone: false,
        ),
      ],
    ),
    ChecklistRun(
      id: 'chk-2',
      title: 'Закрытие торгового зала',
      branchName: 'Филиал «Сомони»',
      responsiblePerson: 'Зарина Шарипова',
      entries: [
        const ChecklistEntry(
          id: 'e-5',
          runId: 'chk-2',
          text: 'Сформировать Z-отчет смены',
          isDone: true,
        ),
        const ChecklistEntry(
          id: 'e-6',
          runId: 'chk-2',
          text: 'Подготовить наличность для инкассации',
          isDone: true,
        ),
        const ChecklistEntry(
          id: 'e-7',
          runId: 'chk-2',
          text: 'Сдать ключи от помещения на пульт охраны',
          isDone: true,
        ),
      ],
    ),
  ];

  @override
  Future<List<ChecklistRun>> getTodayRuns() async {
    try {
      final response = await _client.dio.get('/api/v1/checklists/runs/today');
      if (response.statusCode == 200 && response.data is List) {
        return (response.data as List)
            .map((e) => ChecklistRun.fromJson(e as Map<String, dynamic>))
            .toList();
      }
    } catch (_) {}
    return List.from(_mockRuns);
  }

  @override
  Future<ChecklistRun> createRun({
    required String title,
    required String branchName,
    required String responsiblePerson,
    required List<String> items,
  }) async {
    final runId = 'chk-${DateTime.now().millisecondsSinceEpoch}';
    final newRun = ChecklistRun(
      id: runId,
      title: title,
      branchName: branchName,
      responsiblePerson: responsiblePerson,
      entries: items
          .map(
            (text) => ChecklistEntry(
              id: 'e-${DateTime.now().millisecondsSinceEpoch}-${items.indexOf(text)}',
              runId: runId,
              text: text,
              isDone: false,
            ),
          )
          .toList(),
    );

    try {
      final response = await _client.dio.post(
        '/api/v1/checklists/runs',
        data: newRun.toJson(),
      );
      if (response.statusCode == 200 || response.statusCode == 201) {
        return ChecklistRun.fromJson(response.data as Map<String, dynamic>);
      }
    } catch (_) {}

    _mockRuns.add(newRun);
    return newRun;
  }

  @override
  Future<void> toggleEntry({
    required String runId,
    required String entryId,
    required bool isDone,
  }) async {
    try {
      await _client.dio.patch(
        '/api/v1/checklists/entries/$entryId/toggle',
        data: {'is_done': isDone},
      );
    } catch (_) {}

    final runIndex = _mockRuns.indexWhere((r) => r.id == runId);
    if (runIndex != -1) {
      final run = _mockRuns[runIndex];
      final newEntries = run.entries.map((e) {
        if (e.id == entryId) {
          return e.copyWith(isDone: isDone);
        }
        return e;
      }).toList();
      _mockRuns[runIndex] = ChecklistRun(
        id: run.id,
        title: run.title,
        branchName: run.branchName,
        responsiblePerson: run.responsiblePerson,
        entries: newEntries,
      );
    }
  }

  @override
  Future<ChecklistEntry> addRunEntry({
    required String runId,
    required String text,
  }) async {
    final entry = ChecklistEntry(
      id: 'e-${DateTime.now().millisecondsSinceEpoch}',
      runId: runId,
      text: text,
      isDone: false,
    );
    try {
      await _client.dio.post(
        '/api/v1/checklists/runs/$runId/entries',
        data: entry.toJson(),
      );
    } catch (_) {}

    final runIndex = _mockRuns.indexWhere((r) => r.id == runId);
    if (runIndex != -1) {
      final run = _mockRuns[runIndex];
      final newEntries = List<ChecklistEntry>.from(run.entries)..add(entry);
      _mockRuns[runIndex] = ChecklistRun(
        id: run.id,
        title: run.title,
        branchName: run.branchName,
        responsiblePerson: run.responsiblePerson,
        entries: newEntries,
      );
    }
    return entry;
  }

  @override
  Future<void> deleteRunEntry({
    required String runId,
    required String entryId,
  }) async {
    try {
      await _client.dio.delete('/api/v1/checklists/entries/$entryId');
    } catch (_) {}

    final runIndex = _mockRuns.indexWhere((r) => r.id == runId);
    if (runIndex != -1) {
      final run = _mockRuns[runIndex];
      final newEntries = run.entries.where((e) => e.id != entryId).toList();
      _mockRuns[runIndex] = ChecklistRun(
        id: run.id,
        title: run.title,
        branchName: run.branchName,
        responsiblePerson: run.responsiblePerson,
        entries: newEntries,
      );
    }
  }
}
