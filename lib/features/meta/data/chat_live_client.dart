import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:crypto/crypto.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/ssl_pinning.dart';
import '../domain/meta_models.dart';
import 'api_meta_repository.dart';

/// Live chat socket state, same steps as the web `useChatLive`.
enum ChatLiveStatus { off, connecting, online, offline }

/// One server event from `/api/ws/chats` (`services/chat_events.py`).
class ChatEvent {
  const ChatEvent(this.type, this.data);

  final String type;
  final Map<String, dynamic> data;

  static ChatEvent? decode(String raw) {
    try {
      final json = jsonDecode(raw);
      if (json is! Map || json['type'] is! String) return null;
      return ChatEvent(json['type'] as String, Map<String, dynamic>.from(json));
    } on FormatException {
      return null;
    }
  }

  MetaThread? get thread => metaThreadFromJson(data['thread']);
  MetaMessage? get message => metaMessageFromJson(data['message']);
  int? get id => _int(data['id']);
  int? get storeId => _int(data['store_id']);
  DateTime? get peerReadAt {
    final raw = data['peer_read_at'];
    return raw is String ? DateTime.tryParse(raw) : null;
  }

  /// `ready.unread` or `unread.total`.
  int? get unread => _int(data['unread']) ?? _int(data['total']);

  static int? _int(Object? raw) => switch (raw) {
    int v => v,
    num v => v.toInt(),
    _ => null,
  };
}

/// A connected socket; [messages] completes when the connection is gone.
abstract class ChatSocketChannel {
  Stream<String> get messages;
  int? get closeCode;
  void send(String data);
  Future<void> close();
}

typedef ChatSocketConnector = Future<ChatSocketChannel> Function(Uri uri);
typedef ChatTimerFactory =
    Timer Function(Duration duration, void Function() callback);

/// Holds one `/ws/chats` connection: token in the first frame, reconnect with
/// growing pauses, pause while the app is in background.
///
/// Close codes: 4403 — chats are closed for this user, 4401 — sign-in refused
/// (three in a row stop retries, like the web client).
class ChatLiveClient {
  ChatLiveClient({
    required this.url,
    required Future<String?> Function() token,
    ChatSocketConnector? connector,
    ChatTimerFactory? timer,
  }) : _tokenSource = token,
       _connector = connector ?? connectPinnedWebSocket,
       _timer = timer ?? Timer.new;

  static const maxBackoff = Duration(seconds: 30);

  /// Server pings every 25 s; silence this long means a dead connection.
  static const silenceLimit = Duration(seconds: 70);

  final Uri url;
  final Future<String?> Function() _tokenSource;
  final ChatSocketConnector _connector;
  final ChatTimerFactory _timer;

  final _events = StreamController<ChatEvent>.broadcast();
  final _statuses = StreamController<ChatLiveStatus>.broadcast();

  ChatLiveStatus _status = ChatLiveStatus.off;
  ChatSocketChannel? _channel;
  StreamSubscription<String>? _sub;
  Timer? _retry;
  Timer? _watchdog;
  bool _running = false;
  bool _disposed = false;
  int _generation = 0;
  int _attempt = 0;
  int _denied = 0;

  Stream<ChatEvent> get events => _events.stream;
  Stream<ChatLiveStatus> get statuses => _statuses.stream;
  ChatLiveStatus get status => _status;
  bool get isRunning => _running;

  /// Pause before reconnect attempt [attempt] (1-based): 2, 4, 8, 16, 30 s.
  static Duration backoffFor(int attempt) {
    final seconds = 1 << min(attempt, 5);
    final delay = Duration(seconds: seconds);
    return delay > maxBackoff ? maxBackoff : delay;
  }

  /// Connects unless already running. Safe to call repeatedly.
  void start() {
    if (_disposed || _running) return;
    _running = true;
    _attempt = 0;
    _denied = 0;
    unawaited(_connect(++_generation));
  }

  /// Drops the connection and any pending retry; [start] resumes.
  void stop() {
    if (!_running && _channel == null) return;
    _running = false;
    _generation++;
    _teardown();
    _setStatus(ChatLiveStatus.off);
  }

  /// Fresh connection with a fresh token (store switch, new sign-in).
  void restart() {
    stop();
    start();
  }

  Future<void> dispose() async {
    stop();
    _disposed = true;
    await _events.close();
    await _statuses.close();
  }

  Future<void> _connect(int generation) async {
    if (!_alive(generation)) return;
    final String? token;
    try {
      token = await _tokenSource();
    } catch (_) {
      _schedule(generation);
      return;
    }
    if (!_alive(generation)) return;
    if (token == null || token.isEmpty) {
      _schedule(generation);
      return;
    }
    _setStatus(
      _attempt == 0 ? ChatLiveStatus.connecting : ChatLiveStatus.offline,
    );
    final ChatSocketChannel channel;
    try {
      channel = await _connector(url);
    } catch (_) {
      if (_alive(generation)) _schedule(generation);
      return;
    }
    if (!_alive(generation)) {
      unawaited(channel.close().catchError((Object _) {}));
      return;
    }
    _channel = channel;
    _sub = channel.messages.listen(
      (raw) => _onMessage(generation, raw),
      onError: (Object _) {},
      onDone: () => _onClosed(generation, channel.closeCode),
    );
    _armWatchdog(generation);
    channel.send(jsonEncode({'type': 'auth', 'token': token}));
  }

