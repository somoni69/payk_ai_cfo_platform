import 'crm_models.dart';

/// Абстрактный контракт для репозитория сделок и лидов.
abstract class CrmRepository {
  /// Получить полный список клиентов
  Future<List<CrmClient>> getClients();

  /// Получить список сделок
  Future<List<CrmDeal>> getDeals();

  /// Получить сводные показатели CRM
  Future<CrmStatsData> getCrmStats();

  /// Зарегистрировать нового клиента
  Future<CrmClient> createClient(CrmClient client);

  /// Открыть сделку
  Future<CrmDeal> createDeal(String clientId, String title, double amount, String stage);
}
