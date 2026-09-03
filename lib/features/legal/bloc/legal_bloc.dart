import 'package:dio/dio.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/network/user_facing_error.dart';
import '../domain/legal_models.dart';
import '../domain/legal_repository.dart';
import 'legal_event.dart';
import 'legal_state.dart';

class LegalBloc extends Bloc<LegalEvent, LegalState> {
  LegalBloc(this._repository) : super(LegalLoading()) {
    on<LoadLegalData>(_onLoadLegalData);
    on<ToggleDeadlineStatus>(_onToggleDeadlineStatus);
    on<AskLawyerQuestion>(_onAskLawyerQuestion);
    on<ClearLawyerHistory>(_onClearLawyerHistory);
    on<ClearGeneratedContract>(_onClearGeneratedContract);
    on<GenerateContractFromTemplate>(_onGenerateContractFromTemplate);
    on<CreateLawRequested>(_onCreateLaw);
    on<DeleteLawRequested>(_onDeleteLaw);
    on<CreateDeadlineRequested>(_onCreateDeadline);
    on<CreateTemplateRequested>(_onCreateTemplate);
    on<UpdateTemplateRequested>(_onUpdateTemplate);
    on<DeleteTemplateRequested>(_onDeleteTemplate);
    on<ExportGeneratedContractRequested>(_onExportGeneratedContract);
  }

  static const List<Map<String, String>> _welcomeHistory = [
    {
      'sender': 'ai',
      'text':
          'Салом! Я готов помочь вам с юридическими вопросами законодательства Республики Таджикистан. Например: "Какая ставка налога на прибыль по упрощенной системе?"',
    },
  ];

  final LegalRepository _repository;
  Future<List<Object>>? _dataRequest;

  Future<void> _onLoadLegalData(
    LoadLegalData event,
    Emitter<LegalState> emit,
  ) async {
    final previous = state is LegalLoaded ? state as LegalLoaded : null;
    if (previous == null) emit(LegalLoading());

    var request = _dataRequest;
    if (request == null) {
      request = Future.wait<Object>([
        _repository.getTemplates(forceRefresh: event.forceRefresh),
        _repository.getLaws(forceRefresh: event.forceRefresh),
        _repository.getDeadlines(forceRefresh: event.forceRefresh),
      ]);
      _dataRequest = request;
    }

    try {
      final results = await request;
      if (emit.isDone) return;
      emit(
        LegalLoaded(
          templates: (results[0] as List).cast<ContractTemplate>(),
          laws: (results[1] as List).cast<Law>(),
          deadlines: (results[2] as List).cast<LegalDeadline>(),
          chatHistory: previous?.chatHistory ?? _welcomeHistory,
        ),
      );
    } catch (error) {
      if (emit.isDone) return;
      final message = userFacingError(
        error,
        fallback:
            'Не удалось загрузить юридические данные. Проверьте соединение.',
      );
      if (previous != null) {
        emit(previous.copyWith(errorMessage: message));
      } else {
        emit(LegalError(message));
      }
    } finally {
      if (identical(_dataRequest, request)) _dataRequest = null;
    }
  }

  Future<void> _onToggleDeadlineStatus(
    ToggleDeadlineStatus event,
    Emitter<LegalState> emit,
  ) async {
    if (state is! LegalLoaded) return;
    final currentState = state as LegalLoaded;
    final optimisticDeadlines = currentState.deadlines.map((deadline) {
      return deadline.id == event.id
          ? deadline.copyWith(isDone: event.isDone)
          : deadline;
    }).toList();

    emit(currentState.copyWith(deadlines: optimisticDeadlines));

    try {
      final updated = await _repository.updateDeadlineStatus(
        event.id,
        event.isDone,
      );
      if (state is! LegalLoaded) return;
      final latest = state as LegalLoaded;
      final finalDeadlines = latest.deadlines.map((deadline) {
        return deadline.id == event.id ? updated : deadline;
      }).toList();
      emit(latest.copyWith(deadlines: finalDeadlines));
    } catch (error) {
      emit(
        currentState.copyWith(
          errorMessage: userFacingError(
            error,
            fallback: 'Не удалось обновить статус. Повторите попытку.',
          ),
        ),
      );
    }
  }

