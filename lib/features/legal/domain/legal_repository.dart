import 'legal_models.dart';

abstract class LegalRepository {
  /// Получить шаблоны договоров
  Future<List<ContractTemplate>> getTemplates();

  /// Сгенерировать договор на основе заполненного шаблона
  Future<GeneratedContract> generateContract(String templateId, Map<String, String> data);

  /// Получить законы РТ (База законов)
  Future<List<Law>> getLaws();

  /// Получить сроки сдачи отчетностей / уплаты налогов
  Future<List<LegalDeadline>> getDeadlines();

  /// Обновить статус сдачи (выполнено / не выполнено)
  Future<LegalDeadline> updateDeadlineStatus(String deadlineId, bool isDone);

  /// Запрос к ИИ-Юристу
  Future<String> askAiLawyer(String question);
}
