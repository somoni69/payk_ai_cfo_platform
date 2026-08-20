import '../../../core/network/api_client.dart';
import '../../../core/network/user_facing_error.dart';
import '../../../core/network/expiring_request_cache.dart';
import '../domain/crm_models.dart';
import '../domain/crm_repository.dart';

/// CRM API: `/crm/*` (OpenAPI + web Payk-Ecosystem parity).
class ApiCrmRepository implements CrmRepository {
  final ApiClient _apiClient = ApiClient();
  final _clientsByKey = <String, ExpiringRequestCache<ClientsPage>>{};
  final _dealsCache = ExpiringRequestCache<List<CrmDeal>>();
  final _statsCache = ExpiringRequestCache<CrmStatsData>();
  final _loyaltyCache = ExpiringRequestCache<List<LoyaltySummaryRow>>();
  final _reactivationCache = ExpiringRequestCache<List<CrmClient>>();
  final _churnCache = ExpiringRequestCache<List<CrmClient>>();
  final _birthdaysCache = ExpiringRequestCache<List<BirthdayRow>>();

  String? _dealsCacheKey;

  int _requirePositiveId(String value, String fieldName) {
    final id = int.tryParse(value);
    if (id == null || id <= 0) {
      throw ArgumentError.value(value, fieldName, ErrorKeys.invalidId);
    }
    return id;
  }

  double _toDouble(dynamic val) {
    if (val == null) return 0.0;
    if (val is num) return val.toDouble();
    return double.tryParse(val.toString()) ?? 0.0;
  }

  DateTime? _parseDate(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value.toUtc();
    if (value is String && value.isNotEmpty) {
      return DateTime.tryParse(value)?.toUtc();
    }
    return null;
  }

  CrmClient _mapClient(Map<String, dynamic> map) {
    return CrmClient(
      id: (map['id'] ?? '').toString(),
      fullName: map['full_name']?.toString() ?? '',
      phone: map['phone']?.toString(),
      email: map['email']?.toString(),
      birthDate: _parseDate(map['birth_date']),
      loyaltyLevel: map['loyalty_level']?.toString() ?? 'bronze',
      bonusPoints: _toDouble(map['bonus_points']),
      totalSpent: _toDouble(map['total_spent']),
      acquisitionCost: _toDouble(map['acquisition_cost']),
      purchasesCount: map['purchases_count'] is int
          ? map['purchases_count'] as int
          : int.tryParse('${map['purchases_count']}') ?? 0,
      lastPurchaseAt: _parseDate(map['last_purchase_at']),
      note: map['note']?.toString(),
      createdAt: _parseDate(map['created_at']) ?? DateTime.now().toUtc(),
      roi: map['roi'] != null ? _toDouble(map['roi']) : null,
      churnRisk: map['churn_risk'] == true,
    );
  }

  CrmDeal _mapDeal(Map<String, dynamic> map) {
    return CrmDeal(
      id: (map['id'] ?? '').toString(),
      clientId: (map['client_id'] ?? '').toString(),
      title: map['title']?.toString() ?? '',
      amount: _toDouble(map['amount']),
      stage: map['stage']?.toString() ?? 'lead',
      createdAt: _parseDate(map['created_at']) ?? DateTime.now().toUtc(),
      clientName: map['client_name']?.toString(),
      expectedClose: _parseDate(map['expected_close']),
    );
  }

  void _invalidateMutations() {
    for (final cache in _clientsByKey.values) {
      cache.invalidate();
    }
    _clientsByKey.clear();
    _dealsCache.invalidate();
    _statsCache.invalidate();
    _loyaltyCache.invalidate();
    _reactivationCache.invalidate();
    _churnCache.invalidate();
    _birthdaysCache.invalidate();
    _dealsCacheKey = null;
  }

  @override
  Future<ClientsPage> getClients({
    ClientListFilters filters = const ClientListFilters(),
    bool forceRefresh = false,
  }) {
    final key =
        '${filters.query ?? ''}|${filters.level ?? ''}|${filters.page}|${filters.size}';
    final cache = _clientsByKey.putIfAbsent(
      key,
      ExpiringRequestCache<ClientsPage>.new,
    );
    return cache.get(() => _fetchClients(filters), forceRefresh: forceRefresh);
  }

