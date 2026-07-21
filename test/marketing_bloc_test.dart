import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:payk_ai_cfo_platform/features/marketing/bloc/marketing_bloc.dart';
import 'package:payk_ai_cfo_platform/features/marketing/bloc/marketing_event.dart';
import 'package:payk_ai_cfo_platform/features/marketing/bloc/marketing_state.dart';
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
  });
}
