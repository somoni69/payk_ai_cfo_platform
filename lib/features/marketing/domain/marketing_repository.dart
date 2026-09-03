import 'marketing_ai_models.dart';
import 'marketing_models.dart';

abstract class MarketingRepository {
  Future<List<MarketingCampaign>> getCampaigns({bool forceRefresh = false});

  Future<MarketingCampaign> createCampaign({
    required String name,
    required String channel,
    required double budget,
    required double spent,
    required int leads,
    required int conversions,
    required double revenue,
  });

  Future<List<SocialPost>> getPosts({bool forceRefresh = false});

  Future<SocialPost> createPost({
    required String text,
    required String channel,
  });

  Future<SocialPost> publishPost(String id);

  Future<void> deleteCampaign(String id);

  Future<void> deletePost(String id);

  Future<List<String>> generateAiIdeas(String prompt);

  Future<String> generateAiText(String prompt);

  Future<BrandGuide> getBrandGuide({bool forceRefresh = false});

  Future<BrandGuide> updateBrandGuide(BrandGuide brandGuide);

  // Marketing AI Studio (Zero-Spend 3-Phase Pipeline)
  Future<List<MarketingIdea>> getAiIdeas({String lang = 'ru'});

  Future<MarketingCampaignAi> createAiCampaign({
    required String name,
    String? product,
    int? goalQty,
    int? goalDays,
    String? briefText,
    String? ideaSource,
  });

  Future<List<MarketingConcept>> generateAiConcepts(String campaignId);

  Future<MarketingConcept> reviseAiConcept({
    required String campaignId,
    required List<String> baseIds,
    required String note,
  });

  Future<MarketingConcept> approveAiConcept(String conceptId);

  Future<MarketingMediaAsset> generateAiScript(String conceptId);

  Future<MarketingVideoQuota> getVideoQuota();

  Future<MarketingMediaAsset> generateAiMedia({
    required String mediaId,
    required String kind,
    bool confirm = true,
  });

  Future<void> rejectAiMedia({required String mediaId, required String reason});

  Future<List<MarketingPublicationStats>> getPublicationStats();

  Future<MarketingPublicationStats> getPublicationStatsById(
    String publicationId,
  );

  Future<List<int>> exportCampaigns({String format = 'xlsx'});
}

abstract interface class CancellableMarketingRepository {
  void cancelPendingRequests();
}
