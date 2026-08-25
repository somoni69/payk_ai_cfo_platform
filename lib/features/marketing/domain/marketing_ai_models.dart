import 'package:equatable/equatable.dart';

/// Идея кампании от ИИ (Фаза 1.1).
class MarketingIdea extends Equatable {
  final String source; // 'season' | 'sales_drop' | 'stale_stock' | 'manual'
  final String tag;
  final String title;
  final String reason;

  const MarketingIdea({
    required this.source,
    required this.tag,
    required this.title,
    required this.reason,
  });

  factory MarketingIdea.fromJson(Map<String, dynamic> json) {
    return MarketingIdea(
      source: (json['source'] ?? '').toString(),
      tag: (json['tag'] ?? '').toString(),
      title: (json['title'] ?? '').toString(),
      reason: (json['reason'] ?? '').toString(),
    );
  }

  @override
  List<Object?> get props => [source, tag, title, reason];
}

/// Концепция рекламного ролика/поста (Фаза 1.4).
class MarketingConcept extends Equatable {
  final String id;
  final String campaignId;
  final String variant; // 'A' | 'B' | 'Rev'
  final int roundNo;
  final String title;
  final String? storyline;
  final String? theses;
  final String? tone;
  final String? format;
  final int? durationSec;
  final String? cta;
  final String status; // 'draft' | 'approved' | 'rejected'
  final DateTime? approvedAt;
  final DateTime createdAt;

  const MarketingConcept({
    required this.id,
    required this.campaignId,
    required this.variant,
    required this.roundNo,
    required this.title,
    this.storyline,
    this.theses,
    this.tone,
    this.format,
    this.durationSec,
    this.cta,
    required this.status,
    this.approvedAt,
    required this.createdAt,
  });

  bool get isApproved => status == 'approved';

  factory MarketingConcept.fromJson(Map<String, dynamic> json) {
    DateTime? parseDt(dynamic v) {
      if (v == null) return null;
      if (v is DateTime) return v;
      if (v is String && v.isNotEmpty) return DateTime.tryParse(v);
      return null;
    }

    return MarketingConcept(
      id: (json['id'] ?? '').toString(),
      campaignId: (json['campaign_id'] ?? '').toString(),
      variant: (json['variant'] ?? 'A').toString(),
      roundNo: json['round_no'] is num ? (json['round_no'] as num).toInt() : 1,
      title: (json['title'] ?? '').toString(),
      storyline: json['storyline']?.toString(),
      theses: json['theses']?.toString(),
      tone: json['tone']?.toString(),
      format: json['format']?.toString(),
      durationSec: json['duration_sec'] is num
          ? (json['duration_sec'] as num).toInt()
          : null,
      cta: json['cta']?.toString(),
      status: (json['status'] ?? 'draft').toString(),
      approvedAt: parseDt(json['approved_at']),
      createdAt: parseDt(json['created_at']) ?? DateTime.now(),
    );
  }

  @override
  List<Object?> get props => [
    id,
    campaignId,
    variant,
    roundNo,
    title,
    storyline,
    theses,
    tone,
    format,
    durationSec,
    cta,
    status,
    approvedAt,
    createdAt,
  ];
}

/// Кампания в AI Студии маркетинга.
class MarketingCampaignAi extends Equatable {
  final String id;
  final String name;
  final String? product;
  final int? goalQty;
  final int? goalDays;
  final String? briefText;
  final String? ideaSource;
  final String? aiStatus;
  final DateTime createdAt;
  final List<MarketingConcept> concepts;

  const MarketingCampaignAi({
    required this.id,
    required this.name,
    this.product,
    this.goalQty,
    this.goalDays,
    this.briefText,
    this.ideaSource,
    this.aiStatus,
    required this.createdAt,
    this.concepts = const [],
  });

  factory MarketingCampaignAi.fromJson(Map<String, dynamic> json) {
    final list = json['concepts'] as List<dynamic>? ?? [];
    return MarketingCampaignAi(
      id: (json['id'] ?? '').toString(),
      name: (json['name'] ?? '').toString(),
      product: json['product']?.toString(),
      goalQty: json['goal_qty'] is num
          ? (json['goal_qty'] as num).toInt()
          : null,
      goalDays: json['goal_days'] is num
          ? (json['goal_days'] as num).toInt()
          : null,
      briefText: json['brief_text']?.toString(),
      ideaSource: json['idea_source']?.toString(),
      aiStatus: json['ai_status']?.toString(),
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
      concepts: list
          .whereType<Map<String, dynamic>>()
          .map(MarketingConcept.fromJson)
          .toList(),
    );
  }

