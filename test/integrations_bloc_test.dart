import 'package:flutter_test/flutter_test.dart';
import 'package:payk_ai_cfo_platform/features/integrations/bloc/integrations_bloc.dart';
import 'package:payk_ai_cfo_platform/features/integrations/bloc/integrations_event.dart';
import 'package:payk_ai_cfo_platform/features/integrations/bloc/integrations_state.dart';
import 'package:payk_ai_cfo_platform/features/integrations/domain/integrations_models.dart';
import 'package:payk_ai_cfo_platform/features/integrations/domain/integrations_repository.dart';

class MockIntegrationsTestRepository implements IntegrationsRepository {
  bool shouldFail = false;

  @override
  Future<List<IntegrationInfo>> getIntegrationsStatus() async {
    if (shouldFail) throw Exception('Status failed');
    return [
      const IntegrationInfo(system: '1c', name: '1C Integration', available: true, canSync: true),
    ];
  }

  @override
  Future<List<SyncLog>> getSyncLogs() async {
    if (shouldFail) throw Exception('Logs failed');
    return [
      SyncLog(id: '1', system: '1c', direction: 'inflow', success: true, records: 5, createdAt: DateTime.now()),
    ];
  }

  @override
  Future<SyncResult> triggerSync(String system) async {
    if (shouldFail) throw Exception('Sync trigger failed');
    return SyncResult(system: system, success: true, records: 5, message: 'Sync done');
  }
}

void main() {
  group('IntegrationsBloc Unit Tests', () {
    late MockIntegrationsTestRepository repository;
    late IntegrationsBloc bloc;

    setUp(() {
      repository = MockIntegrationsTestRepository();
      bloc = IntegrationsBloc(repository);
    });

    tearDown(() {
      bloc.close();
    });

    test('Initial state is empty IntegrationsState', () {
      expect(bloc.state.integrations, isEmpty);
      expect(bloc.state.logs, isEmpty);
      expect(bloc.state.isLoading, false);
    });

    test('LoadIntegrationsData emits loading state and populated lists', () async {
      final expected = [
        isA<IntegrationsState>().having((s) => s.isLoading, 'loading', true),
        isA<IntegrationsState>()
            .having((s) => s.isLoading, 'loading', false)
            .having((s) => s.integrations.first.name, 'first integration name', '1C Integration')
            .having((s) => s.logs.first.records, 'first log records count', 5),
      ];

      expectLater(bloc.stream, emitsInOrder(expected));
      bloc.add(LoadIntegrationsData());
    });

    test('TriggerSyncRequested fires sync and reloads logs', () async {
      final expected = [
        isA<IntegrationsState>().having((s) => s.isSyncing, 'isSyncing', true),
        isA<IntegrationsState>()
            .having((s) => s.isSyncing, 'isSyncing', false)
            .having((s) => s.syncMessage, 'sync message', 'Sync done'),
      ];

      expectLater(bloc.stream, emitsInOrder(expected));
      bloc.add(const TriggerSyncRequested('1c'));
    });
  });
}
