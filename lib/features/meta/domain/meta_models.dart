class MetaStatus {
  final bool connected;
  final List<String> channels;
  final String? note;

  const MetaStatus({
    required this.connected,
    this.channels = const [],
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

class MetaMessage {
  final int id;
  final bool outgoing;
  final String text;
  final DateTime createdAt;

  const MetaMessage({
    required this.id,
    required this.outgoing,
    required this.text,
    required this.createdAt,
  });
}
