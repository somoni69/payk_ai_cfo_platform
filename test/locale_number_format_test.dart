import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:payk_ai_cfo_platform/core/localization/locale_number_format.dart';

void main() {
  group('parseLocalizedNumberForLocale', () {
    const russian = Locale('ru');
    const tajik = Locale('tg');

    test('accepts comma decimals and localized grouping spaces', () {
      expect(parseLocalizedNumberForLocale('1234,50', russian), 1234.5);
      expect(parseLocalizedNumberForLocale('1 234,50', tajik), 1234.5);
      expect(parseLocalizedNumberForLocale('1 234,50', russian), 1234.5);
      expect(parseLocalizedNumberForLocale('1 234,50', tajik), 1234.5);
    });

    test('accepts dot keyboards and conventional mixed separators', () {
      expect(parseLocalizedNumberForLocale('1234.50', tajik), 1234.5);
      expect(parseLocalizedNumberForLocale('1.234,50', russian), 1234.5);
      expect(parseLocalizedNumberForLocale('1,234.50', tajik), 1234.5);
      expect(parseLocalizedNumberForLocale('−0,75', russian), -0.75);
    });

    test('rejects empty, malformed and non-finite values', () {
      expect(parseLocalizedNumberForLocale('', russian), isNull);
      expect(parseLocalizedNumberForLocale('1,2,3', tajik), isNull);
      expect(parseLocalizedNumberForLocale('not a number', russian), isNull);
      expect(parseLocalizedNumberForLocale('Infinity', tajik), isNull);
    });
  });

  group('formatLocalizedNumberForLocale', () {
    test(
      'keeps meaningful fractional money instead of rounding to integers',
      () {
        final formatted = formatLocalizedNumberForLocale(
          1234.5,
          const Locale('ru'),
        );

        expect(formatted.replaceAll(RegExp(r'[\s\u00A0\u202F]'), ''), '1234,5');
      },
    );

    test('can produce exact decimals for calculated form values', () {
      final formatted = formatLocalizedNumberForLocale(
        10.5,
        const Locale('tg'),
        minimumFractionDigits: 2,
        maximumFractionDigits: 2,
        useGrouping: false,
      );

      expect(formatted, '10,50');
    });
  });

  testWidgets('context helpers use the locale from the widget tree', (
    tester,
  ) async {
    double? parsed;

    await tester.pumpWidget(
      Localizations(
        locale: const Locale('tg'),
        delegates: const [DefaultWidgetsLocalizations.delegate],
        child: Builder(
          builder: (context) {
            parsed = parseLocalizedNumber(context, '1234,50');
            return Directionality(
              textDirection: TextDirection.ltr,
              child: Text(
                formatLocalizedNumber(
                  context,
                  1234.5,
                  minimumFractionDigits: 2,
                  maximumFractionDigits: 2,
                ),
              ),
            );
          },
        ),
      ),
    );

    expect(parsed, 1234.5);
    final text = tester.widget<Text>(find.byType(Text)).data!;
    expect(text.replaceAll(RegExp(r'[\s\u00A0\u202F]'), ''), '1234,50');
  });
}
