import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String _read(String path) => File(path).readAsStringSync();

void main() {
  group('platform release configuration', () {
    test('Android release disables cleartext traffic and backups', () {
      final manifest = _read('android/app/src/main/AndroidManifest.xml');
      final backupRules = _read(
        'android/app/src/main/res/xml/backup_rules.xml',
      );
      final extractionRules = _read(
        'android/app/src/main/res/xml/data_extraction_rules.xml',
      );

      expect(manifest, contains('android:usesCleartextTraffic="false"'));
      expect(manifest, contains('android:allowBackup="false"'));
      expect(manifest, contains('@xml/backup_rules'));
      expect(manifest, contains('@xml/data_extraction_rules'));
      expect(backupRules, contains('<exclude domain="root" path="."/>'));
      expect(extractionRules, contains('<device-transfer>'));
    });

    test('Android production release requires identity and signing', () {
      final gradle = _read('android/app/build.gradle.kts');

      expect(gradle, contains('releaseRequested && !allowUnsafeRelease'));
      expect(gradle, contains('check(hasReleaseSigning)'));
      expect(
        gradle,
        contains('!applicationIdValue.startsWith("com.example.")'),
      );
    });

    test('iOS includes Russian and Tajik system localizations', () {
      final plist = _read('ios/Runner/Info.plist');
      final project = _read('ios/Runner.xcodeproj/project.pbxproj');
      final russian = _read('ios/Runner/ru.lproj/InfoPlist.strings');
      final tajik = _read('ios/Runner/tg.lproj/InfoPlist.strings');

      expect(plist, contains('<key>CFBundleLocalizations</key>'));
      expect(plist, contains('<string>ru</string>'));
      expect(plist, contains('<string>tg</string>'));
      expect(project, contains('InfoPlist.strings in Resources'));
      expect(russian, contains('безопасного и быстрого входа'));
      expect(tajik, contains('воридшавии бехатар ва зуд'));
    });

    test('iOS device release rejects placeholder identity', () {
      final project = _read('ios/Runner.xcodeproj/project.pbxproj');

      expect(project, contains(r'$PAYK_ALLOW_UNSAFE_RELEASE'));
      expect(project, contains(r'$PRODUCT_BUNDLE_IDENTIFIER'));
      expect(project, contains('com.example.*'));
      expect(project, contains(r'$DEVELOPMENT_TEAM'));
    });

    test(
      'Android production release enables R8 minification and proguard rules',
      () {
        final gradle = _read('android/app/build.gradle.kts');
        final proguard = _read('android/app/proguard-rules.pro');

        expect(gradle, contains('isMinifyEnabled = true'));
        expect(gradle, contains('isShrinkResources = true'));
        expect(gradle, contains('proguard-rules.pro'));
        expect(proguard, contains('-keep class io.flutter.app.**'));
        expect(proguard, contains('-keep class androidx.biometric.**'));
        expect(proguard, contains('-keep class androidx.security.crypto.**'));
      },
    );

    test('Android MainActivity allows screenshots (no FLAG_SECURE constraint)', () {
      final mainActivity = _read(
        'android/app/src/main/kotlin/com/example/payk_ai_cfo_platform/MainActivity.kt',
      );

      expect(mainActivity, isNot(contains('FLAG_SECURE')));
    });

    test('CI compiles the release variant explicitly with obfuscation', () {
      final workflow = _read('.github/workflows/flutter_quality.yml');

      expect(workflow, contains('flutter build apk --release --no-pub'));
      expect(workflow, contains('--obfuscate'));
      expect(
        workflow,
        contains('--split-debug-info=build/app/outputs/symbols'),
      );
      expect(
        workflow,
        contains('ORG_GRADLE_PROJECT_allowUnsafeRelease: "true"'),
      );
    });
  });
}
