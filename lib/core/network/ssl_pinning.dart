import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:flutter/foundation.dart';

/// Configures SSL/TLS Certificate & Public Key Pinning on the provided [Dio] instance.
///
/// Fingerprint format: SHA-256 hex string (with or without colons/spaces).
/// Configured via `--dart-define=PAYK_SSL_SHA256=<sha256_fingerprint>`.
///
/// When [allowInsecure] is true or [expectedFingerprint] is empty, default system
/// TLS validation is retained for local development/testing.
void configureSslPinning(
  Dio dio, {
  bool allowInsecure = false,
  String expectedFingerprint = const String.fromEnvironment('PAYK_SSL_SHA256'),
}) {
  if (kIsWeb) return;

  final normalizedExpected = _normalizeFingerprint(expectedFingerprint);

  dio.httpClientAdapter = IOHttpClientAdapter(
    createHttpClient: () {
      final context = SecurityContext(withTrustedRoots: true);
      final client = HttpClient(context: context);
      if (normalizedExpected.isNotEmpty && !allowInsecure) {
        client.badCertificateCallback =
            (X509Certificate cert, String host, int port) {
              return _validateCertificate(cert, normalizedExpected);
            };
      }
      return client;
    },
    validateCertificate: (cert, host, port) {
      if (allowInsecure || normalizedExpected.isEmpty) {
        return true;
      }
      if (cert == null) return false;
      return _validateCertificate(cert, normalizedExpected);
    },
  );
}

bool _validateCertificate(X509Certificate? cert, String normalizedExpected) {
  if (cert == null) return false;
  final certSha256 = sha256
      .convert(cert.der)
      .bytes
      .map((b) => b.toRadixString(16).padLeft(2, '0'))
      .join('')
      .toUpperCase();
  return certSha256 == normalizedExpected;
}

String _normalizeFingerprint(String input) {
  return input.replaceAll(RegExp(r'[^A-Fa-f0-9]'), '').toUpperCase();
}
