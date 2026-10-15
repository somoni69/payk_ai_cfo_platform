import 'package:flutter_test/flutter_test.dart';
import 'package:payk_ai_cfo_platform/features/meta/cubit/meta_cubit.dart';
import 'package:payk_ai_cfo_platform/features/meta/domain/meta_models.dart';
import 'package:payk_ai_cfo_platform/features/meta/domain/meta_repository.dart';

class _FakeMetaRepository implements MetaRepository {
  MetaStatus status = const MetaStatus(connected: true);
  MetaPlace? sentPlace;
  String? sentFilename;
  String? sentCaption;
  bool failSend = false;

  MetaMessage _message(String text) => MetaMessage(
    id: 1,
    outgoing: true,
    text: text,
    createdAt: DateTime(2026, 10, 10, 12),
  );

  @override
  Future<MetaStatus> getStatus() async => status;

  @override
  Future<List<MetaThread>> getThreads({String? channel}) async => const [
    MetaThread(id: 7, channel: 'whatsapp', peerId: 'p1'),
  ];

  @override
  Future<List<MetaMessage>> getMessages(int threadId) async => const [];

  @override
  Future<MetaMessage> reply(int threadId, String text) async => _message(text);

  @override
  Future<String> suggestReply(int threadId) async => '';

  @override
  Future<MetaMessage> sendAttachment(
    int threadId, {
    required String filename,
    required List<int> bytes,
    String caption = '',
  }) async {
    if (failSend) throw Exception('error_server');
    sentFilename = filename;
    sentCaption = caption;
    return _message('Фото');
  }

  @override
  Future<MetaMessage> sendLocation(int threadId, MetaPlace place) async {
    sentPlace = place;
    return _message('Геолокация');
  }

  @override
  Future<MetaThread> linkClient(int threadId, int clientId) =>
      throw UnimplementedError();

  @override
  Future<void> deleteThread(int threadId) async {}

  @override
  Future<void> sendTyping(int threadId, {required bool on}) async {}

  @override
  Future<int> getUnreadTotal() async => 0;

  @override
  Future<List<MetaStage>> getStages() async => const [];

  @override
  Future<List<MetaStaff>> getStaff() async => const [];

  @override
  Future<MetaThread> setThreadStage(int threadId, int stageId) =>
      throw UnimplementedError();

  @override
  Future<MetaThread> setThreadAssignee(int threadId, int? userId) =>
      throw UnimplementedError();

  @override
  Future<List<MetaComment>> getComments({bool onlyNew = false}) async =>
      const [];

  @override
  Future<MetaComment> replyComment(int id, String text) =>
      throw UnimplementedError();

  @override
  Future<({int threadId, MetaComment comment})> dmComment(
    int id,
    String text,
  ) => throw UnimplementedError();

  @override
  Future<void> markCommentsSeen() async {}

  @override
  Future<CommentSettings> getCommentSettings() async => const CommentSettings(
    aiEnabled: false,
    aiAvailable: false,
    connected: false,
  );

  @override
  Future<CommentSettings> setCommentAi(bool enabled) =>
      throw UnimplementedError();

  @override
  Future<MetaAnalytics> getAnalytics({
    required DateTime since,
    required DateTime until,
    String? channel,
    String? assignee,
  }) => throw UnimplementedError();

  @override
  Future<ThreadCard> getThreadCard(int threadId) => throw UnimplementedError();

  @override
  Future<List<CardHistoryEntry>> getThreadHistory(int threadId) async =>
      const [];

  @override
  Future<ThreadCard> updateCardClient(int threadId, CardClientInput input) =>
      throw UnimplementedError();

  @override
  Future<ThreadCard> createCardDeal(
    int threadId, {
    required String title,
    required String amount,
    required String stage,
  }) => throw UnimplementedError();

  @override
  Future<ThreadCard> updateCardDeal(int threadId, int dealId, String stage) =>
      throw UnimplementedError();

  @override
  Future<ThreadCard> rejectThread(int threadId, String? reason) =>
      throw UnimplementedError();

  @override
  Future<List<ThreadTask>> getThreadTasks(int threadId) async => const [];

  @override
  Future<ThreadTask> createThreadTask(
    int threadId, {
    required String title,
    String? dueDate,
    int? assigneeId,
  }) => throw UnimplementedError();

  @override
  Future<ThreadTask> finishThreadTask(int threadId, int taskId) =>
      throw UnimplementedError();
}

void main() {
  test('local nine-digit numbers keep no plus and dial +992', () {
    expect(displayPhone('801600004'), '801600004');
    expect(displayPhone('992911050527'), '+992911050527');
    expect(displayPhone('+992911050527'), '+992911050527');
    expect(phoneHref('801600004'), 'tel:+992801600004');
    expect(phoneHref('992911050527'), 'tel:+992911050527');
    expect(phoneHref('+992 91 105 05 27'), 'tel:+992911050527');
    expect(phoneHref('  '), isNull);
  });

  test('MetaPlace parses the store point and rejects broken values', () {
    final place = MetaPlace.fromJson({'lat': 38.5, 'lng': 68.7, 'label': ' '});
    expect(place?.lat, 38.5);
    expect(place?.label, isNull);
    expect(MetaPlace.fromJson({'lat': '38.5', 'lng': 68.7}), isNull);
    expect(MetaPlace.fromJson(null), isNull);
  });

  test('attachment is appended to the open chat with its caption', () async {
    final repo = _FakeMetaRepository();
    final cubit = MetaCubit(repo);
    await cubit.load();
    await cubit.selectThread(cubit.state.threads.first);

    await cubit.sendAttachment(
      filename: 'a.jpg',
      bytes: const [1, 2, 3],
      caption: 'Цена',
    );

    expect(repo.sentFilename, 'a.jpg');
    expect(repo.sentCaption, 'Цена');
    expect(cubit.state.messages, hasLength(1));
    expect(cubit.state.isSending, isFalse);
    await cubit.close();
  });

  test('failed attachment shows an error and adds no message', () async {
    final repo = _FakeMetaRepository()..failSend = true;
    final cubit = MetaCubit(repo);
    await cubit.load();
    await cubit.selectThread(cubit.state.threads.first);

    await cubit.sendAttachment(filename: 'a.jpg', bytes: const [1]);

    expect(cubit.state.messages, isEmpty);
    expect(cubit.state.error, isNotNull);
    expect(cubit.state.isSending, isFalse);
    await cubit.close();
  });

  test('our address is sent only when the store has a saved point', () async {
    final repo = _FakeMetaRepository();
    final cubit = MetaCubit(repo);
    await cubit.load();
    await cubit.selectThread(cubit.state.threads.first);

    await cubit.sendOurAddress();
    expect(repo.sentPlace, isNull);

    repo.status = const MetaStatus(
      connected: true,
      place: MetaPlace(lat: 38.5, lng: 68.7, label: 'Магазин'),
    );
    await cubit.load();
    await cubit.sendOurAddress();

    expect(repo.sentPlace?.label, 'Магазин');
    expect(cubit.state.messages, hasLength(1));
    await cubit.close();
  });
}
