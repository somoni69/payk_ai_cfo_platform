import '../../../core/network/api_client.dart';
import '../../../core/network/expiring_request_cache.dart';
import '../domain/crm_models.dart';
import '../domain/crm_repository.dart';

/// Конкретная реализация CRM репозитория для бэкенда PAYK.
class ApiCrmRepository implements CrmRepository {
  final ApiClient _apiClient = ApiClient();
  final _clientsCache = ExpiringRequestCache<List<CrmClient>>();
  final _dealsCache = ExpiringRequestCache<List<CrmDeal>>();
  final _statsCache = ExpiringRequestCache<CrmStatsData>();

  int _requirePositiveId(String value, String fieldName) {
    final id = int.tryParse(value);
    if (id == null || id <= 0) {
      throw ArgumentError.value(value, fieldName, 'Ожидается положительный ID');
    }
    return id;
  }

  double _toDouble(dynamic val) {
    if (val == null) return 0.0;
    if (val is num) return val.toDouble();
    return double.tryParse(val.toString()) ?? 0.0;
  }

  @override
  Future<List<CrmClient>> getClients({bool forceRefresh = false}) =>
      _clientsCache.get(_fetchClients, forceRefresh: forceRefresh);

  Future<List<CrmClient>> _fetchClients() async {
    try {
      final response = await _apiClient.dio.get(
        '/crm/clients',
        queryParameters: {'page': 1, 'size': 100},
      );
      final dataMap = response.data as Map<String, dynamic>;
      final list = (dataMap['items'] ?? []) as List<dynamic>;

      return list.map((item) {
        final map = item as Map<String, dynamic>;
        return CrmClient(
          id: (map['id'] ?? '').toString(),
          fullName: map['full_name'] ?? '',
          phone: map['phone']?.toString(),
          email: map['email']?.toString(),
          loyaltyLevel: map['loyalty_level']?.toString() ?? 'bronze',
          bonusPoints: _toDouble(map['bonus_points']),
          totalSpent: _toDouble(map['total_spent']),
          acquisitionCost: _toDouble(map['acquisition_cost']),
          purchasesCount: map['purchases_count'] ?? 0,
          note: map['note']?.toString(),
          createdAt: DateTime.parse(
            map['created_at'] ?? DateTime.now().toIso8601String(),
          ),
          roi: map['roi'] != null ? _toDouble(map['roi']) : null,
          churnRisk: map['churn_risk'] ?? false,
        );
      }).toList();
    } catch (e) {
      throw Exception('Не удалось загрузить клиентов: ${e.toString()}');
    }
  }

  @override
  Future<List<CrmDeal>> getDeals({bool forceRefresh = false}) =>
      _dealsCache.get(_fetchDeals, forceRefresh: forceRefresh);

  Future<List<CrmDeal>> _fetchDeals() async {
    try {
      final response = await _apiClient.dio.get('/crm/deals');
      final list = response.data as List<dynamic>;

      return list.map((item) {
        final map = item as Map<String, dynamic>;
        return CrmDeal(
          id: (map['id'] ?? '').toString(),
          clientId: (map['client_id'] ?? '').toString(),
          title: map['title'] ?? '',
          amount: _toDouble(map['amount']),
          stage: map['stage'] ?? 'lead',
          createdAt: DateTime.parse(
            map['created_at'] ?? DateTime.now().toIso8601String(),
          ),
          clientName: map['client_name']?.toString(),
        );
      }).toList();
    } catch (e) {
      throw Exception('Не удалось загрузить сделки: ${e.toString()}');
    }
  }

  @override
  Future<CrmStatsData> getCrmStats({bool forceRefresh = false}) =>
      _statsCache.get(_fetchCrmStats, forceRefresh: forceRefresh);

  Future<CrmStatsData> _fetchCrmStats() async {
    try {
      final response = await _apiClient.dio.get('/crm/stats');
      final map = response.data as Map<String, dynamic>;

      return CrmStatsData(
        clientsTotal: map['clients_total'] ?? 0,
        activeClients: map['active_clients'] ?? 0,
        ltvTotal: _toDouble(map['ltv_total']),
        cacTotal: _toDouble(map['cac_total']),
        roi: map['roi'] != null ? _toDouble(map['roi']) : null,
        churnCount: map['churn_count'] ?? 0,
        reactivationCount: map['reactivation_count'] ?? 0,
      );
    } catch (e) {
      throw Exception('Не удалось получить статистику CRM: ${e.toString()}');
    }
  }

  @override
  Future<CrmClient> createClient(CrmClient client) async {
    try {
      final payload = {
        'full_name': client.fullName,
        'phone': client.phone,
        'email': client.email,
        'acquisition_cost': client.acquisitionCost,
        'note': client.note,
      };

      final response = await _apiClient.dio.post('/crm/clients', data: payload);
      final map = response.data as Map<String, dynamic>;
      _clientsCache.invalidate();
      _statsCache.invalidate();

      return CrmClient(
        id: (map['id'] ?? '').toString(),
        fullName: map['full_name'] ?? '',
        phone: map['phone']?.toString(),
        email: map['email']?.toString(),
        loyaltyLevel: map['loyalty_level']?.toString() ?? 'bronze',
        bonusPoints: _toDouble(map['bonus_points']),
        totalSpent: _toDouble(map['total_spent']),
        acquisitionCost: _toDouble(map['acquisition_cost']),
        purchasesCount: map['purchases_count'] ?? 0,
        note: map['note']?.toString(),
        createdAt: DateTime.parse(
          map['created_at'] ?? DateTime.now().toIso8601String(),
        ),
        roi: map['roi'] != null ? _toDouble(map['roi']) : null,
        churnRisk: map['churn_risk'] ?? false,
      );
    } catch (e) {
      throw Exception('Не удалось добавить клиента: ${e.toString()}');
    }
  }

  @override
  Future<CrmDeal> createDeal(
    String clientId,
    String title,
    double amount,
    String stage,
  ) async {
    try {
      final payload = {
        'client_id': _requirePositiveId(clientId, 'clientId'),
        'title': title,
        'amount': amount,
        'stage': stage,
      };

      final response = await _apiClient.dio.post('/crm/deals', data: payload);
      final map = response.data as Map<String, dynamic>;
      _dealsCache.invalidate();
      _statsCache.invalidate();

      return CrmDeal(
        id: (map['id'] ?? '').toString(),
        clientId: (map['client_id'] ?? '').toString(),
        title: map['title'] ?? '',
        amount: _toDouble(map['amount']),
        stage: map['stage'] ?? 'lead',
        createdAt: DateTime.parse(
          map['created_at'] ?? DateTime.now().toIso8601String(),
        ),
        clientName: map['client_name']?.toString(),
      );
    } catch (e) {
      throw Exception('Не удалось создать сделку: ${e.toString()}');
    }
  }
}
