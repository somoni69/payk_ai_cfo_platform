import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:payk_ai_cfo_platform/core/localization/locale_date_time_format.dart';
import 'package:payk_ai_cfo_platform/core/localization/locale_number_format.dart';

void main() {
  setUpAll(() => initializeDateFormatting('ru'));

  group('NumberFormat & DateFormat Caching & Performance Tests (PERF-09)', () {
    test(
      'NumberFormat instance is cached and returns identical object on repeated calls',
      () {
        const ru = Locale('ru');
        const tg = Locale('tg');

        final fmt1 = localizedNumberFormatForLocale(
          ru,
          minimumFractionDigits: 2,
          maximumFractionDigits: 2,
        );
        final fmt2 = localizedNumberFormatForLocale(
          ru,
          minimumFractionDigits: 2,
          maximumFractionDigits: 2,
        );
        final fmtTg = localizedNumberFormatForLocale(
          tg,
          minimumFractionDigits: 2,
          maximumFractionDigits: 2,
        );

        // Both ru calls return identical cached instance
        expect(identical(fmt1, fmt2), isTrue);

        // Tajik resolves to Russian number format symbols and shares cache
        expect(identical(fmt1, fmtTg), isTrue);
      },
    );

    test('NumberFormat formatting performance under high-frequency workload', () {
      const locale = Locale('ru');
      final stopwatch = Stopwatch()..start();

      for (int i = 0; i < 5000; i++) {
        final formatted = formatLocalizedNumberForLocale(
          1234567.89 + i,
          locale,
        );
        expect(formatted, contains('1'));
      }

      stopwatch.stop();
      // 5,000 formatted numbers with cached formatter should complete in < 2000ms
      expect(stopwatch.elapsedMilliseconds, lessThan(2000));
    });

    test(
      'parseLocalizedNumberForLocale handles commas, dots, regular and non-breaking spaces',
      () {
        const ru = Locale('ru');

        expect(parseLocalizedNumberForLocale('1 500,50', ru), 1500.50);
        expect(parseLocalizedNumberForLocale('1 500.50', ru), 1500.50);
        expect(parseLocalizedNumberForLocale('1500,50', ru), 1500.50);
        expect(parseLocalizedNumberForLocale('1500.50', ru), 1500.50);
        expect(parseLocalizedNumberForLocale('  25 000,00  ', ru), 25000.0);
        expect(parseLocalizedNumberForLocale('-350,75', ru), -350.75);
        expect(
          parseLocalizedNumberForLocale('−350,75', ru),
          -350.75,
        ); // unicode minus
        expect(parseLocalizedNumberForLocale('invalid_number', ru), isNull);
        expect(parseLocalizedNumberForLocale('', ru), isNull);
      },
    );

    test('DateFormat caching across all LocalizedDateTimeStyle patterns', () {
      final date = DateTime.utc(2026, 9, 1, 14, 30);
      const localeRu = Locale('ru');
      const localeTg = Locale('tg');

      final d1 = formatLocalizedDateTimeForLocale(
        date,
        localeRu,
        style: LocalizedDateTimeStyle.date,
        convertToLocal: false,
      );
      final d2 = formatLocalizedDateTimeForLocale(
        date,
        localeRu,
        style: LocalizedDateTimeStyle.date,
        convertToLocal: false,
      );
      expect(d1, d2);
      expect(d1, '01.09.2026');

      final timeStr = formatLocalizedDateTimeForLocale(
        date,
        localeTg,
        style: LocalizedDateTimeStyle.time,
        convertToLocal: false,
      );
      expect(timeStr, '14:30');

      final dayMonth = formatLocalizedDateTimeForLocale(
        date,
        localeRu,
        style: LocalizedDateTimeStyle.dayMonthTime,
        convertToLocal: false,
      );
      expect(dayMonth, '01.09 14:30');

      final fullDateTime = formatLocalizedDateTimeForLocale(
        date,
        localeRu,
        style: LocalizedDateTimeStyle.dateTime,
        convertToLocal: false,
      );
      expect(fullDateTime, '01.09.2026 14:30');
    });

    test(
      'resolveDateTimeFormatLocale defaults to bundled ru locale for unsupported tags',
      () {
        expect(resolveDateTimeFormatLocale(const Locale('ru')), 'ru');
        expect(resolveDateTimeFormatLocale(const Locale('tg')), 'ru');
        expect(resolveDateTimeFormatLocale(const Locale('unknown')), 'ru');
      },
    );
  });
}
