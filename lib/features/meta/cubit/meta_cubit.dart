import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/network/user_facing_error.dart';
import '../data/chat_live_client.dart';
import '../domain/meta_models.dart';
import '../domain/meta_repository.dart';
import 'chat_live_cubit.dart';
import 'meta_state.dart';

export 'meta_state.dart';

class MetaCubit extends Cubit<MetaState> {
  final MetaRepository _repository;
  final ChatLiveCubit? _liveCubit;
  final DateTime Function() _clock;
  Timer? _pollTimer;
  Duration? _pollInterval;
  StreamSubscription<ChatEvent>? _eventSub;
  StreamSubscription<bool>? _liveSub;

  /// «Печатает…» goes at most this often while the operator types (web value).
  static const typingEvery = Duration(seconds: 6);
  int? _typingThreadId;
  DateTime? _typingSentAt;

  /// With [live], server events update the screen and polling runs only
  /// while the socket is down.
  MetaCubit(this._repository, {ChatLiveCubit? live, DateTime Function()? clock})
    : _liveCubit = live,
      _clock = clock ?? DateTime.now,
      super(MetaState.initial) {
    final live = _liveCubit;
    if (live != null) {
      _eventSub = live.events.listen(_onLiveEvent);
      _liveSub = live.stream
          .map((s) => s.online)
          .distinct()
          .listen((_) => _syncPolling());
    }
  }

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
        } catch (_) {
          // Keep what is on screen; the next refresh retries.
        }
        if (isClosed) return;
        if (state.selectedThread?.id != selected.id) messages = state.messages;
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
    if (thread?.id != state.selectedThread?.id) composerStopped();
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
      if (isClosed || state.selectedThread?.id != thread.id) return;
      emit(state.copyWith(messages: messages, isLoadingMessages: false));
    } catch (e) {
      if (isClosed || state.selectedThread?.id != thread.id) return;
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

    composerStopped();
    emit(state.copyWith(isSending: true, clearError: true));
    try {
      final sent = await _repository.reply(selected.id, text.trim());
      if (isClosed) return;
      if (state.selectedThread?.id != selected.id) {
        emit(state.copyWith(isSending: false));
        return;
      }
      emit(
        state.copyWith(
          messages: _mergeMessage(state.messages, sent),
          isSending: false,
        ),
      );
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

  Future<void> sendAttachment({
    required String filename,
    required List<int> bytes,
    String caption = '',
  }) => _sendOne(
    (threadId) => _repository.sendAttachment(
      threadId,
      filename: filename,
      bytes: bytes,
      caption: caption,
    ),
  );

  /// Sends the store's saved «наш адрес» point, when the server has one.
  Future<void> sendOurAddress() async {
    final place = state.status?.place;
    if (place == null) return;
    await _sendOne((threadId) => _repository.sendLocation(threadId, place));
  }

  Future<void> _sendOne(Future<MetaMessage> Function(int threadId) send) async {
    final selected = state.selectedThread;
    if (selected == null || state.isSending) return;
    emit(state.copyWith(isSending: true, clearError: true));
    try {
      final sent = await send(selected.id);
      if (isClosed) return;
      if (state.selectedThread?.id != selected.id) {
        emit(state.copyWith(isSending: false));
        return;
      }
      emit(
        state.copyWith(
          messages: _mergeMessage(state.messages, sent),
          isSending: false,
        ),
      );
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

  Future<bool> deleteThread() async {
    final selected = state.selectedThread;
    if (selected == null || state.isSending) return false;
    emit(state.copyWith(isSending: true, clearError: true));
    try {
      await _repository.deleteThread(selected.id);
      if (isClosed) return true;
      emit(
        state.copyWith(
          isSending: false,
          clearSelectedThread: true,
          messages: const [],
          threads: state.threads
              .where((item) => item.id != selected.id)
              .toList(),
        ),
      );
      return true;
    } catch (e) {
      if (isClosed) return false;
      emit(
        state.copyWith(
          isSending: false,
          error: userFacingError(e, fallback: ErrorKeys.saveFailed),
        ),
      );
      return false;
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

  /// Fallback refresh. With a live socket it runs only while the socket is down.
  void startPolling({Duration interval = const Duration(seconds: 15)}) {
    _pollInterval = interval;
    _pollTimer?.cancel();
    _pollTimer = null;
    _syncPolling();
  }

  void stopPolling() {
    _pollInterval = null;
    _pollTimer?.cancel();
    _pollTimer = null;
  }

  bool get isPolling => _pollTimer != null;

  void _syncPolling() {
    final interval = _pollInterval;
    final want =
        interval != null && !isClosed && !(_liveCubit?.state.online ?? false);
    if (!want) {
      _pollTimer?.cancel();
      _pollTimer = null;
      return;
    }
    _pollTimer ??= Timer.periodic(interval, (_) {
      if (!isClosed && !state.isLoading) {
        unawaited(load(silent: true));
      }
    });
  }

  /// Operator typed in the reply field: throttled «печатает…» for the peer.
  void composerChanged(String text) {
    final selected = state.selectedThread;
    if (selected == null) return;
    if (_typingThreadId != null && _typingThreadId != selected.id) {
      composerStopped();
    }
    if (text.trim().isEmpty) {
      composerStopped();
      return;
    }
    final now = _clock();
    final last = _typingSentAt;
    if (last != null && now.difference(last) < typingEvery) return;
    _typingThreadId = selected.id;
    _typingSentAt = now;
    _sendTyping(selected.id, on: true);
  }

  /// Reply sent, field cleared, chat switched or closed: «печатает…» off.
  void composerStopped() {
    final threadId = _typingThreadId;
    _typingThreadId = null;
    _typingSentAt = null;
    if (threadId != null) _sendTyping(threadId, on: false);
  }

  void _sendTyping(int threadId, {required bool on}) {
    // A lost typing hint is harmless; the server answers even for Umnico.
    unawaited(
      _repository.sendTyping(threadId, on: on).catchError((Object _) {}),
    );
  }

  void _onLiveEvent(ChatEvent event) {
    if (isClosed) return;
    switch (event.type) {
      case 'ready' || 'resync':
        // The feed may be stale after a gap: reread once.
        if (!state.isLoading) unawaited(load(silent: true));
      case 'message.new' || 'message.update':
        final thread = event.thread;
        final message = event.message;
        if (thread == null || message == null) return;
        final threads = _upsertThread(state.threads, thread, insert: true);
        final selected = state.selectedThread;
        if (selected?.id != thread.id) {
          emit(state.copyWith(threads: threads));
          return;
        }
        emit(
          state.copyWith(
            threads: threads,
            selectedThread: thread,
            messages: _mergeMessage(state.messages, message),
          ),
        );
        if (event.type == 'message.new' && !message.outgoing) {
          // Rereading the open chat lets the server clear unread and mark seen.
          unawaited(_rereadOpen(thread.id));
        }
      case 'thread.update':
        final thread = event.thread;
        if (thread == null) return;
        emit(
          state.copyWith(
            threads: _upsertThread(state.threads, thread, insert: true),
            selectedThread: state.selectedThread?.id == thread.id
                ? thread
                : null,
          ),
        );
      case 'thread.read':
        final id = event.id;
        if (id == null) return;
        final readAt = event.peerReadAt;
        final selected = state.selectedThread;
        emit(
          state.copyWith(
            threads: [
              for (final t in state.threads)
                t.id == id ? t.copyWith(peerReadAt: readAt) : t,
            ],
            selectedThread: selected?.id == id
                ? selected!.copyWith(peerReadAt: readAt)
                : null,
          ),
        );
      case 'thread.deleted':
        final id = event.id;
        if (id == null) return;
        final open = state.selectedThread?.id == id;
        if (open) composerStopped();
        emit(
          state.copyWith(
            threads: state.threads.where((t) => t.id != id).toList(),
            clearSelectedThread: open,
            messages: open ? const [] : null,
          ),
        );
    }
  }

  Future<void> _rereadOpen(int threadId) async {
    try {
      final messages = await _repository.getMessages(threadId);
      if (isClosed || state.selectedThread?.id != threadId) return;
      emit(state.copyWith(messages: messages));
    } catch (_) {
      // The pushed message is already on screen.
    }
  }

  List<MetaThread> _upsertThread(
    List<MetaThread> threads,
    MetaThread thread, {
    required bool insert,
  }) {
    final index = threads.indexWhere((t) => t.id == thread.id);
    final channel = state.selectedChannel;
    final fits = channel.isEmpty || channel == thread.channel;
    final List<MetaThread> next;
    if (index >= 0) {
      next = List<MetaThread>.from(threads)..[index] = thread;
    } else if (insert && fits) {
      next = [thread, ...threads];
    } else {
      return threads;
    }
    next.sort((a, b) {
      final at = a.lastMessageAt;
      final bt = b.lastMessageAt;
      if (at == null && bt == null) return 0;
      if (at == null) return 1;
      if (bt == null) return -1;
      return bt.compareTo(at);
    });
    return next;
  }

  static List<MetaMessage> _mergeMessage(
    List<MetaMessage> messages,
    MetaMessage message,
  ) {
    final index = messages.indexWhere((m) => m.id == message.id);
    if (index < 0) return [...messages, message];
    return List<MetaMessage>.from(messages)..[index] = message;
  }

  @override
  Future<void> close() async {
    composerStopped();
    stopPolling();
    await _eventSub?.cancel();
    await _liveSub?.cancel();
    return super.close();
  }
}
