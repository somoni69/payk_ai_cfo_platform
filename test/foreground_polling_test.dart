import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:payk_ai_cfo_platform/core/lifecycle/foreground_ticker.dart';
import 'package:payk_ai_cfo_platform/core/theme/app_theme.dart';
import 'package:payk_ai_cfo_platform/features/permissions/cubit/permissions_cubit.dart';
import 'package:payk_ai_cfo_platform/presentation/widgets/ledger_bottom_sheet.dart';

import 'permissions_cubit_test.dart' show MockPermissionsRepository;

void main() {
  group('ForegroundTicker', () {
    testWidgets('stops in background and ticks at once on resume', (
      tester,
    ) async {
      var ticks = 0;
      final ticker = ForegroundTicker(const Duration(seconds: 10), () {
        ticks++;
      });

      await tester.pump(const Duration(seconds: 10));
      expect(ticks, 1);

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      expect(ticker.isActive, isFalse);
      await tester.pump(const Duration(seconds: 60));
      expect(ticks, 1, reason: 'no polling while in background');

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      expect(ticks, 2, reason: 'immediate refresh on return');
      await tester.pump(const Duration(seconds: 10));
      expect(ticks, 3);
      ticker.dispose();
    });

    testWidgets('dispose stops ticks and lifecycle callbacks', (tester) async {
      var ticks = 0;
      final ticker = ForegroundTicker(const Duration(seconds: 1), () {
        ticks++;
      });
      ticker.dispose();
      await tester.pump(const Duration(seconds: 5));
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      expect(ticks, 0);
    });
  });

  group('PermissionsCubit.setForeground', () {
    test('pauses polling in background, reloads once on resume', () async {
      final repo = MockPermissionsRepository();
      final cubit = PermissionsCubit(repo);
      addTearDown(cubit.close);

      cubit.startPolling(interval: const Duration(hours: 1));
      expect(cubit.isPolling, isTrue);

      cubit.setForeground(false);
      expect(cubit.isPolling, isFalse);
      expect(repo.getMyPermissionsCallCount, 0);

      cubit.setForeground(true);
      await Future<void>.delayed(Duration.zero);
      expect(cubit.isPolling, isTrue);
      expect(repo.getMyPermissionsCallCount, 1);

      cubit.setForeground(true);
      await Future<void>.delayed(Duration.zero);
      expect(repo.getMyPermissionsCallCount, 1, reason: 'no duplicate reload');
    });

    test('resume without active polling does not start it', () async {
      final repo = MockPermissionsRepository();
      final cubit = PermissionsCubit(repo);
      addTearDown(cubit.close);

      cubit.setForeground(false);
      cubit.setForeground(true);
      await Future<void>.delayed(Duration.zero);
      expect(cubit.isPolling, isFalse);
      expect(repo.getMyPermissionsCallCount, 0);
    });

    test('startPolling while in background waits for resume', () async {
      final cubit = PermissionsCubit(MockPermissionsRepository());
      addTearDown(cubit.close);

      cubit.setForeground(false);
      cubit.startPolling(interval: const Duration(hours: 1));
      expect(cubit.isPolling, isFalse);
      cubit.setForeground(true);
      expect(cubit.isPolling, isTrue);
    });
  });

  testWidgets('LedgerBottomSheet disposes its controllers after closing', (
    tester,
  ) async {
    final controller = TextEditingController(text: 'x');
    var disposed = false;
    late BuildContext hostContext;
    await tester.pumpWidget(
      MaterialApp(
        theme: LedgerTheme.light,
        home: Builder(
          builder: (context) {
            hostContext = context;
            return const SizedBox();
          },
        ),
      ),
    );

    LedgerBottomSheet.show<void>(
      context: hostContext,
      title: 'T',
      disposables: [controller],
      builder: (context, _) => TextField(controller: controller),
    );
    await tester.pumpAndSettle();
    expect(find.byType(TextField), findsOneWidget);

    Navigator.of(hostContext).pop();
    await tester.pumpAndSettle();
    expect(find.byType(TextField), findsNothing);
    try {
      controller.addListener(() {});
    } on FlutterError {
      disposed = true;
    }
    expect(disposed, isTrue);
  });
}
