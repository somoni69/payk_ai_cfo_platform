import 'package:equatable/equatable.dart';
import '../domain/marketing_ai_models.dart';
import '../domain/marketing_models.dart';

class MarketingState extends Equatable {
  final List<MarketingCampaign> campaigns;
  final List<SocialPost> posts;
  final bool isCampaignsLoading;
  final bool isPostsLoading;
  final bool isCreatingCampaign;
  final bool isCreatingPost;
  final bool isGenerating;
  final List<String> generatedIdeas;
  final String? generatedText;
  final MarketingPromptMedia? generatedImage;
  final MarketingPromptMedia? generatedVideo;
  final BrandGuide? brandGuide;
  final bool isBrandLoading;
  final bool isSavingBrand;
  final String? errorMessage;

  // AI Studio State
  final bool isStudioLoading;
  final List<MarketingIdea> aiIdeas;
  final MarketingCampaignAi? currentAiCampaign;
  final MarketingVideoQuota? videoQuota;
  final MarketingMediaAsset? currentScript;
  final MarketingMediaAsset? currentMedia;
  final List<MarketingPublicationStats> publicationStats;
  final String? studioSuccessMessage;
  final String? refreshingPublicationId;

  const MarketingState({
    this.campaigns = const [],
    this.posts = const [],
    this.isCampaignsLoading = false,
    this.isPostsLoading = false,
    this.isCreatingCampaign = false,
    this.isCreatingPost = false,
    this.isGenerating = false,
    this.generatedIdeas = const [],
    this.generatedText,
    this.generatedImage,
    this.generatedVideo,
    this.brandGuide,
    this.isBrandLoading = false,
    this.isSavingBrand = false,
    this.errorMessage,
    this.isStudioLoading = false,
    this.aiIdeas = const [],
    this.currentAiCampaign,
    this.videoQuota,
    this.currentScript,
    this.currentMedia,
    this.publicationStats = const [],
    this.studioSuccessMessage,
    this.refreshingPublicationId,
  });

  MarketingState copyWith({
    List<MarketingCampaign>? campaigns,
    List<SocialPost>? posts,
    bool? isCampaignsLoading,
    bool? isPostsLoading,
    bool? isCreatingCampaign,
    bool? isCreatingPost,
    bool? isGenerating,
    List<String>? generatedIdeas,
    String? generatedText,
    MarketingPromptMedia? generatedImage,
    MarketingPromptMedia? generatedVideo,
    BrandGuide? brandGuide,
    bool? isBrandLoading,
    bool? isSavingBrand,
    String? errorMessage,
    bool clearError = false,
    bool? isStudioLoading,
    List<MarketingIdea>? aiIdeas,
    MarketingCampaignAi? currentAiCampaign,
    MarketingVideoQuota? videoQuota,
    MarketingMediaAsset? currentScript,
    MarketingMediaAsset? currentMedia,
    List<MarketingPublicationStats>? publicationStats,
    String? studioSuccessMessage,
    bool clearStudioSuccess = false,
    String? refreshingPublicationId,
    bool clearRefreshingPublication = false,
    bool clearCampaign = false,
    bool clearScript = false,
    bool clearMedia = false,
  }) {
    return MarketingState(
      campaigns: campaigns ?? this.campaigns,
      posts: posts ?? this.posts,
      isCampaignsLoading: isCampaignsLoading ?? this.isCampaignsLoading,
      isPostsLoading: isPostsLoading ?? this.isPostsLoading,
      isCreatingCampaign: isCreatingCampaign ?? this.isCreatingCampaign,
      isCreatingPost: isCreatingPost ?? this.isCreatingPost,
      isGenerating: isGenerating ?? this.isGenerating,
      generatedIdeas: generatedIdeas ?? this.generatedIdeas,
      generatedText: generatedText ?? this.generatedText,
      generatedImage: generatedImage ?? this.generatedImage,
      generatedVideo: generatedVideo ?? this.generatedVideo,
      brandGuide: brandGuide ?? this.brandGuide,
      isBrandLoading: isBrandLoading ?? this.isBrandLoading,
      isSavingBrand: isSavingBrand ?? this.isSavingBrand,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      isStudioLoading: isStudioLoading ?? this.isStudioLoading,
      aiIdeas: aiIdeas ?? this.aiIdeas,
      currentAiCampaign: clearCampaign
          ? null
          : (currentAiCampaign ?? this.currentAiCampaign),
      videoQuota: videoQuota ?? this.videoQuota,
      currentScript: clearScript ? null : (currentScript ?? this.currentScript),
      currentMedia: clearMedia ? null : (currentMedia ?? this.currentMedia),
      publicationStats: publicationStats ?? this.publicationStats,
      studioSuccessMessage: clearStudioSuccess
          ? null
          : (studioSuccessMessage ?? this.studioSuccessMessage),
      refreshingPublicationId: clearRefreshingPublication
          ? null
          : (refreshingPublicationId ?? this.refreshingPublicationId),
    );
  }

  @override
  List<Object?> get props => [
    campaigns,
    posts,
    isCampaignsLoading,
    isPostsLoading,
    isCreatingCampaign,
    isCreatingPost,
    isGenerating,
    generatedIdeas,
    generatedText,
    generatedImage,
    generatedVideo,
    brandGuide,
    isBrandLoading,
    isSavingBrand,
    errorMessage,
    isStudioLoading,
    aiIdeas,
    currentAiCampaign,
    videoQuota,
    currentScript,
    currentMedia,
    publicationStats,
    studioSuccessMessage,
    refreshingPublicationId,
  ];
}
