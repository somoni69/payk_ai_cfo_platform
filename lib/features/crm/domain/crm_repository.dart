import 'crm_models.dart';

/// Контракт CRM: клиенты, воронка, лояльность, реактивация, отток, ДР.
abstract class CrmRepository {
  Future<ClientsPage> getClients({
    ClientListFilters filters = const ClientListFilters(),
    bool forceRefresh = false,
  });

  Future<CrmClient> getClient(String id);

  Future<List<CrmDeal>> getDeals({
    String? stage,
    String? clientId,
    bool forceRefresh = false,
  });

  Future<CrmStatsData> getCrmStats({bool forceRefresh = false});

  Future<CrmClient> createClient(CrmClient client);

  Future<CrmClient> updateClient(String id, {
    String? fullName,
    String? phone,
    String? email,
    DateTime? birthDate,
    double? acquisitionCost,
    String? note,
    bool clearBirthDate = false,
  });

  Future<void> deleteClient(String id);

  Future<CrmClient> registerPurchase(String clientId, double amount);

  Future<CrmDeal> createDeal({
    required String clientId,
    required String title,
    required double amount,
    required String stage,
    DateTime? expectedClose,
  });

  Future<CrmDeal> updateDeal(
    String id, {
    String? title,
    double? amount,
    String? stage,
    DateTime? expectedClose,
    bool clearExpectedClose = false,
  });

  Future<void> deleteDeal(String id);

  Future<List<LoyaltySummaryRow>> getLoyaltySummary({
    bool forceRefresh = false,
  });

  Future<List<LoyaltyTxn>> getLoyaltyTxns({
    String? clientId,
    int page = 1,
    int size = 50,
  });

  Future<LoyaltyTxn> createLoyaltyTxn({
    required String clientId,
    required double points,
    String? reason,
  });

  Future<List<CrmClient>> getReactivation({int? days, bool forceRefresh = false});

  Future<bool> sendReactivation(String clientId, String text);

  Future<List<CrmClient>> getChurn({int? days, bool forceRefresh = false});

  Future<ChurnAdvice> analyzeChurn(String clientId);

  Future<List<BirthdayRow>> getBirthdays({
    int withinDays = 30,
    bool forceRefresh = false,
  });
}
