import 'package:dio/dio.dart';
import '../../../core/network/user_facing_error.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/expiring_request_cache.dart';
import '../domain/marketing_ai_models.dart';
import '../domain/marketing_models.dart';
import '../domain/marketing_repository.dart';

class ApiMarketingRepository
    implements MarketingRepository, CancellableMarketingRepository {
  final ApiClient _apiClient = ApiClient();
  final _campaignsCache = ExpiringRequestCache<List<MarketingCampaign>>();
  final _postsCache = ExpiringRequestCache<List<SocialPost>>();
  CancelToken? _ideasCancelToken;
  CancelToken? _textCancelToken;
  CancelToken? _imageCancelToken;
  CancelToken? _videoCancelToken;

  @override
  Future<List<MarketingCampaign>> getCampaigns({bool forceRefresh = false}) =>
      _campaignsCache.get(_fetchCampaigns, forceRefresh: forceRefresh);

  Future<List<MarketingCampaign>> _fetchCampaigns() async {
    try {
      final response = await _apiClient.dio.get('/marketing/campaigns');
      final list = response.data as List<dynamic>;

      return list.map((item) {
        final map = item as Map<String, dynamic>;
        return MarketingCampaign(
          id: (map['id'] ?? '').toString(),
          name: map['name'] ?? '',
          channel: map['channel'],
          budget: double.tryParse((map['budget'] ?? '0').toString()) ?? 0.0,
          spent: double.tryParse((map['spent'] ?? '0').toString()) ?? 0.0,
          leads: (map['leads'] ?? 0) as int,
          conversions: (map['conversions'] ?? 0) as int,
          revenue: double.tryParse((map['revenue'] ?? '0').toString()) ?? 0.0,
          startedAt: map['started_at'] != null
              ? DateTime.parse(map['started_at'])
              : null,
          endedAt: map['ended_at'] != null
              ? DateTime.parse(map['ended_at'])
              : null,
          roi: double.tryParse((map['roi'] ?? '0').toString()) ?? 0.0,
          cac: map['cac'] != null
              ? double.tryParse(map['cac'].toString())
              : null,
        );
      }).toList();
    } catch (e) {
      throw Exception(userFacingError(e, fallback: ErrorKeys.loadFailed));
    }
  }

  @override
  Future<MarketingCampaign> createCampaign({
    required String name,
    required String channel,
    required double budget,
    required double spent,
    required int leads,
    required int conversions,
    required double revenue,
  }) async {
    try {
      final payload = {
        'name': name,
        'channel': channel,
        'budget': budget,
        'spent': spent,
        'leads': leads,
        'conversions': conversions,
        'revenue': revenue,
      };
      final response = await _apiClient.dio.post(
        '/marketing/campaigns',
        data: payload,
      );
      final map = response.data as Map<String, dynamic>;
      _campaignsCache.invalidate();

      return MarketingCampaign(
        id: (map['id'] ?? '').toString(),
        name: map['name'] ?? '',
        channel: map['channel'],
        budget: double.tryParse((map['budget'] ?? '0').toString()) ?? 0.0,
        spent: double.tryParse((map['spent'] ?? '0').toString()) ?? 0.0,
        leads: (map['leads'] ?? 0) as int,
        conversions: (map['conversions'] ?? 0) as int,
        revenue: double.tryParse((map['revenue'] ?? '0').toString()) ?? 0.0,
        startedAt: map['started_at'] != null
            ? DateTime.parse(map['started_at'])
            : null,
        endedAt: map['ended_at'] != null
            ? DateTime.parse(map['ended_at'])
            : null,
        roi: double.tryParse((map['roi'] ?? '0').toString()) ?? 0.0,
        cac: map['cac'] != null ? double.tryParse(map['cac'].toString()) : null,
      );
    } catch (e) {
      throw Exception(userFacingError(e, fallback: ErrorKeys.loadFailed));
    }
  }

  @override
  Future<List<SocialPost>> getPosts({bool forceRefresh = false}) =>
      _postsCache.get(_fetchPosts, forceRefresh: forceRefresh);

  Future<List<SocialPost>> _fetchPosts() async {
    try {
      final response = await _apiClient.dio.get('/marketing/posts');
      final dynamic responseData = response.data;
      final List<dynamic> list = responseData is Map<String, dynamic>
          ? (responseData['items'] as List<dynamic>? ?? [])
          : (responseData as List<dynamic>? ?? []);

      return list.map((item) {
        final map = item as Map<String, dynamic>;
        return SocialPost(
          id: (map['id'] ?? '').toString(),
          text: map['text'] ?? '',
          imageUrl: map['image_url'],
          channel: map['channel'] ?? 'telegram',
          status: map['status'] ?? 'draft',
          scheduledAt: map['scheduled_at'] != null
              ? DateTime.parse(map['scheduled_at'])
              : null,
          publishedAt: map['published_at'] != null
              ? DateTime.parse(map['published_at'])
              : null,
          createdAt: DateTime.parse(
            map['created_at'] ?? DateTime.now().toIso8601String(),
          ),
        );
      }).toList();
    } catch (e) {
      throw Exception(userFacingError(e, fallback: ErrorKeys.loadFailed));
    }
  }

  @override
  Future<SocialPost> createPost({
    required String text,
    required String channel,
  }) async {
    try {
      final payload = {'text': text, 'channel': channel};
      final response = await _apiClient.dio.post(
        '/marketing/posts',
        data: payload,
      );
      final map = response.data as Map<String, dynamic>;
      _postsCache.invalidate();

      return SocialPost(
        id: (map['id'] ?? '').toString(),
        text: map['text'] ?? '',
        imageUrl: map['image_url'],
        channel: map['channel'] ?? channel,
        status: map['status'] ?? 'draft',
        scheduledAt: map['scheduled_at'] != null
            ? DateTime.parse(map['scheduled_at'])
            : null,
        publishedAt: map['published_at'] != null
            ? DateTime.parse(map['published_at'])
            : null,
        createdAt: DateTime.parse(
          map['created_at'] ?? DateTime.now().toIso8601String(),
        ),
      );
    } catch (e) {
      throw Exception(userFacingError(e, fallback: ErrorKeys.loadFailed));
    }
  }

  @override
  Future<void> deleteCampaign(String id) async {
    await _apiClient.dio.delete('/marketing/campaigns/$id');
    _campaignsCache.invalidate();
  }

  @override
  Future<void> deletePost(String id) async {
    await _apiClient.dio.delete('/marketing/posts/$id');
    _postsCache.invalidate();
  }

  @override
  Future<SocialPost> publishPost(String id) async {
    try {
      final response = await _apiClient.dio.post(
        '/marketing/posts/$id/publish',
      );
      final map = response.data as Map<String, dynamic>;
      _postsCache.invalidate();

      return SocialPost(
        id: (map['id'] ?? '').toString(),
        text: map['text'] ?? '',
        imageUrl: map['image_url'],
        channel: map['channel'] ?? 'telegram',
        status: map['status'] ?? 'published',
        scheduledAt: map['scheduled_at'] != null
            ? DateTime.parse(map['scheduled_at'])
            : null,
        publishedAt: map['published_at'] != null
            ? DateTime.parse(map['published_at'])
            : null,
        createdAt: DateTime.parse(
          map['created_at'] ?? DateTime.now().toIso8601String(),
        ),
      );
    } catch (e) {
      throw Exception(userFacingError(e, fallback: ErrorKeys.loadFailed));
    }
  }

  @override
  Future<List<String>> generateAiIdeas(String prompt) async {
    _ideasCancelToken?.cancel('Запрос заменён новым');
    final cancelToken = CancelToken();
    _ideasCancelToken = cancelToken;

    try {
      final response = await _apiClient.dio.post(
        '/marketing/ai-ideas',
        data: {'prompt': prompt},
        options: ApiClient.longRunningOptions(),
        cancelToken: cancelToken,
      );
      final map = response.data as Map<String, dynamic>;
      final list = (map['ideas'] ?? []) as List<dynamic>;
      return list.map((e) => e.toString()).toList();
    } catch (error) {
      if (error is DioException && CancelToken.isCancel(error)) rethrow;
      throw Exception(ErrorKeys.loadFailed);
    } finally {
      if (identical(_ideasCancelToken, cancelToken)) {
        _ideasCancelToken = null;
      }
    }
  }

  @override
  Future<String> generateAiText(String prompt) async {
    _textCancelToken?.cancel('Запрос заменён новым');
    final cancelToken = CancelToken();
    _textCancelToken = cancelToken;

    try {
      final response = await _apiClient.dio.post(
        '/marketing/ai-text',
        data: {'prompt': prompt},
        options: ApiClient.longRunningOptions(),
        cancelToken: cancelToken,
      );
      final map = response.data as Map<String, dynamic>;
      return map['text'] ?? 'Нет сгенерированного текста';
    } catch (error) {
      if (error is DioException && CancelToken.isCancel(error)) rethrow;
      throw Exception(ErrorKeys.loadFailed);
    } finally {
      if (identical(_textCancelToken, cancelToken)) {
        _textCancelToken = null;
      }
    }
  }

  @override
  Future<MarketingPromptMedia> generateAiImage(String prompt) {
    return _generatePromptMedia(
      path: '/marketing/ai-image',
      prompt: prompt,
      receiveTimeout: const Duration(seconds: 150),
      current: () => _imageCancelToken,
      adopt: (token) => _imageCancelToken = token,
    );
  }

  @override
  Future<MarketingPromptMedia> generateAiVideo(String prompt) {
    return _generatePromptMedia(
      path: '/marketing/ai-video',
      prompt: prompt,
      receiveTimeout: const Duration(minutes: 7),
      current: () => _videoCancelToken,
      adopt: (token) => _videoCancelToken = token,
    );
  }

  Future<MarketingPromptMedia> _generatePromptMedia({
    required String path,
    required String prompt,
    required Duration receiveTimeout,
    required CancelToken? Function() current,
    required void Function(CancelToken?) adopt,
  }) async {
    current()?.cancel('Запрос заменён новым');
    final cancelToken = CancelToken();
    adopt(cancelToken);
    try {
      final response = await _apiClient.dio.post(
        path,
        data: {'prompt': prompt},
        options: ApiClient.longRunningOptions(receiveTimeout: receiveTimeout),
        cancelToken: cancelToken,
      );
      final data = response.data;
      if (data is Map) {
        return MarketingPromptMedia.fromJson(Map<String, dynamic>.from(data));
      }
      throw Exception(ErrorKeys.loadFailed);
    } catch (error) {
      if (error is DioException && CancelToken.isCancel(error)) rethrow;
      throw Exception(userFacingError(error, fallback: ErrorKeys.loadFailed));
    } finally {
      if (identical(current(), cancelToken)) adopt(null);
    }
  }

  @override
  Future<BrandGuide> getBrandGuide({bool forceRefresh = false}) async {
    try {
      final response = await _apiClient.dio.get('/marketing/ai/brand');
      if (response.data is! Map) throw Exception(ErrorKeys.invalidResponse);
      return BrandGuide.fromJson(
        Map<String, dynamic>.from(response.data as Map),
      );
    } catch (error) {
      throw Exception(userFacingError(error, fallback: ErrorKeys.loadFailed));
    }
  }

  @override
  Future<BrandGuide> updateBrandGuide(BrandGuide brandGuide) async {
    try {
      final response = await _apiClient.dio.put(
        '/marketing/ai/brand',
        data: brandGuide.toJson(),
      );
      if (response.data is! Map) throw Exception(ErrorKeys.invalidResponse);
      return BrandGuide.fromJson(
        Map<String, dynamic>.from(response.data as Map),
      );
    } catch (error) {
      throw Exception(userFacingError(error, fallback: ErrorKeys.saveFailed));
    }
  }

  @override
  Future<List<MarketingIdea>> getAiIdeas({String lang = 'ru'}) async {
    try {
      final response = await _apiClient.dio.get(
        '/marketing/ai/ideas',
        queryParameters: {'lang': lang},
        options: ApiClient.longRunningOptions(),
      );
      final list = response.data as List<dynamic>? ?? [];
      return list
          .whereType<Map<String, dynamic>>()
          .map(MarketingIdea.fromJson)
          .toList();
    } catch (e) {
      throw Exception(userFacingError(e, fallback: ErrorKeys.loadFailed));
    }
  }

  @override
  Future<MarketingCampaignAi> createAiCampaign({
    required String name,
    String? product,
    int? goalQty,
    int? goalDays,
    String? briefText,
    String? ideaSource,
  }) async {
    try {
      final payload = <String, dynamic>{
        'name': name,
        'product': ?product,
        'goal_qty': ?goalQty,
        'goal_days': ?goalDays,
        'brief_text': ?briefText,
        'idea_source': ?ideaSource,
      };
      final response = await _apiClient.dio.post(
        '/marketing/ai/campaigns',
        data: payload,
      );
      return MarketingCampaignAi.fromJson(
        Map<String, dynamic>.from(response.data as Map),
      );
    } catch (e) {
      throw Exception(userFacingError(e, fallback: ErrorKeys.saveFailed));
    }
  }

  @override
  Future<List<MarketingConcept>> generateAiConcepts(String campaignId) async {
    try {
      final response = await _apiClient.dio.post(
        '/marketing/ai/campaigns/$campaignId/concepts',
        options: ApiClient.longRunningOptions(),
      );
      final list = response.data as List<dynamic>? ?? [];
      return list
          .whereType<Map<String, dynamic>>()
          .map(MarketingConcept.fromJson)
          .toList();
    } catch (e) {
      throw Exception(userFacingError(e, fallback: ErrorKeys.loadFailed));
    }
  }

  @override
  Future<MarketingConcept> reviseAiConcept({
    required String campaignId,
    required List<String> baseIds,
    required String note,
  }) async {
    try {
      final intBaseIds = baseIds
          .map((e) => int.tryParse(e))
          .whereType<int>()
          .toList();
      final response = await _apiClient.dio.post(
        '/marketing/ai/campaigns/$campaignId/revise',
        data: {'base_ids': intBaseIds, 'note': note},
        options: ApiClient.longRunningOptions(),
      );
      return MarketingConcept.fromJson(
        Map<String, dynamic>.from(response.data as Map),
      );
    } catch (e) {
      throw Exception(userFacingError(e, fallback: ErrorKeys.saveFailed));
    }
  }

  @override
  Future<MarketingConcept> approveAiConcept(String conceptId) async {
    try {
      final response = await _apiClient.dio.post(
        '/marketing/ai/concepts/$conceptId/approve',
      );
      return MarketingConcept.fromJson(
        Map<String, dynamic>.from(response.data as Map),
      );
    } catch (e) {
      throw Exception(userFacingError(e, fallback: ErrorKeys.saveFailed));
    }
  }

  @override
  Future<MarketingMediaAsset> generateAiScript(String conceptId) async {
    try {
      final response = await _apiClient.dio.post(
        '/marketing/ai/concepts/$conceptId/script',
        options: ApiClient.longRunningOptions(),
      );
      return MarketingMediaAsset.fromJson(
        Map<String, dynamic>.from(response.data as Map),
      );
    } catch (e) {
      throw Exception(userFacingError(e, fallback: ErrorKeys.loadFailed));
    }
  }

  @override
  Future<MarketingVideoQuota> getVideoQuota() async {
    try {
      final response = await _apiClient.dio.get('/marketing/ai/media/quota');
      return MarketingVideoQuota.fromJson(
        Map<String, dynamic>.from(response.data as Map),
      );
    } catch (e) {
      return const MarketingVideoQuota(
        month: '',
        videoUsed: 0,
        videoLimit: 10,
        videoLeft: 10,
      );
    }
  }

  @override
  Future<MarketingMediaAsset> generateAiMedia({
    required String mediaId,
    required String kind,
    bool confirm = true,
  }) async {
    try {
      final response = await _apiClient.dio.post(
        '/marketing/ai/media/$mediaId/generate',
        queryParameters: {'kind': kind, 'confirm': confirm},
        options: ApiClient.longRunningOptions(),
      );
      return MarketingMediaAsset.fromJson(
        Map<String, dynamic>.from(response.data as Map),
      );
    } catch (e) {
      throw Exception(userFacingError(e, fallback: ErrorKeys.saveFailed));
    }
  }

  @override
  Future<void> rejectAiMedia({
    required String mediaId,
    required String reason,
  }) async {
    try {
      await _apiClient.dio.post(
        '/marketing/ai/media/$mediaId/reject',
        data: {'reason': reason},
      );
    } catch (e) {
      throw Exception(userFacingError(e, fallback: ErrorKeys.saveFailed));
    }
  }

  @override
  Future<List<MarketingPublicationStats>> getPublicationStats() async {
    try {
      final response = await _apiClient.dio.get('/marketing/ai/report');
      final list = response.data as List<dynamic>? ?? [];
      return list
          .whereType<Map<String, dynamic>>()
          .map(MarketingPublicationStats.fromJson)
          .toList();
    } catch (e) {
      return const [];
    }
  }

  @override
  Future<MarketingPublicationStats> getPublicationStatsById(
    String publicationId,
  ) async {
    final response = await _apiClient.dio.get(
      '/marketing/ai/publications/$publicationId/stats',
    );
    return MarketingPublicationStats.fromJson(
      Map<String, dynamic>.from(response.data as Map),
    );
  }

  @override
  Future<List<int>> exportCampaigns({String format = 'xlsx'}) async {
    try {
      final response = await _apiClient.dio.get<List<int>>(
        '/marketing/campaigns/export',
        queryParameters: {'fmt': format},
        options: Options(responseType: ResponseType.bytes),
      );
      return response.data ?? <int>[];
    } catch (e) {
      throw Exception(userFacingError(e, fallback: ErrorKeys.loadFailed));
    }
  }

  @override
  void cancelPendingRequests() {
    _ideasCancelToken?.cancel('Экран закрыт');
    _textCancelToken?.cancel('Экран закрыт');
    _imageCancelToken?.cancel('Экран закрыт');
    _videoCancelToken?.cancel('Экран закрыт');
    _ideasCancelToken = null;
    _textCancelToken = null;
    _imageCancelToken = null;
    _videoCancelToken = null;
  }
}
