import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:payk_ai_cfo_platform/core/localization/language_cubit.dart';
import 'package:payk_ai_cfo_platform/core/localization/tajik_material_localizations.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('LanguageCubit', () {
    late LanguageCubit languageCubit;

    setUp(() {
      languageCubit = LanguageCubit();
    });

    tearDown(() async {
      await languageCubit.close();
    });

    test('starts in Russian and rejects unsupported languages', () async {
      expect(languageCubit.state, const Locale('ru'));

      await languageCubit.setLanguage('en');

      expect(languageCubit.state, const Locale('ru'));
    });

    test('switches between Russian and Tajik', () async {
      await languageCubit.setLanguage('tg');
      expect(languageCubit.state, const Locale('tg'));
      expect(languageCubit.translate('dashboard'), 'Панели молиявӣ');
      expect(languageCubit.translate('cash'), 'Хазина ва амалиётҳо');

      expect(languageCubit.translate('common_previous'), 'Қаблӣ');
      expect(languageCubit.translate('common_next'), 'Баъдӣ');
      expect(languageCubit.translate('common_copy'), 'Нусхабардорӣ');
      expect(languageCubit.translate('common_send'), 'Фиристодан');
      expect(
        languageCubit.translate('legal_clear_history'),
        'Пок кардани таърих',
      );

      await languageCubit.setLanguage('ru');
      expect(languageCubit.state, const Locale('ru'));
      expect(languageCubit.translate('dashboard'), 'Финансовая панель');
    });

    test('Russian and Tajik catalogs are complete and symmetric', () {
      expect(
        LanguageCubit.russianKeys,
        unorderedEquals(LanguageCubit.tajikKeys),
      );
      expect(LanguageCubit.russianKeys.length, greaterThan(600));
    });

    test('substitutes parameters and falls back to the key', () async {
      await languageCubit.setLanguage('tg');

      expect(
        languageCubit.translate(
          'cash_shift_open_details',
          params: {'time': '09:00', 'balance': 1200},
        ),
        'Оғоз: 09:00 • Бақия: 1200 TJS',
      );
      expect(
        languageCubit.translate('missing_key_reference'),
        'missing_key_reference',
      );
    });

    test('translates exact and parameterized runtime messages', () async {
      await languageCubit.setLanguage('tg');

      expect(
        languageCubit.translateMessage('Товар не найден.'),
        'Мол ёфт нашуд.',
      );
      expect(
        languageCubit.translateMessage(
          'Не удалось загрузить задачи: Exception: timeout',
        ),
        'Вазифаҳо бор карда нашуданд: timeout',
      );
      expect(
        languageCubit.translateMessage(
          'Сотрудник "Фарид" успешно принят на работу.',
        ),
        'Корманди "Фарид" бомуваффақият ба кор қабул шуд.',
      );
      expect(
        languageCubit.translateMessage(
          'Не удалось загрузить финансовые данные. Проверьте соединение.',
        ),
        'Маълумоти молиявӣ бор карда нашуд. Пайвастшавиро санҷед.',
      );
      expect(
        languageCubit.translateMessage(
          'Сессия истекла. Войдите в приложение снова.',
        ),
        'Муҳлати сессия анҷом ёфт. Боз ба барнома ворид шавед.',
      );
    });

    test('uses the bootstrapped language on the first frame', () async {
      final bootstrappedCubit = LanguageCubit(initialLanguageCode: 'tg');

      expect(bootstrappedCubit.state, const Locale('tg'));

      await bootstrappedCubit.close();
    });
  });

  test('persists and restores the selected interface language', () async {
    FlutterSecureStorage.setMockInitialValues({});
    const storage = FlutterSecureStorage();
    final firstCubit = LanguageCubit(storage: storage);

    await firstCubit.setLanguage('tg');
    expect(await storage.read(key: 'interface_language'), 'tg');
    await firstCubit.close();

    final restoredCubit = LanguageCubit(storage: storage);
    await Future<void>.delayed(Duration.zero);

    expect(restoredCubit.state, const Locale('tg'));
    await restoredCubit.close();
  });

  test('explicit selection wins over a delayed language restore', () async {
    FlutterSecureStorage.setMockInitialValues({});
    final restoredValue = Completer<String?>();
    final cubit = LanguageCubit(
      storage: _DelayedReadStorage(restoredValue.future),
    );

    await cubit.setLanguage('tg');
    restoredValue.complete('ru');
    await Future<void>.delayed(Duration.zero);

    expect(cubit.state, const Locale('tg'));
    await cubit.close();
  });

  test(
    'latest language is persisted when writes finish out of order',
    () async {
      final storage = _ReorderingWriteStorage();
      final cubit = LanguageCubit(storage: storage, initialLanguageCode: 'ru');

      final firstSelection = cubit.setLanguage('tg');
      final secondSelection = cubit.setLanguage('ru');
      await Future<void>.delayed(Duration.zero);

      storage.releaseTajikWrite();
      await Future.wait<void>([firstSelection, secondSelection]);

      expect(cubit.state, const Locale('ru'));
      expect(storage.persistedValue, 'ru');
      await cubit.close();
    },
  );

  test('Tajik Material localizations cover built-in controls', () async {
    final localizations = await const TajikMaterialLocalizationsDelegate().load(
      const Locale('tg'),
    );

    expect(localizations.cancelButtonLabel, 'Бекор кардан');
    expect(localizations.datePickerHelpText, 'Санаро интихоб кунед');
    expect(localizations.showMenuTooltip, 'Намоиши меню');
    expect(
      localizations.formatFullDate(DateTime(2026, 7, 17)),
      'ҷумъа, 17 июл 2026',
    );
  });
}

final class _DelayedReadStorage extends FlutterSecureStorage {
  _DelayedReadStorage(this._readResult);

  final Future<String?> _readResult;

  @override
  Future<String?> read({
    required String key,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) => _readResult;
}

final class _ReorderingWriteStorage extends FlutterSecureStorage {
  final Completer<void> _tajikWriteRelease = Completer<void>();
  String? persistedValue;

  void releaseTajikWrite() {
    if (!_tajikWriteRelease.isCompleted) {
      _tajikWriteRelease.complete();
    }
  }

  @override
  Future<void> write({
    required String key,
    required String? value,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    if (value == 'tg') {
      await _tajikWriteRelease.future;
    }
    persistedValue = value;
  }
}
