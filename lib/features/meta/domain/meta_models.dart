class MetaAccount {
  final String channel;
  final String? name;
  final String? error;

  const MetaAccount({required this.channel, this.name, this.error});
}

class MetaStatus {
  final bool connected;
  final List<String> channels;
  final List<MetaAccount> accounts;
  final String? note;

  /// «Наш адрес» магазина (`place` в `/meta/status`), если он сохранён.
  final MetaPlace? place;

  const MetaStatus({
    required this.connected,
    this.channels = const [],
    this.accounts = const [],
    this.note,
    this.place,
  });
}

/// Точка, которую сотрудник отправляет клиенту одной кнопкой.
class MetaPlace {
  final double lat;
  final double lng;
  final String? label;

  const MetaPlace({required this.lat, required this.lng, this.label});

  static MetaPlace? fromJson(dynamic raw) {
    if (raw is! Map) return null;
    final lat = raw['lat'];
    final lng = raw['lng'];
    if (lat is! num || lng is! num) return null;
    final label = raw['label']?.toString().trim();
    return MetaPlace(
      lat: lat.toDouble(),
      lng: lng.toDouble(),
      label: label == null || label.isEmpty ? null : label,
    );
  }
}

class MetaThread {
  final int id;
  final String channel;
  final String peerId;
  final String? peerName;
  final String? peerPhone;
  final int? clientId;
  final String? clientName;
  final String? lastText;
  final DateTime? lastMessageAt;
  final int unread;

  /// When the peer last read our messages (`peer_read_at`), if the channel tells.
  final DateTime? peerReadAt;

  /// Funnel column. Null on servers that do not send it yet.
  final int? stageId;

  /// Staff member responsible for the dialog.
  final int? assigneeId;

  const MetaThread({
    required this.id,
    required this.channel,
    required this.peerId,
    this.peerName,
    this.peerPhone,
    this.clientId,
    this.clientName,
    this.lastText,
    this.lastMessageAt,
    this.unread = 0,
    this.peerReadAt,
    this.stageId,
    this.assigneeId,
  });

  MetaThread copyWith({
    DateTime? peerReadAt,
    int? stageId,
    int? assigneeId,
    bool clearAssignee = false,
  }) => MetaThread(
    id: id,
    channel: channel,
    peerId: peerId,
    peerName: peerName,
    peerPhone: peerPhone,
    clientId: clientId,
    clientName: clientName,
    lastText: lastText,
    lastMessageAt: lastMessageAt,
    unread: unread,
    peerReadAt: peerReadAt ?? this.peerReadAt,
    stageId: stageId ?? this.stageId,
    assigneeId: clearAssignee ? null : (assigneeId ?? this.assigneeId),
  );

  /// CRM name, then the name from the channel, then the phone.
  String get namedTitle {
    for (final raw in [clientName, peerName, peerPhone]) {
      final value = raw?.trim() ?? '';
      if (value.isNotEmpty) return value;
    }
    return '';
  }

  String titleOr(String fallback) {
    final name = namedTitle;
    return name.isEmpty ? fallback : name;
  }

  String get displayName => titleOr(peerId);
}

class MetaAttachment {
  final String kind;
  final String status;
  final String? path;
  final String? name;
  final String? mime;
  final int? size;
  final String? caption;
  final double? lat;
  final double? lng;
  final String? label;
  final String? error;

  /// Instagram context: `story_reply`, `story_mention`, `story`, `share`, `reel`.
  final String? note;

  /// Link target for `kind == 'link'` (shared posts, stories).
  final String? url;

  /// Machine reason for `status == 'failed'`; `expired` means a gone story.
  final String? errorCode;

  const MetaAttachment({
    required this.kind,
    this.status = 'ok',
    this.path,
    this.name,
    this.mime,
    this.size,
    this.caption,
    this.lat,
    this.lng,
    this.label,
    this.error,
    this.note,
    this.url,
    this.errorCode,
  });

  factory MetaAttachment.fromJson(Map<String, dynamic> json) {
    double? number(Object? raw) => switch (raw) {
      num value => value.toDouble(),
      String value => double.tryParse(value),
      _ => null,
    };
    final sizeRaw = json['size'];
    return MetaAttachment(
      kind: (json['kind'] ?? 'file').toString(),
      status: (json['status'] ?? 'ok').toString(),
      path: json['path']?.toString(),
      name: json['name']?.toString(),
      mime: json['mime']?.toString(),
      size: switch (sizeRaw) {
        int value => value,
        num value => value.toInt(),
        String value => int.tryParse(value),
        _ => null,
      },
      caption: json['caption']?.toString(),
      lat: number(json['lat']),
      lng: number(json['lng']),
      label: json['label']?.toString(),
      error: json['error']?.toString(),
      note: json['note']?.toString(),
      url: json['url']?.toString(),
      errorCode: json['error_code']?.toString(),
    );
  }
}

