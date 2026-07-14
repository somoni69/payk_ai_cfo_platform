import 'package:flutter_bloc/flutter_bloc.dart';
import '../domain/legal_models.dart';
import '../domain/legal_repository.dart';
import 'legal_event.dart';
import 'legal_state.dart';

class LegalBloc extends Bloc<LegalEvent, LegalState> {
  final LegalRepository _repository;

  LegalBloc(this._repository) : super(LegalLoading()) {
    on<LoadLegalData>(_onLoadLegalData);
    on<ToggleDeadlineStatus>(_onToggleDeadlineStatus);
    on<AskLawyerQuestion>(_onAskLawyerQuestion);
    on<ClearLawyerHistory>(_onClearLawyerHistory);
    on<GenerateContractFromTemplate>(_onGenerateContractFromTemplate);
  }

  void _onLoadLegalData(LoadLegalData event, Emitter<LegalState> emit) async {
    if (state is! LegalLoaded) {
      emit(LegalLoading());
    }
    Future<List<T>> safeList<T>(Future<List<T>> future) async {
      try {
        return await future;
      } catch (_) {
        return <T>[];
      }
    }

    try {
      final results = await Future.wait([
        safeList(_repository.getTemplates()),
        safeList(_repository.getLaws()),
        safeList(_repository.getDeadlines()),
      ]);

      emit(LegalLoaded(
        templates: results[0] as List<ContractTemplate>,
        laws: results[1] as List<Law>,
        deadlines: results[2] as List<LegalDeadline>,
        chatHistory: const [
          {
            'sender': 'ai',
            'text': 'Салом! Я готов помочь вам с юридическими вопросами законодательства Республики Таджикистан. Например: "Какая ставка налога на прибыль по упрощенной системе?"'
          }
        ],
      ));
    } catch (e) {
      emit(LegalError('Не удалось загрузить юридические данные: ${e.toString()}'));
    }
  }

  void _onToggleDeadlineStatus(ToggleDeadlineStatus event, Emitter<LegalState> emit) async {
    if (state is! LegalLoaded) return;
    final currentState = state as LegalLoaded;

    // Оптимистичное обновление в UI
    final updatedDeadlines = currentState.deadlines.map((d) {
      if (d.id == event.id) {
        return d.copyWith(isDone: event.isDone);
      }
      return d;
    }).toList();

    emit(currentState.copyWith(deadlines: updatedDeadlines));

    try {
      final updated = await _repository.updateDeadlineStatus(event.id, event.isDone);
      
      // Синхронизируем с результатом сервера
      final finalDeadlines = currentState.deadlines.map((d) {
        if (d.id == event.id) return updated;
        return d;
      }).toList();

      emit((state as LegalLoaded).copyWith(deadlines: finalDeadlines));
    } catch (e) {
      // Откатываем в случае ошибки
      emit(currentState.copyWith(errorMessage: 'Не удалось обновить статус: ${e.toString()}'));
    }
  }

  void _onAskLawyerQuestion(AskLawyerQuestion event, Emitter<LegalState> emit) async {
    if (state is! LegalLoaded) return;
    final currentState = state as LegalLoaded;

    final updatedHistory = List<Map<String, String>>.from(currentState.chatHistory)
      ..add({'sender': 'user', 'text': event.question});

    emit(currentState.copyWith(
      chatHistory: updatedHistory,
      isAskingAi: true,
    ));

    try {
      final answer = await _repository.askAiLawyer(event.question);
      
      final finalHistory = List<Map<String, String>>.from(updatedHistory)
        ..add({'sender': 'ai', 'text': answer});

      emit((state as LegalLoaded).copyWith(
        chatHistory: finalHistory,
        isAskingAi: false,
      ));
    } catch (e) {
      final finalHistory = List<Map<String, String>>.from(updatedHistory)
        ..add({'sender': 'ai', 'text': 'Произошла ошибка при получении ответа: ${e.toString()}'});

      emit((state as LegalLoaded).copyWith(
        chatHistory: finalHistory,
        isAskingAi: false,
      ));
    }
  }

  void _onClearLawyerHistory(ClearLawyerHistory event, Emitter<LegalState> emit) {
    if (state is! LegalLoaded) return;
    final currentState = state as LegalLoaded;

    emit(currentState.copyWith(
      chatHistory: const [
        {
          'sender': 'ai',
          'text': 'Салом! Я готов помочь вам с юридическими вопросами законодательства Республики Таджикистан. Например: "Какая ставка налога на прибыль по упрощенной системе?"'
        }
      ],
    ));
  }

  void _onGenerateContractFromTemplate(GenerateContractFromTemplate event, Emitter<LegalState> emit) async {
    if (state is! LegalLoaded) return;
    final currentState = state as LegalLoaded;

    emit(currentState.copyWith(isGenerating: true, generatedContract: null));

    try {
      final contract = await _repository.generateContract(event.templateId, event.variables);
      emit((state as LegalLoaded).copyWith(
        isGenerating: false,
        generatedContract: contract,
      ));
    } catch (e) {
      emit((state as LegalLoaded).copyWith(
        isGenerating: false,
        errorMessage: 'Не удалось сгенерировать договор: ${e.toString()}',
      ));
    }
  }
}