  Future<ClientsPage> _fetchClients(ClientListFilters filters) async {
    try {
      final params = <String, dynamic>{
        'page': filters.page,
        'size': filters.size,
      };
      final q = filters.query?.trim();
      if (q != null && q.isNotEmpty) params['q'] = q;
      if (filters.level != null && filters.level!.isNotEmpty) {
        params['level'] = filters.level;
      }

      final response = await _apiClient.dio.get(
        '/crm/clients',
        queryParameters: params,
      );
      final dataMap = response.data as Map<String, dynamic>;
      final list = (dataMap['items'] ?? []) as List<dynamic>;
      return ClientsPage(
        items: list
            .map((item) => _mapClient(item as Map<String, dynamic>))
            .toList(),
        total: dataMap['total'] is int
            ? dataMap['total'] as int
            : int.tryParse('${dataMap['total']}') ?? list.length,
        page: dataMap['page'] is int ? dataMap['page'] as int : filters.page,
        size: dataMap['size'] is int ? dataMap['size'] as int : filters.size,
      );
    } catch (e) {
      throw Exception(userFacingError(e, fallback: ErrorKeys.loadFailed));
    }
  }

  @override
  Future<CrmClient> getClient(String id) async {
    try {
      final response = await _apiClient.dio.get(
        '/crm/clients/${_requirePositiveId(id, 'id')}',
      );
      return _mapClient(response.data as Map<String, dynamic>);
    } catch (e) {
      throw Exception(userFacingError(e, fallback: ErrorKeys.loadFailed));
    }
  }

  @override
  Future<List<CrmDeal>> getDeals({
    String? stage,
    String? clientId,
    bool forceRefresh = false,
  }) {
    final key = '${stage ?? ''}|${clientId ?? ''}';
    if (forceRefresh || key != _dealsCacheKey) {
      _dealsCache.invalidate();
      _dealsCacheKey = key;
    }
    return _dealsCache.get(
      () => _fetchDeals(stage: stage, clientId: clientId),
      forceRefresh: forceRefresh,
    );
  }

  Future<List<CrmDeal>> _fetchDeals({String? stage, String? clientId}) async {
    try {
      final params = <String, dynamic>{};
      if (stage != null && stage.isNotEmpty) params['stage'] = stage;
      if (clientId != null && clientId.isNotEmpty) {
        params['client_id'] = _requirePositiveId(clientId, 'clientId');
      }
      final response = await _apiClient.dio.get(
        '/crm/deals',
        queryParameters: params.isEmpty ? null : params,
      );
      final list = response.data as List<dynamic>;
      return list
          .map((item) => _mapDeal(item as Map<String, dynamic>))
          .toList();
    } catch (e) {
      throw Exception(userFacingError(e, fallback: ErrorKeys.loadFailed));
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
      throw Exception(userFacingError(e, fallback: ErrorKeys.loadFailed));
    }
  }

  @override
  Future<CrmClient> createClient(CrmClient client) async {
    try {
      final payload = <String, dynamic>{
        'full_name': client.fullName,
        if (client.phone != null) 'phone': client.phone,
        if (client.email != null) 'email': client.email,
        if (client.birthDate != null)
          'birth_date': client.birthDate!.toIso8601String().split('T').first,
        'acquisition_cost': client.acquisitionCost,
        if (client.note != null) 'note': client.note,
      };
      final response = await _apiClient.dio.post('/crm/clients', data: payload);
      _invalidateMutations();
      return _mapClient(response.data as Map<String, dynamic>);
    } catch (e) {
      throw Exception(userFacingError(e, fallback: ErrorKeys.saveFailed));
    }
  }

  @override
  Future<CrmClient> updateClient(
    String id, {
    String? fullName,
    String? phone,
    String? email,
    DateTime? birthDate,
    double? acquisitionCost,
    String? note,
    bool clearBirthDate = false,
  }) async {
    try {
      final payload = <String, dynamic>{};
      if (fullName != null) payload['full_name'] = fullName;
      if (phone != null) payload['phone'] = phone;
      if (email != null) payload['email'] = email;
      if (clearBirthDate) {
        payload['birth_date'] = null;
      } else if (birthDate != null) {
        payload['birth_date'] = birthDate.toIso8601String().split('T').first;
      }
      if (acquisitionCost != null) {
        payload['acquisition_cost'] = acquisitionCost;
      }
      if (note != null) payload['note'] = note;

      final response = await _apiClient.dio.patch(
        '/crm/clients/${_requirePositiveId(id, 'id')}',
        data: payload,
      );
      _invalidateMutations();
      return _mapClient(response.data as Map<String, dynamic>);
    } catch (e) {
      throw Exception(userFacingError(e, fallback: ErrorKeys.saveFailed));
    }
  }

  @override
  Future<void> deleteClient(String id) async {
    try {
      await _apiClient.dio.delete(
        '/crm/clients/${_requirePositiveId(id, 'id')}',
      );
      _invalidateMutations();
    } catch (e) {
      throw Exception(userFacingError(e, fallback: ErrorKeys.saveFailed));
    }
  }

