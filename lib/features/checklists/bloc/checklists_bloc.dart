import 'package:flutter_bloc/flutter_bloc.dart';
import '../domain/checklist_models.dart';
import '../domain/checklists_repository.dart';
import 'checklists_event.dart';
import 'checklists_state.dart';

class ChecklistsBloc extends Bloc<ChecklistsEvent, ChecklistsState> {
  final ChecklistsRepository _repository;

  ChecklistsBloc(this._repository) : super(ChecklistsInitial()) {
    on<LoadChecklists>(_onLoadChecklists);
    on<ToggleEntryRequested>(_onToggleEntryRequested);
    on<AddEntryRequested>(_onAddEntryRequested);
    on<DeleteEntryRequested>(_onDeleteEntryRequested);
    on<CreateTemplateRequested>(_onCreateTemplate);
    on<DeleteTemplateRequested>(_onDeleteTemplate);
  }

  Future<void> _onLoadChecklists(
    LoadChecklists event,
    Emitter<ChecklistsState> emit,
  ) async {
    if (state is! ChecklistsLoaded || event.forceRefresh) {
      emit(ChecklistsLoading());
    }
    try {
      final results = await Future.wait([
        _repository.getTodayRuns(),
        _repository.getTemplates(),
        _repository.getSummary(),
      ]);
      emit(
        ChecklistsLoaded(
          todayRuns: results[0] as List<ChecklistRun>,
          templates: results[1] as List<ChecklistTemplate>,
          summary: results[2] as List<ChecklistSummaryRow>,
        ),
      );
    } catch (e) {
      emit(ChecklistsError(e.toString()));
    }
  }

  Future<void> _reload(Emitter<ChecklistsState> emit, {String? msg}) async {
    final runs = await _repository.getTodayRuns();
    final templates = await _repository.getTemplates();
    final summary = await _repository.getSummary();
    emit(
      ChecklistsLoaded(
        todayRuns: runs,
        templates: templates,
        summary: summary,
        actionMessage: msg,
      ),
    );
  }

  Future<void> _onToggleEntryRequested(
    ToggleEntryRequested event,
    Emitter<ChecklistsState> emit,
  ) async {
    try {
      await _repository.toggleEntry(
        runId: event.runId,
        entryId: event.entryId,
        isDone: event.isDone,
      );
      await _reload(emit);
    } catch (e) {
      emit(ChecklistsError(e.toString()));
    }
  }

  Future<void> _onAddEntryRequested(
    AddEntryRequested event,
    Emitter<ChecklistsState> emit,
  ) async {
    try {
      await _repository.addRunEntry(runId: event.runId, text: event.text);
      await _reload(emit);
    } catch (e) {
      emit(ChecklistsError(e.toString()));
    }
  }

  Future<void> _onDeleteEntryRequested(
    DeleteEntryRequested event,
    Emitter<ChecklistsState> emit,
  ) async {
    try {
      await _repository.deleteRunEntry(
        runId: event.runId,
        entryId: event.entryId,
      );
      await _reload(emit);
    } catch (e) {
      emit(ChecklistsError(e.toString()));
    }
  }

  Future<void> _onCreateTemplate(
    CreateTemplateRequested event,
    Emitter<ChecklistsState> emit,
  ) async {
    try {
      await _repository.createTemplate(
        name: event.name,
        description: event.description,
        regulationText: event.regulationText,
        regulationUrl: event.regulationUrl,
        branchId: event.branchId,
        items: event.items,
      );
      await _reload(emit, msg: 'checklists_toast_template_created');
    } catch (e) {
      emit(ChecklistsError(e.toString()));
    }
  }

  Future<void> _onDeleteTemplate(
    DeleteTemplateRequested event,
    Emitter<ChecklistsState> emit,
  ) async {
    try {
      await _repository.deleteTemplate(event.id);
      await _reload(emit, msg: 'checklists_toast_template_deleted');
    } catch (e) {
      emit(ChecklistsError(e.toString()));
    }
  }
}
