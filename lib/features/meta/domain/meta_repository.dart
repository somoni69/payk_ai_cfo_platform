import 'meta_models.dart';

abstract class MetaRepository {
  Future<MetaStatus> getStatus();
  Future<List<MetaThread>> getThreads({String? channel});
  Future<List<MetaMessage>> getMessages(int threadId);
  Future<MetaMessage> reply(int threadId, String text);
  Future<String> suggestReply(int threadId);

  /// Photo, video or document (`POST /meta/threads/{id}/attachments`).
  Future<MetaMessage> sendAttachment(
    int threadId, {
    required String filename,
    required List<int> bytes,
    String caption = '',
  });

  /// «Печатает…» for the peer (`POST /meta/threads/{id}/typing`).
  Future<void> sendTyping(int threadId, {required bool on});

  /// Unread total across the store's dialogs (`GET /meta/unread`).
  Future<int> getUnreadTotal();

  /// Location pin (`POST /meta/threads/{id}/location`).
  Future<MetaMessage> sendLocation(int threadId, MetaPlace place);

  /// Link dialog to CRM client (`POST /meta/threads/{id}/link`).
  Future<MetaThread> linkClient(int threadId, int clientId);

  /// Delete the whole thread. Server allows this only for director and owner.
  Future<void> deleteThread(int threadId);

  Future<List<MetaStage>> getStages();
  Future<List<MetaStaff>> getStaff();
  Future<MetaThread> setThreadStage(int threadId, int stageId);
  Future<MetaThread> setThreadAssignee(int threadId, int? userId);

  Future<List<MetaComment>> getComments({bool onlyNew = false});
  Future<MetaComment> replyComment(int id, String text);
  Future<({int threadId, MetaComment comment})> dmComment(int id, String text);
  Future<void> markCommentsSeen();
  Future<CommentSettings> getCommentSettings();
  Future<CommentSettings> setCommentAi(bool enabled);

  Future<MetaAnalytics> getAnalytics({
    required DateTime since,
    required DateTime until,
    String? channel,
    String? assignee,
  });

  Future<ThreadCard> getThreadCard(int threadId);
  Future<List<CardHistoryEntry>> getThreadHistory(int threadId);
  Future<ThreadCard> updateCardClient(int threadId, CardClientInput input);
  Future<ThreadCard> createCardDeal(
    int threadId, {
    required String title,
    required String amount,
    required String stage,
  });
  Future<ThreadCard> updateCardDeal(int threadId, int dealId, String stage);
  Future<ThreadCard> rejectThread(int threadId, String? reason);

  Future<List<ThreadTask>> getThreadTasks(int threadId);
  Future<ThreadTask> createThreadTask(
    int threadId, {
    required String title,
    String? dueDate,
    int? assigneeId,
  });
  Future<ThreadTask> finishThreadTask(int threadId, int taskId);
}
