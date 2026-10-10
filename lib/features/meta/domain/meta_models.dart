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
  });

  MetaThread copyWith({DateTime? peerReadAt}) => MetaThread(
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
  );

  String get displayName => (peerName != null && peerName!.trim().isNotEmpty)
      ? peerName!.trim()
      : (clientName != null && clientName!.trim().isNotEmpty)
      ? clientName!.trim()
      : peerId;
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
