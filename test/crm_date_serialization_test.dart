import 'package:flutter_test/flutter_test.dart';
import 'package:payk_ai_cfo_platform/features/crm/data/api_crm_repository.dart';

void main() {
  group('CRM date-only fields', () {
    test('birth_date keeps the calendar day as a local date', () {
      final day = parseCrmDay('1990-05-01');

      expect(day, DateTime(1990, 5, 1));
      expect(day!.isUtc, isFalse);
    });

    test('missing birth_date stays null instead of today', () {
      expect(parseCrmDay(null), isNull);
      expect(parseCrmDay(''), isNull);
      expect(parseCrmDay('not-a-date'), isNull);
    });

    test('expected_close is sent as UTC midnight of the picked day', () {
      final value = crmExpectedCloseValue(DateTime(2026, 10, 10, 0, 30));

      expect(value, '2026-10-10T00:00:00.000Z');
    });
  });
}
