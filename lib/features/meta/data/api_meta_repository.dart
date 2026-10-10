import 'package:dio/dio.dart';

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
        place: MetaPlace.fromJson(map['place']),
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
      return list.map(metaThreadFromJson).whereType<MetaThread>().toList();
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
      return list.map(metaMessageFromJson).whereType<MetaMessage>().toList();
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
      final msg = metaMessageFromJson(response.data);
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
  Future<MetaMessage> sendAttachment(
    int threadId, {
    required String filename,
    required List<int> bytes,
    String caption = '',
  }) async {
    try {
      final form = FormData.fromMap({
        'file': MultipartFile.fromBytes(bytes, filename: filename),
        'caption': caption.trim(),
      });
      final response = await _apiClient.dio.post<dynamic>(
        '/meta/threads/$threadId/attachments',
        data: form,
        // The file goes to PAYK first, then to Meta: minutes on a weak network.
        options: ApiClient.longRunningOptions(
          receiveTimeout: const Duration(seconds: 180),
        ).copyWith(sendTimeout: const Duration(seconds: 180)),
      );
      final msg = metaMessageFromJson(response.data);
      if (msg == null) throw Exception(ErrorKeys.invalidResponse);
      return msg;
    } catch (e) {
      throw Exception(userFacingError(e, fallback: ErrorKeys.saveFailed));
    }
  }

  @override
  Future<void> sendTyping(int threadId, {required bool on}) async {
    try {
      await _apiClient.dio.post<dynamic>(
        '/meta/threads/$threadId/typing',
        data: {'on': on},
      );
    } catch (e) {
      throw Exception(userFacingError(e, fallback: ErrorKeys.generic));
    }
  }

  @override
  Future<int> getUnreadTotal() async {
    try {
      final response = await _apiClient.dio.get<dynamic>('/meta/unread');
      final total = response.data is Map ? response.data['total'] : null;
      if (total is! num) throw Exception(ErrorKeys.invalidResponse);
      return total.toInt();
    } catch (e) {
      throw Exception(userFacingError(e, fallback: ErrorKeys.loadFailed));
    }
  }

  @override
  Future<MetaMessage> sendLocation(int threadId, MetaPlace place) async {
    try {
      final response = await _apiClient.dio.post<dynamic>(
        '/meta/threads/$threadId/location',
        data: {
          'lat': place.lat,
          'lng': place.lng,
          if (place.label != null) 'label': place.label,
        },
      );
      final msg = metaMessageFromJson(response.data);
      if (msg == null) throw Exception(ErrorKeys.invalidResponse);
      return msg;
    } catch (e) {
      throw Exception(userFacingError(e, fallback: ErrorKeys.saveFailed));
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
      final thread = metaThreadFromJson(response.data);
      if (thread == null) throw Exception(ErrorKeys.invalidResponse);
      return thread;
    } catch (e) {
      throw Exception(userFacingError(e, fallback: ErrorKeys.saveFailed));
    }
  }
}

/// REST and WebSocket share this dialog shape (`services/chat_events.py`).
MetaThread? metaThreadFromJson(dynamic raw) {
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
    clientName: map['client_name']?.toString() ?? map['clientName']?.toString(),
    lastText: map['last_text']?.toString() ?? map['lastText']?.toString(),
    lastMessageAt: lastAtRaw is String ? DateTime.tryParse(lastAtRaw) : null,
    unread: unread,
    peerReadAt: _dateOrNull(map['peer_read_at']),
  );
}

/// REST and WebSocket share this message shape (`services/chat_events.py`).
MetaMessage? metaMessageFromJson(dynamic raw) {
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
  final attachmentsRaw = map['attachments'];
  final attachments = attachmentsRaw is List
      ? attachmentsRaw
            .whereType<Map>()
            .map(
              (item) =>
                  MetaAttachment.fromJson(Map<String, dynamic>.from(item)),
            )
            .toList(growable: false)
      : const <MetaAttachment>[];
  return MetaMessage(
    id: id,
    outgoing: map['outgoing'] == true,
    text: (map['text'] ?? '').toString(),
    createdAt: createdRaw is String
        ? (DateTime.tryParse(createdRaw) ?? DateTime.now())
        : DateTime.now(),
    attachments: attachments,
    read: map['read'] == true,
  );
}

DateTime? _dateOrNull(Object? raw) =>
    raw is String && raw.isNotEmpty ? DateTime.tryParse(raw) : null;
