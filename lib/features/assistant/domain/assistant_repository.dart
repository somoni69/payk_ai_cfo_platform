import 'assistant_models.dart';

abstract class AssistantRepository {
  Future<List<AssistantMessage>> getHistory(String module, {int limit = 50});

  Future<String> ask({required String question, required String module});

  Future<void> clearHistory(String module);

  Future<AdviceResponse> getAdvice(String module, {required String lang});

  Future<AdviceResponse> generateAdvice(String module, {required String lang});
}
