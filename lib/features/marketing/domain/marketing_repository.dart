import 'marketing_models.dart';

abstract class MarketingRepository {
  Future<List<MarketingCampaign>> getCampaigns();
  
  Future<MarketingCampaign> createCampaign({
    required String name,
    required String channel,
    required double budget,
    required double spent,
    required int leads,
    required int conversions,
    required double revenue,
  });

  Future<List<SocialPost>> getPosts();

  Future<SocialPost> createPost({
    required String text,
    required String channel,
  });

  Future<SocialPost> publishPost(String id);

  Future<List<String>> generateAiIdeas(String prompt);

  Future<String> generateAiText(String prompt);
}
