import '../../../core/network/api_client.dart';
import '../../../core/network/user_facing_error.dart';
import '../domain/meta_models.dart';
import '../domain/meta_repository.dart';

class ApiMetaRepository implements MetaRepository {
  final ApiClient _apiClient;

  ApiMetaRepository({ApiClient? apiClient})
    : _apiClient = apiClient ?? ApiClient();

  @override
  Future<MetaStatus> getStatus() async {
    try {
      final response = await _apiClient.dio.get<dynamic>('/meta/status');
      final map = response.data is Map
          ? Map<String, dynamic>.from(response.data as Map)
          : <String, dynamic>{};
      final channelsRaw = map['channels'];
      final channels = channelsRaw is List
          ? channelsRaw.map((e) => e.toString()).toList()
          : const <String>[];
      final accountsRaw = map['accounts'];
      final accounts = accountsRaw is List
          ? accountsRaw.whereType<Map>().map((item) {
              final account = Map<String, dynamic>.from(item);
              return MetaAccount(
                channel: (account['channel'] ?? '').toString(),
                name: account['name']?.toString(),
                error: account['error']?.toString(),
              );
            }).toList()
          : const <MetaAccount>[];
      return MetaStatus(
        connected: map['connected'] == true,
        channels: channels,
        accounts: accounts,
        note: map['note']?.toString(),
      );
    } catch (e) {
      throw Exception(userFacingError(e, fallback: ErrorKeys.loadFailed));
    }
  }

  @override
  Future<List<MetaThread>> getThreads({String? channel}) async {
    try {
      final response = await _apiClient.dio.get<dynamic>(
        '/meta/threads',
        queryParameters: {
          if (channel != null && channel.isNotEmpty) 'channel': channel,
        },
      );
      final list = response.data is List
          ? response.data as List
          : const <dynamic>[];
      return list.map(_threadFromJson).whereType<MetaThread>().toList();
    } catch (e) {
      throw Exception(userFacingError(e, fallback: ErrorKeys.loadFailed));
    }
  }

  @override
  Future<List<MetaMessage>> getMessages(int threadId) async {
    try {
      final response = await _apiClient.dio.get<dynamic>(
        '/meta/threads/$threadId/messages',
      );
      final list = response.data is List
          ? response.data as List
          : const <dynamic>[];
      return list.map(_messageFromJson).whereType<MetaMessage>().toList();
    } catch (e) {
      throw Exception(userFacingError(e, fallback: ErrorKeys.loadFailed));
    }
  }

  @override
  Future<MetaMessage> reply(int threadId, String text) async {
    try {
      final response = await _apiClient.dio.post<dynamic>(
        '/meta/threads/$threadId/reply',
        data: {'text': text.trim()},
      );
      final msg = _messageFromJson(response.data);
      if (msg == null) throw Exception(ErrorKeys.invalidResponse);
      return msg;
    } catch (e) {
      throw Exception(userFacingError(e, fallback: ErrorKeys.saveFailed));
    }
  }

  @override
  Future<String> suggestReply(int threadId) async {
    try {
      final response = await _apiClient.dio.post<dynamic>(
        '/meta/threads/$threadId/suggest',
        options: ApiClient.longRunningOptions(),
      );
      final body = response.data is Map ? response.data as Map : null;
      final suggestion = body?['suggestion'];
      if (suggestion is! String || suggestion.trim().isEmpty) {
        throw Exception(ErrorKeys.invalidResponse);
      }
      return suggestion.trim();
    } catch (e) {
      throw Exception(userFacingError(e, fallback: ErrorKeys.generic));
    }
  }

  @override
  Future<void> deleteThread(int threadId) async {
    try {
      await _apiClient.dio.delete<dynamic>('/meta/threads/$threadId');
    } catch (e) {
      throw Exception(userFacingError(e, fallback: ErrorKeys.saveFailed));
    }
  }

  @override
  Future<MetaThread> linkClient(int threadId, int clientId) async {
    try {
      final response = await _apiClient.dio.post<dynamic>(
        '/meta/threads/$threadId/link',
        data: {'client_id': clientId},
      );
      final thread = _threadFromJson(response.data);
      if (thread == null) throw Exception(ErrorKeys.invalidResponse);
      return thread;
    } catch (e) {
      throw Exception(userFacingError(e, fallback: ErrorKeys.saveFailed));
    }
  }

  MetaThread? _threadFromJson(dynamic raw) {
    if (raw is! Map) return null;
    final map = Map<String, dynamic>.from(raw);
    final idRaw = map['id'];
    final id = switch (idRaw) {
      int v => v,
      num v => v.toInt(),
      String v => int.tryParse(v),
      _ => null,
    };
    if (id == null) return null;
    final lastAtRaw = map['last_message_at'] ?? map['lastMessageAt'];
    final clientIdRaw = map['client_id'] ?? map['clientId'];
    final clientId = switch (clientIdRaw) {
      int v => v,
      num v => v.toInt(),
      String v => int.tryParse(v),
      _ => null,
    };
    final unreadRaw = map['unread'];
    final unread = switch (unreadRaw) {
      int v => v,
      num v => v.toInt(),
      String v => int.tryParse(v) ?? 0,
      _ => 0,
    };
    return MetaThread(
      id: id,
      channel: (map['channel'] ?? '').toString(),
      peerId: (map['peer_id'] ?? map['peerId'] ?? '').toString(),
      peerName: map['peer_name']?.toString() ?? map['peerName']?.toString(),
      peerPhone: map['peer_phone']?.toString() ?? map['peerPhone']?.toString(),
      clientId: clientId,
      clientName:
          map['client_name']?.toString() ?? map['clientName']?.toString(),
      lastText: map['last_text']?.toString() ?? map['lastText']?.toString(),
      lastMessageAt: lastAtRaw is String ? DateTime.tryParse(lastAtRaw) : null,
      unread: unread,
    );
  }

  MetaMessage? _messageFromJson(dynamic raw) {
    if (raw is! Map) return null;
    final map = Map<String, dynamic>.from(raw);
    final idRaw = map['id'];
    final id = switch (idRaw) {
      int v => v,
      num v => v.toInt(),
      String v => int.tryParse(v) ?? 0,
      _ => 0,
    };
    final createdRaw = map['created_at'] ?? map['createdAt'];
    return MetaMessage(
      id: id,
      outgoing: map['outgoing'] == true,
      text: (map['text'] ?? '').toString(),
      createdAt: createdRaw is String
          ? (DateTime.tryParse(createdRaw) ?? DateTime.now())
          : DateTime.now(),
    );
  }
}
