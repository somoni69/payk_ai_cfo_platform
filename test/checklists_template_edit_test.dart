import 'package:flutter_test/flutter_test.dart';
import 'package:payk_ai_cfo_platform/features/checklists/bloc/checklists_bloc.dart';
import 'package:payk_ai_cfo_platform/features/checklists/bloc/checklists_event.dart';
import 'package:payk_ai_cfo_platform/features/checklists/bloc/checklists_state.dart';
import 'package:payk_ai_cfo_platform/features/checklists/data/api_checklists_repository.dart';
import 'package:payk_ai_cfo_platform/features/checklists/domain/checklist_models.dart';
import 'package:payk_ai_cfo_platform/features/checklists/domain/checklists_repository.dart';
import 'package:payk_ai_cfo_platform/features/meta/presentation/meta_attachments.dart';

class _Repo implements ChecklistsRepository {
  final calls = <String>[];

  @override
  Future<void> updateTemplate({
    required String id,
    required String name,
    String? regulationText,
    String? regulationUrl,
    String? branchId,
  }) async => calls.add('patch $id $name');

  @override
  Future<void> addTemplateItem({
    required String templateId,
    required String text,
    required int position,
  }) async => calls.add('add $templateId $text@$position');

  @override
  Future<void> deleteTemplateItem(String itemId) async =>
      calls.add('delete $itemId');

  @override
  Future<ChecklistTemplate> createTemplate({
    required String name,
    String? description,
    String? regulationText,
    String? regulationUrl,
    String? branchId,
    List<String> items = const [],
  }) async {
    calls.add('create');
    return ChecklistTemplate(id: '9', name: name);
  }

  @override
  Future<List<ChecklistRun>> getTodayRuns() async => const [];
  @override
  Future<List<ChecklistTemplate>> getTemplates({
    bool activeOnly = false,
  }) async => const [];
  @override
  Future<List<ChecklistSummaryRow>> getSummary() async => const [];

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

const _template = ChecklistTemplate(
  id: '5',
  name: 'Открытие',
  items: [
    ChecklistTemplateItem(id: '1', text: 'Свет'),
    ChecklistTemplateItem(id: '2', text: 'Касса', position: 1),
  ],
);

void main() {
  test('PATCH body clears empty fields and sends branch null for all', () {
    expect(
      checklistTemplatePatchBody(
        name: ' Открытие ',
        regulationText: '  ',
        regulationUrl: 'https://x',
        branchId: null,
      ),
      {
        'name': 'Открытие',
        'regulation_text': null,
        'regulation_url': 'https://x',
        'branch_id': null,
      },
    );
    expect(
      checklistTemplatePatchBody(name: 'a', branchId: '3')['branch_id'],
      3,
    );
  });

  test('items diff: removed ids and new texts with their position', () {
    final diff = checklistItemsDiff(_template.items, [
      (id: '2', text: 'Касса'),
      (id: null, text: 'Витрина'),
    ]);
    expect(diff.remove, ['1']);
    expect(diff.add.single, (text: 'Витрина', position: 1));
  });

  test('saving an edit updates in place instead of creating a copy', () async {
    final repo = _Repo();
    final bloc = ChecklistsBloc(repo);
    bloc.add(
      const UpdateTemplateRequested(
        template: _template,
        name: 'Открытие смены',
        items: [(id: '2', text: 'Касса'), (id: null, text: 'Витрина')],
      ),
    );
    final state = await bloc.stream.firstWhere((s) => s is ChecklistsLoaded);
    expect(repo.calls, [
      'patch 5 Открытие смены',
      'delete 1',
      'add 5 Витрина@1',
    ]);
    expect(
      (state as ChecklistsLoaded).actionMessage,
      'checklists_toast_template_updated',
    );
    await bloc.close();
  });

  test('Meta: voice marker and Instagram post links', () {
    expect(metaIsVoice('[Голосовое сообщение]'), isTrue);
    expect(metaIsVoice('Видео'), isFalse);
    expect(
      metaIsInstagramPost('https://www.instagram.com/reel/AbC_1-x/'),
      isTrue,
    );
    expect(metaIsInstagramPost('https://instagram.com/p/XYZ'), isTrue);
    expect(metaIsInstagramPost('https://instagram.com/somebody'), isFalse);
  });
}
