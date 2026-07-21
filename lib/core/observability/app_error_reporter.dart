import 'dart:async';

import 'package:flutter/foundation.dart';

typedef AppErrorSink =
    FutureOr<void> Function(
      Object error,
      StackTrace stackTrace,
      String context,
    );

/// Privacy-aware entry point for crash reporting.
///
/// A production sink (for example, the company's approved telemetry backend)
/// can be installed during bootstrap. Until then failures are still captured
/// by Flutter's global handlers without printing tokens, payloads or PII here.
final class AppErrorReporter {
  AppErrorReporter._();

  static AppErrorSink? _sink;

  static void installSink(AppErrorSink sink) {
    _sink = sink;
  }

  static Future<void> capture(
    Object error,
    StackTrace stackTrace, {
    required String context,
  }) async {
    final sink = _sink;
    if (sink == null) return;

    try {
      await sink(error, stackTrace, context);
    } catch (_) {
      // Telemetry must never crash or block the application.
    }
  }

  static Future<void> captureFlutterError(FlutterErrorDetails details) {
    return capture(
      details.exception,
      details.stack ?? StackTrace.current,
      context: details.context?.toDescription() ?? 'flutter-framework',
    );
  }
}
