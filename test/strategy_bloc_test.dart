import 'package:flutter_test/flutter_test.dart';
import 'package:payk_ai_cfo_platform/features/strategy/bloc/strategy_bloc.dart';
import 'package:payk_ai_cfo_platform/features/strategy/bloc/strategy_event.dart';
import 'package:payk_ai_cfo_platform/features/strategy/bloc/strategy_state.dart';
import 'package:payk_ai_cfo_platform/features/strategy/domain/strategy_models.dart';
import 'package:payk_ai_cfo_platform/features/strategy/domain/strategy_repository.dart';

class MockStrategyRepository implements StrategyRepository {
  bool shouldFail = false;

  @override
  Future<WhatIfResponseData> askWhatIf(String question) async {
    if (shouldFail) throw Exception('What-if request failed');
    return WhatIfResponseData(
      answer: 'Имитация ответа для вопроса: "$question". Влияние на прибыль: +5%.',
    );
  }

  @override
  Future<AiIdeasResponseData> generateAiIdeas(String prompt) async {
    if (shouldFail) throw Exception('Ai Ideas request failed');
    return AiIdeasResponseData(
      ideas: [
        'Идея 1 для "$prompt"',
        'Идея 2 для "$prompt"',
      ],
    );
  }

  @override
  Future<List<StrategicAnalysis>> getAnalyses(String type) async {
    if (shouldFail) throw Exception('Analyses request failed');
    return [
      StrategicAnalysis(
        id: '1',
        type: type,
        period: '2026-Q2',
        data: const {'strengths': ['Strength 1']},
        generatedByAi: true,
        createdAt: DateTime.now(),
      ),
    ];
  }

  @override
  Future<StrategicAnalysis> generateAnalysis(String type, String period) async {
    if (shouldFail) throw Exception('Generate Analysis request failed');
    return StrategicAnalysis(
      id: '2',
      type: type,
      period: period,
      data: const {'strengths': ['Strength 2']},
      generatedByAi: true,
      createdAt: DateTime.now(),
    );
  }
}

void main() {
  group('StrategyBloc Unit Tests', () {
    late MockStrategyRepository repository;
    late StrategyBloc bloc;

    setUp(() {
      repository = MockStrategyRepository();
      bloc = StrategyBloc(repository);
    });

    tearDown(() {
      bloc.close();
    });

    test('Initial state is empty StrategyState', () {
      expect(bloc.state.isWhatIfLoading, false);
      expect(bloc.state.whatIfAnswer, null);
      expect(bloc.state.isMarketingLoading, false);
      expect(bloc.state.marketingIdeas, isEmpty);
    });

    test('AskWhatIfRequested emits loading and then what-if answer', () async {
      final expected = [
        const StrategyState(isWhatIfLoading: true),
        const StrategyState(
          isWhatIfLoading: false,
          whatIfAnswer: 'Имитация ответа для вопроса: "Что если поднять цены?". Влияние на прибыль: +5%.',
        ),
      ];

      expectLater(bloc.stream, emitsInOrder(expected));
      bloc.add(const AskWhatIfRequested('Что если поднять цены?'));
    });

    test('GenerateMarketingIdeasRequested emits loading and then list of ideas', () async {
      final expected = [
        const StrategyState(isMarketingLoading: true),
        const StrategyState(
          isMarketingLoading: false,
          marketingIdeas: [
            'Идея 1 для "Канал Telegram"',
            'Идея 2 для "Канал Telegram"',
          ],
        ),
      ];

      expectLater(bloc.stream, emitsInOrder(expected));
      bloc.add(const GenerateMarketingIdeasRequested('Канал Telegram'));
    });

    test('AskWhatIfRequested handles repository failure and sets errorMessage', () async {
      repository.shouldFail = true;

      final expected = [
        const StrategyState(isWhatIfLoading: true),
        isA<StrategyState>()
            .having((s) => s.isWhatIfLoading, 'isWhatIfLoading', false)
            .having((s) => s.errorMessage, 'errorMessage', contains('What-if request failed')),
      ];

      expectLater(bloc.stream, emitsInOrder(expected));
      bloc.add(const AskWhatIfRequested('Что если поднять цены?'));
    });

    test('LoadStrategicAnalyses emits loading and then updates analyses list', () async {
      final expected = [
        isA<StrategyState>().having((s) => s.isAnalysisLoading, 'loading', true),
        isA<StrategyState>()
            .having((s) => s.isAnalysisLoading, 'loading', false)
            .having((s) => s.analyses.first.type, 'type', 'swot'),
      ];

      expectLater(bloc.stream, emitsInOrder(expected));
      bloc.add(const LoadStrategicAnalyses('swot'));
    });

    test('GenerateStrategicAnalysis triggers AI analysis and updates latestAnalysis', () async {
      final expected = [
        isA<StrategyState>().having((s) => s.isGeneratingAnalysis, 'generating', true),
        isA<StrategyState>()
            .having((s) => s.isGeneratingAnalysis, 'generating', false)
            .having((s) => s.latestAnalysis?.id, 'latest id', '2'),
      ];

      expectLater(bloc.stream, emitsInOrder(expected));
      bloc.add(const GenerateStrategicAnalysis(type: 'swot', period: '2026-Q2'));
    });
  });
}