  @override
  Future<CrmClient> registerPurchase(
    String clientId,
    double amount, {
    DateTime? occurredAt,
  }) async {
    try {
      final response = await _apiClient.dio.post(
        '/crm/clients/${_requirePositiveId(clientId, 'clientId')}/purchase',
        data: {
          'amount': amount,
          if (occurredAt != null)
            'occurred_at': occurredAt.toUtc().toIso8601String(),
        },
      );
      _invalidateMutations();
      return _mapClient(response.data as Map<String, dynamic>);
    } catch (e) {
      throw Exception(userFacingError(e, fallback: ErrorKeys.saveFailed));
    }
  }

  @override
  Future<CrmDeal> createDeal({
    required String clientId,
    required String title,
    required double amount,
    required String stage,
    DateTime? expectedClose,
  }) async {
    try {
      final payload = <String, dynamic>{
        'client_id': _requirePositiveId(clientId, 'clientId'),
        'title': title,
        'amount': amount,
        'stage': stage,
        if (expectedClose != null)
          'expected_close': expectedClose.toUtc().toIso8601String(),
      };
      final response = await _apiClient.dio.post('/crm/deals', data: payload);
      _invalidateMutations();
      return _mapDeal(response.data as Map<String, dynamic>);
    } catch (e) {
      throw Exception(userFacingError(e, fallback: ErrorKeys.saveFailed));
    }
  }

  @override
  Future<CrmDeal> updateDeal(
    String id, {
    String? title,
    double? amount,
    String? stage,
    DateTime? expectedClose,
    bool clearExpectedClose = false,
  }) async {
    try {
      final payload = <String, dynamic>{};
      if (title != null) payload['title'] = title;
      if (amount != null) payload['amount'] = amount;
      if (stage != null) payload['stage'] = stage;
      if (clearExpectedClose) {
        payload['expected_close'] = null;
      } else if (expectedClose != null) {
        payload['expected_close'] = expectedClose.toUtc().toIso8601String();
      }
      final response = await _apiClient.dio.patch(
        '/crm/deals/${_requirePositiveId(id, 'id')}',
        data: payload,
      );
      _invalidateMutations();
      return _mapDeal(response.data as Map<String, dynamic>);
    } catch (e) {
      throw Exception(userFacingError(e, fallback: ErrorKeys.saveFailed));
    }
  }

  @override
  Future<void> deleteDeal(String id) async {
    try {
      await _apiClient.dio.delete('/crm/deals/${_requirePositiveId(id, 'id')}');
      _invalidateMutations();
    } catch (e) {
      throw Exception(userFacingError(e, fallback: ErrorKeys.saveFailed));
    }
  }

  @override
  Future<List<LoyaltySummaryRow>> getLoyaltySummary({
    bool forceRefresh = false,
  }) => _loyaltyCache.get(_fetchLoyaltySummary, forceRefresh: forceRefresh);

  Future<List<LoyaltySummaryRow>> _fetchLoyaltySummary() async {
    try {
      final response = await _apiClient.dio.get('/crm/loyalty/summary');
      final list = response.data as List<dynamic>;
      return list.map((item) {
        final map = item as Map<String, dynamic>;
        return LoyaltySummaryRow(
          level: map['level']?.toString() ?? 'bronze',
          clients: map['clients'] is int
              ? map['clients'] as int
              : int.tryParse('${map['clients']}') ?? 0,
          totalSpent: _toDouble(map['total_spent']),
          bonusPoints: _toDouble(map['bonus_points']),
        );
      }).toList();
    } catch (e) {
      throw Exception(userFacingError(e, fallback: ErrorKeys.loadFailed));
    }
  }

  @override
  Future<LoyaltyTxnsPage> getLoyaltyTxns({
    String? clientId,
    int page = 1,
    int size = 30,
  }) async {
    try {
      final params = <String, dynamic>{'page': page, 'size': size};
      if (clientId != null && clientId.isNotEmpty) {
        params['client_id'] = _requirePositiveId(clientId, 'clientId');
      }
      final response = await _apiClient.dio.get(
        '/crm/loyalty/transactions',
        queryParameters: params,
      );
      final dataMap = response.data as Map<String, dynamic>;
      final list = (dataMap['items'] ?? []) as List<dynamic>;
      final items = list.map((item) {
        final map = item as Map<String, dynamic>;
        return LoyaltyTxn(
          id: (map['id'] ?? '').toString(),
          clientId: (map['client_id'] ?? '').toString(),
          points: _toDouble(map['points']),
          reason: map['reason']?.toString(),
          createdAt: _parseDate(map['created_at']) ?? DateTime.now().toUtc(),
        );
      }).toList();
      return LoyaltyTxnsPage(
        items: items,
        total: dataMap['total'] is int
            ? dataMap['total'] as int
            : int.tryParse('${dataMap['total']}') ?? items.length,
        page: dataMap['page'] is int ? dataMap['page'] as int : page,
        size: dataMap['size'] is int ? dataMap['size'] as int : size,
      );
    } catch (e) {
      throw Exception(userFacingError(e, fallback: ErrorKeys.loadFailed));
    }
  }

