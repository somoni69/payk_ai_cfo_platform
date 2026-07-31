import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:payk_ai_cfo_platform/features/notifications/bloc/notifications_bloc.dart';
import 'package:payk_ai_cfo_platform/features/notifications/bloc/notifications_event.dart';
import 'package:payk_ai_cfo_platform/features/notifications/bloc/notifications_state.dart';
import 'package:payk_ai_cfo_platform/features/notifications/domain/notification_model.dart';
import 'package:payk_ai_cfo_platform/features/notifications/domain/notifications_repository.dart';

class _NotificationsTestRepository implements NotificationsRepository {
  final notifications = <AppNotification>[
    AppNotification(
      id: '1',
      title: 'Audit',
      description: 'Description',
      type: NotificationType.audit,
      severity: NotificationSeverity.critical,
      dateTime: DateTime(2026, 7, 18),
    ),
  ];

  Completer<List<AppNotification>>? loadGate;
  Completer<List<AppNotification>>? refreshGate;
  final Map<String, Completer<void>> markGates = {};
  bool failRefresh = false;
  bool failMarkAsRead = false;
  int loadReads = 0;
  int refreshReads = 0;

  @override
  Future<List<AppNotification>> getNotifications() async {
    loadReads++;
    final gate = loadGate;
    if (gate != null) return gate.future;
    return List<AppNotification>.from(notifications);
  }

  @override
  Future<List<AppNotification>> refreshNotifications() async {
    refreshReads++;
    if (failRefresh) throw Exception('private backend detail');
    final gate = refreshGate;
    if (gate != null) return gate.future;
    return List<AppNotification>.from(notifications);
  }

  @override
  Future<void> markAsRead(String id) async {
    if (failMarkAsRead) throw Exception('private backend detail');
    final gate = markGates[id];
    if (gate != null) await gate.future;
  }
}

void main() {
  group('NotificationsBloc', () {
    late _NotificationsTestRepository repository;
    late NotificationsBloc bloc;

    setUp(() {
      repository = _NotificationsTestRepository();
      bloc = NotificationsBloc(repository);
    });

    tearDown(() async {
      await bloc.close();
    });

    test('force refresh supersedes an older in-flight load', () async {
      final loadGate = Completer<List<AppNotification>>();
      final refreshGate = Completer<List<AppNotification>>();
      repository
        ..loadGate = loadGate
        ..refreshGate = refreshGate;
      final first = Completer<void>();
      final second = Completer<void>();

      bloc
        ..add(LoadNotifications(completion: first))
        ..add(LoadNotifications(forceRefresh: true, completion: second));

      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(repository.loadReads, 1);
      expect(repository.refreshReads, 1);

      final refreshed = AppNotification(
        id: '2',
        title: 'Latest',
        description: 'Latest notification',
        type: NotificationType.aiAdvice,
        severity: NotificationSeverity.info,
        dateTime: DateTime(2026, 7, 20),
      );
      refreshGate.complete([refreshed]);
      await second.future;

      expect((bloc.state as NotificationsLoaded).notifications.single.id, '2');

      loadGate.complete(List<AppNotification>.from(repository.notifications));
      await first.future;

      expect((bloc.state as NotificationsLoaded).notifications.single.id, '2');
    });

    test(
      'failed refresh keeps loaded notifications and hides details',
      () async {
        final initialLoad = bloc.stream.firstWhere(
          (state) => state is NotificationsLoaded,
        );
        bloc.add(const LoadNotifications());
        await initialLoad;

        repository.failRefresh = true;
        final completion = Completer<void>();
        bloc.add(LoadNotifications(forceRefresh: true, completion: completion));
        await completion.future;

        final state = bloc.state as NotificationsLoaded;
        expect(state.notifications, hasLength(1));
        expect(state.errorMessage, contains('Проверьте соединение'));
        expect(state.errorMessage, isNot(contains('private backend detail')));
      },
    );

    test('failed mark-as-read keeps the current list', () async {
      final initialLoad = bloc.stream.firstWhere(
        (state) => state is NotificationsLoaded,
      );
      bloc.add(const LoadNotifications());
      await initialLoad;

      repository.failMarkAsRead = true;
      final failed = bloc.stream.firstWhere(
        (state) => state is NotificationsLoaded && state.errorMessage != null,
      );
      bloc.add(const MarkNotificationAsRead('1'));
      final state = await failed as NotificationsLoaded;

      expect(state.notifications.single.isRead, false);
      expect(state.errorMessage, isNot(contains('private backend detail')));
    });

    test(
      'mark-as-read preserves notifications loaded by concurrent refresh',
      () async {
        bloc.add(const LoadNotifications());
        await bloc.stream.firstWhere((state) => state is NotificationsLoaded);

        final markGate = Completer<void>();
        repository.markGates['1'] = markGate;
        bloc.add(const MarkNotificationAsRead('1'));
        await Future<void>.delayed(Duration.zero);

        repository.notifications.add(
          AppNotification(
            id: '2',
            title: 'New',
            description: 'Arrived during mark',
            type: NotificationType.aiForecast,
            severity: NotificationSeverity.info,
            dateTime: DateTime(2026, 7, 20),
          ),
        );
        final refreshed = bloc.stream.firstWhere(
          (state) =>
              state is NotificationsLoaded && state.notifications.length == 2,
        );
        bloc.add(const LoadNotifications(forceRefresh: true));
        await refreshed;

        final marked = bloc.stream.firstWhere(
          (state) =>
              state is NotificationsLoaded &&
              state.notifications.length == 2 &&
              state.notifications.firstWhere((item) => item.id == '1').isRead,
        );
        markGate.complete();
        final state = await marked as NotificationsLoaded;

        expect(
          state.notifications.map((item) => item.id),
          containsAll(['1', '2']),
        );
      },
    );
  });
}
