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

  bool shouldFail = false;

  @override
  Future<List<CrmClient>> getClients({bool forceRefresh = false}) async {
    if (shouldFail) throw Exception('Get clients error');
    return List.from(clients);
  }

  @override
  Future<List<CrmDeal>> getDeals({bool forceRefresh = false}) async {
    if (shouldFail) throw Exception('Get deals error');
    return List.from(deals);
  }

  @override
  Future<CrmStatsData> getCrmStats({bool forceRefresh = false}) async {
    if (shouldFail) throw Exception('Get CRM stats error');
    return stats;
  }

  @override
  Future<CrmClient> createClient(CrmClient client) async {
    if (shouldFail) throw Exception('Create client error');
    final newClient = client.copyWith(id: (clients.length + 1).toString());
    clients.add(newClient);
    return newClient;
  }

  @override
  Future<CrmDeal> createDeal(
    String clientId,
    String title,
    double amount,
    String stage,
  ) async {
    if (shouldFail) throw Exception('Create deal error');
    final newDeal = CrmDeal(
      id: (deals.length + 1).toString(),
      clientId: clientId,
      title: title,
      amount: amount,
      stage: stage,
      createdAt: DateTime.now(),
      clientName: 'Test Client',
    );
    deals.add(newDeal);
    return newDeal;
  }
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
            .having((s) => s.stats.clientsTotal, 'stats total clients', 1),
      ];

      expectLater(bloc.stream, emitsInOrder(expected));
      bloc.add(LoadCrmData());
    });

    test(
      'CreateClientRequested appends client and updates stats cost',
      () async {
        bloc.add(LoadCrmData());
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

        final List<CrmState> emitted = [];
        final sub = bloc.stream.listen(emitted.add);

        await Future.delayed(const Duration(milliseconds: 50));
        sub.cancel();

        expect(emitted, isNotEmpty);
        final loaded = emitted.first as CrmLoaded;
        expect(loaded.clients.length, 2);
        expect(loaded.clients.last.fullName, 'Зоир Тошев');
        expect(loaded.stats.cacTotal, 250.0); // 150 + 100
      },
    );

    test(
      'CreateDealRequested optimistically registers deal and loads real item',
      () async {
        bloc.add(LoadCrmData());
        await bloc.stream.firstWhere((s) => s is CrmLoaded);

        bloc.add(
          const CreateDealRequested(
            clientId: '1',
            title: 'Укладка плитки',
            amount: 2500.0,
            stage: 'proposal',
          ),
        );

        final List<CrmState> emitted = [];
        final sub = bloc.stream.listen(emitted.add);

        await Future.delayed(const Duration(milliseconds: 50));
        sub.cancel();

        expect(emitted, isNotEmpty);
        final firstLoaded = emitted.first as CrmLoaded;
        // В списке должен сразу появиться временный лид
        expect(
          firstLoaded.deals
              .firstWhere((d) => d.title == 'Укладка плитки')
              .amount,
          2500.0,
        );
      },
    );
  });
}
