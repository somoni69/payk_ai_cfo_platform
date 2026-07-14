import 'package:flutter_bloc/flutter_bloc.dart';
import '../domain/marketing_models.dart';
import '../domain/marketing_repository.dart';
import 'marketing_event.dart';
import 'marketing_state.dart';

class MarketingBloc extends Bloc<MarketingEvent, MarketingState> {
  final MarketingRepository _repository;

  MarketingBloc(this._repository) : super(const MarketingState()) {
    on<LoadMarketingData>(_onLoadMarketingData);
    on<CreateCampaignRequested>(_onCreateCampaignRequested);
    on<CreatePostRequested>(_onCreatePostRequested);
    on<PublishPostRequested>(_onPublishPostRequested);
    on<GenerateIdeasRequested>(_onGenerateIdeasRequested);
    on<GenerateTextRequested>(_onGenerateTextRequested);
  }

  void _onLoadMarketingData(LoadMarketingData event, Emitter<MarketingState> emit) async {
    Future<List<T>> safeList<T>(Future<List<T>> future) async {
      try {
        return await future;
      } catch (_) {
        return <T>[];
      }
    }

    emit(state.copyWith(isCampaignsLoading: true, isPostsLoading: true, clearError: true));
    try {
      final results = await Future.wait([
        safeList(_repository.getCampaigns()),
        safeList(_repository.getPosts()),
      ]);

      emit(state.copyWith(
        isCampaignsLoading: false,
        isPostsLoading: false,
        campaigns: results[0] as List<MarketingCampaign>,
        posts: results[1] as List<SocialPost>,
      ));
    } catch (e) {
      emit(state.copyWith(
        isCampaignsLoading: false,
        isPostsLoading: false,
        errorMessage: 'Ошибка загрузки данных маркетинга: ${e.toString()}',
      ));
    }
  }

  void _onCreateCampaignRequested(CreateCampaignRequested event, Emitter<MarketingState> emit) async {
    emit(state.copyWith(isCreatingCampaign: true, clearError: true));
    try {
      final campaign = await _repository.createCampaign(
        name: event.name,
        channel: event.channel,
        budget: event.budget,
        spent: event.spent,
        leads: event.leads,
        conversions: event.conversions,
        revenue: event.revenue,
      );

      final updated = List<MarketingCampaign>.from(state.campaigns)..insert(0, campaign);
      emit(state.copyWith(
        isCreatingCampaign: false,
        campaigns: updated,
      ));
    } catch (e) {
      emit(state.copyWith(
        isCreatingCampaign: false,
        errorMessage: 'Не удалось создать рекламную кампанию: ${e.toString()}',
      ));
    }
  }

  void _onCreatePostRequested(CreatePostRequested event, Emitter<MarketingState> emit) async {
    emit(state.copyWith(isCreatingPost: true, clearError: true));
    try {
      final post = await _repository.createPost(
        text: event.text,
        channel: event.channel,
      );

      final updated = List<SocialPost>.from(state.posts)..insert(0, post);
      emit(state.copyWith(
        isCreatingPost: false,
        posts: updated,
      ));
    } catch (e) {
      emit(state.copyWith(
        isCreatingPost: false,
        errorMessage: 'Не удалось создать публикацию: ${e.toString()}',
      ));
    }
  }

  void _onPublishPostRequested(PublishPostRequested event, Emitter<MarketingState> emit) async {
    emit(state.copyWith(clearError: true));
    try {
      final published = await _repository.publishPost(event.id);
      final updated = state.posts.map((p) => p.id == event.id ? published : p).toList();

      emit(state.copyWith(posts: updated));
    } catch (e) {
      emit(state.copyWith(errorMessage: 'Не удалось опубликовать пост: ${e.toString()}'));
    }
  }

  void _onGenerateIdeasRequested(GenerateIdeasRequested event, Emitter<MarketingState> emit) async {
    emit(state.copyWith(isGenerating: true, clearError: true));
    try {
      final ideas = await _repository.generateAiIdeas(event.prompt);
      emit(state.copyWith(
        isGenerating: false,
        generatedIdeas: ideas,
      ));
    } catch (e) {
      emit(state.copyWith(
        isGenerating: false,
        errorMessage: 'Ошибка AI: ${e.toString()}',
      ));
    }
  }

  void _onGenerateTextRequested(GenerateTextRequested event, Emitter<MarketingState> emit) async {
    emit(state.copyWith(isGenerating: true, clearError: true));
    try {
      final text = await _repository.generateAiText(event.prompt);
      emit(state.copyWith(
        isGenerating: false,
        generatedText: text,
      ));
    } catch (e) {
      emit(state.copyWith(
        isGenerating: false,
        errorMessage: 'Ошибка AI: ${e.toString()}',
      ));
    }
  }
}