  @override
  List<Object?> get props => [
    id,
    name,
    product,
    goalQty,
    goalDays,
    briefText,
    ideaSource,
    aiStatus,
    createdAt,
    concepts,
  ];
}

/// Медиа-ассет (сценарий, фото Imagen, видео Google Veo).
class MarketingMediaAsset extends Equatable {
  final String id;
  final String conceptId;
  final String kind; // 'photo' | 'video'
  final String? fileUrl;
  final int version;
  final String? script;
  final String? postText;
  final String? firstComment;
  final String status; // 'generating' | 'ready' | 'rejected' | 'failed'
  final String? rejectReason;
  final double cost;
  final DateTime createdAt;

  const MarketingMediaAsset({
    required this.id,
    required this.conceptId,
    required this.kind,
    this.fileUrl,
    required this.version,
    this.script,
    this.postText,
    this.firstComment,
    required this.status,
    this.rejectReason,
    this.cost = 0.0,
    required this.createdAt,
  });

  bool get isReady => status == 'ready';
  bool get isGenerating => status == 'generating';
  bool get isRejected => status == 'rejected';

  factory MarketingMediaAsset.fromJson(Map<String, dynamic> json) {
    double toDec(dynamic val) {
      if (val == null) return 0.0;
      if (val is num) return val.toDouble();
      return double.tryParse(val.toString()) ?? 0.0;
    }

    return MarketingMediaAsset(
      id: (json['id'] ?? '').toString(),
      conceptId: (json['concept_id'] ?? '').toString(),
      kind: (json['kind'] ?? 'photo').toString(),
      fileUrl: json['file_url']?.toString(),
      version: json['version'] is num ? (json['version'] as num).toInt() : 1,
      script: json['script']?.toString(),
      postText: json['post_text']?.toString(),
      firstComment: json['first_comment']?.toString(),
      status: (json['status'] ?? 'ready').toString(),
      rejectReason: json['reject_reason']?.toString(),
      cost: toDec(json['cost']),
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  @override
  List<Object?> get props => [
    id,
    conceptId,
    kind,
    fileUrl,
    version,
    script,
    postText,
    firstComment,
    status,
    rejectReason,
    cost,
    createdAt,
  ];
}

/// Ежемесячная квота на генерацию видео Google Veo.
class MarketingVideoQuota extends Equatable {
  final String month;
  final int videoUsed;
  final int videoLimit;
  final int videoLeft;

  const MarketingVideoQuota({
    required this.month,
    required this.videoUsed,
    required this.videoLimit,
    required this.videoLeft,
  });

  factory MarketingVideoQuota.fromJson(Map<String, dynamic> json) {
    int toI(dynamic v) =>
        v is num ? v.toInt() : (int.tryParse(v?.toString() ?? '') ?? 0);
    return MarketingVideoQuota(
      month: (json['month'] ?? '').toString(),
      videoUsed: toI(json['video_used']),
      videoLimit: toI(json['video_limit']),
      videoLeft: toI(json['video_left']),
    );
  }

  @override
  List<Object?> get props => [month, videoUsed, videoLimit, videoLeft];
}

/// Статистика и ROI публикаций (Фаза 5).
class MarketingPublicationStats extends Equatable {
  final String publicationId;
  final int comments;
  final int authors;
  final int intents;
  final int prepaid;
  final int purchases;
  final double revenue;
  final double spend;
  final double? roiPercent;
  final String? period;

  const MarketingPublicationStats({
    required this.publicationId,
    required this.comments,
    required this.authors,
    required this.intents,
    required this.prepaid,
    required this.purchases,
    required this.revenue,
    required this.spend,
    this.roiPercent,
    this.period,
  });

  factory MarketingPublicationStats.fromJson(Map<String, dynamic> json) {
    int toI(dynamic v) =>
        v is num ? v.toInt() : (int.tryParse(v?.toString() ?? '') ?? 0);
    double toD(dynamic v) {
      if (v == null) return 0.0;
      if (v is num) return v.toDouble();
      return double.tryParse(v.toString()) ?? 0.0;
    }

    return MarketingPublicationStats(
      publicationId: (json['publication_id'] ?? '').toString(),
      comments: toI(json['comments']),
      authors: toI(json['authors']),
      intents: toI(json['intents']),
      prepaid: toI(json['prepaid']),
      purchases: toI(json['purchases']),
      revenue: toD(json['revenue']),
      spend: toD(json['spend']),
      roiPercent: json['roi_percent'] != null ? toD(json['roi_percent']) : null,
      period: json['period']?.toString(),
    );
  }

  @override
  List<Object?> get props => [
    publicationId,
    comments,
    authors,
    intents,
    prepaid,
    purchases,
    revenue,
    spend,
    roiPercent,
    period,
  ];
}
