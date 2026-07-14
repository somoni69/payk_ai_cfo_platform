import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:payk_ai_cfo_platform/core/localization/language_cubit.dart';

void main() {
  group('LanguageCubit Unit Tests', () {
    late LanguageCubit languageCubit;

    setUp(() {
      languageCubit = LanguageCubit();
    });

    tearDown(() {
      languageCubit.close();
    });

    test('Initial state should be Locale("ru")', () {
      expect(languageCubit.state, const Locale('ru'));
    });

    test('setLanguage should emit correct Locale state', () {
      languageCubit.setLanguage('tg');
      expect(languageCubit.state, const Locale('tg'));

      languageCubit.setLanguage('ru');
      expect(languageCubit.state, const Locale('ru'));
    });

    test('translate should return correct translation keys for RU and TJ', () {
      // Test RU default
      expect(languageCubit.translate('dashboard'), 'Финансовая панель');
      expect(languageCubit.translate('cash'), 'Касса и операции');

      // Switch to TJ
      languageCubit.setLanguage('tg');
      expect(languageCubit.translate('dashboard'), 'Панели молиявӣ');
      expect(languageCubit.translate('cash'), 'Хазина ва амалиётҳо');
    });

    test('translate should fallback to original key if key is missing', () {
      expect(languageCubit.translate('missing_key_reference'), 'missing_key_reference');
    });
  });
}
