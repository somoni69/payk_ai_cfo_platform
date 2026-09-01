import 'package:flutter_test/flutter_test.dart';
import 'package:payk_ai_cfo_platform/features/network/bloc/network_bloc.dart';
import 'package:payk_ai_cfo_platform/features/network/bloc/network_event.dart';
import 'package:payk_ai_cfo_platform/features/network/bloc/network_state.dart';
import 'package:payk_ai_cfo_platform/features/network/domain/network_models.dart';
import 'package:payk_ai_cfo_platform/features/network/domain/network_repository.dart';

class FakeNetworkRepository implements NetworkRepository {
  List<NetworkStore> stores = [
    const NetworkStore(
      id: 1,
      name: 'Store 1',
      location: 'Location 1',
      isActive: true,
      usersCount: 5,
    ),
    const NetworkStore(
      id: 2,
      name: 'Store 2',
      location: 'Location 2',
      isActive: true,
      usersCount: 3,
    ),
  ];

  List<StoreSummaryRow> summary = [
    const StoreSummaryRow(
      storeId: 1,
      storeName: 'Store 1',
      isActive: true,
      revenue: 10000.0,
      expenses: 4000.0,
      profit: 6000.0,
      operationsCount: 150,
    ),
    const StoreSummaryRow(
      storeId: 2,
      storeName: 'Store 2',
      isActive: true,
      revenue: 8000.0,
      expenses: 3000.0,
      profit: 5000.0,
      operationsCount: 90,
    ),
  ];

  ActingStore? actingStore;

  @override
  Future<List<LoginStore>> fetchLoginStores() async {
    return stores
        .map((s) => LoginStore(id: s.id, name: s.name, location: s.location))
        .toList();
  }

  @override
  Future<List<NetworkStore>> fetchStores() async =>
      List<NetworkStore>.of(stores);

  @override
  Future<List<StoreSummaryRow>> fetchSummary({
    DateTime? dateFrom,
    DateTime? dateTo,
  }) async => List<StoreSummaryRow>.of(summary);

  @override
  Future<NetworkStore> createStore(StoreCreateInput input) async {
    final created = NetworkStore(
      id: stores.length + 1,
      name: input.name,
      location: input.location,
      isActive: true,
      usersCount: input.directorUsername != null ? 1 : 0,
    );
    stores.add(created);
    return created;
  }

  @override
  Future<NetworkStore> updateStore(
    int id, {
    String? name,
    String? location,
    bool? isActive,
  }) async {
    final index = stores.indexWhere((s) => s.id == id);
    if (index == -1) throw Exception('Store not found');
    final existing = stores[index];
    final updated = NetworkStore(
      id: existing.id,
      name: name ?? existing.name,
      location: location ?? existing.location,
      isActive: isActive ?? existing.isActive,
      usersCount: existing.usersCount,
    );
    stores[index] = updated;
    return updated;
  }

  @override
  Future<StoreDeleteResult> deleteStore(int id) async {
    final index = stores.indexWhere((s) => s.id == id);
    if (index == -1) throw Exception('Store not found');
    final removed = stores.removeAt(index);
    return StoreDeleteResult(
      deleted: true,
      deactivated: false,
      message: 'Магазин «${removed.name}» удален',
    );
  }

  @override
  Future<void> resetDirectorPassword(
    int id, {
    String? username,
    required String password,
  }) async {}

  @override
  Future<ActingStore> enterStore(int storeId) async {
    final store = stores.firstWhere((s) => s.id == storeId);
    actingStore = ActingStore(id: store.id, name: store.name);
    return actingStore!;
  }

  @override
  Future<void> leaveStore() async {
    actingStore = null;
  }

  @override
  Future<ActingStore?> getActingStore() async => actingStore;

  @override
  Future<void> clearActingStore() async {
    actingStore = null;
  }
}

