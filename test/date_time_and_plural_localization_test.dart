import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:payk_ai_cfo_platform/core/localization/language_cubit.dart';
import 'package:payk_ai_cfo_platform/core/localization/locale_date_time_format.dart';

void main() {
  setUpAll(() => initializeDateFormatting('ru'));

  test(
    'date-time formatter pads components and preserves date-only values',
    () {
      final value = DateTime(2026, 1, 2, 3, 4);

      expect(
        formatLocalizedDateTimeForLocale(
          value,
          const Locale('tg'),
          convertToLocal: false,
        ),
        '02.01.2026 03:04',
      );
      expect(
        formatLocalizedDateTimeForLocale(
          value,
          const Locale('ru'),
          style: LocalizedDateTimeStyle.dayMonthTime,
          convertToLocal: false,
        ),
        '02.01 03:04',
      );
    },
  );

  test('Russian plural helper handles one, few, teens, and many', () {
    final language = LanguageCubit(initialLanguageCode: 'ru');
    addTearDown(language.close);

    expect(
      language.translatePlural('tasks_priority_urgent_count', 1),
      '1 критическая',
    );
    expect(
      language.translatePlural('tasks_priority_urgent_count', 2),
      '2 критические',
    );
    expect(
      language.translatePlural('tasks_priority_urgent_count', 11),
      '11 критических',
    );
    expect(
      language.translatePlural('integrations_records_imported', 21),
      'Импортирована: 21 запись',
    );
    expect(
      language.translatePlural('strategy_factors_found', 24),
      '24 фактора найдено',
    );
  });

  test('Tajik plural catalog has symmetric forms', () {
    final language = LanguageCubit(initialLanguageCode: 'tg');
    addTearDown(language.close);

    expect(
      language.translatePlural('integrations_records_imported', 1),
      'Ворид карда шуд: 1 сабт',
    );
    expect(
      language.translatePlural('integrations_records_imported', 14),
      'Ворид карда шуд: 14 сабт',
    );
  });
}
