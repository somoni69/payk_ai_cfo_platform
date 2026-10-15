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

  @override
  Future<List<MetaStage>> getStages() async {
    try {
      final response = await _apiClient.dio.get<dynamic>('/meta/stages');
      final raw = response.data;
      if (raw is! List) return const [];
      return [
        for (final item in raw.whereType<Map>())
          MetaStage.fromJson(Map<String, dynamic>.from(item)),
      ];
    } catch (e) {
      throw Exception(userFacingError(e, fallback: ErrorKeys.loadFailed));
    }
  }

  @override
  Future<List<MetaStaff>> getStaff() async {
    try {
      final response = await _apiClient.dio.get<dynamic>('/users/lookup');
      final raw = response.data;
      if (raw is! List) return const [];
      return [
        for (final item in raw.whereType<Map>())
          MetaStaff.fromJson(Map<String, dynamic>.from(item)),
      ];
    } catch (e) {
      throw Exception(userFacingError(e, fallback: ErrorKeys.loadFailed));
    }
  }

  @override
  Future<MetaThread> setThreadStage(int threadId, int stageId) async {
    try {
      final response = await _apiClient.dio.patch<dynamic>(
        '/meta/threads/$threadId/stage',
        data: {'stage_id': stageId},
      );
      final thread = metaThreadFromJson(response.data);
      if (thread == null) throw Exception(ErrorKeys.invalidResponse);
      return thread;
    } catch (e) {
      throw Exception(userFacingError(e, fallback: ErrorKeys.saveFailed));
    }
  }

  @override
  Future<MetaThread> setThreadAssignee(int threadId, int? userId) async {
    try {
      final response = await _apiClient.dio.patch<dynamic>(
        '/meta/threads/$threadId/assignee',
        data: {'user_id': userId},
      );
      final thread = metaThreadFromJson(response.data);
      if (thread == null) throw Exception(ErrorKeys.invalidResponse);
      return thread;
    } catch (e) {
      throw Exception(userFacingError(e, fallback: ErrorKeys.saveFailed));
    }
  }

  @override
  Future<List<MetaComment>> getComments({bool onlyNew = false}) async {
    try {
      final response = await _apiClient.dio.get<dynamic>(
        '/meta/comments',
        queryParameters: onlyNew ? {'only_new': true} : null,
      );
      final raw = response.data;
      if (raw is! List) return const [];
      return [
        for (final item in raw.whereType<Map>())
          MetaComment.fromJson(Map<String, dynamic>.from(item)),
      ];
    } catch (e) {
      throw Exception(userFacingError(e, fallback: ErrorKeys.loadFailed));
    }
  }

  @override
  Future<MetaComment> replyComment(int id, String text) async {
    try {
      final response = await _apiClient.dio.post<dynamic>(
        '/meta/comments/$id/reply',
        data: {'text': text},
      );
      if (response.data is! Map) throw Exception(ErrorKeys.invalidResponse);
      return MetaComment.fromJson(
        Map<String, dynamic>.from(response.data as Map),
      );
    } catch (e) {
      throw Exception(userFacingError(e, fallback: ErrorKeys.saveFailed));
    }
  }

  @override
  Future<({int threadId, MetaComment comment})> dmComment(
    int id,
    String text,
  ) async {
    try {
      final response = await _apiClient.dio.post<dynamic>(
        '/meta/comments/$id/dm',
        data: {'text': text},
      );
      final map = response.data is Map
          ? Map<String, dynamic>.from(response.data as Map)
          : <String, dynamic>{};
      final commentRaw = map['comment'];
      if (commentRaw is! Map) throw Exception(ErrorKeys.invalidResponse);
      return (
        threadId: _jsonInt(map['thread_id']) ?? 0,
        comment: MetaComment.fromJson(Map<String, dynamic>.from(commentRaw)),
      );
    } catch (e) {
      throw Exception(userFacingError(e, fallback: ErrorKeys.saveFailed));
    }
  }

  @override
  Future<void> markCommentsSeen() async {
    try {
      await _apiClient.dio.post<dynamic>('/meta/comments/seen');
    } catch (e) {
      throw Exception(userFacingError(e, fallback: ErrorKeys.saveFailed));
    }
  }

  @override
  Future<CommentSettings> getCommentSettings() async {
    try {
      final response = await _apiClient.dio.get<dynamic>(
        '/meta/comments/settings',
      );
      if (response.data is! Map) throw Exception(ErrorKeys.invalidResponse);
      return CommentSettings.fromJson(
        Map<String, dynamic>.from(response.data as Map),
      );
    } catch (e) {
      throw Exception(userFacingError(e, fallback: ErrorKeys.loadFailed));
    }
  }

  @override
  Future<CommentSettings> setCommentAi(bool enabled) async {
    try {
      final response = await _apiClient.dio.put<dynamic>(
        '/meta/comments/settings',
        data: {'ai_enabled': enabled},
      );
      if (response.data is! Map) throw Exception(ErrorKeys.invalidResponse);
      return CommentSettings.fromJson(
        Map<String, dynamic>.from(response.data as Map),
      );
    } catch (e) {
      throw Exception(userFacingError(e, fallback: ErrorKeys.saveFailed));
    }
  }

  @override
  Future<MetaAnalytics> getAnalytics({
    required DateTime since,
    required DateTime until,
    String? channel,
    String? assignee,
  }) async {
    try {
      final response = await _apiClient.dio.get<dynamic>(
        '/meta/analytics',
        queryParameters: {
          'since': since.toUtc().toIso8601String(),
          'until': until.toUtc().toIso8601String(),
          if (channel != null && channel.isNotEmpty) 'channel': channel,
          if (assignee != null && assignee.isNotEmpty) 'assignee': assignee,
        },
      );
      if (response.data is! Map) throw Exception(ErrorKeys.invalidResponse);
      return MetaAnalytics.fromJson(
        Map<String, dynamic>.from(response.data as Map),
      );
    } catch (e) {
      throw Exception(userFacingError(e, fallback: ErrorKeys.loadFailed));
    }
  }

  @override
  Future<ThreadCard> getThreadCard(int threadId) async {
    try {
      final response = await _apiClient.dio.get<dynamic>(
        '/meta/threads/$threadId/card',
      );
      if (response.data is! Map) throw Exception(ErrorKeys.invalidResponse);
      return ThreadCard.fromJson(
        Map<String, dynamic>.from(response.data as Map),
      );
    } catch (e) {
      throw Exception(userFacingError(e, fallback: ErrorKeys.loadFailed));
    }
  }

  @override
  Future<List<CardHistoryEntry>> getThreadHistory(int threadId) async {
    try {
      final response = await _apiClient.dio.get<dynamic>(
        '/meta/threads/$threadId/history',
      );
      final raw = response.data;
      if (raw is! List) return const [];
      return [
        for (final item in raw.whereType<Map>())
          CardHistoryEntry.fromJson(Map<String, dynamic>.from(item)),
      ];
    } catch (e) {
      throw Exception(userFacingError(e, fallback: ErrorKeys.loadFailed));
    }
  }

  @override
  Future<ThreadCard> updateCardClient(
    int threadId,
    CardClientInput input,
  ) async {
    try {
      final response = await _apiClient.dio.put<dynamic>(
        '/meta/threads/$threadId/client',
        data: input.toJson(),
      );
      if (response.data is! Map) throw Exception(ErrorKeys.invalidResponse);
      return ThreadCard.fromJson(
        Map<String, dynamic>.from(response.data as Map),
      );
    } catch (e) {
      throw Exception(userFacingError(e, fallback: ErrorKeys.saveFailed));
    }
  }

  @override
  Future<ThreadCard> createCardDeal(
    int threadId, {
    required String title,
    required String amount,
    required String stage,
  }) async {
    try {
      final response = await _apiClient.dio.post<dynamic>(
        '/meta/threads/$threadId/deals',
        data: {'title': title, 'amount': amount, 'stage': stage},
      );
      if (response.data is! Map) throw Exception(ErrorKeys.invalidResponse);
      return ThreadCard.fromJson(
        Map<String, dynamic>.from(response.data as Map),
      );
    } catch (e) {
      throw Exception(userFacingError(e, fallback: ErrorKeys.saveFailed));
    }
  }

  @override
  Future<ThreadCard> updateCardDeal(
    int threadId,
    int dealId,
    String stage,
  ) async {
    try {
      final response = await _apiClient.dio.patch<dynamic>(
        '/meta/threads/$threadId/deals/$dealId',
        data: {'stage': stage},
      );
      if (response.data is! Map) throw Exception(ErrorKeys.invalidResponse);
      return ThreadCard.fromJson(
        Map<String, dynamic>.from(response.data as Map),
      );
    } catch (e) {
      throw Exception(userFacingError(e, fallback: ErrorKeys.saveFailed));
    }
  }

  @override
  Future<ThreadCard> rejectThread(int threadId, String? reason) async {
    try {
      final response = await _apiClient.dio.post<dynamic>(
        '/meta/threads/$threadId/reject',
        data: {'reason': reason},
      );
      if (response.data is! Map) throw Exception(ErrorKeys.invalidResponse);
      return ThreadCard.fromJson(
        Map<String, dynamic>.from(response.data as Map),
      );
    } catch (e) {
      throw Exception(userFacingError(e, fallback: ErrorKeys.saveFailed));
    }
  }

  @override
  Future<List<ThreadTask>> getThreadTasks(int threadId) async {
    try {
      final response = await _apiClient.dio.get<dynamic>(
        '/meta/threads/$threadId/tasks',
      );
      final raw = response.data;
      if (raw is! List) return const [];
      return [
        for (final item in raw.whereType<Map>())
          ThreadTask.fromJson(Map<String, dynamic>.from(item)),
      ];
    } catch (e) {
      throw Exception(userFacingError(e, fallback: ErrorKeys.loadFailed));
    }
  }

  @override
  Future<ThreadTask> createThreadTask(
    int threadId, {
    required String title,
    String? dueDate,
    int? assigneeId,
  }) async {
    try {
      final response = await _apiClient.dio.post<dynamic>(
        '/meta/threads/$threadId/tasks',
        data: {'title': title, 'due_date': dueDate, 'assignee_id': assigneeId},
      );
      if (response.data is! Map) throw Exception(ErrorKeys.invalidResponse);
      return ThreadTask.fromJson(
        Map<String, dynamic>.from(response.data as Map),
      );
    } catch (e) {
      throw Exception(userFacingError(e, fallback: ErrorKeys.saveFailed));
    }
  }

  @override
  Future<ThreadTask> finishThreadTask(int threadId, int taskId) async {
    try {
      final response = await _apiClient.dio.post<dynamic>(
        '/meta/threads/$threadId/tasks/$taskId/done',
      );
      if (response.data is! Map) throw Exception(ErrorKeys.invalidResponse);
      return ThreadTask.fromJson(
        Map<String, dynamic>.from(response.data as Map),
      );
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
    stageId: _jsonInt(map['stage_id']),
    assigneeId: _jsonInt(map['assignee_id']),
    tasksOpen: _jsonInt(map['tasks_open']) ?? 0,
    createdAt: _dateOrNull(map['created_at']),
  );
}

int? _jsonInt(Object? raw) => switch (raw) {
  int v => v,
  num v => v.toInt(),
  String v => int.tryParse(v),
  _ => null,
};

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
