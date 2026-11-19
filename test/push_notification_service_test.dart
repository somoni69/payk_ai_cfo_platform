import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:payk_ai_cfo_platform/core/notifications/push_notification_service.dart';
import 'package:payk_ai_cfo_platform/firebase_options.dart';

void main() {
  group('DefaultFirebaseOptions (Payk Business)', () {
    test('uses shared payk-app-loyalty project with tj.payk.cfo appId', () {
      expect(DefaultFirebaseOptions.android.projectId, 'payk-app-loyalty');
      expect(DefaultFirebaseOptions.android.messagingSenderId, '713617302599');
      expect(
        DefaultFirebaseOptions.android.appId,
        '1:713617302599:android:550d18f5a92828d306bd62',
      );
      expect(
        DefaultFirebaseOptions.android.storageBucket,
        'payk-app-loyalty.firebasestorage.app',
      );
    });

    test('currentPlatform resolves Android and Payk Business iOS', () {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      expect(
        DefaultFirebaseOptions.currentPlatform.appId,
        DefaultFirebaseOptions.android.appId,
      );
      expect(DefaultFirebaseOptions.isSupportedPlatform, isTrue);

      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      expect(DefaultFirebaseOptions.isSupportedPlatform, isTrue);
      expect(
        DefaultFirebaseOptions.currentPlatform.appId,
        '1:713617302599:ios:858a3617f8f1fd0906bd62',
      );
      expect(
        DefaultFirebaseOptions.currentPlatform.iosBundleId,
        'tj.payk.cfo.app',
      );

      debugDefaultTargetPlatformOverride = null;
    });
  });

  group('PushNotificationService', () {
    test('uses business-isolated topic and normalizes routes safely', () {
      expect(PushNotificationService.defaultTopic, 'business_all');
      expect(PushNotificationService.defaultRoute, '/inbox');
      expect(PushNotificationService.normalizeRoute(null), '/inbox');
      expect(PushNotificationService.normalizeRoute(''), '/inbox');
      expect(PushNotificationService.normalizeRoute('notifications'), '/inbox');
      expect(
        PushNotificationService.normalizeRoute(' /notifications '),
        '/notifications',
      );
      expect(PushNotificationService.normalizeRoute('/tasks'), '/tasks');
    });
  });
}
