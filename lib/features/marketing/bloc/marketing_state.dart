import 'package:equatable/equatable.dart';
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
  final String? errorMessage;

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
    this.errorMessage,
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
    String? errorMessage,
    bool clearError = false,
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
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
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
        errorMessage,
      ];
}
