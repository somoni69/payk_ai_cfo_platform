import 'package:flutter_test/flutter_test.dart';
import 'package:payk_ai_cfo_platform/features/legal/bloc/legal_bloc.dart';
import 'package:payk_ai_cfo_platform/features/legal/bloc/legal_event.dart';
import 'package:payk_ai_cfo_platform/features/legal/bloc/legal_state.dart';
import 'package:payk_ai_cfo_platform/features/legal/domain/legal_models.dart';
import 'package:payk_ai_cfo_platform/features/legal/domain/legal_repository.dart';
import 'package:payk_ai_cfo_platform/features/legal/presentation/legal_screen.dart';

class MockLegalTestRepository implements LegalRepository {
  @override
  Future<List<ContractTemplate>> getTemplates({
    bool forceRefresh = false,
  }) async {
    return const [
      ContractTemplate(
        id: '1',
        name: 'Test Template',
        body: 'Body {var}',
        variables: [TemplateVariable(key: 'var', label: 'V')],
      ),
    ];
  }

  @override
  Future<List<Law>> getLaws({bool forceRefresh = false}) async {
    return [
      Law(
        id: '1',
        title: 'Test Law',
        body: 'Law Body',
        createdAt: DateTime.now(),
      ),
    ];
  }

  @override
  Future<List<LegalDeadline>> getDeadlines({bool forceRefresh = false}) async {
    return [
      LegalDeadline(
        id: '1',
        title: 'Test DL',
        type: 'TAX',
        dueDate: DateTime.now(),
        isDone: false,
      ),
    ];
  }

  @override
  Future<LegalDeadline> updateDeadlineStatus(
    String deadlineId,
    bool isDone,
  ) async {
    return LegalDeadline(
      id: deadlineId,
      title: 'Test DL',
      type: 'TAX',
      dueDate: DateTime.now(),
      isDone: isDone,
    );
  }

  @override
  Future<String> askAiLawyer(String question) async {
    return 'Answer for $question';
  }

  @override
  Future<GeneratedContract> generateContract(
    String templateId,
    Map<String, String> data,
  ) async {
    return GeneratedContract(
      id: 'gen_1',
      title: 'Gen title',
      body: 'Gen body',
      createdAt: DateTime.now(),
    );
  }

  @override
  Future<Law> createLaw({
    required String title,
    required String body,
    String? category,
  }) async {
    return Law(
      id: 'new_law',
      title: title,
      body: body,
      category: category,
      createdAt: DateTime.now(),
    );
  }

  @override
  Future<void> deleteLaw(String id) async {}

  @override
  Future<LegalDeadline> createDeadline({
    required String title,
    required String type,
    required DateTime dueDate,
    String? amount,
    String? note,
  }) async {
    return LegalDeadline(
      id: 'new_dl',
      title: title,
      type: type,
      dueDate: dueDate,
      amount: amount,
      note: note,
      isDone: false,
      daysLeft: dueDate.difference(DateTime.now()).inDays,
    );
  }

  @override
  Future<ContractTemplate> createTemplate({
    required String name,
    required String body,
    String? category,
  }) async {
    return ContractTemplate(
      id: 'new_tpl',
      name: name,
      body: body,
      category: category,
      variables: const [],
    );
  }
}

void main() {
  group('Legal chat lifecycle', () {
    test('auto-scroll reacts only to chat history changes', () {
      const previous = LegalLoaded(
        templates: [],
        laws: [],
        deadlines: [],
        chatHistory: [
          {'sender': 'ai', 'text': 'welcome'},
        ],
      );
      final nonChatUpdate = previous.copyWith(isGenerating: true);
      final chatUpdate = previous.copyWith(
        chatHistory: [
          ...previous.chatHistory,
          {'sender': 'user', 'text': 'question'},
        ],
      );

      expect(shouldAutoScrollLegalChat(previous, nonChatUpdate), isFalse);
      expect(shouldAutoScrollLegalChat(previous, chatUpdate), isTrue);
      expect(shouldAutoScrollLegalChat(LegalLoading(), previous), isTrue);
    });
  });

  group('LegalBloc Unit Tests', () {
    late MockLegalTestRepository repository;
    late LegalBloc bloc;

    setUp(() {
      repository = MockLegalTestRepository();
      bloc = LegalBloc(repository);
    });

    tearDown(() {
      bloc.close();
    });

    test('Initial state is LegalLoading', () {
      expect(bloc.state, isA<LegalLoading>());
    });

    test(
      'LoadLegalData emits loading and then loaded with lists and welcome msg',
      () async {
        final expected = [
          isA<LegalLoading>(),
          isA<LegalLoaded>()
              .having(
                (s) => s.templates.first.name,
                'template name',
                'Test Template',
              )
              .having((s) => s.laws.first.title, 'law title', 'Test Law')
              .having(
                (s) => s.deadlines.first.title,
                'deadline title',
                'Test DL',
              )
              .having((s) => s.chatHistory.first['sender'], 'sender', 'ai'),
        ];

        expectLater(bloc.stream, emitsInOrder(expected));
        bloc.add(LoadLegalData());
      },
    );

    test('ToggleDeadlineStatus updates deadline item', () async {
      bloc.add(LoadLegalData());
      await bloc.stream.firstWhere((s) => s is LegalLoaded);

      bloc.add(const ToggleDeadlineStatus(id: '1', isDone: true));

      final List<LegalState> emitted = [];
      final sub = bloc.stream.listen(emitted.add);

      await Future.delayed(const Duration(milliseconds: 50));
      sub.cancel();

      expect(emitted, isNotEmpty);
      final loaded = emitted.first as LegalLoaded;
      expect(loaded.deadlines.first.isDone, true);
    });

    test('AskLawyerQuestion appends user question and AI answer', () async {
      bloc.add(LoadLegalData());
      await bloc.stream.firstWhere((s) => s is LegalLoaded);

      bloc.add(const AskLawyerQuestion('What is the tax rate?'));

      final List<LegalState> emitted = [];
      final sub = bloc.stream.listen(emitted.add);

      await Future.delayed(const Duration(milliseconds: 100));
      sub.cancel();

      expect(emitted.any((s) => s is LegalLoaded && s.isAskingAi), true);
      final finalLoaded =
          emitted.lastWhere((s) => s is LegalLoaded && !s.isAskingAi)
              as LegalLoaded;
      expect(finalLoaded.chatHistory.length, 3); // Welcome + User + AI
      expect(
        finalLoaded.chatHistory.last['text'],
        'Answer for What is the tax rate?',
      );
    });

    test(
      'GenerateContractFromTemplate updates isGenerating and stores contract',
      () async {
        bloc.add(LoadLegalData());
        await bloc.stream.firstWhere((s) => s is LegalLoaded);

        bloc.add(
          const GenerateContractFromTemplate(
            templateId: '1',
            variables: {'var': 'Value'},
          ),
        );

        final List<LegalState> emitted = [];
        final sub = bloc.stream.listen(emitted.add);

        await Future.delayed(const Duration(milliseconds: 100));
        sub.cancel();

        expect(emitted.any((s) => s is LegalLoaded && s.isGenerating), true);
        final finalLoaded =
            emitted.lastWhere((s) => s is LegalLoaded && !s.isGenerating)
                as LegalLoaded;
        expect(finalLoaded.generatedContract?.id, 'gen_1');
      },
    );
  });
}