  Future<void> _onAskLawyerQuestion(
    AskLawyerQuestion event,
    Emitter<LegalState> emit,
  ) async {
    if (state is! LegalLoaded) return;
    final currentState = state as LegalLoaded;
    final updatedHistory = List<Map<String, String>>.from(
      currentState.chatHistory,
    )..add({'sender': 'user', 'text': event.question});

    emit(currentState.copyWith(chatHistory: updatedHistory, isAskingAi: true));

    try {
      final answer = await _repository.askAiLawyer(event.question);
      if (emit.isDone || state is! LegalLoaded) return;
      final finalHistory = List<Map<String, String>>.from(updatedHistory)
        ..add({'sender': 'ai', 'text': answer});
      emit(
        (state as LegalLoaded).copyWith(
          chatHistory: finalHistory,
          isAskingAi: false,
        ),
      );
    } catch (error) {
      if (_isCancelled(error) || emit.isDone || state is! LegalLoaded) return;
      final message = userFacingError(
        error,
        fallback: 'Не удалось получить ответ ИИ. Повторите попытку.',
      );
      final finalHistory = List<Map<String, String>>.from(updatedHistory)
        ..add({'sender': 'ai', 'text': message});
      emit(
        (state as LegalLoaded).copyWith(
          chatHistory: finalHistory,
          isAskingAi: false,
        ),
      );
    }
  }

  void _onClearLawyerHistory(
    ClearLawyerHistory event,
    Emitter<LegalState> emit,
  ) {
    if (state is! LegalLoaded) return;
    emit((state as LegalLoaded).copyWith(chatHistory: _welcomeHistory));
  }

  void _onClearGeneratedContract(
    ClearGeneratedContract event,
    Emitter<LegalState> emit,
  ) {
    if (state is! LegalLoaded) return;
    emit((state as LegalLoaded).copyWith(clearGeneratedContract: true));
  }

  Future<void> _onGenerateContractFromTemplate(
    GenerateContractFromTemplate event,
    Emitter<LegalState> emit,
  ) async {
    if (state is! LegalLoaded) return;
    final currentState = state as LegalLoaded;
    emit(
      currentState.copyWith(
        isGenerating: true,
        clearGeneratedContract: true,
        clearError: true,
        clearSuccess: true,
      ),
    );

    try {
      final contract = await _repository.generateContract(
        event.templateId,
        event.variables,
      );
      if (emit.isDone || state is! LegalLoaded) return;
      emit(
        (state as LegalLoaded).copyWith(
          isGenerating: false,
          generatedContract: contract,
        ),
      );
    } catch (error) {
      if (_isCancelled(error) || emit.isDone || state is! LegalLoaded) return;
      emit(
        (state as LegalLoaded).copyWith(
          isGenerating: false,
          errorMessage: userFacingError(
            error,
            fallback: 'Не удалось сгенерировать договор. Повторите попытку.',
          ),
        ),
      );
    }
  }

  Future<void> _onCreateLaw(
    CreateLawRequested event,
    Emitter<LegalState> emit,
  ) async {
    if (state is! LegalLoaded) return;
    final current = state as LegalLoaded;
    emit(
      current.copyWith(isMutating: true, clearError: true, clearSuccess: true),
    );
    try {
      final law = await _repository.createLaw(
        title: event.title,
        body: event.body,
        category: event.category,
      );
      if (emit.isDone || state is! LegalLoaded) return;
      final latest = state as LegalLoaded;
      emit(
        latest.copyWith(
          isMutating: false,
          laws: [law, ...latest.laws],
          successMessage: 'legal_toast_law_created',
        ),
      );
    } catch (error) {
      if (emit.isDone || state is! LegalLoaded) return;
      emit(
        (state as LegalLoaded).copyWith(
          isMutating: false,
          errorMessage: userFacingError(error, fallback: ErrorKeys.saveFailed),
        ),
      );
    }
  }

  Future<void> _onDeleteLaw(
    DeleteLawRequested event,
    Emitter<LegalState> emit,
  ) async {
    if (state is! LegalLoaded) return;
    final current = state as LegalLoaded;
    emit(
      current.copyWith(isMutating: true, clearError: true, clearSuccess: true),
    );
    try {
      await _repository.deleteLaw(event.id);
      if (emit.isDone || state is! LegalLoaded) return;
      final latest = state as LegalLoaded;
      emit(
        latest.copyWith(
          isMutating: false,
          laws: latest.laws.where((law) => law.id != event.id).toList(),
        ),
      );
    } catch (error) {
      if (emit.isDone || state is! LegalLoaded) return;
      emit(
        (state as LegalLoaded).copyWith(
          isMutating: false,
          errorMessage: userFacingError(error, fallback: ErrorKeys.saveFailed),
        ),
      );
    }
  }

