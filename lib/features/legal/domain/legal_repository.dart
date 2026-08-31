import 'legal_models.dart';

abstract class LegalRepository {
  /// Получить шаблоны договоров
  Future<List<ContractTemplate>> getTemplates({bool forceRefresh = false});

  /// Сгенерировать договор на основе заполненного шаблона
  Future<GeneratedContract> generateContract(
    String templateId,
    Map<String, String> data,
  );

  /// Получить законы РТ (База законов)
  Future<List<Law>> getLaws({bool forceRefresh = false});

  /// Получить сроки сдачи отчетностей / уплаты налогов
  Future<List<LegalDeadline>> getDeadlines({bool forceRefresh = false});

  /// Обновить статус сдачи (выполнено / не выполнено)
  Future<LegalDeadline> updateDeadlineStatus(String deadlineId, bool isDone);

  /// Запрос к ИИ-Юристу
  Future<String> askAiLawyer(String question);

  Future<Law> createLaw({
    required String title,
    required String body,
    String? category,
  });

  Future<void> deleteLaw(String id);

  Future<LegalDeadline> createDeadline({
    required String title,
    required String type,
    required DateTime dueDate,
    String? amount,
    String? note,
  });

  Future<ContractTemplate> createTemplate({
    required String name,
    required String body,
    String? category,
  });

  Future<ContractTemplate> updateTemplate({
    required String id,
    String? name,
    String? body,
    String? category,
  });

  Future<void> deleteTemplate(String id);

  Future<List<int>> exportGeneratedContract(String contractId);
}

abstract interface class CancellableLegalRepository {
  void cancelPendingRequests();
}
