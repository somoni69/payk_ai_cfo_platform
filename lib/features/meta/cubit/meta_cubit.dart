import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/network/user_facing_error.dart';
import '../domain/meta_models.dart';
import '../domain/meta_repository.dart';
import 'meta_state.dart';

export 'meta_state.dart';

class MetaCubit extends Cubit<MetaState> {
  final MetaRepository _repository;
  Timer? _pollTimer;

  MetaCubit(this._repository) : super(MetaState.initial);

  Future<void> load({String? channel, bool silent = false}) async {
    final activeChannel = channel ?? state.selectedChannel;
    if (!silent) {
      emit(
        state.copyWith(
          selectedChannel: activeChannel,
          isLoading: true,
          clearError: true,
        ),
      );
    }
    try {
      final results = await Future.wait<Object>([
        _repository.getStatus(),
        _repository.getThreads(
          channel: activeChannel.isEmpty ? null : activeChannel,
        ),
      ]);
      if (isClosed) return;
      final status = results[0] as MetaStatus;
      final threads = results[1] as List<MetaThread>;

      List<MetaMessage> messages = state.messages;
      final selected = state.selectedThread;
      if (silent && selected != null) {
        try {
          messages = await _repository.getMessages(selected.id);
        } catch (_) {}
      }

      emit(
        state.copyWith(
          status: status,
          threads: threads,
          messages: messages,
          isLoading: false,
          clearError: true,
        ),
      );
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

  void setChannel(String channel) {
    emit(state.copyWith(selectedChannel: channel));
    unawaited(load(channel: channel));
  }

  Future<void> selectThread(MetaThread? thread) async {
    if (thread == null) {
      emit(
        state.copyWith(
          clearSelectedThread: true,
          messages: const [],
          isLoadingMessages: false,
        ),
      );
      return;
    }
    emit(
      state.copyWith(
        selectedThread: thread,
        isLoadingMessages: true,
        clearError: true,
      ),
    );
    try {
      final messages = await _repository.getMessages(thread.id);
      if (isClosed) return;
      emit(state.copyWith(messages: messages, isLoadingMessages: false));
    } catch (e) {
      if (isClosed) return;
      emit(
        state.copyWith(
          isLoadingMessages: false,
          error: userFacingError(e, fallback: ErrorKeys.loadFailed),
        ),
      );
    }
  }

  Future<void> sendMessage(String text) async {
    final selected = state.selectedThread;
    if (selected == null || text.trim().isEmpty || state.isSending) return;

    emit(state.copyWith(isSending: true, clearError: true));
    try {
      final sent = await _repository.reply(selected.id, text.trim());
      if (isClosed) return;
      final updated = [...state.messages, sent];
      emit(state.copyWith(messages: updated, isSending: false));
    } catch (e) {
      if (isClosed) return;
      emit(
        state.copyWith(
          isSending: false,
          error: userFacingError(e, fallback: ErrorKeys.saveFailed),
        ),
      );
    }
  }

  Future<String?> suggestReply() async {
    final selected = state.selectedThread;
    if (selected == null || state.isSending) return null;
    emit(state.copyWith(isSending: true, clearError: true));
    try {
      final suggestion = await _repository.suggestReply(selected.id);
      if (isClosed) return suggestion;
      emit(state.copyWith(isSending: false));
      return suggestion;
    } catch (e) {
      if (isClosed) return null;
      emit(
        state.copyWith(
          isSending: false,
          error: userFacingError(e, fallback: ErrorKeys.loadFailed),
        ),
      );
      return null;
    }
  }

  Future<void> linkClient(int clientId) async {
    final selected = state.selectedThread;
    if (selected == null) return;
    try {
      final updated = await _repository.linkClient(selected.id, clientId);
      if (isClosed) return;
      final threadIdx = state.threads.indexWhere((t) => t.id == selected.id);
      List<MetaThread> threads = state.threads;
      if (threadIdx != -1) {
        threads = List<MetaThread>.from(state.threads)..[threadIdx] = updated;
      }
      emit(state.copyWith(selectedThread: updated, threads: threads));
    } catch (e) {
      if (isClosed) return;
      emit(
        state.copyWith(
          error: userFacingError(e, fallback: ErrorKeys.saveFailed),
        ),
      );
    }
  }

  void startPolling({Duration interval = const Duration(seconds: 15)}) {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(interval, (_) {
      if (!isClosed && !state.isLoading) {
        unawaited(load(silent: true));
      }
    });
  }

  void stopPolling() {
    _pollTimer?.cancel();
    _pollTimer = null;
  }

  @override
  Future<void> close() {
    stopPolling();
    return super.close();
  }
}
