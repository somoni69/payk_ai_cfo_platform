import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:flutter/foundation.dart';

const String _defaultFingerprint = String.fromEnvironment('PAYK_SSL_SHA256');
const String _defaultBackupFingerprint = String.fromEnvironment(
  'PAYK_SSL_SHA256_BACKUP',
);
const bool _allowUnpinnedRelease = bool.fromEnvironment(
  'PAYK_ALLOW_UNPINNED_RELEASE',
);

const String _pinFormatHint =
    'PAYK_SSL_SHA256 must be a hex SHA-256 certificate fingerprint '
    '(64 hex characters, colons/spaces are allowed).';

/// Fails closed when a release build has no certificate pin.
///
/// Release builds must be built with `--dart-define=PAYK_SSL_SHA256=<hex>`.
/// A second pin can be supplied via `PAYK_SSL_SHA256_BACKUP` for rotation.
/// The explicit `PAYK_ALLOW_UNPINNED_RELEASE=true` escape hatch exists only for
/// local compile validation and must never be used for a distributed build.
void assertSslPinningConfigured({
  bool allowInsecure = false,
  String expectedFingerprint = _defaultFingerprint,
  String backupFingerprint = _defaultBackupFingerprint,
}) {
  if (allowInsecure) {
    if (kReleaseMode && !_allowUnpinnedRelease) {
      throw StateError(
        'ALLOW_INSECURE_API is forbidden in release builds. '
        'Build with HTTPS and PAYK_SSL_SHA256 instead.',
      );
    }
    return;
  }

  final pins = _configuredPins(expectedFingerprint, backupFingerprint);
  if (pins.isEmpty) {
    if (kReleaseMode && !_allowUnpinnedRelease) {
      throw StateError(
        'Release builds require a TLS certificate pin. '
        'Pass --dart-define=PAYK_SSL_SHA256=<hex> (and optionally '
        'PAYK_SSL_SHA256_BACKUP=<hex>).',
      );
    }
    return;
  }
}

/// Configures SSL/TLS certificate pinning on the provided [Dio] instance.
///
/// Fingerprint format: SHA-256 hex string (with or without colons/spaces).
/// Configured via `--dart-define=PAYK_SSL_SHA256=<fingerprint>` and an optional
/// second pin via `PAYK_SSL_SHA256_BACKUP=<fingerprint>`.
///
/// When [allowInsecure] is true or no pin is configured, default system TLS
/// validation is retained for local development/testing.
void configureSslPinning(
  Dio dio, {
  bool allowInsecure = false,
  String expectedFingerprint = _defaultFingerprint,
  String backupFingerprint = _defaultBackupFingerprint,
}) {
  if (kIsWeb) return;

  final pins = _configuredPins(expectedFingerprint, backupFingerprint);

  dio.httpClientAdapter = IOHttpClientAdapter(
    createHttpClient: () {
      final context = SecurityContext(withTrustedRoots: true);
      final client = HttpClient(context: context);
      if (pins.isNotEmpty && !allowInsecure) {
        client.badCertificateCallback =
            (X509Certificate cert, String host, int port) {
              return _validateCertificate(cert, pins);
            };
      }
      return client;
    },
    validateCertificate: (cert, host, port) {
      if (allowInsecure || pins.isEmpty) {
        return true;
      }
      if (cert == null) return false;
      return _validateCertificate(cert, pins);
    },
  );
}

/// [HttpClient] with the same trust rules as the API client (WebSocket handshake).
HttpClient createPinnedHttpClient({
  bool allowInsecure = false,
  String expectedFingerprint = _defaultFingerprint,
  String backupFingerprint = _defaultBackupFingerprint,
}) {
  final pins = _configuredPins(expectedFingerprint, backupFingerprint);
  final client = HttpClient(context: SecurityContext(withTrustedRoots: true));
  if (pins.isNotEmpty && !allowInsecure) {
    client.badCertificateCallback = (cert, host, port) =>
        _validateCertificate(cert, pins);
  }
  return client;
}

/// Whether a server certificate passes one of the configured pins (no pin: any).
bool acceptsPinnedCertificate(
  X509Certificate? cert, {
  bool allowInsecure = false,
  String expectedFingerprint = _defaultFingerprint,
  String backupFingerprint = _defaultBackupFingerprint,
}) {
  final pins = _configuredPins(expectedFingerprint, backupFingerprint);
  if (allowInsecure || pins.isEmpty) return true;
  return _validateCertificate(cert, pins);
}

bool _validateCertificate(X509Certificate? cert, Set<String> pins) {
  if (cert == null) return false;
  final certSha256 = sha256
      .convert(cert.der)
      .bytes
      .map((b) => b.toRadixString(16).padLeft(2, '0'))
      .join('')
      .toUpperCase();
  return pins.contains(certSha256);
}

Set<String> _configuredPins(String primary, String backup) {
  final pins = <String>{};
  for (final raw in [primary, backup]) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) continue;
    final normalized = _normalizeFingerprint(trimmed);
    if (normalized.length != 64) {
      throw StateError(_pinFormatHint);
    }
    pins.add(normalized);
  }
  return pins;
}

String _normalizeFingerprint(String input) {
  return input.replaceAll(RegExp(r'[^A-Fa-f0-9]'), '').toUpperCase();
}