  void _onMessage(int generation, String raw) {
    if (!_alive(generation)) return;
    _armWatchdog(generation);
    final event = ChatEvent.decode(raw);
    if (event == null) return;
    switch (event.type) {
      case 'ping':
        _channel?.send(jsonEncode({'type': 'pong'}));
        return;
      case 'pong':
        return;
      case 'ready':
        _attempt = 0;
        _denied = 0;
        _setStatus(ChatLiveStatus.online);
    }
    if (!_events.isClosed) _events.add(event);
  }

  void _onClosed(int generation, int? code) {
    if (!_alive(generation)) return;
    _teardown();
    if (code == 4403 || (code == 4401 && ++_denied >= 3)) {
      // No access: nothing to wait for until rights or sign-in change.
      _running = false;
      _setStatus(ChatLiveStatus.off);
      return;
    }
    _setStatus(ChatLiveStatus.offline);
    _schedule(generation);
  }

  void _schedule(int generation) {
    if (!_alive(generation)) return;
    _retry?.cancel();
    _attempt += 1;
    _retry = _timer(backoffFor(_attempt), () {
      _retry = null;
      unawaited(_connect(generation));
    });
  }

  void _armWatchdog(int generation) {
    _watchdog?.cancel();
    _watchdog = _timer(silenceLimit, () => _onClosed(generation, null));
  }

  void _teardown() {
    _retry?.cancel();
    _retry = null;
    _watchdog?.cancel();
    _watchdog = null;
    final sub = _sub;
    final channel = _channel;
    _sub = null;
    _channel = null;
    if (sub != null) unawaited(sub.cancel());
    if (channel != null) {
      unawaited(channel.close().catchError((Object _) {}));
    }
  }

  bool _alive(int generation) =>
      !_disposed && _running && generation == _generation;

  void _setStatus(ChatLiveStatus status) {
    if (_status == status) return;
    _status = status;
    if (!_statuses.isClosed) _statuses.add(status);
  }
}

/// `https://host/api` → `wss://host/api/ws/chats`.
Uri chatSocketUri([String? apiBase]) {
  final base = Uri.parse(apiBase ?? ApiClient().dio.options.baseUrl);
  final path = base.path.endsWith('/')
      ? base.path.substring(0, base.path.length - 1)
      : base.path;
  return base.replace(
    scheme: base.scheme == 'https' ? 'wss' : 'ws',
    path: '$path/ws/chats',
  );
}

/// WebSocket over `dart:io` with the API client's certificate pin.
///
/// The handshake is made by hand so the server certificate can be checked
/// against the pin before the socket is used.
Future<ChatSocketChannel> connectPinnedWebSocket(Uri uri) async {
  final client = createPinnedHttpClient(
    allowInsecure: ApiClient.allowInsecureApi,
  );
  try {
    final random = Random.secure();
    final key = base64.encode(
      List<int>.generate(16, (_) => random.nextInt(256)),
    );
    final request = await client
        .getUrl(uri.replace(scheme: uri.scheme == 'wss' ? 'https' : 'http'))
        .timeout(const Duration(seconds: 15));
    request.followRedirects = false;
    request.headers
      ..set(HttpHeaders.connectionHeader, 'Upgrade')
      ..set(HttpHeaders.upgradeHeader, 'websocket')
      ..set('Sec-WebSocket-Version', '13')
      ..set('Sec-WebSocket-Key', key);
    final response = await request.close().timeout(const Duration(seconds: 15));
    final expectedAccept = base64.encode(
      sha1
          .convert(utf8.encode('${key}258EAFA5-E914-47DA-95CA-C5AB0DC85B11'))
          .bytes,
    );
    if (response.statusCode != HttpStatus.switchingProtocols ||
        response.headers.value('sec-websocket-accept') != expectedAccept) {
      throw const WebSocketException('Handshake refused');
    }
    if (uri.scheme == 'wss' &&
        !acceptsPinnedCertificate(
          response.certificate,
          allowInsecure: ApiClient.allowInsecureApi,
        )) {
      throw const HandshakeException('Certificate pin mismatch');
    }
    final socket = await response.detachSocket();
    final ws = WebSocket.fromUpgradedSocket(socket, serverSide: false);
    return _IoChatSocket(ws, client);
  } catch (_) {
    client.close(force: true);
    rethrow;
  }
}

class _IoChatSocket implements ChatSocketChannel {
  _IoChatSocket(this._ws, this._client);

  final WebSocket _ws;
  final HttpClient _client;

  @override
  Stream<String> get messages => _ws.where((data) => data is String).cast();

  @override
  int? get closeCode => _ws.closeCode;

  @override
  void send(String data) {
    if (_ws.readyState == WebSocket.open) _ws.add(data);
  }

  @override
  Future<void> close() async {
    try {
      await _ws.close().timeout(const Duration(seconds: 3));
    } catch (_) {
      // A dead network never answers the close frame.
    } finally {
      _client.close(force: true);
    }
  }
}
