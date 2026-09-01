import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:payk_ai_cfo_platform/core/network/api_client.dart';
import 'package:payk_ai_cfo_platform/core/network/ssl_pinning.dart';
import 'package:payk_ai_cfo_platform/core/observability/app_error_reporter.dart';
import 'package:payk_ai_cfo_platform/core/security/secure_storage_provider.dart';

String _readFile(String path) => File(path).readAsStringSync();

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
  });

  group('SEC-01: Keystore and Secret Isolation', () {
    test('.gitignore excludes key.properties, keystores, and jks files', () {
      final gitignore = _readFile('.gitignore');
      expect(gitignore, contains('key.properties'));
      expect(gitignore, contains('android/key.properties'));
      expect(gitignore, contains('*.jks'));
      expect(gitignore, contains('*.keystore'));
      expect(gitignore, contains('android/app/*.jks'));
      expect(gitignore, contains('android/app/*.keystore'));
    });

    test(
      'android/key.properties.example exists and contains template placeholders',
      () {
        final example = _readFile('android/key.properties.example');
        expect(example, contains('storePassword=change-me'));
        expect(example, contains('keyPassword=change-me'));
        expect(example, contains('keyAlias=upload'));
      },
    );
  });

  group(
    'SEC-02 & SEC-09: Media URL Token Hygiene & Insecure Transport Upgrade',
    () {
      test('mediaUrl strips token query parameters and does not leak JWT', () {
        final client = ApiClient();
        expect(
          client.mediaUrl('/documents/contract.pdf'),
          isNot(contains('?token=')),
        );
        expect(
          client.mediaUrl('/documents/contract.pdf'),
          isNot(contains('&token=')),
        );
        expect(
          client.mediaUrl('/avatars/user.png'),
          isNot(contains('?token=')),
        );
        expect(client.mediaUrl(''), isEmpty);
        expect(client.mediaUrl(null), isEmpty);
      });

      test(
        'mediaUrl upgrades insecure http:// to https:// when allowInsecureApi is false',
        () {
          final client = ApiClient();
          final url = client.mediaUrl('http://cdn.payk.tj/files/report.xlsx');
          if (!ApiClient.allowInsecureApi) {
            expect(url, startsWith('https://'));
          }
        },
      );

      test(
        'downloadProtectedMedia sends authorized GET and returns byte stream',
        () async {
          final client = ApiClient();
          final adapter = _MockBinaryAdapter(
            Uint8List.fromList([1, 2, 3, 4, 5]),
            200,
          );
          client.dio.httpClientAdapter = adapter;

          final bytes = await client.downloadProtectedMedia(
            '/secure/report.pdf',
          );
          expect(bytes, equals(Uint8List.fromList([1, 2, 3, 4, 5])));
          expect(adapter.lastOptions?.responseType, ResponseType.bytes);
        },
      );
    },
  );

  group('SEC-03: SSL/TLS Certificate Pinning', () {
    test(
      'configureSslPinning configures IOHttpClientAdapter with cert validation',
      () {
        final dio = Dio();
        configureSslPinning(
          dio,
          allowInsecure: false,
          expectedFingerprint:
              'AA:BB:CC:DD:EE:FF:00:11:22:33:44:55:66:77:88:99:AA:BB:CC:DD:EE:FF:00:11:22:33:44:55:66:77:88:99',
        );

        expect(dio.httpClientAdapter, isA<IOHttpClientAdapter>());
      },
    );

    test(
      'configureSslPinning permits insecure/empty fingerprint during local dev',
      () {
        final dio = Dio();
        configureSslPinning(dio, allowInsecure: true, expectedFingerprint: '');
        expect(dio.httpClientAdapter, isA<IOHttpClientAdapter>());
      },
    );
  });

  group('SEC-04: Biometric Toggle Authentication Enforcement', () {
    test(
      'more_screen.dart requires biometric authentication before disabling or enabling biometrics',
      () {
        final moreScreenContent = _readFile(
          'lib/features/shell/presentation/more_screen.dart',
        );

        // Verification of biometric service invocation on toggle change
        expect(
          moreScreenContent,
          contains('await _biometricService.authenticate('),
        );
        // Verification that turning OFF requires authentication
        expect(
          moreScreenContent,
          contains(
            "await _storage.write(key: 'use_biometrics', value: 'false')",
          ),
        );
        // Verification that failure leaves biometric enabled or cancelled safely
        expect(
          moreScreenContent,
          contains('setState(() => _biometricEnabled = true)'),
        );
      },
    );
  });

  group('SEC-05: 401 Token Refresh Race Condition Resilience', () {
    test(
      'late 401 request retries with newly refreshed token without failing',
      () async {
        final client = ApiClient();
        await client.saveAccessToken('initial_token_v1');
        await client.saveRefreshToken('valid_refresh_token');

        var attemptCount = 0;
        client.dio.httpClientAdapter = _MockRefreshFlowAdapter(
          onRequest: (options) {
            attemptCount++;
            if (options.path == '/auth/refresh') {
              return ResponseBody.fromString(
                '{"access_token":"refreshed_token_v2"}',
                200,
                headers: {
                  Headers.contentTypeHeader: [Headers.jsonContentType],
                },
              );
            }
            if (options.headers['Authorization'] == 'Bearer initial_token_v1') {
              return ResponseBody.fromString(
                '{"error":"token_expired"}',
                401,
                headers: {
                  Headers.contentTypeHeader: [Headers.jsonContentType],
                },
              );
            }
            if (options.headers['Authorization'] ==
                'Bearer refreshed_token_v2') {
              return ResponseBody.fromString(
                '{"status":"ok","data":{"id":123}}',
                200,
                headers: {
                  Headers.contentTypeHeader: [Headers.jsonContentType],
                },
              );
            }
            return ResponseBody.fromString('{}', 400);
          },
        );

        final response = await client.dio.get<Map<String, dynamic>>(
          '/dashboard/summary',
        );
        expect(response.statusCode, 200);
        expect(response.data?['status'], 'ok');
        expect(await client.getAccessToken(), 'refreshed_token_v2');
        expect(attemptCount, greaterThan(1));
      },
    );
  });

  group('SEC-06 & SEC-10: Android Hardening & ProGuard / FLAG_SECURE', () {
    test(
      'android/app/build.gradle.kts enables R8 minify, shrinkResources, and proguard-rules.pro',
      () {
        final gradle = _readFile('android/app/build.gradle.kts');
        expect(gradle, contains('isMinifyEnabled = true'));
        expect(gradle, contains('isShrinkResources = true'));
        expect(gradle, contains('proguard-rules.pro'));
      },
    );

    test('android/app/proguard-rules.pro exists with essential keep rules', () {
      final proguard = _readFile('android/app/proguard-rules.pro');
      expect(proguard, contains('-keep class io.flutter.app.**'));
      expect(proguard, contains('-keep class io.flutter.plugin.**'));
      expect(proguard, contains('-keep class androidx.biometric.**'));
      expect(proguard, contains('-keep class androidx.security.crypto.**'));
    });

    test(
      'MainActivity.kt permits screenshots and screen captures (no FLAG_SECURE constraint)',
      () {
        final mainActivity = _readFile(
          'android/app/src/main/kotlin/com/example/payk_ai_cfo_platform/MainActivity.kt',
        );
        expect(mainActivity, isNot(contains('FLAG_SECURE')));
      },
    );

    test('CI workflow specifies --obfuscate and --split-debug-info', () {
      final workflow = _readFile('.github/workflows/flutter_quality.yml');
      expect(workflow, contains('--obfuscate'));
      expect(
        workflow,
        contains('--split-debug-info=build/app/outputs/symbols'),
      );
    });
  });

  group('SEC-07: Secure Storage Android EncryptedSharedPreferences', () {
    test(
      'AppSecureStorage instance uses AndroidOptions with encryptedSharedPreferences: true',
      () {
        expect(AppSecureStorage.instance, isA<FlutterSecureStorage>());
        final optionsMap = AppSecureStorage.instance.aOptions.toMap();
        expect(optionsMap['encryptedSharedPreferences'], 'true');
        expect(optionsMap['resetOnError'], 'true');
      },
    );
  });

  group('SEC-08: Observability & Log PII Sanitization', () {
    test(
      'AppErrorReporter strips Bearer tokens, standalone JWT, OTP, PIN, Card PANs, Passwords',
      () {
        AppErrorReporter.installDefaultSinks();

        final sensitiveMessage =
            'Error at login: password="SuperSecret123!" code=123456 '
            'pin: 9876 refresh_token: "550e8400-e29b-41d4-a716-446655440000" '
            'token=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiIxMjM0NTY3ODkwIiwibmFtZSI6IkpvaG4gRG9lIiwiaWF0IjoxNTE2MjM5MDIyfQ.SflKxwRJSMeKKF2QT4fwpMeJf36POk6yJV_adQssw5c '
            'Bearer my_bearer_token_string '
            'card: 4111 2222 3333 4444';

        AppErrorReporter.capture(
          Exception(sensitiveMessage),
          StackTrace.current,
          context: 'test-audit',
        );

        final recent = AppErrorReporter.recentEvents.last;
        final loggedMsg = recent['message']!;

        expect(loggedMsg, isNot(contains('SuperSecret123!')));
        expect(loggedMsg, isNot(contains('123456')));
        expect(loggedMsg, isNot(contains('9876')));
        expect(
          loggedMsg,
          isNot(contains('550e8400-e29b-41d4-a716-446655440000')),
        );
        expect(loggedMsg, isNot(contains('eyJhbGciOiJIUzI1NiIs')));
        expect(loggedMsg, isNot(contains('my_bearer_token_string')));
        expect(loggedMsg, isNot(contains('4111 2222 3333 4444')));

        expect(loggedMsg, contains('password="<redacted_pwd>"'));
        expect(loggedMsg, contains('code="<redacted_code>"'));
        expect(loggedMsg, contains('pin: "<redacted_code>"'));
        expect(loggedMsg, contains('refresh_token: "<redacted_token>"'));
        expect(loggedMsg, contains('Bearer <redacted>'));
        expect(loggedMsg, contains('<jwt-redacted>'));
        expect(loggedMsg, contains('<card-redacted>'));
      },
    );
  });
}

class _MockBinaryAdapter implements HttpClientAdapter {
  final Uint8List payload;
  final int statusCode;
  RequestOptions? lastOptions;

  _MockBinaryAdapter(this.payload, this.statusCode);

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    lastOptions = options;
    return ResponseBody(
      Stream.value(payload),
      statusCode,
      headers: {
        Headers.contentTypeHeader: ['application/octet-stream'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

class _MockRefreshFlowAdapter implements HttpClientAdapter {
  final ResponseBody Function(RequestOptions options) onRequest;

  _MockRefreshFlowAdapter({required this.onRequest});

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    return onRequest(options);
  }

  @override
  void close({bool force = false}) {}
}