  @override
  Future<LoyaltyTxn> createLoyaltyTxn({
    required String clientId,
    required double points,
    String? reason,
  }) async {
    try {
      final response = await _apiClient.dio.post(
        '/crm/loyalty/transactions',
        data: {
          'client_id': _requirePositiveId(clientId, 'clientId'),
          'points': points,
          if (reason != null && reason.isNotEmpty) 'reason': reason,
        },
      );
      _invalidateMutations();
      final map = response.data as Map<String, dynamic>;
      return LoyaltyTxn(
        id: (map['id'] ?? '').toString(),
        clientId: (map['client_id'] ?? '').toString(),
        points: _toDouble(map['points']),
        reason: map['reason']?.toString(),
        createdAt: _parseDate(map['created_at']) ?? DateTime.now().toUtc(),
      );
    } catch (e) {
      throw Exception(userFacingError(e, fallback: ErrorKeys.saveFailed));
    }
  }

  @override
  Future<List<CrmClient>> getReactivation({
    int? days,
    bool forceRefresh = false,
  }) {
    return _reactivationCache.get(
      () => _fetchList('/crm/reactivation', days: days),
      forceRefresh: forceRefresh,
    );
  }

  @override
  Future<bool> sendReactivation(String clientId, String text) async {
    try {
      final response = await _apiClient.dio.post(
        '/crm/reactivation/${_requirePositiveId(clientId, 'clientId')}/send',
        data: {'text': text},
      );
      final map = response.data is Map
          ? response.data as Map
          : const <String, dynamic>{};
      return map['ok'] == true;
    } catch (e) {
      throw Exception(userFacingError(e, fallback: ErrorKeys.saveFailed));
    }
  }

  @override
  Future<List<CrmClient>> getChurn({int? days, bool forceRefresh = false}) {
    return _churnCache.get(
      () => _fetchList('/crm/churn', days: days),
      forceRefresh: forceRefresh,
    );
  }

  Future<List<CrmClient>> _fetchList(String path, {int? days}) async {
    try {
      final response = await _apiClient.dio.get(
        path,
        queryParameters: days != null ? {'days': days} : null,
      );
      final list = response.data as List<dynamic>;
      return list
          .map((item) => _mapClient(item as Map<String, dynamic>))
          .toList();
    } catch (e) {
      throw Exception(userFacingError(e, fallback: ErrorKeys.loadFailed));
    }
  }

  @override
  Future<ChurnAdvice> analyzeChurn(String clientId) async {
    try {
      final response = await _apiClient.dio.post(
        '/crm/churn/${_requirePositiveId(clientId, 'clientId')}/analyze',
        options: ApiClient.longRunningOptions(),
      );
      final map = response.data as Map<String, dynamic>;
      return ChurnAdvice(
        clientId: (map['client_id'] ?? clientId).toString(),
        risk: map['risk'] == true,
        advice: map['advice']?.toString() ?? '',
      );
    } catch (e) {
      throw Exception(userFacingError(e, fallback: ErrorKeys.loadFailed));
    }
  }

  @override
  Future<List<BirthdayRow>> getBirthdays({
    int withinDays = 30,
    bool forceRefresh = false,
  }) {
    return _birthdaysCache.get(
      () => _fetchBirthdays(withinDays),
      forceRefresh: forceRefresh,
    );
  }

  Future<List<BirthdayRow>> _fetchBirthdays(int withinDays) async {
    try {
      final response = await _apiClient.dio.get(
        '/crm/birthdays',
        queryParameters: {'within_days': withinDays},
      );
      final data = response.data;
      final list = data is List
          ? data
          : (data is Map ? [data] : const <dynamic>[]);
      return list.map((item) {
        final map = item as Map<String, dynamic>;
        return BirthdayRow(
          id: (map['id'] ?? '').toString(),
          fullName: map['full_name']?.toString() ?? '',
          phone: map['phone']?.toString(),
          birthDate: _parseDate(map['birth_date']) ?? DateTime.now().toUtc(),
          daysUntil: map['days_until'] is int
              ? map['days_until'] as int
              : int.tryParse('${map['days_until']}') ?? 0,
          turning: map['turning'] is int
              ? map['turning'] as int
              : int.tryParse('${map['turning']}'),
        );
      }).toList();
    } catch (e) {
      throw Exception(userFacingError(e, fallback: ErrorKeys.loadFailed));
    }
  }
}
