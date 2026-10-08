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

  const MetaStatus({
    required this.connected,
    this.channels = const [],
    this.accounts = const [],
    this.note,
  });
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
  });

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
    );
  }
}

/// Строки вида «[Фото]» дублируют вложение, когда оно уже показано.
String metaTextWithoutLabels(String text, List<MetaAttachment> attachments) {
  if (attachments.isEmpty) return text;
  final label = RegExp(r'^\[[^\]]+\]( .*)?$');
  return text
      .split('\n')
      .where((line) => !label.hasMatch(line.trim()))
      .join('\n')
      .trim();
}

class MetaMessage {
  final int id;
  final bool outgoing;
  final String text;
  final DateTime createdAt;
  final List<MetaAttachment> attachments;

  const MetaMessage({
    required this.id,
    required this.outgoing,
    required this.text,
    required this.createdAt,
    this.attachments = const [],
  });
}