  Future<void> _onCreateDeadline(
    CreateDeadlineRequested event,
    Emitter<LegalState> emit,
  ) async {
    if (state is! LegalLoaded) return;
    final current = state as LegalLoaded;
    emit(
      current.copyWith(isMutating: true, clearError: true, clearSuccess: true),
    );
    try {
      final deadline = await _repository.createDeadline(
        title: event.title,
        type: event.type,
        dueDate: event.dueDate,
        amount: event.amount,
        note: event.note,
      );
      if (emit.isDone || state is! LegalLoaded) return;
      final latest = state as LegalLoaded;
      emit(
        latest.copyWith(
          isMutating: false,
          deadlines: [deadline, ...latest.deadlines],
          successMessage: 'legal_toast_deadline_created',
        ),
      );
    } catch (error) {
      if (emit.isDone || state is! LegalLoaded) return;
      emit(
        (state as LegalLoaded).copyWith(
          isMutating: false,
          errorMessage: userFacingError(error, fallback: ErrorKeys.saveFailed),
        ),
      );
    }
  }

  Future<void> _onCreateTemplate(
    CreateTemplateRequested event,
    Emitter<LegalState> emit,
  ) async {
    if (state is! LegalLoaded) return;
    final current = state as LegalLoaded;
    emit(
      current.copyWith(isMutating: true, clearError: true, clearSuccess: true),
    );
    try {
      final template = await _repository.createTemplate(
        name: event.name,
        body: event.body,
        category: event.category,
      );
      if (emit.isDone || state is! LegalLoaded) return;
      final latest = state as LegalLoaded;
      emit(
        latest.copyWith(
          isMutating: false,
          templates: [template, ...latest.templates],
          successMessage: 'legal_toast_template_saved',
        ),
      );
    } catch (error) {
      if (emit.isDone || state is! LegalLoaded) return;
      emit(
        (state as LegalLoaded).copyWith(
          isMutating: false,
          errorMessage: userFacingError(error, fallback: ErrorKeys.saveFailed),
        ),
      );
    }
  }

  Future<void> _onUpdateTemplate(
    UpdateTemplateRequested event,
    Emitter<LegalState> emit,
  ) async {
    if (state is! LegalLoaded) return;
    final current = state as LegalLoaded;
    emit(
      current.copyWith(isMutating: true, clearError: true, clearSuccess: true),
    );
    try {
      final template = await _repository.updateTemplate(
        id: event.id,
        name: event.name,
        body: event.body,
        category: event.category,
      );
      if (emit.isDone || state is! LegalLoaded) return;
      final latest = state as LegalLoaded;
      emit(
        latest.copyWith(
          isMutating: false,
          templates: latest.templates
              .map((item) => item.id == template.id ? template : item)
              .toList(),
          successMessage: 'legal_toast_template_saved',
        ),
      );
    } catch (error) {
      if (emit.isDone || state is! LegalLoaded) return;
      emit(
        (state as LegalLoaded).copyWith(
          isMutating: false,
          errorMessage: userFacingError(error, fallback: ErrorKeys.saveFailed),
        ),
      );
    }
  }

  Future<void> _onDeleteTemplate(
    DeleteTemplateRequested event,
    Emitter<LegalState> emit,
  ) async {
    if (state is! LegalLoaded) return;
    final current = state as LegalLoaded;
    emit(
      current.copyWith(isMutating: true, clearError: true, clearSuccess: true),
    );
    try {
      await _repository.deleteTemplate(event.id);
      if (emit.isDone || state is! LegalLoaded) return;
      final latest = state as LegalLoaded;
      emit(
        latest.copyWith(
          isMutating: false,
          templates: latest.templates
              .where((template) => template.id != event.id)
              .toList(),
        ),
      );
    } catch (error) {
      if (emit.isDone || state is! LegalLoaded) return;
      emit(
        (state as LegalLoaded).copyWith(
          isMutating: false,
          errorMessage: userFacingError(error, fallback: ErrorKeys.saveFailed),
        ),
      );
    }
  }

  Future<void> _onExportGeneratedContract(
    ExportGeneratedContractRequested event,
    Emitter<LegalState> emit,
  ) async {
    if (state is! LegalLoaded) return;
    final current = state as LegalLoaded;
    emit(
      current.copyWith(isMutating: true, clearError: true, clearSuccess: true),
    );
    try {
      final bytes = await _repository.exportGeneratedContract(event.contractId);
      if (emit.isDone || state is! LegalLoaded) return;
      emit(
        (state as LegalLoaded).copyWith(
          isMutating: false,
          successMessage: bytes.isEmpty
              ? ErrorKeys.saveFailed
              : 'legal_export_ok',
        ),
      );
    } catch (error) {
      if (emit.isDone || state is! LegalLoaded) return;
      emit(
        (state as LegalLoaded).copyWith(
          isMutating: false,
          errorMessage: userFacingError(error, fallback: ErrorKeys.saveFailed),
        ),
      );
    }
  }

  bool _isCancelled(Object error) =>
      error is DioException && CancelToken.isCancel(error);

  @override
  Future<void> close() {
    final repository = _repository;
    if (repository is CancellableLegalRepository) {
      (repository as CancellableLegalRepository).cancelPendingRequests();
    }
    return super.close();
  }
}
