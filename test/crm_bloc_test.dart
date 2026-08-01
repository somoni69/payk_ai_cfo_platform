import 'package:flutter_test/flutter_test.dart';
import 'package:payk_ai_cfo_platform/features/crm/bloc/crm_bloc.dart';
import 'package:payk_ai_cfo_platform/features/crm/bloc/crm_event.dart';
import 'package:payk_ai_cfo_platform/features/crm/bloc/crm_state.dart';
import 'package:payk_ai_cfo_platform/features/crm/domain/crm_models.dart';
import 'package:payk_ai_cfo_platform/features/crm/domain/crm_repository.dart';

class MockCrmRepository implements CrmRepository {
  List<CrmClient> clients = [];
  List<CrmDeal> deals = [];
  CrmStatsData stats = const CrmStatsData(
    clientsTotal: 0,
    activeClients: 0,
    ltvTotal: 0.0,
    cacTotal: 0.0,
    churnCount: 0,
    reactivationCount: 0,
  );
  List<LoyaltySummaryRow> loyalty = const [];
  List<CrmClient> reactivation = const [];
  List<CrmClient> churn = const [];
  List<BirthdayRow> birthdays = const [];
  List<LoyaltyTxn> loyaltyTxns = const [];

  bool shouldFail = false;

  @override
  Future<ClientsPage> getClients({
    ClientListFilters filters = const ClientListFilters(),
    bool forceRefresh = false,
  }) async {
    if (shouldFail) throw Exception('error_load_failed');
    return ClientsPage(
      items: List.from(clients),
      total: clients.length,
      page: filters.page,
      size: filters.size,
    );
  }

  @override
  Future<CrmClient> getClient(String id) async {
    return clients.firstWhere((c) => c.id == id);
  }

  @override
  Future<List<CrmDeal>> getDeals({
    String? stage,
    String? clientId,
    bool forceRefresh = false,
  }) async {
    if (shouldFail) throw Exception('error_load_failed');
    var list = List<CrmDeal>.from(deals);
    if (clientId != null) {
      list = list.where((d) => d.clientId == clientId).toList();
    }
    if (stage != null) {
      list = list.where((d) => d.stage == stage).toList();
    }
    return list;
  }

  @override
  Future<CrmStatsData> getCrmStats({bool forceRefresh = false}) async {
    if (shouldFail) throw Exception('error_load_failed');
    return stats;
  }

  @override
  Future<CrmClient> createClient(CrmClient client) async {
    if (shouldFail) throw Exception('error_save_failed');
    final newClient = client.copyWith(id: (clients.length + 1).toString());
    clients.add(newClient);
    stats = CrmStatsData(
      clientsTotal: stats.clientsTotal + 1,
      activeClients: stats.activeClients + 1,
      ltvTotal: stats.ltvTotal,
      cacTotal: stats.cacTotal + newClient.acquisitionCost,
      roi: stats.roi,
      churnCount: stats.churnCount,
      reactivationCount: stats.reactivationCount,
    );
    return newClient;
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
    final idx = clients.indexWhere((c) => c.id == id);
    final updated = clients[idx].copyWith(
      fullName: fullName,
      phone: phone,
      email: email,
      birthDate: birthDate,
      acquisitionCost: acquisitionCost,
      note: note,
      clearBirthDate: clearBirthDate,
    );
    clients[idx] = updated;
    return updated;
  }

  @override
  Future<void> deleteClient(String id) async {
    clients.removeWhere((c) => c.id == id);
  }

  @override
  Future<CrmClient> registerPurchase(String clientId, double amount) async {
    final idx = clients.indexWhere((c) => c.id == clientId);
    final c = clients[idx];
    final updated = c.copyWith(
      totalSpent: c.totalSpent + amount,
      purchasesCount: c.purchasesCount + 1,
      lastPurchaseAt: DateTime.now(),
    );
    clients[idx] = updated;
    return updated;
  }

  @override
  Future<CrmDeal> createDeal({
    required String clientId,
    required String title,
    required double amount,
    required String stage,
    DateTime? expectedClose,
  }) async {
    if (shouldFail) throw Exception('error_save_failed');
    final newDeal = CrmDeal(
      id: (deals.length + 1).toString(),
      clientId: clientId,
      title: title,
      amount: amount,
      stage: stage,
      createdAt: DateTime.now(),
      clientName: 'Test Client',
      expectedClose: expectedClose,
    );
    deals.add(newDeal);
    return newDeal;
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
    final idx = deals.indexWhere((d) => d.id == id);
    final updated = deals[idx].copyWith(
      title: title,
      amount: amount,
      stage: stage,
      expectedClose: expectedClose,
      clearExpectedClose: clearExpectedClose,
    );
    deals[idx] = updated;
    return updated;
  }

  @override
  Future<void> deleteDeal(String id) async {
    deals.removeWhere((d) => d.id == id);
  }

  @override
  Future<List<LoyaltySummaryRow>> getLoyaltySummary({
    bool forceRefresh = false,
  }) async =>
      List.from(loyalty);

