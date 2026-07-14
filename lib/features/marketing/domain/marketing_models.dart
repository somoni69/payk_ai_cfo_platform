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
