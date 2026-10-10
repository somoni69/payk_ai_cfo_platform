import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../data/chat_live_client.dart';
import '../domain/meta_repository.dart';

class ChatLiveState extends Equatable {
  const ChatLiveState({this.status = ChatLiveStatus.off, this.unread = 0});

  final ChatLiveStatus status;

  /// Unread across the store's dialogs — badge on «Чаты» in «Ещё».
  final int unread;

  bool get online => status == ChatLiveStatus.online;

  ChatLiveState copyWith({ChatLiveStatus? status, int? unread}) =>
      ChatLiveState(
        status: status ?? this.status,
        unread: unread ?? this.unread,
      );

  @override
  List<Object?> get props => [status, unread];
}

typedef ChatPeriodicFactory =
    Timer Function(Duration period, void Function(Timer timer) callback);

/// One live chat connection for the whole app (single source for the unread
/// badge and the open chat). Lives above the router: `/meta` is a root route.
///
/// Events are passed on only after `ready` for the active store, so a late
/// event from a previous store never reaches the screen. While the socket is
/// down the unread total is polled; once it is online polling stops.
class ChatLiveCubit extends Cubit<ChatLiveState> {
  ChatLiveCubit({
    required MetaRepository repository,
    required ChatLiveClient client,
    ChatPeriodicFactory? periodic,
    this.unreadPollEvery = const Duration(seconds: 60),
  }) : _repo = repository,
       _socket = client,
       _periodic = periodic ?? Timer.periodic,
       super(const ChatLiveState()) {
    _statusSub = _socket.statuses.listen(_onStatus);
    _eventSub = _socket.events.listen(_onEvent);
  }

  final MetaRepository _repo;
  final ChatLiveClient _socket;
  final ChatPeriodicFactory _periodic;
  final Duration unreadPollEvery;

  final _events = StreamController<ChatEvent>.broadcast();
  late final StreamSubscription<ChatLiveStatus> _statusSub;
  late final StreamSubscription<ChatEvent> _eventSub;
  Timer? _poll;
  int? _storeId;
  bool _foreground = true;
  bool _ready = false;
  int _unreadSeq = 0;

  /// Store events after `ready`, already filtered to the active store.
  Stream<ChatEvent> get events => _events.stream;
  int? get storeId => _storeId;

  /// Signed in with a store: connect (or reconnect for another store).
  void activate(int storeId) {
    if (isClosed) return;
    if (_storeId == storeId && _socket.isRunning) return;
    final switched = _storeId != storeId;
    _storeId = storeId;
    _ready = false;
    if (switched) emit(state.copyWith(unread: 0));
    if (_foreground) {
      _socket.restart();
      unawaited(refreshUnread());
    }
    _syncPolling();
  }

  /// Signed out or no store (owner at the network root): no chats.
  void deactivate() {
    if (isClosed) return;
    _storeId = null;
    _ready = false;
    _socket.stop();
    _syncPolling();
    emit(const ChatLiveState());
  }

  /// App lifecycle: close the socket in background, reconnect on return.
  void setForeground(bool foreground) {
    if (isClosed || _foreground == foreground) return;
    _foreground = foreground;
    if (_storeId == null) return;
    if (foreground) {
      _ready = false;
      _socket.start();
      unawaited(refreshUnread());
    } else {
      _socket.stop();
    }
    _syncPolling();
  }

  Future<void> refreshUnread() async {
    final store = _storeId;
    if (store == null) return;
    final seq = ++_unreadSeq;
    try {
      final total = await _repo.getUnreadTotal();
      if (isClosed || store != _storeId || seq != _unreadSeq) return;
      emit(state.copyWith(unread: total < 0 ? 0 : total));
    } catch (_) {
      // The badge keeps the last known value; the next poll or event fixes it.
    }
  }

  void _onStatus(ChatLiveStatus status) {
    if (isClosed) return;
    if (status != ChatLiveStatus.online) _ready = false;
    emit(state.copyWith(status: status));
    _syncPolling();
  }

  void _onEvent(ChatEvent event) {
    if (isClosed || _storeId == null) return;
    if (event.type == 'ready') {
      final store = event.storeId;
      _ready = store == null || store == _storeId;
      if (!_ready) return;
    }
    if (!_ready) return;
    final unread = switch (event.type) {
      'ready' || 'unread' => event.unread,
      _ => null,
    };
    if (unread != null) {
      _unreadSeq++; // a slower REST answer must not overwrite the push
      emit(state.copyWith(unread: unread < 0 ? 0 : unread));
    }
    if (!_events.isClosed) _events.add(event);
  }

  void _syncPolling() {
    final want = _storeId != null && _foreground && !state.online;
    if (want && _poll == null) {
      _poll = _periodic(unreadPollEvery, (_) => unawaited(refreshUnread()));
    } else if (!want) {
      _poll?.cancel();
      _poll = null;
    }
  }

  @override
  Future<void> close() async {
    _poll?.cancel();
    _poll = null;
    await _statusSub.cancel();
    await _eventSub.cancel();
    await _socket.dispose();
    await _events.close();
    return super.close();
  }
}
