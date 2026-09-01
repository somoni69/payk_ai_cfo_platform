import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:payk_ai_cfo_platform/core/observability/app_error_reporter.dart';

void main() {
  group('AppErrorReporter & Telemetry Sanitization Tests (Tier 1 & Tier 2)', () {
    setUp(() {
      AppErrorReporter.installDefaultSinks();
    });

    test(
      'captures and stores sanitized errors in in-memory ring buffer',
      () async {
        await AppErrorReporter.capture(
          Exception('Network call failed on /api/cash/shifts'),
          StackTrace.current,
          context: 'CashBloc',
        );

        final events = AppErrorReporter.recentEvents;
        expect(events, isNotEmpty);
        final last = events.last;
        expect(last['context'], 'CashBloc');
        expect(
          last['message'],
          contains('Network call failed on /api/cash/shifts'),
        );
        expect(last['stackHint'], isNotEmpty);
        expect(last['at'], isNotEmpty);
      },
    );

    test('sanitizes Bearer tokens from error strings', () async {
      const rawError =
          'Failed request with header: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.e30.t-ID';
      await AppErrorReporter.capture(
        rawError,
        StackTrace.current,
        context: 'AuthInterceptor',
      );

      final events = AppErrorReporter.recentEvents;
      final last = events.last;
      expect(
        last['message'],
        isNot(contains('eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9')),
      );
      expect(last['message'], contains('Bearer <redacted>'));
    });

    test('sanitizes passwords and secrets from error strings', () async {
      const rawError =
          'Invalid payload data: {"username": "admin", "password": "superSecretPassword123!"}';
      await AppErrorReporter.capture(
        rawError,
        StackTrace.current,
        context: 'ApiClient',
      );

      final events = AppErrorReporter.recentEvents;
      final last = events.last;
      expect(last['message'], isNot(contains('superSecretPassword123!')));
      expect(last['message'], contains('<redacted_pwd>'));
    });

    test(
      'ring buffer maintains maximum 40 entries limit without unbounded growth',
      () async {
        for (int i = 0; i < 50; i++) {
          await AppErrorReporter.capture(
            'Error occurrence #$i',
            StackTrace.current,
            context: 'LoadStress',
          );
        }

        final events = AppErrorReporter.recentEvents;
        expect(events.length, lessThanOrEqualTo(40));
        expect(events.last['message'], 'Error occurrence #49');
      },
    );

    test(
      'custom telemetry sink receives error and survives sink exceptions gracefully',
      () async {
        final receivedContexts = <String>[];
        AppErrorReporter.installSink((error, stackTrace, context) {
          receivedContexts.add(context);
          if (context == 'ThrowingSink') {
            throw Exception('External Crashlytics service failure');
          }
        });

        // Regular sink call
        await AppErrorReporter.capture(
          'Normal error',
          StackTrace.current,
          context: 'NormalModule',
        );
        expect(receivedContexts, contains('NormalModule'));

        // Sinks that throw must not crash application execution
        expect(
          () async => await AppErrorReporter.capture(
            'Crashing sink error',
            StackTrace.current,
            context: 'ThrowingSink',
          ),
          returnsNormally,
        );
        expect(receivedContexts, contains('ThrowingSink'));
      },
    );

    test('captureFlutterError extracts FlutterErrorDetails cleanly', () async {
      final details = FlutterErrorDetails(
        exception: Exception('Widget build failed in LedgerCard'),
        stack: StackTrace.current,
        context: ErrorDescription('building LedgerCard widget tree'),
      );

      await AppErrorReporter.captureFlutterError(details);

      final events = AppErrorReporter.recentEvents;
      expect(
        events.last['context'],
        contains('building LedgerCard widget tree'),
      );
      expect(
        events.last['message'],
        contains('Widget build failed in LedgerCard'),
      );
    });
  });
}
