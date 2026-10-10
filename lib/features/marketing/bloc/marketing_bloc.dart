import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/network/user_facing_error.dart';
import '../domain/marketing_ai_models.dart';
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
    on<DeleteCampaignRequested>(_onDeleteCampaignRequested);
    on<DeletePostRequested>(_onDeletePostRequested);
    on<GenerateIdeasRequested>(_onGenerateIdeasRequested);
    on<GenerateTextRequested>(_onGenerateTextRequested);
    on<GenerateImageRequested>(_onGenerateImageRequested);
    on<GenerateVideoRequested>(_onGenerateVideoRequested);
    on<UpdateBrandGuideRequested>(_onUpdateBrandGuideRequested);
    on<LoadAiStudioDataRequested>(_onLoadAiStudioDataRequested);
    on<GenerateAiStudioIdeasRequested>(_onGenerateAiStudioIdeasRequested);
    on<CreateAiStudioCampaignRequested>(_onCreateAiStudioCampaignRequested);
    on<GenerateAiStudioConceptsRequested>(_onGenerateAiStudioConceptsRequested);
    on<ReviseAiStudioConceptRequested>(_onReviseAiStudioConceptRequested);
    on<ApproveAiStudioConceptRequested>(_onApproveAiStudioConceptRequested);
    on<GenerateAiStudioScriptRequested>(_onGenerateAiStudioScriptRequested);
    on<GenerateAiStudioMediaRequested>(_onGenerateAiStudioMediaRequested);
    on<RejectAiStudioMediaRequested>(_onRejectAiStudioMediaRequested);
    on<LoadAiStudioReportRequested>(_onLoadAiStudioReportRequested);
    on<RefreshPublicationStatsRequested>(_onRefreshPublicationStatsRequested);
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
        _brandOrError(event.forceRefresh),
      ]);
      _dataRequest = request;
    }

    try {
      final results = await request;
      if (emit.isDone) return;
      final brand = results[2];
      emit(
        state.copyWith(
          isCampaignsLoading: false,
          isPostsLoading: false,
          isBrandLoading: false,
          campaigns: (results[0] as List).cast<MarketingCampaign>(),
          posts: (results[1] as List).cast<SocialPost>(),
          brandGuide: brand is BrandGuide ? brand : null,
          errorMessage: brand is _BrandLoadFailed ? brand.message : null,
        ),
      );
    } catch (error) {
      if (emit.isDone) return;
      emit(
        state.copyWith(
          isCampaignsLoading: false,
          isPostsLoading: false,
          isBrandLoading: false,
          errorMessage: userFacingError(
            error,
            fallback: 'marketing_err_refresh',
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
            fallback: 'marketing_err_create_post',
          ),
        ),
      );
    }
  }

  Future<void> _onDeleteCampaignRequested(
    DeleteCampaignRequested event,
    Emitter<MarketingState> emit,
  ) async {
    emit(state.copyWith(clearError: true));
    try {
      await _repository.deleteCampaign(event.id);
      emit(
        state.copyWith(
          campaigns: state.campaigns
              .where((campaign) => campaign.id != event.id)
              .toList(),
        ),
      );
    } catch (error) {
      emit(
        state.copyWith(
          errorMessage: userFacingError(
            error,
            fallback: 'marketing_err_delete_campaign',
          ),
        ),
      );
    }
  }

  Future<void> _onDeletePostRequested(
    DeletePostRequested event,
    Emitter<MarketingState> emit,
  ) async {
    emit(state.copyWith(clearError: true));
    try {
      await _repository.deletePost(event.id);
      emit(
        state.copyWith(
          posts: state.posts.where((post) => post.id != event.id).toList(),
        ),
      );
    } catch (error) {
      emit(
        state.copyWith(
          errorMessage: userFacingError(
            error,
            fallback: 'marketing_err_delete_post',
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
            fallback: 'marketing_err_publish_post',
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
            fallback: 'marketing_err_ai_ideas',
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
            fallback: 'marketing_err_gen_text',
          ),
        ),
      );
    }
  }

  Future<void> _onGenerateImageRequested(
    GenerateImageRequested event,
    Emitter<MarketingState> emit,
  ) async {
    emit(state.copyWith(isGenerating: true, clearError: true));
    try {
      final generatedImage = await _repository.generateAiImage(event.prompt);
      if (emit.isDone) return;
      emit(state.copyWith(isGenerating: false, generatedImage: generatedImage));
    } catch (error) {
      if (_isCancelled(error) || emit.isDone) return;
      emit(
        state.copyWith(
          isGenerating: false,
          errorMessage: userFacingError(
            error,
            fallback: 'marketing_err_gen_image',
          ),
        ),
      );
    }
  }

  Future<void> _onGenerateVideoRequested(
    GenerateVideoRequested event,
    Emitter<MarketingState> emit,
  ) async {
    emit(state.copyWith(isGenerating: true, clearError: true));
    try {
      final generatedVideo = await _repository.generateAiVideo(event.prompt);
      if (emit.isDone) return;
      emit(state.copyWith(isGenerating: false, generatedVideo: generatedVideo));
    } catch (error) {
      if (_isCancelled(error) || emit.isDone) return;
      emit(
        state.copyWith(
          isGenerating: false,
          errorMessage: userFacingError(
            error,
            fallback: 'marketing_err_gen_video',
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
            fallback: 'marketing_err_save_brand',
          ),
        ),
      );
    }
  }

  Future<void> _onLoadAiStudioDataRequested(
    LoadAiStudioDataRequested event,
    Emitter<MarketingState> emit,
  ) async {
    emit(state.copyWith(isStudioLoading: true, clearError: true));
    try {
      final ideasFuture = _repository.getAiIdeas(lang: event.lang);
      final quotaFuture = _repository.getVideoQuota();
      final statsFuture = _repository.getPublicationStats();
      final results = await Future.wait<Object>([
        ideasFuture,
        quotaFuture,
        statsFuture,
      ]);
      if (emit.isDone) return;
      emit(
        state.copyWith(
          isStudioLoading: false,
          aiIdeas: results[0] as List<MarketingIdea>,
          videoQuota: results[1] as MarketingVideoQuota,
          publicationStats: results[2] as List<MarketingPublicationStats>,
        ),
      );
    } catch (e) {
      if (_isCancelled(e) || emit.isDone) return;
      emit(
        state.copyWith(
          isStudioLoading: false,
          errorMessage: userFacingError(
            e,
            fallback: 'marketing_err_studio_load',
          ),
        ),
      );
    }
  }

  Future<void> _onGenerateAiStudioIdeasRequested(
    GenerateAiStudioIdeasRequested event,
    Emitter<MarketingState> emit,
  ) async {
    emit(state.copyWith(isStudioLoading: true, clearError: true));
    try {
      final ideas = await _repository.getAiIdeas(lang: event.lang);
      if (emit.isDone) return;
      emit(state.copyWith(isStudioLoading: false, aiIdeas: ideas));
    } catch (e) {
      if (_isCancelled(e) || emit.isDone) return;
      emit(
        state.copyWith(
          isStudioLoading: false,
          errorMessage: userFacingError(e, fallback: 'marketing_err_gen_ideas'),
        ),
      );
    }
  }

  Future<void> _onCreateAiStudioCampaignRequested(
    CreateAiStudioCampaignRequested event,
    Emitter<MarketingState> emit,
  ) async {
    emit(state.copyWith(isStudioLoading: true, clearError: true));
    try {
      final campaign = await _repository.createAiCampaign(
        name: event.name,
        product: event.product,
        goalQty: event.goalQty,
        goalDays: event.goalDays,
        briefText: event.briefText,
        ideaSource: event.ideaSource,
      );
      if (emit.isDone) return;
      emit(
        state.copyWith(
          isStudioLoading: false,
          currentAiCampaign: campaign,
          studioSuccessMessage: 'marketing_campaign_created',
        ),
      );
    } catch (e) {
      if (_isCancelled(e) || emit.isDone) return;
      emit(
        state.copyWith(
          isStudioLoading: false,
          errorMessage: userFacingError(
            e,
            fallback: 'marketing_err_create_campaign',
          ),
        ),
      );
    }
  }

  Future<void> _onGenerateAiStudioConceptsRequested(
    GenerateAiStudioConceptsRequested event,
    Emitter<MarketingState> emit,
  ) async {
    emit(state.copyWith(isStudioLoading: true, clearError: true));
    try {
      final concepts = await _repository.generateAiConcepts(event.campaignId);
      if (emit.isDone) return;
      if (state.currentAiCampaign != null) {
        final updated = MarketingCampaignAi(
          id: state.currentAiCampaign!.id,
          name: state.currentAiCampaign!.name,
          product: state.currentAiCampaign!.product,
          goalQty: state.currentAiCampaign!.goalQty,
          goalDays: state.currentAiCampaign!.goalDays,
          briefText: state.currentAiCampaign!.briefText,
          ideaSource: state.currentAiCampaign!.ideaSource,
          aiStatus: 'concepts_generated',
          createdAt: state.currentAiCampaign!.createdAt,
          concepts: concepts,
        );
        emit(
          state.copyWith(
            isStudioLoading: false,
            currentAiCampaign: updated,
            studioSuccessMessage: 'marketing_concepts_generated',
          ),
        );
      } else {
        emit(state.copyWith(isStudioLoading: false));
      }
    } catch (e) {
      if (_isCancelled(e) || emit.isDone) return;
      emit(
        state.copyWith(
          isStudioLoading: false,
          errorMessage: userFacingError(
            e,
            fallback: 'marketing_err_gen_concepts',
          ),
        ),
      );
    }
  }

  Future<void> _onReviseAiStudioConceptRequested(
    ReviseAiStudioConceptRequested event,
    Emitter<MarketingState> emit,
  ) async {
    emit(state.copyWith(isStudioLoading: true, clearError: true));
    try {
      final revised = await _repository.reviseAiConcept(
        campaignId: event.campaignId,
        baseIds: event.baseIds,
        note: event.note,
      );
      if (emit.isDone) return;
      if (state.currentAiCampaign != null) {
        final currentConcepts = List<MarketingConcept>.from(
          state.currentAiCampaign!.concepts,
        )..add(revised);
        final updated = MarketingCampaignAi(
          id: state.currentAiCampaign!.id,
          name: state.currentAiCampaign!.name,
          product: state.currentAiCampaign!.product,
          goalQty: state.currentAiCampaign!.goalQty,
          goalDays: state.currentAiCampaign!.goalDays,
          briefText: state.currentAiCampaign!.briefText,
          ideaSource: state.currentAiCampaign!.ideaSource,
          aiStatus: 'revised',
          createdAt: state.currentAiCampaign!.createdAt,
          concepts: currentConcepts,
        );
        emit(
          state.copyWith(
            isStudioLoading: false,
            currentAiCampaign: updated,
            studioSuccessMessage: 'marketing_concept_revised',
          ),
        );
      } else {
        emit(state.copyWith(isStudioLoading: false));
      }
    } catch (e) {
      if (_isCancelled(e) || emit.isDone) return;
      emit(
        state.copyWith(
          isStudioLoading: false,
          errorMessage: userFacingError(
            e,
            fallback: 'marketing_err_revise_concept',
          ),
        ),
      );
    }
  }

  Future<void> _onApproveAiStudioConceptRequested(
    ApproveAiStudioConceptRequested event,
    Emitter<MarketingState> emit,
  ) async {
    emit(state.copyWith(isStudioLoading: true, clearError: true));
    try {
      final approved = await _repository.approveAiConcept(event.conceptId);
      if (emit.isDone) return;
      if (state.currentAiCampaign != null) {
        final updatedConcepts = state.currentAiCampaign!.concepts.map((c) {
          return c.id == event.conceptId ? approved : c;
        }).toList();
        final updated = MarketingCampaignAi(
          id: state.currentAiCampaign!.id,
          name: state.currentAiCampaign!.name,
          product: state.currentAiCampaign!.product,
          goalQty: state.currentAiCampaign!.goalQty,
          goalDays: state.currentAiCampaign!.goalDays,
          briefText: state.currentAiCampaign!.briefText,
          ideaSource: state.currentAiCampaign!.ideaSource,
          aiStatus: 'approved',
          createdAt: state.currentAiCampaign!.createdAt,
          concepts: updatedConcepts,
        );
        emit(
          state.copyWith(
            isStudioLoading: false,
            currentAiCampaign: updated,
            studioSuccessMessage: 'marketing_concept_approved',
          ),
        );
      } else {
        emit(state.copyWith(isStudioLoading: false));
      }
    } catch (e) {
      if (_isCancelled(e) || emit.isDone) return;
      emit(
        state.copyWith(
          isStudioLoading: false,
          errorMessage: userFacingError(
            e,
            fallback: 'marketing_err_approve_concept',
          ),
        ),
      );
    }
  }

  Future<void> _onGenerateAiStudioScriptRequested(
    GenerateAiStudioScriptRequested event,
    Emitter<MarketingState> emit,
  ) async {
    emit(state.copyWith(isStudioLoading: true, clearError: true));
    try {
      final script = await _repository.generateAiScript(event.conceptId);
      if (emit.isDone) return;
      emit(
        state.copyWith(
          isStudioLoading: false,
          currentScript: script,
          currentMedia: script,
          studioSuccessMessage: 'marketing_script_generated',
        ),
      );
    } catch (e) {
      if (_isCancelled(e) || emit.isDone) return;
      emit(
        state.copyWith(
          isStudioLoading: false,
          errorMessage: userFacingError(
            e,
            fallback: 'marketing_err_gen_script',
          ),
        ),
      );
    }
  }

  Future<void> _onGenerateAiStudioMediaRequested(
    GenerateAiStudioMediaRequested event,
    Emitter<MarketingState> emit,
  ) async {
    emit(state.copyWith(isStudioLoading: true, clearError: true));
    try {
      final media = await _repository.generateAiMedia(
        mediaId: event.mediaId,
        kind: event.kind,
        confirm: event.confirm,
      );
      final quota = await _repository.getVideoQuota();
      if (emit.isDone) return;
      emit(
        state.copyWith(
          isStudioLoading: false,
          currentMedia: media,
          videoQuota: quota,
          studioSuccessMessage: 'marketing_media_generated',
        ),
      );
    } catch (e) {
      if (_isCancelled(e) || emit.isDone) return;
      emit(
        state.copyWith(
          isStudioLoading: false,
          errorMessage: userFacingError(e, fallback: 'marketing_err_gen_media'),
        ),
      );
    }
  }

  Future<void> _onRejectAiStudioMediaRequested(
    RejectAiStudioMediaRequested event,
    Emitter<MarketingState> emit,
  ) async {
    emit(state.copyWith(isStudioLoading: true, clearError: true));
    try {
      await _repository.rejectAiMedia(
        mediaId: event.mediaId,
        reason: event.reason,
      );
      if (emit.isDone) return;
      if (state.currentMedia != null) {
        final rejected = MarketingMediaAsset(
          id: state.currentMedia!.id,
          conceptId: state.currentMedia!.conceptId,
          kind: state.currentMedia!.kind,
          fileUrl: state.currentMedia!.fileUrl,
          version: state.currentMedia!.version,
          script: state.currentMedia!.script,
          postText: state.currentMedia!.postText,
          firstComment: state.currentMedia!.firstComment,
          status: 'rejected',
          rejectReason: event.reason,
          cost: state.currentMedia!.cost,
          createdAt: state.currentMedia!.createdAt,
        );
        emit(
          state.copyWith(
            isStudioLoading: false,
            currentMedia: rejected,
            studioSuccessMessage: 'marketing_media_rejected',
          ),
        );
      } else {
        emit(state.copyWith(isStudioLoading: false));
      }
    } catch (e) {
      if (_isCancelled(e) || emit.isDone) return;
      emit(
        state.copyWith(
          isStudioLoading: false,
          errorMessage: userFacingError(
            e,
            fallback: 'marketing_err_reject_media',
          ),
        ),
      );
    }
  }

  Future<void> _onLoadAiStudioReportRequested(
    LoadAiStudioReportRequested event,
    Emitter<MarketingState> emit,
  ) async {
    emit(state.copyWith(isStudioLoading: true, clearError: true));
    try {
      final stats = await _repository.getPublicationStats();
      if (emit.isDone) return;
      emit(state.copyWith(isStudioLoading: false, publicationStats: stats));
    } catch (e) {
      if (_isCancelled(e) || emit.isDone) return;
      emit(
        state.copyWith(
          isStudioLoading: false,
          errorMessage: userFacingError(e, fallback: 'marketing_err_roi'),
        ),
      );
    }
  }

  Future<void> _onRefreshPublicationStatsRequested(
    RefreshPublicationStatsRequested event,
    Emitter<MarketingState> emit,
  ) async {
    emit(
      state.copyWith(
        refreshingPublicationId: event.publicationId,
        clearError: true,
      ),
    );
    try {
      final updated = await _repository.getPublicationStatsById(
        event.publicationId,
      );
      if (emit.isDone) return;
      final next = [
        for (final row in state.publicationStats)
          if (row.publicationId == updated.publicationId) updated else row,
      ];
      if (next.every((row) => row.publicationId != updated.publicationId)) {
        next.insert(0, updated);
      }
      emit(
        state.copyWith(
          publicationStats: next,
          clearRefreshingPublication: true,
        ),
      );
    } catch (e) {
      if (_isCancelled(e) || emit.isDone) return;
      emit(
        state.copyWith(
          clearRefreshingPublication: true,
          errorMessage: userFacingError(
            e,
            fallback: 'marketing_err_post_stats',
          ),
        ),
      );
    }
  }

  /// The brand form must not open blank when the server failed: saving it
  /// would overwrite the real guide. The failure is shown, not hidden.
  Future<Object> _brandOrError(bool forceRefresh) async {
    try {
      return await _repository.getBrandGuide(forceRefresh: forceRefresh);
    } catch (error) {
      if (_isCancelled(error)) rethrow;
      return _BrandLoadFailed(
        userFacingError(error, fallback: ErrorKeys.loadFailed),
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

/// Brand guide failed while campaigns and posts loaded; keeps them visible.
class _BrandLoadFailed {
  const _BrandLoadFailed(this.message);
  final String message;
}
