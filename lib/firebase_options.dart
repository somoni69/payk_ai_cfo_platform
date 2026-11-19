// File generated for Firebase configuration (shared project: payk-app-loyalty).
// ignore_for_file: type=lint
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, kIsWeb;

/// Default [FirebaseOptions] for Payk Business.
class DefaultFirebaseOptions {
  /// Platforms currently configured for Firebase in this project.
  ///
  static bool get isSupportedPlatform =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      throw UnsupportedError(
        'DefaultFirebaseOptions have not been configured for web.',
      );
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyAp7DnTXTJVdLc1cNA9Pjy2nhQNaR2yzU4',
    appId: '1:713617302599:android:550d18f5a92828d306bd62',
    messagingSenderId: '713617302599',
    projectId: 'payk-app-loyalty',
    storageBucket: 'payk-app-loyalty.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyBQSYZD2i8ZATgRICIj1H33kQM2ud4NjE8',
    appId: '1:713617302599:ios:858a3617f8f1fd0906bd62',
    messagingSenderId: '713617302599',
    projectId: 'payk-app-loyalty',
    storageBucket: 'payk-app-loyalty.firebasestorage.app',
    iosBundleId: 'tj.payk.cfo.app',
  );
}
