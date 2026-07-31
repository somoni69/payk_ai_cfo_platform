import 'package:flutter_bloc/flutter_bloc.dart';
import '../domain/checklists_repository.dart';
import 'checklists_event.dart';
import 'checklists_state.dart';

class ChecklistsBloc extends Bloc<ChecklistsEvent, ChecklistsState> {
  final ChecklistsRepository _repository;

  ChecklistsBloc(this._repository) : super(ChecklistsInitial()) {
    on<LoadChecklists>(_onLoadChecklists);
    on<CreateChecklistRunRequested>(_onCreateChecklistRunRequested);
    on<ToggleEntryRequested>(_onToggleEntryRequested);
    on<AddEntryRequested>(_onAddEntryRequested);
    on<DeleteEntryRequested>(_onDeleteEntryRequested);
  }

  Future<void> _onLoadChecklists(
    LoadChecklists event,
    Emitter<ChecklistsState> emit,
  ) async {
    if (state is! ChecklistsLoaded || event.forceRefresh) {
      emit(ChecklistsLoading());
    }
    try {
      final runs = await _repository.getTodayRuns();
      emit(ChecklistsLoaded(todayRuns: runs));
    } catch (e) {
      emit(ChecklistsError(e.toString()));
    }
  }

  Future<void> _onCreateChecklistRunRequested(
    CreateChecklistRunRequested event,
    Emitter<ChecklistsState> emit,
  ) async {
    try {
      await _repository.createRun(
        title: event.title,
        branchName: event.branchName,
        responsiblePerson: event.responsiblePerson,
        items: event.items,
      );
      final runs = await _repository.getTodayRuns();
      emit(ChecklistsLoaded(todayRuns: runs));
    } catch (e) {
      emit(ChecklistsError(e.toString()));
    }
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
      final runs = await _repository.getTodayRuns();
      emit(ChecklistsLoaded(todayRuns: runs));
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
      final runs = await _repository.getTodayRuns();
      emit(ChecklistsLoaded(todayRuns: runs));
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
      final runs = await _repository.getTodayRuns();
      emit(ChecklistsLoaded(todayRuns: runs));
    } catch (e) {
      emit(ChecklistsError(e.toString()));
    }
  }
}
