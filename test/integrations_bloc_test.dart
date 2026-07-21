import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:payk_ai_cfo_platform/features/integrations/bloc/integrations_bloc.dart';
import 'package:payk_ai_cfo_platform/features/integrations/bloc/integrations_event.dart';
import 'package:payk_ai_cfo_platform/features/integrations/bloc/integrations_state.dart';
import 'package:payk_ai_cfo_platform/features/integrations/domain/integrations_models.dart';
import 'package:payk_ai_cfo_platform/features/integrations/domain/integrations_repository.dart';

class MockIntegrationsTestRepository implements IntegrationsRepository {
  bool shouldFail = false;
  Completer<void>? loadGate;
  int statusReads = 0;
  int logReads = 0;

  @override
  Future<List<IntegrationInfo>> getIntegrationsStatus({
    bool forceRefresh = false,
  }) async {
    statusReads++;
    if (shouldFail) throw Exception('Status failed');
    final gate = loadGate;
    if (gate != null) await gate.future;
    return [
      const IntegrationInfo(
        system: '1c',
        name: '1C Integration',
        available: true,
        canSync: true,
      ),
    ];
  }

  @override
  Future<List<SyncLog>> getSyncLogs({bool forceRefresh = false}) async {
    logReads++;
    if (shouldFail) throw Exception('Logs failed');
    final gate = loadGate;
    if (gate != null) await gate.future;
    return [
      SyncLog(
        id: '1',
        system: '1c',
        direction: 'inflow',
        success: true,
        records: 5,
        createdAt: DateTime.now(),
      ),
    ];
  }

  @override
  Future<SyncResult> triggerSync(String system) async {
    if (shouldFail) throw Exception('Sync trigger failed');
    return SyncResult(
      system: system,
      success: true,
      records: 5,
      message: 'Sync done',
    );
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

    test(
      'LoadIntegrationsData emits loading state and populated lists',
      () async {
        final expected = [
          isA<IntegrationsState>().having((s) => s.isLoading, 'loading', true),
          isA<IntegrationsState>()
              .having((s) => s.isLoading, 'loading', false)
              .having(
                (s) => s.integrations.first.name,
                'first integration name',
                '1C Integration',
              )
              .having(
                (s) => s.logs.first.records,
                'first log records count',
                5,
              ),
        ];

        expectLater(bloc.stream, emitsInOrder(expected));
        bloc.add(LoadIntegrationsData());
      },
    );

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
    test('reload during initial load shares the pending request', () async {
      final gate = Completer<void>();
      repository.loadGate = gate;
      bloc.add(const LoadIntegrationsData());

      await Future<void>.delayed(const Duration(milliseconds: 20));
      var completed = false;
      final first = bloc.reload();
      final second = bloc.reload();
      expect(identical(first, second), true);
      first.then((_) => completed = true);

      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(repository.statusReads, 1);
      expect(repository.logReads, 1);
      expect(completed, false);

      gate.complete();
      await Future.wait<void>([first, second]);

      expect(completed, true);
      expect(bloc.state.integrations, isNotEmpty);
      expect(bloc.state.logs, isNotEmpty);
    });
  });
}
