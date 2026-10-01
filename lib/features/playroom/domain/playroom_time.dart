import 'package:intl/intl.dart';

/// Игровая живёт по времени магазина: Душанбе, UTC+5, без летнего времени.
const kStoreOffset = Duration(hours: 5);

class StoreClock {
  final String date;
  final int minute;
  final String hhmm;

  const StoreClock({
    required this.date,
    required this.minute,
    required this.hhmm,
  });
}

/// Стена часов Душанбе для любого момента. Пояс устройства не важен.
DateTime dushanbeWall(DateTime value) {
  final utc = value.toUtc();
  return DateTime.utc(
    utc.year,
    utc.month,
    utc.day,
    utc.hour,
    utc.minute,
    utc.second,
    utc.millisecond,
    utc.microsecond,
  ).add(kStoreOffset);
}

StoreClock storeParts([DateTime? value]) {
  final wall = dushanbeWall(value ?? DateTime.now());
  final hour = wall.hour;
  final minute = wall.minute;
  final month = wall.month.toString().padLeft(2, '0');
  final day = wall.day.toString().padLeft(2, '0');
  return StoreClock(
    date: '${wall.year}-$month-$day',
    minute: hour * 60 + minute,
    hhmm:
        '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}',
  );
}

String storeTime(DateTime value) => storeParts(value).hhmm;

String storeDate(DateTime value) {
  final parts = storeParts(value).date.split('-');
  return '${parts[2]}.${parts[1]}.${parts[0]}';
}

/// Начало в указанный местный день и время, со смещением +05:00.
String isoAt(String date, String hhmm) => '${date}T$hhmm:00+05:00';

int? hhmmToMinute(String hhmm) {
  final parts = hhmm.split(':');
  if (parts.length < 2) return null;
  final hour = int.tryParse(parts[0]);
  final minute = int.tryParse(parts[1]);
  if (hour == null || minute == null) return null;
  return hour * 60 + minute;
}

/// Тариф по минуте начала. null — игровая ещё закрыта.
double? rateAt({
  required int minuteOfDay,
  required String openFrom,
  required String dayUntil,
  required double dayRate,
  required double eveningRate,
}) {
  final open = hhmmToMinute(openFrom);
  final until = hhmmToMinute(dayUntil);
  if (open == null || until == null) return null;
  if (minuteOfDay < open) return null;
  return minuteOfDay <= until ? dayRate : eveningRate;
}

/// Минут до полуночи от минуты суток.
int minutesToClose(int minuteOfDay) => 24 * 60 - minuteOfDay;

/// Сколько ещё можно купить с этой минуты, шагом полчаса.
int cappedMinutes(int minuteOfDay) => (minutesToClose(minuteOfDay) ~/ 30) * 30;

double playroomPrice(int people, double rate, int minutes) {
  return (people * rate * minutes * 100 / 60).round() / 100;
}

String fmtMinutes(int total, {required String hours, required String minutes}) {
  final whole = total ~/ 60;
  final rest = total % 60;
  if (whole > 0 && rest > 0) return '$whole $hours $rest $minutes';
  if (whole > 0) return '$whole $hours';
  return '$rest $minutes';
}

String ticketNo(int number) => number.toString().padLeft(6, '0');

/// «10», «12,5» — без хвостовых нулей.
String fmtRate(num value) {
  final number = value.toDouble();
  if (number == number.roundToDouble()) return number.round().toString();
  return number.toString().replaceAll('.', ',');
}

int secondsLeft(DateTime endAt, [DateTime? now]) {
  final clock = now ?? DateTime.now();
  return ((endAt.millisecondsSinceEpoch - clock.millisecondsSinceEpoch) / 1000)
      .round();
}

String endClock(int startMinute, int minutes) {
  final end = startMinute + minutes;
  final hour = (end ~/ 60) % 24;
  final minute = end % 60;
  return '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
}

final _somoni = NumberFormat('#,##0.00', 'ru_RU');

String formatSomoni(num value) => '${_somoni.format(value)} смн';