void main() {
  group('Network Models & JSON Tests', () {
    test('LoginStore parses from and converts to JSON correctly', () {
      final json = {'id': 10, 'name': 'Филиал 1', 'location': 'Душанбе'};
      final store = LoginStore.fromJson(json);

      expect(store.id, 10);
      expect(store.name, 'Филиал 1');
      expect(store.location, 'Душанбе');
      expect(store.toJson(), json);
    });

    test('NetworkStore parses from and converts to JSON correctly', () {
      final json = {
        'id': 20,
        'name': 'Филиал 2',
        'location': 'Худжанд',
        'is_active': true,
        'users_count': 8,
        'operations_count': 12,
        'has_data': true,
      };
      final store = NetworkStore.fromJson(json);

      expect(store.id, 20);
      expect(store.name, 'Филиал 2');
      expect(store.location, 'Худжанд');
      expect(store.isActive, isTrue);
      expect(store.usersCount, 8);
      expect(store.operationsCount, 12);
      expect(store.hasData, isTrue);
      expect(store.toJson(), json);
    });

    test('StoreSummaryRow parses revenue and calculates profit fallback', () {
      final json = {
        'store_id': 1,
        'store_name': 'Store A',
        'is_active': true,
        'revenue': '15000.50',
        'expenses': 5000.50,
        'operations_count': 120,
      };
      final row = StoreSummaryRow.fromJson(json);

      expect(row.storeId, 1);
      expect(row.storeName, 'Store A');
      expect(row.revenue, 15000.50);
      expect(row.expenses, 5000.50);
      expect(row.profit, 10000.0);
      expect(row.operationsCount, 120);
    });

    test('NetworkLoaded calculates network totals accurately', () {
      const summary = [
        StoreSummaryRow(
          storeId: 1,
          storeName: 'S1',
          revenue: 10000,
          expenses: 3000,
          profit: 7000,
          operationsCount: 50,
        ),
        StoreSummaryRow(
          storeId: 2,
          storeName: 'S2',
          revenue: 20000,
          expenses: 7000,
          profit: 13000,
          operationsCount: 100,
        ),
      ];

      const state = NetworkLoaded(stores: [], summary: summary);

      expect(state.totalRevenue, 30000.0);
      expect(state.totalExpenses, 10000.0);
      expect(state.totalProfit, 20000.0);
      expect(state.totalOperations, 150);
    });
  });

  group('NetworkBloc Tests', () {
    late FakeNetworkRepository repository;
    late NetworkBloc bloc;

    setUp(() {
      repository = FakeNetworkRepository();
      bloc = NetworkBloc(repository);
    });

    tearDown(() async {
      await bloc.close();
    });

    test('initial state is NetworkLoading', () {
      expect(bloc.state, const NetworkLoading());
    });

    test('LoadNetworkData loads stores and summary correctly', () async {
      final stateFuture = bloc.stream.firstWhere((s) => s is NetworkLoaded);
      bloc.add(const LoadNetworkData());
      await stateFuture;

      expect(bloc.state, isA<NetworkLoaded>());
      final loaded = bloc.state as NetworkLoaded;
      expect(loaded.stores.length, 2);
      expect(loaded.summary.length, 2);
      expect(loaded.totalProfit, 11000.0);
    });

    test('CreateStoreRequested adds a new store to the network', () async {
      final loadFuture = bloc.stream.firstWhere((s) => s is NetworkLoaded);
      bloc.add(const LoadNetworkData());
      await loadFuture;

      final createFuture = bloc.stream.firstWhere(
        (s) => s is NetworkLoaded && s.actionMessage == 'network_store_created',
      );
      bloc.add(
        const CreateStoreRequested(
          input: StoreCreateInput(
            name: 'New Store 3',
            location: 'Location 3',
            directorUsername: 'dir3',
            directorPassword: 'password123',
            directorFullName: 'Director Three',
          ),
        ),
      );
      await createFuture;

      expect(bloc.state, isA<NetworkLoaded>());
      final loaded = bloc.state as NetworkLoaded;
      expect(loaded.stores.length, 3);
      expect(loaded.stores.last.name, 'New Store 3');
      expect(loaded.actionMessage, 'network_store_created');
    });

    test(
      'EnterStoreRequested and LeaveStoreRequested update acting store',
      () async {
        final loadFuture = bloc.stream.firstWhere((s) => s is NetworkLoaded);
        bloc.add(const LoadNetworkData());
        await loadFuture;

        final enterFuture = bloc.stream.firstWhere(
          (s) => s is NetworkLoaded && s.actionMessage == 'network_entered',
        );
        bloc.add(const EnterStoreRequested(storeId: 1));
        await enterFuture;

        var loaded = bloc.state as NetworkLoaded;
        expect(loaded.actingStore?.id, 1);
        expect(loaded.actingStore?.name, 'Store 1');
        expect(loaded.actionMessage, 'network_entered');

        final leaveFuture = bloc.stream.firstWhere(
          (s) => s is NetworkLoaded && s.actionMessage == 'network_left',
        );
        bloc.add(const LeaveStoreRequested());
        await leaveFuture;

        loaded = bloc.state as NetworkLoaded;
        expect(loaded.actingStore, isNull);
        expect(loaded.actionMessage, 'network_left');
      },
    );

    test(
      'UpdateStoreRequested, DeleteStoreRequested, ResetDirectorPasswordRequested work',
      () async {
        final loadFuture = bloc.stream.firstWhere((s) => s is NetworkLoaded);
        bloc.add(const LoadNetworkData());
        await loadFuture;

        final updateFuture = bloc.stream.firstWhere(
          (s) =>
              s is NetworkLoaded && s.actionMessage == 'network_store_updated',
        );
        bloc.add(
          const UpdateStoreRequested(
            storeId: 1,
            name: 'Store 1 Renamed',
            location: 'New Location',
            isActive: false,
          ),
        );
        await updateFuture;
        var loaded = bloc.state as NetworkLoaded;
        expect(
          loaded.stores.firstWhere((s) => s.id == 1).name,
          'Store 1 Renamed',
        );

        final pwdFuture = bloc.stream.firstWhere(
          (s) =>
              s is NetworkLoaded &&
              s.actionMessage == 'network_director_password_reset',
        );
        bloc.add(
          const ResetDirectorPasswordRequested(
            storeId: 1,
            password: 'new_password123',
          ),
        );
        await pwdFuture;

        final deleteFuture = bloc.stream.firstWhere(
          (s) =>
              s is NetworkLoaded && s.actionMessage == 'network_store_deleted',
        );
        bloc.add(const DeleteStoreRequested(storeId: 1));
        await deleteFuture;
        loaded = bloc.state as NetworkLoaded;
        expect(loaded.stores.any((s) => s.id == 1), isFalse);
      },
    );
  });
}
