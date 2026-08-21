class MarketingCampaign {
  final String id;
  final String name;
  final String? channel;
  final double budget;
  final double spent;
  final int leads;
  final int conversions;
  final double revenue;
  final DateTime? startedAt;
  final DateTime? endedAt;
  final double roi;
  final double? cac;

  const MarketingCampaign({
    required this.id,
    required this.name,
    this.channel,
    required this.budget,
    required this.spent,
    required this.leads,
    required this.conversions,
    required this.revenue,
    this.startedAt,
    this.endedAt,
    required this.roi,
    this.cac,
  });
}

class SocialPost {
  final String id;
  final String text;
  final String? imageUrl;
  final String channel;
  final String status; // 'draft', 'published'
  final DateTime? scheduledAt;
  final DateTime? publishedAt;
  final DateTime createdAt;

  const SocialPost({
    required this.id,
    required this.text,
    this.imageUrl,
    required this.channel,
    required this.status,
    this.scheduledAt,
    this.publishedAt,
    required this.createdAt,
  });
}

class BrandGuide {
  final String? brandName;
  final String? logoUrl;
  final String? colors;
  final String? tone;
  final String? forbidden;
  final String? audience;
  final int videoLimitMonth;
  final int learnedRounds;

  const BrandGuide({
    this.brandName,
    this.logoUrl,
    this.colors,
    this.tone,
    this.forbidden,
    this.audience,
    this.videoLimitMonth = 10,
    this.learnedRounds = 0,
  });

  factory BrandGuide.fromJson(Map<String, dynamic> json) {
    return BrandGuide(
      brandName: json['brand_name']?.toString(),
      logoUrl: json['logo_url']?.toString(),
      colors: json['colors']?.toString(),
      tone: json['tone']?.toString(),
      forbidden: json['forbidden']?.toString(),
      audience: json['audience']?.toString(),
      videoLimitMonth: (json['video_limit_month'] as num?)?.toInt() ?? 10,
      learnedRounds: (json['learned_rounds'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'brand_name': brandName,
      'logo_url': logoUrl,
      'colors': colors,
      'tone': tone,
      'forbidden': forbidden,
      'audience': audience,
      'video_limit_month': videoLimitMonth,
      'learned_rounds': learnedRounds,
    };
  }
}
