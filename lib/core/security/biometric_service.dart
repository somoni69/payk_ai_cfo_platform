import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';

enum BiometricKind { faceId, touchId, fingerprint, faceUnlock, generic, none }

/// Сервис биометрической безопасности (Face ID на iOS, Fingerprint/Биометрия на Android).
class BiometricService {
  final LocalAuthentication _auth;

  BiometricService({LocalAuthentication? auth})
    : _auth = auth ?? LocalAuthentication();

  /// Проверяет аппаратную поддержку биометрии устройством.
  Future<bool> isDeviceSupported() async {
    try {
      return await _auth.isDeviceSupported();
    } catch (_) {
      return false;
    }
  }

  /// Проверяет, настроена ли биометрия и доступна ли она для использования.
  Future<bool> canCheckBiometrics() async {
    try {
      return await _auth.canCheckBiometrics;
    } catch (_) {
      return false;
    }
  }

  /// Комплексная проверка готовности биометрии.
  Future<bool> isBiometricsAvailable() async {
    try {
      final supported = await isDeviceSupported();
      if (!supported) return false;
      final canCheck = await canCheckBiometrics();
      if (!canCheck) return false;
      final biometrics = await getAvailableBiometrics();
      return biometrics.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  /// Возвращает список доступных биометрических датчиков на устройстве.
  Future<List<BiometricType>> getAvailableBiometrics() async {
    try {
      return await _auth.getAvailableBiometrics();
    } catch (_) {
      return const [];
    }
  }

  /// Определяет основной вид биометрии на текущем устройстве (Face ID vs Fingerprint).
  Future<BiometricKind> getPrimaryBiometricKind() async {
    if (kIsWeb) return BiometricKind.none;

    final available = await getAvailableBiometrics();
    if (available.isEmpty) {
      final canCheck = await canCheckBiometrics();
      if (!canCheck) return BiometricKind.none;
      return BiometricKind.generic;
    }

    if (Platform.isIOS) {
      if (available.contains(BiometricType.face)) {
        return BiometricKind.faceId;
      }
      if (available.contains(BiometricType.fingerprint)) {
        return BiometricKind.touchId;
      }
    } else if (Platform.isAndroid) {
      if (available.contains(BiometricType.fingerprint)) {
        return BiometricKind.fingerprint;
      }
      if (available.contains(BiometricType.face)) {
        return BiometricKind.faceUnlock;
      }
    }

    if (available.contains(BiometricType.face)) return BiometricKind.faceUnlock;
    if (available.contains(BiometricType.fingerprint)) {
      return BiometricKind.fingerprint;
    }

    return BiometricKind.generic;
  }

  /// Выполняет биометрическую аутентификацию.
  Future<bool> authenticate({
    required String localizedReason,
    String languageCode = 'ru',
  }) async {
    try {
      return await _auth.authenticate(
        localizedReason: localizedReason,
        biometricOnly: true,
        persistAcrossBackgrounding: true,
        sensitiveTransaction: true,
      );
    } on PlatformException catch (_) {
      return false;
    } catch (_) {
      return false;
    }
  }
}