  @override
  Future<List<LoyaltyTxn>> getLoyaltyTxns({
    String? clientId,
    int page = 1,
    int size = 50,
  }) async {
    if (clientId == null) return List.from(loyaltyTxns);
    return loyaltyTxns.where((t) => t.clientId == clientId).toList();
  }

  @override
  Future<LoyaltyTxn> createLoyaltyTxn({
    required String clientId,
    required double points,
    String? reason,
  }) async {
    final txn = LoyaltyTxn(
      id: '${loyaltyTxns.length + 1}',
      clientId: clientId,
      points: points,
      reason: reason,
      createdAt: DateTime.now(),
    );
    loyaltyTxns = [...loyaltyTxns, txn];
    return txn;
  }

  @override
  Future<List<CrmClient>> getReactivation({
    int? days,
    bool forceRefresh = false,
  }) async =>
      List.from(reactivation);

  @override
  Future<bool> sendReactivation(String clientId, String text) async => true;

  @override
  Future<List<CrmClient>> getChurn({
    int? days,
    bool forceRefresh = false,
  }) async =>
      List.from(churn);

  @override
  Future<ChurnAdvice> analyzeChurn(String clientId) async {
    return ChurnAdvice(clientId: clientId, risk: true, advice: 'Call client');
  }

  @override
  Future<List<BirthdayRow>> getBirthdays({
    int withinDays = 30,
    bool forceRefresh = false,
  }) async =>
      List.from(birthdays);
}

void main() {
  group('CrmBloc Unit Tests', () {
    late MockCrmRepository repository;
    late CrmBloc bloc;

    setUp(() {
      repository = MockCrmRepository();
      repository.clients = [
        CrmClient(
          id: '1',
          fullName: 'Олим Каримов',
          loyaltyLevel: 'silver',
          bonusPoints: 10.0,
          totalSpent: 1200.0,
          acquisitionCost: 150.0,
          purchasesCount: 4,
          createdAt: DateTime.now(),
          churnRisk: false,
        ),
      ];
      repository.deals = [
        CrmDeal(
          id: '1',
          clientId: '1',
          title: 'Поставка бетона',
          amount: 5000.0,
          stage: 'negotiation',
          createdAt: DateTime.now(),
          clientName: 'Олим Каримов',
        ),
      ];
      repository.stats = const CrmStatsData(
        clientsTotal: 1,
        activeClients: 1,
        ltvTotal: 1200.0,
        cacTotal: 150.0,
        churnCount: 0,
        reactivationCount: 0,
      );
      repository.loyalty = const [
        LoyaltySummaryRow(
          level: 'silver',
          clients: 1,
          totalSpent: 1200,
          bonusPoints: 10,
        ),
      ];
      bloc = CrmBloc(repository);
    });

    tearDown(() {
      bloc.close();
    });

    test('Initial state is CrmLoading', () {
      expect(bloc.state, isA<CrmLoading>());
    });

    test('LoadCrmData emits CrmLoaded with repository data', () async {
      final expected = [
        isA<CrmLoading>(),
        isA<CrmLoaded>()
            .having((s) => s.clients.length, 'clients count', 1)
            .having((s) => s.deals.length, 'deals count', 1)
            .having((s) => s.stats.clientsTotal, 'stats total clients', 1)
            .having((s) => s.loyaltySummary.length, 'loyalty rows', 1),
      ];

      expectLater(bloc.stream, emitsInOrder(expected));
      bloc.add(const LoadCrmData());
    });

    test('CreateClientRequested reloads clients after create', () async {
      bloc.add(const LoadCrmData());
      await bloc.stream.firstWhere((s) => s is CrmLoaded);

      bloc.add(
        CreateClientRequested(
          CrmClient(
            id: '',
            fullName: 'Зоир Тошев',
            loyaltyLevel: 'bronze',
            bonusPoints: 0,
            totalSpent: 0,
            acquisitionCost: 100.0,
            purchasesCount: 0,
            createdAt: DateTime.now(),
            churnRisk: false,
          ),
        ),
      );

      final loaded = await bloc.stream.firstWhere(
        (s) => s is CrmLoaded && s.clients.length == 2,
      ) as CrmLoaded;

      expect(loaded.clients.last.fullName, 'Зоир Тошев');
      expect(loaded.stats.cacTotal, 250.0);
      expect(loaded.successMessage, 'crm_success_client_created');
    });

    test('CreateDealRequested appends deal after reload', () async {
      bloc.add(const LoadCrmData());
      await bloc.stream.firstWhere((s) => s is CrmLoaded);

      bloc.add(
        const CreateDealRequested(
          clientId: '1',
          title: 'Укладка плитки',
          amount: 2500.0,
          stage: 'proposal',
        ),
      );

      final loaded = await bloc.stream.firstWhere(
        (s) =>
            s is CrmLoaded &&
            s.deals.any((d) => d.title == 'Укладка плитки'),
      ) as CrmLoaded;

      expect(
        loaded.deals.firstWhere((d) => d.title == 'Укладка плитки').amount,
        2500.0,
      );
      expect(loaded.successMessage, 'crm_success_deal_created');
    });
  });
}
