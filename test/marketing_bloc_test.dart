import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:payk_ai_cfo_platform/features/marketing/bloc/marketing_bloc.dart';
import 'package:payk_ai_cfo_platform/features/marketing/bloc/marketing_event.dart';
import 'package:payk_ai_cfo_platform/features/marketing/bloc/marketing_state.dart';
import 'package:payk_ai_cfo_platform/features/marketing/domain/marketing_ai_models.dart';
import 'package:payk_ai_cfo_platform/features/marketing/domain/marketing_models.dart';
import 'package:payk_ai_cfo_platform/features/marketing/domain/marketing_repository.dart';

class MockMarketingTestRepository implements MarketingRepository {
  bool shouldFail = false;
  Completer<void>? loadGate;
  int campaignReads = 0;
  int postReads = 0;

  @override
  Future<List<MarketingCampaign>> getCampaigns({
    bool forceRefresh = false,
  }) async {
    campaignReads++;
    if (shouldFail) throw Exception('Campaigns failed');
    final gate = loadGate;
    if (gate != null) await gate.future;
    return [
      const MarketingCampaign(
        id: '1',
        name: 'Camp 1',
        budget: 100.0,
        spent: 50.0,
        leads: 10,
        conversions: 2,
        revenue: 500.0,
        roi: 900.0,
      ),
    ];
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
    if (shouldFail) throw Exception('Create campaign failed');
    return MarketingCampaign(
      id: '2',
      name: name,
      channel: channel,
      budget: budget,
      spent: spent,
      leads: leads,
      conversions: conversions,
      revenue: revenue,
      roi: 200.0,
    );
  }

  @override
  Future<List<SocialPost>> getPosts({bool forceRefresh = false}) async {
    postReads++;
    if (shouldFail) throw Exception('Posts failed');
    final gate = loadGate;
    if (gate != null) await gate.future;
    return [
      SocialPost(
        id: '1',
        text: 'Post 1',
        channel: 'telegram',
        status: 'draft',
        createdAt: DateTime.now(),
      ),
    ];
  }

  @override
  Future<SocialPost> createPost({
    required String text,
    required String channel,
  }) async {
    if (shouldFail) throw Exception('Create post failed');
    return SocialPost(
      id: '2',
      text: text,
      channel: channel,
      status: 'draft',
      createdAt: DateTime.now(),
    );
  }

  @override
  Future<void> deleteCampaign(String id) async {}

  @override
  Future<void> deletePost(String id) async {}

  @override
  Future<SocialPost> publishPost(String id) async {
    if (shouldFail) throw Exception('Publish post failed');
    return SocialPost(
      id: id,
      text: 'Published Text',
      channel: 'telegram',
      status: 'published',
      createdAt: DateTime.now(),
    );
  }

  @override
  Future<List<String>> generateAiIdeas(String prompt) async {
    if (shouldFail) throw Exception('AI failed');
    return ['Idea A', 'Idea B'];
  }

  @override
  Future<String> generateAiText(String prompt) async {
    if (shouldFail) throw Exception('AI Text failed');
    return 'Copied Copy text';
  }

  BrandGuide brandGuide = const BrandGuide(
    brandName: 'Test Brand',
    tone: 'Friendly',
    videoLimitMonth: 10,
  );

  @override
  Future<BrandGuide> getBrandGuide({bool forceRefresh = false}) async {
    if (shouldFail) throw Exception('Brand failed');
    return brandGuide;
  }

  @override
  Future<BrandGuide> updateBrandGuide(BrandGuide updated) async {
    if (shouldFail) throw Exception('Update brand failed');
    brandGuide = updated;
    return brandGuide;
  }

  @override
  Future<List<MarketingIdea>> getAiIdeas({String lang = 'ru'}) async {
    if (shouldFail) throw Exception('AI Ideas failed');
    return [
      const MarketingIdea(
        source: 'season',
        tag: 'Сезон',
        title: 'Сезонная акция',
        reason: 'Летний сезон',
      ),
    ];
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
    if (shouldFail) throw Exception('Create AI Campaign failed');
    return MarketingCampaignAi(
      id: 'ai-1',
      name: name,
      product: product,
      createdAt: DateTime.now(),
    );
  }

  @override
  Future<List<MarketingConcept>> generateAiConcepts(String campaignId) async {
    if (shouldFail) throw Exception('Generate Concepts failed');
    return [
      MarketingConcept(
        id: 'conc-1',
        campaignId: campaignId,
        variant: 'A',
        roundNo: 1,
        title: 'Concept A',
        status: 'draft',
        createdAt: DateTime.now(),
      ),
    ];
  }

  @override
  Future<MarketingConcept> reviseAiConcept({
    required String campaignId,
    required List<String> baseIds,
    required String note,
  }) async {
    if (shouldFail) throw Exception('Revise Concept failed');
    return MarketingConcept(
      id: 'conc-rev',
      campaignId: campaignId,
      variant: 'Rev',
      roundNo: 2,
      title: 'Revised: $note',
      status: 'draft',
      createdAt: DateTime.now(),
    );
  }

  @override
  Future<MarketingConcept> approveAiConcept(String conceptId) async {
    if (shouldFail) throw Exception('Approve Concept failed');
    return MarketingConcept(
      id: conceptId,
      campaignId: 'ai-1',
      variant: 'A',
      roundNo: 1,
      title: 'Approved Concept',
      status: 'approved',
      approvedAt: DateTime.now(),
      createdAt: DateTime.now(),
    );
  }

  @override
  Future<MarketingMediaAsset> generateAiScript(String conceptId) async {
    if (shouldFail) throw Exception('Generate Script failed');
    return MarketingMediaAsset(
      id: 'media-1',
      conceptId: conceptId,
      kind: 'video',
      version: 1,
      script: 'Test Script',
      status: 'ready',
      cost: 0.0,
      createdAt: DateTime.now(),
    );
  }

