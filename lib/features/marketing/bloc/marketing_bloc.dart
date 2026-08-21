import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/network/user_facing_error.dart';
import '../domain/marketing_models.dart';
import '../domain/marketing_repository.dart';
import 'marketing_event.dart';
import 'marketing_state.dart';

class MarketingBloc extends Bloc<MarketingEvent, MarketingState> {
  MarketingBloc(this._repository) : super(const MarketingState()) {
    on<LoadMarketingData>(_onLoadMarketingData);
    on<CreateCampaignRequested>(_onCreateCampaignRequested);
    on<CreatePostRequested>(_onCreatePostRequested);
    on<PublishPostRequested>(_onPublishPostRequested);
    on<GenerateIdeasRequested>(_onGenerateIdeasRequested);
    on<GenerateTextRequested>(_onGenerateTextRequested);
    on<UpdateBrandGuideRequested>(_onUpdateBrandGuideRequested);
  }

  final MarketingRepository _repository;
  Future<List<Object>>? _dataRequest;
  Completer<void>? _reloadCompleter;

  Future<void> reload() {
    final active = _reloadCompleter;
    if (active != null) return active.future;

    final completer = Completer<void>();
    _reloadCompleter = completer;
    add(const LoadMarketingData(forceRefresh: true));
    return completer.future;
  }

  Future<void> _onLoadMarketingData(
    LoadMarketingData event,
    Emitter<MarketingState> emit,
  ) async {
    emit(
      state.copyWith(
        isCampaignsLoading: true,
        isPostsLoading: true,
        isBrandLoading: true,
        clearError: true,
      ),
    );

    var request = _dataRequest;
    if (request == null) {
      request = Future.wait<Object>([
        _repository.getCampaigns(forceRefresh: event.forceRefresh),
        _repository.getPosts(forceRefresh: event.forceRefresh),
        _repository.getBrandGuide(forceRefresh: event.forceRefresh),
      ]);
      _dataRequest = request;
    }

    try {
      final results = await request;
      if (emit.isDone) return;
      emit(
        state.copyWith(
          isCampaignsLoading: false,
          isPostsLoading: false,
          isBrandLoading: false,
          campaigns: (results[0] as List).cast<MarketingCampaign>(),
          posts: (results[1] as List).cast<SocialPost>(),
          brandGuide: results[2] as BrandGuide,
        ),
      );
    } catch (error) {
      if (emit.isDone) return;
      emit(
        state.copyWith(
          isCampaignsLoading: false,
          isPostsLoading: false,
          errorMessage: userFacingError(
            error,
            fallback: 'Не удалось обновить маркетинг. Проверьте соединение.',
          ),
        ),
      );
    } finally {
      if (identical(_dataRequest, request)) _dataRequest = null;
      final completer = _reloadCompleter;
      _reloadCompleter = null;
      if (completer != null && !completer.isCompleted) {
        completer.complete();
      }
    }
  }

  Future<void> _onCreateCampaignRequested(
    CreateCampaignRequested event,
    Emitter<MarketingState> emit,
  ) async {
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

      final updated = List<MarketingCampaign>.from(state.campaigns)
        ..insert(0, campaign);
      emit(state.copyWith(isCreatingCampaign: false, campaigns: updated));
    } catch (error) {
      emit(
        state.copyWith(
          isCreatingCampaign: false,
          errorMessage: userFacingError(
            error,
            fallback:
                'Не удалось создать рекламную кампанию. Проверьте данные.',
          ),
        ),
      );
    }
  }

  Future<void> _onCreatePostRequested(
    CreatePostRequested event,
    Emitter<MarketingState> emit,
  ) async {
    emit(state.copyWith(isCreatingPost: true, clearError: true));
    try {
      final post = await _repository.createPost(
        text: event.text,
        channel: event.channel,
      );

      final updated = List<SocialPost>.from(state.posts)..insert(0, post);
      emit(state.copyWith(isCreatingPost: false, posts: updated));
    } catch (error) {
      emit(
        state.copyWith(
          isCreatingPost: false,
          errorMessage: userFacingError(
            error,
            fallback: 'Не удалось создать публикацию. Проверьте данные.',
          ),
        ),
      );
    }
  }

  Future<void> _onPublishPostRequested(
    PublishPostRequested event,
    Emitter<MarketingState> emit,
  ) async {
    emit(state.copyWith(clearError: true));
    try {
      final published = await _repository.publishPost(event.id);
      final updated = state.posts
          .map((post) => post.id == event.id ? published : post)
          .toList();
      emit(state.copyWith(posts: updated));
    } catch (error) {
      emit(
        state.copyWith(
          errorMessage: userFacingError(
            error,
            fallback: 'Не удалось опубликовать пост. Повторите попытку.',
          ),
        ),
      );
    }
  }

  Future<void> _onGenerateIdeasRequested(
    GenerateIdeasRequested event,
    Emitter<MarketingState> emit,
  ) async {
    emit(state.copyWith(isGenerating: true, clearError: true));
    try {
      final ideas = await _repository.generateAiIdeas(event.prompt);
      if (emit.isDone) return;
      emit(state.copyWith(isGenerating: false, generatedIdeas: ideas));
    } catch (error) {
      if (_isCancelled(error) || emit.isDone) return;
      emit(
        state.copyWith(
          isGenerating: false,
          errorMessage: userFacingError(
            error,
            fallback: 'Не удалось получить AI-идеи. Повторите попытку.',
          ),
        ),
      );
    }
  }

  Future<void> _onGenerateTextRequested(
    GenerateTextRequested event,
    Emitter<MarketingState> emit,
  ) async {
    emit(state.copyWith(isGenerating: true, clearError: true));
    try {
      final generatedText = await _repository.generateAiText(event.prompt);
      if (emit.isDone) return;
      emit(state.copyWith(isGenerating: false, generatedText: generatedText));
    } catch (error) {
      if (_isCancelled(error) || emit.isDone) return;
      emit(
        state.copyWith(
          isGenerating: false,
          errorMessage: userFacingError(
            error,
            fallback: 'Не удалось сгенерировать текст. Повторите попытку.',
          ),
        ),
      );
    }
  }

  Future<void> _onUpdateBrandGuideRequested(
    UpdateBrandGuideRequested event,
    Emitter<MarketingState> emit,
  ) async {
    emit(state.copyWith(isSavingBrand: true, clearError: true));
    try {
      final updated = await _repository.updateBrandGuide(event.brandGuide);
      if (emit.isDone) return;
      emit(state.copyWith(isSavingBrand: false, brandGuide: updated));
    } catch (error) {
      if (_isCancelled(error) || emit.isDone) return;
      emit(
        state.copyWith(
          isSavingBrand: false,
          errorMessage: userFacingError(
            error,
            fallback: 'Не удалось сохранить бренд-гайд.',
          ),
        ),
      );
    }
  }

  bool _isCancelled(Object error) =>
      error is DioException && CancelToken.isCancel(error);

  @override
  Future<void> close() {
    final repository = _repository;
    if (repository is CancellableMarketingRepository) {
      (repository as CancellableMarketingRepository).cancelPendingRequests();
    }
    return super.close();
  }
}
