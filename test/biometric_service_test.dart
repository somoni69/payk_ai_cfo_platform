import 'package:flutter_test/flutter_test.dart';
import 'package:local_auth/local_auth.dart';
import 'package:payk_ai_cfo_platform/core/security/biometric_service.dart';

class _FakeLocalAuthentication extends Fake implements LocalAuthentication {
  bool supported = true;
  bool canCheck = true;
  List<BiometricType> available = [BiometricType.face];
  bool authResult = true;

  @override
  Future<bool> isDeviceSupported() async => supported;

  @override
  Future<bool> get canCheckBiometrics async => canCheck;

  @override
  Future<List<BiometricType>> getAvailableBiometrics() async => available;

  @override
  Future<bool> authenticate({
    required String localizedReason,
    Iterable<dynamic> authMessages = const [],
    bool biometricOnly = false,
    bool persistAcrossBackgrounding = true,
    bool sensitiveTransaction = true,
  }) async {
    return authResult;
  }

  @override
  Future<bool> stopAuthentication() async => true;
}

void main() {
  group('BiometricService Tests', () {
    late _FakeLocalAuthentication fakeAuth;
    late BiometricService service;

    setUp(() {
      fakeAuth = _FakeLocalAuthentication();
      service = BiometricService(auth: fakeAuth);
    });

    test(
      'isBiometricsAvailable returns true when supported, can check, and available',
      () async {
        fakeAuth.supported = true;
        fakeAuth.canCheck = true;
        fakeAuth.available = [BiometricType.face];

        final isAvailable = await service.isBiometricsAvailable();
        expect(isAvailable, isTrue);
      },
    );

    test(
      'isBiometricsAvailable returns false when device not supported',
      () async {
        fakeAuth.supported = false;
        final isAvailable = await service.isBiometricsAvailable();
        expect(isAvailable, isFalse);
      },
    );

    test(
      'isBiometricsAvailable returns false when no biometrics available',
      () async {
        fakeAuth.supported = true;
        fakeAuth.canCheck = true;
        fakeAuth.available = [];
        final isAvailable = await service.isBiometricsAvailable();
        expect(isAvailable, isFalse);
      },
    );

    test('authenticate passes localized messages and succeeds', () async {
      fakeAuth.authResult = true;
      final result = await service.authenticate(
        localizedReason: 'Test reason',
        languageCode: 'ru',
      );
      expect(result, isTrue);
    });

    test('authenticate in Tajik language succeeds', () async {
      fakeAuth.authResult = true;
      final result = await service.authenticate(
        localizedReason: 'Тасдиқи шахсият',
        languageCode: 'tg',
      );
      expect(result, isTrue);
    });
  });
}
