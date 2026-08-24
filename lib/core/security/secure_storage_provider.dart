import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Аппаратное защищенное хранилище (iOS Secure Enclave Keychain + Android Keystore EncryptedSharedPreferences).
class AppSecureStorage {
  const AppSecureStorage._();

  static const AndroidOptions _androidOptions = AndroidOptions(
    resetOnError: true,
  );

  static const IOSOptions _iosOptions = IOSOptions(
    accessibility: KeychainAccessibility.first_unlock_this_device,
  );

  /// Единый синглтон защищенного хранилища с аппаратным шифрованием AES-256.
  static const FlutterSecureStorage instance = FlutterSecureStorage(
    aOptions: _androidOptions,
    iOptions: _iosOptions,
  );
}