class MetaStage {
  final int id;
  final String name;
  final String color;
  final int position;

  const MetaStage({
    required this.id,
    required this.name,
    this.color = '#362CD1',
    this.position = 0,
  });

  factory MetaStage.fromJson(Map<String, dynamic> json) {
    return MetaStage(
      id: _metaInt(json['id']) ?? 0,
      name: (json['name'] ?? '').toString(),
      color: (json['color'] ?? '#362CD1').toString(),
      position: _metaInt(json['position']) ?? 0,
    );
  }
}

class MetaStaff {
  final int id;
  final String fullName;
  final String role;

  const MetaStaff({required this.id, required this.fullName, this.role = ''});

  factory MetaStaff.fromJson(Map<String, dynamic> json) {
    return MetaStaff(
      id: _metaInt(json['id']) ?? 0,
      fullName: (json['full_name'] ?? json['fullName'] ?? '').toString(),
      role: (json['role'] ?? '').toString(),
    );
  }
}

class MetaComment {
  final int id;
  final String text;
  final String? authorUsername;
  final String? mediaType;
  final String? mediaPermalink;
  final String? mediaCaption;
  final String? mediaThumb;
  final DateTime createdAt;
  final DateTime? seenAt;
  final DateTime? repliedAt;
  final String? replyText;
  final int? replyBy;
  final String? aiStatus;
  final int? dmThreadId;
  final bool dmAllowed;

  const MetaComment({
    required this.id,
    required this.text,
    required this.createdAt,
    this.authorUsername,
    this.mediaType,
    this.mediaPermalink,
    this.mediaCaption,
    this.mediaThumb,
    this.seenAt,
    this.repliedAt,
    this.replyText,
    this.replyBy,
    this.aiStatus,
    this.dmThreadId,
    this.dmAllowed = false,
  });

  bool get unanswered => repliedAt == null;

  factory MetaComment.fromJson(Map<String, dynamic> json) {
    return MetaComment(
      id: _metaInt(json['id']) ?? 0,
      text: (json['text'] ?? '').toString(),
      authorUsername: json['author_username']?.toString(),
      mediaType: json['media_type']?.toString(),
      mediaPermalink: json['media_permalink']?.toString(),
      mediaCaption: json['media_caption']?.toString(),
      mediaThumb: json['media_thumb']?.toString(),
      createdAt:
          DateTime.tryParse('${json['created_at']}') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      seenAt: DateTime.tryParse('${json['seen_at']}'),
      repliedAt: DateTime.tryParse('${json['replied_at']}'),
      replyText: json['reply_text']?.toString(),
      replyBy: _metaInt(json['reply_by']),
      aiStatus: json['ai_status']?.toString(),
      dmThreadId: _metaInt(json['dm_thread_id']),
      dmAllowed: json['dm_allowed'] == true,
    );
  }
}

class CommentSettings {
  final bool aiEnabled;
  final bool aiAvailable;
  final bool connected;

  const CommentSettings({
    required this.aiEnabled,
    required this.aiAvailable,
    required this.connected,
  });

  factory CommentSettings.fromJson(Map<String, dynamic> json) {
    return CommentSettings(
      aiEnabled: json['ai_enabled'] == true,
      aiAvailable: json['ai_available'] == true,
      connected: json['connected'] == true,
    );
  }
}

int? _metaInt(Object? raw) => switch (raw) {
  int v => v,
  num v => v.toInt(),
  String v => int.tryParse(v),
  _ => null,
};

/// Строки вида «[Фото]» дублируют вложение, когда оно уже показано.
String metaTextWithoutLabels(String text, List<MetaAttachment> attachments) {
  if (attachments.isEmpty) return text;
  final label = RegExp(r'^\[[^\]]+\]( .*)?$');
  // The card already shows the place name or caption; do not repeat it.
  final shown = {
    for (final a in attachments) ...[
      if (a.label case final l? when l.trim().isNotEmpty) l.trim(),
      if (a.caption case final c? when c.trim().isNotEmpty) c.trim(),
    ],
  };
  return text
      .split('\n')
      .where((line) => !label.hasMatch(line.trim()))
      .where((line) => !shown.contains(line.trim()))
      .join('\n')
      .trim();
}

class MetaMessage {
  final int id;
  final bool outgoing;
  final String text;
  final DateTime createdAt;
  final List<MetaAttachment> attachments;

  /// Server-side «прочитано» for our outgoing message.
  final bool read;

  const MetaMessage({
    required this.id,
    required this.outgoing,
    required this.text,
    required this.createdAt,
    this.attachments = const [],
    this.read = false,
  });

  /// Our message is read: flagged by the server or sent before [peerReadAt].
  bool isReadBy(DateTime? peerReadAt) {
    if (!outgoing) return false;
    if (read) return true;
    return peerReadAt != null && !createdAt.isAfter(peerReadAt);
  }
}
