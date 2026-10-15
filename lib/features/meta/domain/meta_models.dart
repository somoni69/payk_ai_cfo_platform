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

  /// Open reminder tasks on this dialog («Событие N» on the funnel card).
  final int tasksOpen;

  /// When the client first wrote.
  final DateTime? createdAt;

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
    this.tasksOpen = 0,
    this.createdAt,
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
    tasksOpen: tasksOpen,
    createdAt: createdAt,
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

  /// `normal`, `won` («Купил») or `lost` («Отказ»).
  final String kind;

  const MetaStage({
    required this.id,
    required this.name,
    this.color = '#362CD1',
    this.position = 0,
    this.kind = 'normal',
  });

  factory MetaStage.fromJson(Map<String, dynamic> json) {
    return MetaStage(
      id: _metaInt(json['id']) ?? 0,
      name: (json['name'] ?? '').toString(),
      color: (json['color'] ?? '#362CD1').toString(),
      position: _metaInt(json['position']) ?? 0,
      kind: (json['kind'] ?? 'normal').toString(),
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

/// Reminder task attached to a dialog (`GET /meta/threads/{id}/tasks`).
class ThreadTask {
  final int id;
  final String title;
  final String status;
  final String? dueDate;
  final int? assigneeId;
  final String? assigneeName;
  final DateTime? createdAt;
  final int? threadTasksOpen;

  const ThreadTask({
    required this.id,
    required this.title,
    this.status = 'todo',
    this.dueDate,
    this.assigneeId,
    this.assigneeName,
    this.createdAt,
    this.threadTasksOpen,
  });

  factory ThreadTask.fromJson(Map<String, dynamic> json) {
    return ThreadTask(
      id: _metaInt(json['id']) ?? 0,
      title: (json['title'] ?? '').toString(),
      status: (json['status'] ?? 'todo').toString(),
      dueDate: json['due_date']?.toString(),
      assigneeId: _metaInt(json['assignee_id']),
      assigneeName: json['assignee_name']?.toString(),
      createdAt: _metaDate(json['created_at']),
      threadTasksOpen: _metaInt(json['thread_tasks_open']),
    );
  }
}

class CardContact {
  final String name;
  final String? phone;
  final String? note;

  const CardContact({required this.name, this.phone, this.note});

  factory CardContact.fromJson(Map<String, dynamic> json) {
    return CardContact(
      name: (json['name'] ?? '').toString(),
      phone: json['phone']?.toString(),
      note: json['note']?.toString(),
    );
  }

  Map<String, dynamic> toJson() => {'name': name, 'phone': phone, 'note': note};
}

class CardClient {
  final int id;
  final String fullName;
  final String? phone;
  final String? email;
  final String? birthDate;
  final String? region;
  final List<CardContact> contacts;
  final String? note;
  final DateTime? createdAt;

  const CardClient({
    required this.id,
    required this.fullName,
    this.phone,
    this.email,
    this.birthDate,
    this.region,
    this.contacts = const [],
    this.note,
    this.createdAt,
  });

  factory CardClient.fromJson(Map<String, dynamic> json) {
    final rawContacts = json['contacts'];
    return CardClient(
      id: _metaInt(json['id']) ?? 0,
      fullName: (json['full_name'] ?? '').toString(),
      phone: json['phone']?.toString(),
      email: json['email']?.toString(),
      birthDate: json['birth_date']?.toString(),
      region: json['region']?.toString(),
      contacts: rawContacts is List
          ? [
              for (final item in rawContacts.whereType<Map>())
                CardContact.fromJson(Map<String, dynamic>.from(item)),
            ]
          : const [],
      note: json['note']?.toString(),
      createdAt: _metaDate(json['created_at']),
    );
  }
}

class CardClientInput {
  final String? fullName;
  final String? phone;
  final String? region;
  final String? birthDate;
  final List<CardContact> contacts;

  const CardClientInput({
    this.fullName,
    this.phone,
    this.region,
    this.birthDate,
    this.contacts = const [],
  });

  Map<String, dynamic> toJson() => {
    'full_name': fullName,
    'phone': phone,
    'region': region,
    'birth_date': birthDate,
    'contacts': [for (final contact in contacts) contact.toJson()],
  };
}

class CardDeal {
  final int id;
  final String title;
  final double amount;
  final String stage;
  final DateTime? createdAt;

  const CardDeal({
    required this.id,
    required this.title,
    this.amount = 0,
    this.stage = 'lead',
    this.createdAt,
  });

  factory CardDeal.fromJson(Map<String, dynamic> json) {
    return CardDeal(
      id: _metaInt(json['id']) ?? 0,
      title: (json['title'] ?? '').toString(),
      amount: _metaDouble(json['amount']),
      stage: (json['stage'] ?? 'lead').toString(),
      createdAt: _metaDate(json['created_at']),
    );
  }
}

class CardFile {
  final int messageId;
  final int threadId;
  final bool outgoing;
  final String text;
  final DateTime? createdAt;
  final List<MetaAttachment> attachments;

  const CardFile({
    required this.messageId,
    required this.threadId,
    required this.outgoing,
    required this.text,
    this.createdAt,
    this.attachments = const [],
  });

  factory CardFile.fromJson(Map<String, dynamic> json) {
    final raw = json['attachments'];
    return CardFile(
      messageId: _metaInt(json['message_id']) ?? 0,
      threadId: _metaInt(json['thread_id']) ?? 0,
      outgoing: json['outgoing'] == true,
      text: (json['text'] ?? '').toString(),
      createdAt: _metaDate(json['created_at']),
      attachments: raw is List
          ? [
              for (final item in raw.whereType<Map>())
                MetaAttachment.fromJson(Map<String, dynamic>.from(item)),
            ]
          : const [],
    );
  }
}

class ThreadCard {
  final int threadId;
  final DateTime? createdAt;
  final CardClient? client;
  final List<int> threadIds;
  final List<CardDeal> deals;
  final List<CardFile> files;
  final int filesCount;
  final String? lostReason;

  const ThreadCard({
    required this.threadId,
    this.createdAt,
    this.client,
    this.threadIds = const [],
    this.deals = const [],
    this.files = const [],
    this.filesCount = 0,
    this.lostReason,
  });

  factory ThreadCard.fromJson(Map<String, dynamic> json) {
    final clientRaw = json['client'];
    final idsRaw = json['thread_ids'];
    final dealsRaw = json['deals'];
    final filesRaw = json['files'];
    return ThreadCard(
      threadId: _metaInt(json['thread_id']) ?? 0,
      createdAt: _metaDate(json['created_at']),
      client: clientRaw is Map
          ? CardClient.fromJson(Map<String, dynamic>.from(clientRaw))
          : null,
      threadIds: idsRaw is List
          ? [for (final id in idsRaw) _metaInt(id) ?? 0]
          : const [],
      deals: dealsRaw is List
          ? [
              for (final item in dealsRaw.whereType<Map>())
                CardDeal.fromJson(Map<String, dynamic>.from(item)),
            ]
          : const [],
      files: filesRaw is List
          ? [
              for (final item in filesRaw.whereType<Map>())
                CardFile.fromJson(Map<String, dynamic>.from(item)),
            ]
          : const [],
      filesCount: _metaInt(json['files_count']) ?? 0,
      lostReason: json['lost_reason']?.toString(),
    );
  }
}

class CardHistoryEntry {
  final int id;
  final DateTime? at;
  final String? user;
  final String action;
  final Map<String, dynamic> changes;

  const CardHistoryEntry({
    required this.id,
    required this.action,
    this.at,
    this.user,
    this.changes = const {},
  });

  factory CardHistoryEntry.fromJson(Map<String, dynamic> json) {
    final changes = json['changes'];
    return CardHistoryEntry(
      id: _metaInt(json['id']) ?? 0,
      at: _metaDate(json['at']),
      user: json['user']?.toString(),
      action: (json['action'] ?? '').toString(),
      changes: changes is Map ? Map<String, dynamic>.from(changes) : const {},
    );
  }
}

class AnalyticsTotals {
  final int leads;
  final double? leadsChange;
  final int won;
  final double? wonChange;
  final int lost;
  final double conversion;
  final double? conversionChange;
  final double revenue;
  final double? revenueChange;
  final double? avgFirstReplySec;
  final String? replyGrade;
  final double repliedShare;

  const AnalyticsTotals({
    this.leads = 0,
    this.leadsChange,
    this.won = 0,
    this.wonChange,
    this.lost = 0,
    this.conversion = 0,
    this.conversionChange,
    this.revenue = 0,
    this.revenueChange,
    this.avgFirstReplySec,
    this.replyGrade,
    this.repliedShare = 0,
  });

  factory AnalyticsTotals.fromJson(Map<String, dynamic> json) {
    return AnalyticsTotals(
      leads: _metaInt(json['leads']) ?? 0,
      leadsChange: _metaDoubleOrNull(json['leads_change']),
      won: _metaInt(json['won']) ?? 0,
      wonChange: _metaDoubleOrNull(json['won_change']),
      lost: _metaInt(json['lost']) ?? 0,
      conversion: _metaDouble(json['conversion']),
      conversionChange: _metaDoubleOrNull(json['conversion_change']),
      revenue: _metaDouble(json['revenue']),
      revenueChange: _metaDoubleOrNull(json['revenue_change']),
      avgFirstReplySec: _metaDoubleOrNull(json['avg_first_reply_sec']),
      replyGrade: json['reply_grade']?.toString(),
      repliedShare: _metaDouble(json['replied_share']),
    );
  }
}

class AnalyticsBucket {
  final String key;
  final int leads;
  final int won;
  final double conversion;

  const AnalyticsBucket({
    required this.key,
    this.leads = 0,
    this.won = 0,
    this.conversion = 0,
  });

  factory AnalyticsBucket.fromJson(Map<String, dynamic> json) {
    return AnalyticsBucket(
      key: (json['key'] ?? '').toString(),
      leads: _metaInt(json['leads']) ?? 0,
      won: _metaInt(json['won']) ?? 0,
      conversion: _metaDouble(json['conversion']),
    );
  }
}

class AnalyticsSource {
  final String channel;
  final int leads;
  final int won;

  const AnalyticsSource({required this.channel, this.leads = 0, this.won = 0});

  factory AnalyticsSource.fromJson(Map<String, dynamic> json) {
    return AnalyticsSource(
      channel: (json['channel'] ?? '').toString(),
      leads: _metaInt(json['leads']) ?? 0,
      won: _metaInt(json['won']) ?? 0,
    );
  }
}

class AnalyticsStageRow {
  final int id;
  final String name;
  final String color;
  final String kind;
  final int count;

  const AnalyticsStageRow({
    required this.id,
    required this.name,
    this.color = '#362CD1',
    this.kind = 'normal',
    this.count = 0,
  });

  factory AnalyticsStageRow.fromJson(Map<String, dynamic> json) {
    return AnalyticsStageRow(
      id: _metaInt(json['id']) ?? 0,
      name: (json['name'] ?? '').toString(),
      color: (json['color'] ?? '#362CD1').toString(),
      kind: (json['kind'] ?? 'normal').toString(),
      count: _metaInt(json['count']) ?? 0,
    );
  }
}

class AnalyticsManager {
  final int id;
  final String name;
  final int leads;
  final int won;
  final double revenue;
  final double? avgFirstReplySec;
  final int tasksOpen;
  final int tasksDone;
  final int tasksOverdue;

  const AnalyticsManager({
    required this.id,
    required this.name,
    this.leads = 0,
    this.won = 0,
    this.revenue = 0,
    this.avgFirstReplySec,
    this.tasksOpen = 0,
    this.tasksDone = 0,
    this.tasksOverdue = 0,
  });

  factory AnalyticsManager.fromJson(Map<String, dynamic> json) {
    return AnalyticsManager(
      id: _metaInt(json['id']) ?? 0,
      name: (json['name'] ?? '').toString(),
      leads: _metaInt(json['leads']) ?? 0,
      won: _metaInt(json['won']) ?? 0,
      revenue: _metaDouble(json['revenue']),
      avgFirstReplySec: _metaDoubleOrNull(json['avg_first_reply_sec']),
      tasksOpen: _metaInt(json['tasks_open']) ?? 0,
      tasksDone: _metaInt(json['tasks_done']) ?? 0,
      tasksOverdue: _metaInt(json['tasks_overdue']) ?? 0,
    );
  }
}

class AnalyticsTasks {
  final int open;
  final int done;
  final int overdue;

  const AnalyticsTasks({this.open = 0, this.done = 0, this.overdue = 0});

  factory AnalyticsTasks.fromJson(Map<String, dynamic> json) {
    return AnalyticsTasks(
      open: _metaInt(json['open']) ?? 0,
      done: _metaInt(json['done']) ?? 0,
      overdue: _metaInt(json['overdue']) ?? 0,
    );
  }
}

class MetaAnalytics {
  final String granularity;
  final AnalyticsTotals totals;
  final List<AnalyticsBucket> buckets;
  final List<AnalyticsSource> sources;
  final List<AnalyticsStageRow> stages;
  final List<AnalyticsManager> managers;
  final AnalyticsTasks tasks;

  const MetaAnalytics({
    this.granularity = 'month',
    this.totals = const AnalyticsTotals(),
    this.buckets = const [],
    this.sources = const [],
    this.stages = const [],
    this.managers = const [],
    this.tasks = const AnalyticsTasks(),
  });

  factory MetaAnalytics.fromJson(Map<String, dynamic> json) {
    final period = json['period'];
    final totals = json['totals'];
    final tasks = json['tasks'];
    return MetaAnalytics(
      granularity: period is Map
          ? (period['granularity'] ?? 'month').toString()
          : 'month',
      totals: totals is Map
          ? AnalyticsTotals.fromJson(Map<String, dynamic>.from(totals))
          : const AnalyticsTotals(),
      buckets: _metaList(json['buckets'], AnalyticsBucket.fromJson),
      sources: _metaList(json['sources'], AnalyticsSource.fromJson),
      stages: _metaList(json['stages'], AnalyticsStageRow.fromJson),
      managers: _metaList(json['managers'], AnalyticsManager.fromJson),
      tasks: tasks is Map
          ? AnalyticsTasks.fromJson(Map<String, dynamic>.from(tasks))
          : const AnalyticsTasks(),
    );
  }
}

List<T> _metaList<T>(Object? raw, T Function(Map<String, dynamic> json) parse) {
  if (raw is! List) return const [];
  return [
    for (final item in raw.whereType<Map>())
      parse(Map<String, dynamic>.from(item)),
  ];
}

int? _metaInt(Object? raw) => switch (raw) {
  int v => v,
  num v => v.toInt(),
  String v => int.tryParse(v),
  _ => null,
};

double _metaDouble(Object? raw) => _metaDoubleOrNull(raw) ?? 0;

double? _metaDoubleOrNull(Object? raw) => switch (raw) {
  num v => v.toDouble(),
  String v => double.tryParse(v),
  _ => null,
};

DateTime? _metaDate(Object? raw) =>
    raw is String && raw.isNotEmpty ? DateTime.tryParse(raw) : null;

/// WhatsApp sends a country code without «+» (`992911050527`). A local
/// nine-digit number (`901234567`) is shown unchanged.
String displayPhone(String? raw) {
  if (raw == null) return '';
  final trimmed = raw.trim();
  if (trimmed.isEmpty) return '';
  return RegExp(r'^\d{11,15}$').hasMatch(trimmed) ? '+$trimmed' : trimmed;
}

/// Call link. A local nine-digit number is Tajik (`+992`).
String? phoneHref(String? raw) {
  final digits = (raw ?? '').replaceAll(RegExp(r'[^\d+]'), '');
  if (digits.isEmpty) return null;
  if (digits.startsWith('+')) return 'tel:$digits';
  if (digits.length == 9) return 'tel:+992$digits';
  return 'tel:+$digits';
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