  @override
  Future<MarketingVideoQuota> getVideoQuota() async {
    if (shouldFail) throw Exception('Video Quota failed');
    return const MarketingVideoQuota(
      month: '2026-08',
      videoUsed: 1,
      videoLimit: 10,
      videoLeft: 9,
    );
  }

  @override
  Future<MarketingMediaAsset> generateAiMedia({
    required String mediaId,
    required String kind,
    bool confirm = true,
  }) async {
    if (shouldFail) throw Exception('Generate Media failed');
    return MarketingMediaAsset(
      id: mediaId,
      conceptId: 'conc-1',
      kind: kind,
      version: 1,
      status: 'ready',
      cost: 10.0,
      createdAt: DateTime.now(),
    );
  }

  @override
  Future<void> rejectAiMedia({
    required String mediaId,
    required String reason,
  }) async {
    if (shouldFail) throw Exception('Reject Media failed');
  }

  @override
  Future<List<MarketingPublicationStats>> getPublicationStats() async {
    if (shouldFail) throw Exception('Publication Stats failed');
    return [
      const MarketingPublicationStats(
        publicationId: '1',
        comments: 10,
        authors: 8,
        intents: 5,
        prepaid: 2,
        purchases: 3,
        revenue: 1000.0,
        spend: 200.0,
        roiPercent: 400.0,
      ),
    ];
  }
}

void main() {
  group('MarketingBloc Unit Tests', () {
    late MockMarketingTestRepository repository;
    late MarketingBloc bloc;

    setUp(() {
      repository = MockMarketingTestRepository();
      bloc = MarketingBloc(repository);
    });

    tearDown(() {
      bloc.close();
    });

    test('Initial state is empty MarketingState', () {
      expect(bloc.state.campaigns, isEmpty);
      expect(bloc.state.posts, isEmpty);
      expect(bloc.state.isCampaignsLoading, false);
    });

    test(
      'LoadMarketingData emits loading states and populated campaigns/posts lists',
      () async {
        final expected = [
          isA<MarketingState>().having(
            (s) => s.isCampaignsLoading,
            'loading campaigns',
            true,
          ),
          isA<MarketingState>()
              .having((s) => s.isCampaignsLoading, 'loading campaigns', false)
              .having(
                (s) => s.campaigns.first.name,
                'first camp name',
                'Camp 1',
              )
              .having((s) => s.posts.first.text, 'first post text', 'Post 1'),
        ];

        expectLater(bloc.stream, emitsInOrder(expected));
        bloc.add(LoadMarketingData());
      },
    );

    test(
      'CreateCampaignRequested inserts campaign to campaigns list',
      () async {
        final expected = [
          isA<MarketingState>().having(
            (s) => s.isCreatingCampaign,
            'isCreatingCampaign',
            true,
          ),
          isA<MarketingState>()
              .having((s) => s.isCreatingCampaign, 'isCreatingCampaign', false)
              .having(
                (s) => s.campaigns.first.name,
                'new camp name',
                'Promo A',
              ),
        ];

        expectLater(bloc.stream, emitsInOrder(expected));
        bloc.add(
          const CreateCampaignRequested(
            name: 'Promo A',
            channel: 'telegram',
            budget: 500,
            spent: 400,
            leads: 100,
            conversions: 10,
            revenue: 2000,
          ),
        );
      },
    );

    test(
      'GenerateIdeasRequested returns list of generated marketing ideas',
      () async {
        final expected = [
          isA<MarketingState>().having(
            (s) => s.isGenerating,
            'generating',
            true,
          ),
          isA<MarketingState>()
              .having((s) => s.isGenerating, 'generating', false)
              .having((s) => s.generatedIdeas.length, 'ideas count', 2),
        ];

        expectLater(bloc.stream, emitsInOrder(expected));
        bloc.add(const GenerateIdeasRequested('Cement ads'));
      },
    );
    test(
      'reload during initial load waits and does not duplicate reads',
      () async {
        final gate = Completer<void>();
        repository.loadGate = gate;
        bloc.add(const LoadMarketingData());

        await Future<void>.delayed(const Duration(milliseconds: 20));
        var completed = false;
        final first = bloc.reload();
        final second = bloc.reload();
        expect(identical(first, second), true);
        first.then((_) => completed = true);

        await Future<void>.delayed(const Duration(milliseconds: 20));
        expect(repository.campaignReads, 1);
        expect(repository.postReads, 1);
        expect(completed, false);

        gate.complete();
        await Future.wait<void>([first, second]);

        expect(completed, true);
        expect(bloc.state.campaigns, isNotEmpty);
        expect(bloc.state.posts, isNotEmpty);
      },
    );

    test('LoadAiStudioDataRequested loads AI ideas and video quota', () async {
      bloc.add(const LoadAiStudioDataRequested());
      final state = await bloc.stream.firstWhere(
        (s) => s.aiIdeas.isNotEmpty && s.videoQuota != null,
      );

      expect(state.aiIdeas.first.title, 'Сезонная акция');
      expect(state.videoQuota?.videoLimit, 10);
    });

    test(
      'CreateAiStudioCampaignRequested creates campaign and sets currentAiCampaign',
      () async {
        bloc.add(
          const CreateAiStudioCampaignRequested(
            name: 'Summer Sale',
            product: 'Cement',
            goalDays: 7,
          ),
        );
        final state = await bloc.stream.firstWhere(
          (s) => s.currentAiCampaign != null,
        );

        expect(state.currentAiCampaign?.name, 'Summer Sale');
        expect(state.studioSuccessMessage, 'marketing_campaign_created');
      },
    );
  });
}
