import 'package:flutter_test/flutter_test.dart';
import 'package:payk_ai_cfo_platform/features/playroom/domain/playroom_time.dart';

void main() {
  test('Dushanbe wall clock is UTC+5 with no daylight shift', () {
    final afternoon = DateTime.utc(2026, 9, 29, 10);
    expect(storeParts(afternoon).date, '2026-09-29');
    expect(storeParts(afternoon).hhmm, '15:00');
    expect(storeParts(afternoon).minute, 15 * 60);

    final evening = DateTime.utc(2026, 9, 29, 10, 1);
    expect(storeParts(evening).hhmm, '15:01');

    final closed = DateTime.utc(2026, 9, 29, 2, 59);
    expect(storeParts(closed).hhmm, '07:59');

    final afterMidnight = DateTime.utc(2026, 9, 29, 19, 30);
    expect(storeParts(afterMidnight).date, '2026-09-30');
    expect(storeParts(afterMidnight).hhmm, '00:30');
  });

  test('day rate holds through 15:00 and evening starts at 15:01', () {
    double? rate(int minute) => rateAt(
      minuteOfDay: minute,
      openFrom: '08:00',
      dayUntil: '15:00',
      dayRate: 10,
      eveningRate: 20,
    );

    expect(rate(7 * 60 + 59), isNull);
    expect(rate(8 * 60), 10);
    expect(rate(15 * 60), 10);
    expect(rate(15 * 60 + 1), 20);
  });

  test('price rounds to cents and time stays inside the day', () {
    expect(playroomPrice(2, 10, 90), 30);
    expect(playroomPrice(1, 10, 45), 7.5);
    expect(playroomPrice(3, 20, 30), 30);
    expect(playroomPrice(1, 10, 20), closeTo(3.33, 0.001));
    expect(minutesToClose(23 * 60), 60);
    expect(cappedMinutes(23 * 60), 60);
    expect(cappedMinutes(15 * 60 + 1), 510);
    expect(isoAt('2026-09-29', '14:30'), '2026-09-29T14:30:00+05:00');
    expect(endClock(23 * 60, 30), '23:30');
  });

  test('ticket number, duration and rate match the web format', () {
    expect(ticketNo(7), '000007');
    expect(fmtMinutes(90, hours: 'ч', minutes: 'мин'), '1 ч 30 мин');
    expect(fmtMinutes(60, hours: 'ч', minutes: 'мин'), '1 ч');
    expect(fmtMinutes(30, hours: 'ч', minutes: 'мин'), '30 мин');
    expect(fmtRate(10), '10');
    expect(fmtRate(12.5), '12,5');
    expect(
      secondsLeft(
        DateTime.utc(2026, 9, 29, 12),
        DateTime.utc(2026, 9, 29, 11, 59, 30),
      ),
      30,
    );
  });
}
