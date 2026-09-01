import 'dart:async';
import 'dart:collection';

import 'package:flutter/foundation.dart';

typedef AppErrorSink =
    FutureOr<void> Function(
      Object error,
      StackTrace stackTrace,
      String context,
    );

/// Privacy-aware entry point for crash reporting.
///
/// Install a production sink (Crashlytics / company telemetry) during bootstrap,
/// or call [installDefaultSinks] for debug logging + an in-memory ring buffer
/// usable by support tooling without shipping PII.
final class AppErrorReporter {
  AppErrorReporter._();

  static AppErrorSink? _sink;
  static const int _bufferLimit = 40;
  static final ListQueue<_BufferedError> _recent = ListQueue<_BufferedError>();

  /// Most recent sanitized events (newest last). Safe for diagnostics UI.
  static List<Map<String, String>> get recentEvents =>
      _recent.map((e) => e.toMap()).toList(growable: false);

  static void installSink(AppErrorSink sink) {
    _sink = sink;
  }

  /// Debug: print to console. Always: keep a small in-memory buffer.
  /// Release: no console noise; buffer only unless a custom sink is installed.
  static void installDefaultSinks() {
    installSink((error, stackTrace, context) {
      _buffer(error, stackTrace, context);
      if (kDebugMode) {
        debugPrint('[AppErrorReporter:$context] ${_sanitize('$error')}');
      }
    });
  }

  static void _buffer(Object error, StackTrace stackTrace, String context) {
    _recent.addLast(
      _BufferedError(
        context: context,
        message: _sanitize('$error'),
        // Never store full stacks with potential tokens in long-lived memory.
        stackHint: _sanitize(
          stackTrace.toString().split('\n').take(4).join(' | '),
        ),
        at: DateTime.now().toUtc(),
      ),
    );
    while (_recent.length > _bufferLimit) {
      _recent.removeFirst();
    }
  }

  /// Strips JWT-like blobs, Authorization headers, OTP codes, PINs, tokens,
  /// passwords, and payment card numbers from free-form text.
  static String _sanitize(String raw) {
    var text = raw;
    // Authorization & Bearer tokens
    text = text.replaceAll(
      RegExp(r'Bearer\s+[A-Za-z0-9\-._~+/]+=*', caseSensitive: false),
      'Bearer <redacted>',
    );
    // JWT tokens (3-part base64url)
    text = text.replaceAll(
      RegExp(r'eyJ[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+'),
      '<jwt-redacted>',
    );
    // Passwords and client secrets
    text = text.replaceAllMapped(
      RegExp(
        r'("?(?:password|pass|client_secret|token_secret)"?\s*[:=]\s*)"?[^",}\s]+"?',
        caseSensitive: false,
      ),
      (m) => '${m[1]}"<redacted_pwd>"',
    );
    // 2FA / OTP codes & PINs
    text = text.replaceAllMapped(
      RegExp(
        r'("?(?:code|otp|sms_code|pin|two_factor_code)"?\s*[:=]\s*)"?\d{4,8}"?',
        caseSensitive: false,
      ),
      (m) => '${m[1]}"<redacted_code>"',
    );
    // Refresh & Access Tokens, API keys in JSON or query params
    text = text.replaceAllMapped(
      RegExp(
        r'("?(?:refresh_token|access_token|apiKey|api_key|secret)"?\s*[:=]\s*)"[^"]+"',
        caseSensitive: false,
      ),
      (m) => '${m[1]}"<redacted_token>"',
    );
    // Payment card PANs (13-19 digits with optional spaces/hyphens)
    text = text.replaceAll(
      RegExp(r'\b(?:\d[ -]*?){13,19}\b'),
      '<card-redacted>',
    );
    return text;
  }

  static Future<void> capture(
    Object error,
    StackTrace stackTrace, {
    required String context,
  }) async {
    final sink = _sink;
    if (sink == null) {
      _buffer(error, stackTrace, context);
      return;
    }

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

class _BufferedError {
  _BufferedError({
    required this.context,
    required this.message,
    required this.stackHint,
    required this.at,
  });

  final String context;
  final String message;
  final String stackHint;
  final DateTime at;

  Map<String, String> toMap() => {
    'context': context,
    'message': message,
    'stackHint': stackHint,
    'at': at.toIso8601String(),
  };
}
