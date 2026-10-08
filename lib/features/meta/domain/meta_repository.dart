import 'meta_models.dart';

abstract class MetaRepository {
  Future<MetaStatus> getStatus();
  Future<List<MetaThread>> getThreads({String? channel});
  Future<List<MetaMessage>> getMessages(int threadId);
  Future<MetaMessage> reply(int threadId, String text);
  Future<String> suggestReply(int threadId);

  /// Link dialog to CRM client (`POST /meta/threads/{id}/link`).
  Future<MetaThread> linkClient(int threadId, int clientId);

  /// Delete the whole thread. Server allows this only for director and owner.
  Future<void> deleteThread(int threadId);
}
