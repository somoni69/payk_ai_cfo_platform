import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:payk_ai_cfo_platform/features/meta/cubit/chat_live_cubit.dart';
import 'package:payk_ai_cfo_platform/features/meta/cubit/meta_cubit.dart';
import 'package:payk_ai_cfo_platform/features/meta/data/chat_live_client.dart';
import 'package:payk_ai_cfo_platform/features/meta/domain/meta_models.dart';
import 'package:payk_ai_cfo_platform/features/meta/domain/meta_repository.dart';

class _FakeTimer implements Timer {
  _FakeTimer(this.duration, this.callback);

  final Duration duration;
  final void Function() callback;
  bool cancelled = false;
  bool fired = false;

  void fire() {
    if (cancelled || fired) return;
    fired = true;
    callback();
  }

  @override
  void cancel() => cancelled = true;

  @override
  bool get isActive => !cancelled && !fired;

  @override
  int get tick => fired ? 1 : 0;
}

class _Timers {
  final all = <_FakeTimer>[];

  Timer call(Duration duration, void Function() callback) {
    final timer = _FakeTimer(duration, callback);
    all.add(timer);
    return timer;
  }

  /// Pending reconnect timers (the 70 s watchdog is not one of them).
  List<_FakeTimer> get retries => all
      .where((t) => t.isActive && t.duration != ChatLiveClient.silenceLimit)
      .toList();
}

class _FakeChannel implements ChatSocketChannel {
  final _controller = StreamController<String>();
  final sent = <Map<String, dynamic>>[];
  int? _closeCode;
  bool closedByClient = false;

  void push(Map<String, dynamic> event) => _controller.add(jsonEncode(event));

  void serverClose(int code) {
    _closeCode = code;
    unawaited(_controller.close());
  }

  @override
  Stream<String> get messages => _controller.stream;

  @override
  int? get closeCode => _closeCode;

  @override
  void send(String data) =>
      sent.add(Map<String, dynamic>.from(jsonDecode(data) as Map));

  @override
  Future<void> close() async {
    closedByClient = true;
    if (!_controller.isClosed) await _controller.close();
  }
}

class _Harness {
  _Harness() {
    client = ChatLiveClient(
      url: Uri.parse('wss://example.test/api/ws/chats'),
      token: () async => token,
      connector: (_) async {
        final channel = _FakeChannel();
        channels.add(channel);
        return channel;
      },
      timer: timers.call,
    );
  }

  final timers = _Timers();
  final channels = <_FakeChannel>[];
  String? token = 'access-1';
  late final ChatLiveClient client;

  _FakeChannel get last => channels.last;
}

