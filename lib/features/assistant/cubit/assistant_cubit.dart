import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/network/user_facing_error.dart';
import '../domain/assistant_models.dart';
import '../domain/assistant_repository.dart';
import 'assistant_state.dart';

export 'assistant_state.dart';

class AssistantCubit extends Cubit<AssistantState> {
  final AssistantRepository _repository;

  AssistantCubit(this._repository) : super(AssistantState.initial);

  Future<void> loadAdvice(String module, {required String lang}) async {
    if (module == kAssistantGeneralModule) return;
    emit(state.copyWith(isLoading: true, clearError: true));
    try {
      final advice = await _repository.getAdvice(module, lang: lang);
      if (isClosed) return;
      final updated = Map<String, AdviceResponse>.from(state.adviceByModule)
        ..[module] = advice;
      emit(state.copyWith(adviceByModule: updated, isLoading: false));
    } catch (e) {
      if (isClosed) return;
      emit(
        state.copyWith(
          isLoading: false,
          error: userFacingError(e, fallback: ErrorKeys.loadFailed),
        ),
      );
    }
  }

  Future<void> generateAdvice(String module, {required String lang}) async {
    if (state.isGeneratingAdvice) return;
    emit(state.copyWith(isGeneratingAdvice: true, clearError: true));
    try {
      final advice = await _repository.generateAdvice(module, lang: lang);
      if (isClosed) return;
      final updated = Map<String, AdviceResponse>.from(state.adviceByModule)
        ..[module] = advice;
      emit(state.copyWith(adviceByModule: updated, isGeneratingAdvice: false));
    } catch (e) {
      if (isClosed) return;
      emit(
        state.copyWith(
          isGeneratingAdvice: false,
          error: userFacingError(e, fallback: ErrorKeys.saveFailed),
        ),
      );
    }
  }

  Future<void> loadHistory(String module, {int limit = 50}) async {
    emit(state.copyWith(isLoading: true, clearError: true));
    try {
      final messages = await _repository.getHistory(module, limit: limit);
      if (isClosed) return;
      final updated = Map<String, List<AssistantMessage>>.from(
        state.historyByModule,
      )..[module] = messages;
      emit(state.copyWith(historyByModule: updated, isLoading: false));
    } catch (e) {
      if (isClosed) return;
      emit(
        state.copyWith(
          isLoading: false,
          error: userFacingError(e, fallback: ErrorKeys.loadFailed),
        ),
      );
    }
  }

  Future<void> sendMessage({
    required String question,
    required String module,
  }) async {
    if (state.isSendingMessage) return;
    final currentHistory = List<AssistantMessage>.from(
      state.historyFor(module),
    );
    final now = DateTime.now();
    final userMsg = AssistantMessage(
      id: -now.millisecondsSinceEpoch,
      role: 'user',
      text: question,
      createdAt: now,
    );
    final updatedWithUser = [...currentHistory, userMsg];
    final updatedMap = Map<String, List<AssistantMessage>>.from(
      state.historyByModule,
    )..[module] = updatedWithUser;

    emit(
      state.copyWith(
        historyByModule: updatedMap,
        isSendingMessage: true,
        clearError: true,
      ),
    );

    try {
      final answer = await _repository.ask(question: question, module: module);
      if (isClosed) return;
      final assistantMsg = AssistantMessage(
        id: -now.millisecondsSinceEpoch - 1,
        role: 'assistant',
        text: answer,
        createdAt: DateTime.now(),
      );
      final finalHistory = [...updatedWithUser, assistantMsg];
      final finalMap = Map<String, List<AssistantMessage>>.from(
        state.historyByModule,
      )..[module] = finalHistory;
      emit(state.copyWith(historyByModule: finalMap, isSendingMessage: false));
    } catch (e) {
      if (isClosed) return;
      emit(
        state.copyWith(
          isSendingMessage: false,
          error: userFacingError(e, fallback: ErrorKeys.saveFailed),
        ),
      );
    }
  }

  Future<void> clearHistory(String module) async {
    try {
      await _repository.clearHistory(module);
      if (isClosed) return;
      final updated = Map<String, List<AssistantMessage>>.from(
        state.historyByModule,
      )..[module] = const [];
      emit(state.copyWith(historyByModule: updated));
    } catch (e) {
      if (isClosed) return;
      emit(
        state.copyWith(
          error: userFacingError(e, fallback: ErrorKeys.saveFailed),
        ),
      );
    }
  }
}