Future<void> _flush() async {
  for (var i = 0; i < 5; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

class _Repo implements MetaRepository {
  int unread = 0;
  int unreadCalls = 0;
  final typing = <(int, bool)>[];
  final messagesCalls = <int>[];
  Map<int, Completer<List<MetaMessage>>> pendingMessages = {};

  @override
  Future<int> getUnreadTotal() async {
    unreadCalls++;
    return unread;
  }

  @override
  Future<void> sendTyping(int threadId, {required bool on}) async =>
      typing.add((threadId, on));

  @override
  Future<MetaStatus> getStatus() async => const MetaStatus(connected: true);

  @override
  Future<List<MetaThread>> getThreads({String? channel}) async => [
    MetaThread(
      id: 1,
      channel: 'instagram',
      peerId: 'a',
      lastMessageAt: DateTime.utc(2026, 10, 10, 6),
    ),
    MetaThread(
      id: 2,
      channel: 'whatsapp',
      peerId: 'b',
      lastMessageAt: DateTime.utc(2026, 10, 10, 5),
    ),
  ];

  @override
  Future<List<MetaMessage>> getMessages(int threadId) {
    messagesCalls.add(threadId);
    final pending = pendingMessages.remove(threadId);
    if (pending != null) return pending.future;
    return Future.value([
      MetaMessage(
        id: threadId * 100,
        outgoing: true,
        text: 'hi',
        createdAt: DateTime.utc(2026, 10, 10, 6),
      ),
    ]);
  }

  @override
  Future<MetaMessage> reply(int threadId, String text) async => MetaMessage(
    id: 999,
    outgoing: true,
    text: text,
    createdAt: DateTime.utc(2026, 10, 10, 7),
  );

  @override
  Future<String> suggestReply(int threadId) async => '';

  @override
  Future<MetaMessage> sendAttachment(
    int threadId, {
    required String filename,
    required List<int> bytes,
    String caption = '',
  }) => throw UnimplementedError();

  @override
  Future<MetaMessage> sendLocation(int threadId, MetaPlace place) =>
      throw UnimplementedError();

  @override
  Future<MetaThread> linkClient(int threadId, int clientId) =>
      throw UnimplementedError();

  @override
  Future<void> deleteThread(int threadId) async {}
}

Map<String, dynamic> _thread(int id, {String channel = 'instagram'}) => {
  'id': id,
  'channel': channel,
  'peer_id': 'p$id',
  'unread': 1,
  'last_message_at': '2026-10-10T07:00:00Z',
  'peer_read_at': null,
};

Map<String, dynamic> _message(int id, {bool outgoing = false}) => {
  'id': id,
  'outgoing': outgoing,
  'text': 'msg $id',
  'created_at': '2026-10-10T07:00:00Z',
  'attachments': <dynamic>[],
  'read': false,
};

void main() {
  group('ChatLiveClient', () {
    test('sends the token in the first frame and answers ping', () async {
      final h = _Harness();
      h.client.start();
      await _flush();

      expect(h.client.status, ChatLiveStatus.connecting);
      expect(h.last.sent.first, {'type': 'auth', 'token': 'access-1'});

      h.last.push({'type': 'ready', 'store_id': 5, 'unread': 2});
      h.last.push({'type': 'ping'});
      await _flush();

      expect(h.client.status, ChatLiveStatus.online);
      expect(h.last.sent.last, {'type': 'pong'});
      await h.client.dispose();
    });

    test('reconnects with growing pauses capped at 30 s', () async {
      final h = _Harness();
      h.client.start();
      await _flush();

      final delays = <Duration>[];
      for (var i = 0; i < 6; i++) {
        h.last.serverClose(1006);
        await _flush();
        expect(h.client.status, ChatLiveStatus.offline);
        final retry = h.timers.retries.single;
        delays.add(retry.duration);
        retry.fire();
        await _flush();
      }

      expect(delays.map((d) => d.inSeconds), [2, 4, 8, 16, 30, 30]);
      expect(h.channels, hasLength(7));

      // A successful «ready» resets the pause.
      h.last.push({'type': 'ready', 'store_id': 5, 'unread': 0});
      await _flush();
      h.last.serverClose(1006);
      await _flush();
      expect(h.timers.retries.single.duration, const Duration(seconds: 2));
      await h.client.dispose();
    });

    test('4403 stops retries; three 4401 in a row stop too', () async {
      final h = _Harness();
      h.client.start();
      await _flush();
      h.last.serverClose(4403);
      await _flush();
      expect(h.client.status, ChatLiveStatus.off);
      expect(h.timers.retries, isEmpty);
      expect(h.client.isRunning, isFalse);

      final g = _Harness();
      g.client.start();
      await _flush();
      for (var i = 0; i < 2; i++) {
        g.last.serverClose(4401);
        await _flush();
        g.timers.retries.single.fire();
        await _flush();
      }
      g.last.serverClose(4401);
      await _flush();
      expect(g.client.status, ChatLiveStatus.off);
      expect(g.timers.retries, isEmpty);
      await h.client.dispose();
      await g.client.dispose();
    });

    test('stop (background) closes the socket and cancels retry', () async {
      final h = _Harness();
      h.client.start();
      await _flush();
      h.last.serverClose(1006);
      await _flush();
      final retry = h.timers.retries.single;

      h.client.stop();
      expect(retry.isActive, isFalse);
      expect(h.client.status, ChatLiveStatus.off);

      // Resume connects once with a fresh token.
      h.token = 'access-2';
      h.client.start();
      h.client.start();
      await _flush();
      expect(h.channels, hasLength(2));
      expect(h.last.sent.first['token'], 'access-2');

      h.client.stop();
      await _flush();
      expect(h.last.closedByClient, isTrue);
      expect(h.timers.retries, isEmpty);
      await h.client.dispose();
    });

    test('silence past the watchdog reconnects', () async {
      final h = _Harness();
      h.client.start();
      await _flush();
      final watchdog = h.timers.all.lastWhere(
        (t) => t.isActive && t.duration == ChatLiveClient.silenceLimit,
      );
      watchdog.fire();
      await _flush();
      expect(h.client.status, ChatLiveStatus.offline);
      expect(h.timers.retries, hasLength(1));
      await h.client.dispose();
    });

    test('socket URL follows the API base', () {
      expect(
        chatSocketUri('https://host.test/api').toString(),
        'wss://host.test/api/ws/chats',
      );
      expect(
        chatSocketUri('http://10.0.2.2:8000/api/').toString(),
        'ws://10.0.2.2:8000/api/ws/chats',
      );
    });
  });

  group('ChatLiveCubit', () {
    late _Harness h;
    late _Repo repo;
    late _Timers periodic;
    late ChatLiveCubit live;

    setUp(() {
      h = _Harness();
      repo = _Repo()..unread = 4;
      periodic = _Timers();
      live = ChatLiveCubit(
        repository: repo,
        client: h.client,
        periodic: (period, cb) =>
            periodic(period, () => cb(_FakeTimer(period, () {}))),
      );
    });

    tearDown(() => live.close());

    test('unread comes from REST, then from ready and unread events', () async {
      live.activate(5);
      await _flush();
      expect(live.state.unread, 4);

      h.last.push({'type': 'ready', 'store_id': 5, 'unread': 7});
      await _flush();
      expect(live.state.unread, 7);
      expect(live.state.online, isTrue);

      h.last.push({'type': 'unread', 'total': 2});
      await _flush();
      expect(live.state.unread, 2);
    });

    test('polls unread only while the socket is down', () async {
      live.activate(5);
      await _flush();
      final poll = periodic.all.single;
      expect(poll.isActive, isTrue);

      h.last.push({'type': 'ready', 'store_id': 5, 'unread': 0});
      await _flush();
      expect(poll.isActive, isFalse);

      h.last.serverClose(1006);
      await _flush();
      expect(periodic.all.where((t) => t.isActive), hasLength(1));

      live.setForeground(false);
      expect(periodic.all.where((t) => t.isActive), isEmpty);
      expect(h.client.isRunning, isFalse);

      live.setForeground(true);
      await _flush();
      expect(h.client.isRunning, isTrue);
      expect(periodic.all.where((t) => t.isActive), hasLength(1));
    });

    test('events of another store are dropped', () async {
      final received = <String>[];
      final sub = live.events.listen((e) => received.add(e.type));
      live.activate(5);
      await _flush();

      h.last.push({
        'type': 'message.new',
        'thread': _thread(1),
        'message': _message(1),
      });
      h.last.push({'type': 'ready', 'store_id': 9, 'unread': 50});
      h.last.push({'type': 'unread', 'total': 50});
      await _flush();
      expect(received, isEmpty);
      expect(live.state.unread, 4);

      await sub.cancel();
    });

    test('sign-out stops the socket and clears the badge', () async {
      live.activate(5);
      await _flush();
      h.last.push({'type': 'ready', 'store_id': 5, 'unread': 3});
      await _flush();

      live.deactivate();
      expect(live.state, const ChatLiveState());
      expect(h.client.isRunning, isFalse);
      expect(periodic.all.where((t) => t.isActive), isEmpty);
    });
  });

  group('MetaCubit live events', () {
    late _Harness h;
    late _Repo repo;
    late ChatLiveCubit live;
    late MetaCubit cubit;
    var now = DateTime(2026, 10, 10, 12);

    setUp(() async {
      h = _Harness();
      repo = _Repo();
      live = ChatLiveCubit(
        repository: repo,
        client: h.client,
        periodic: (period, cb) => _FakeTimer(period, () {}),
      );
      cubit = MetaCubit(repo, live: live, clock: () => now);
      live.activate(5);
      await cubit.load();
      await _flush();
      h.last.push({'type': 'ready', 'store_id': 5, 'unread': 0});
      await _flush();
    });

    tearDown(() async {
      await cubit.close();
      await live.close();
    });

    test('new message lands in the open chat once and refreshes it', () async {
      await cubit.selectThread(cubit.state.threads.first);
      repo.messagesCalls.clear();

      h.last.push({
        'type': 'message.new',
        'thread': _thread(1),
        'message': _message(5),
      });
      h.last.push({
        'type': 'message.update',
        'thread': _thread(1),
        'message': _message(5),
      });
      await _flush();

      expect(repo.messagesCalls, [1]);
    });

    test('message for another chat updates only the list', () async {
      await cubit.selectThread(cubit.state.threads.first);
      final before = cubit.state.messages;

      h.last.push({
        'type': 'message.new',
        'thread': _thread(3, channel: 'facebook'),
        'message': _message(6),
      });
      await _flush();

      expect(cubit.state.messages, before);
      expect(cubit.state.threads.first.id, 3);
      expect(cubit.state.selectedThread?.id, 1);
    });

    test(
      'our message is not duplicated when the push follows the reply',
      () async {
        await cubit.selectThread(cubit.state.threads.first);
        await cubit.sendMessage('ok');
        h.last.push({
          'type': 'message.new',
          'thread': _thread(1),
          'message': {..._message(999, outgoing: true), 'text': 'ok'},
        });
        await _flush();

        expect(cubit.state.messages.where((m) => m.id == 999), hasLength(1));
      },
    );

    test('thread.read marks our messages read', () async {
      await cubit.selectThread(cubit.state.threads.first);
      h.last.push({
        'type': 'thread.read',
        'id': 1,
        'peer_read_at': '2026-10-10T06:30:00Z',
      });
      await _flush();

      final readAt = cubit.state.selectedThread?.peerReadAt;
      expect(readAt, DateTime.utc(2026, 10, 10, 6, 30));
      expect(cubit.state.messages.single.isReadBy(readAt), isTrue);
    });

    test('thread.deleted closes the open chat', () async {
      await cubit.selectThread(cubit.state.threads.first);
      h.last.push({'type': 'thread.deleted', 'id': 1});
      await _flush();

      expect(cubit.state.selectedThread, isNull);
      expect(cubit.state.messages, isEmpty);
      expect(cubit.state.threads.map((t) => t.id), [2]);
    });

    test(
      'a slow answer for the previous chat does not overwrite the new one',
      () async {
        final slow = Completer<List<MetaMessage>>();
        repo.pendingMessages[1] = slow;
        final first = cubit.selectThread(cubit.state.threads[0]);
        await cubit.selectThread(cubit.state.threads[1]);
        slow.complete([
          MetaMessage(
            id: 1,
            outgoing: false,
            text: 'old',
            createdAt: DateTime.utc(2026),
          ),
        ]);
        await first;

        expect(cubit.state.selectedThread?.id, 2);
        expect(cubit.state.messages.single.id, 200);
      },
    );

    test('typing is throttled and switched off on send', () async {
      await cubit.selectThread(cubit.state.threads.first);
      cubit.composerChanged('h');
      cubit.composerChanged('he');
      now = now.add(const Duration(seconds: 7));
      cubit.composerChanged('hel');
      await _flush();
      expect(repo.typing, [(1, true), (1, true)]);

      await cubit.sendMessage('hello');
      await _flush();
      expect(repo.typing.last, (1, false));
    });

    test('polling runs only while the socket is down', () async {
      cubit.startPolling();
      expect(cubit.isPolling, isFalse);

      h.last.serverClose(1006);
      await _flush();
      expect(cubit.isPolling, isTrue);
    });
  });
}
