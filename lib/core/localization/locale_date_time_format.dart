import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// Date and time layouts shared by the application.
enum LocalizedDateTimeStyle {
  dayMonthTime('dd.MM HH:mm'),
  date('dd.MM.yyyy'),
  dateTime('dd.MM.yyyy HH:mm'),
  time('HH:mm');

  const LocalizedDateTimeStyle(this.pattern);

  final String pattern;
}

/// Resolves an intl locale with date symbols available to the application.
///
/// intl 0.20 does not bundle Tajik date symbols. The app therefore uses the
/// bundled Russian numeric date conventions for both supported languages.
String resolveDateTimeFormatLocale(Locale locale) {
  if (locale.languageCode == 'ru' || locale.languageCode == 'tg') {
    return 'ru';
  }

  final candidates = <String>[
    Intl.canonicalizedLocale(locale.toLanguageTag()),
    Intl.canonicalizedLocale(locale.languageCode),
  ];
  for (final candidate in candidates) {
    if (DateFormat.localeExists(candidate)) return candidate;
  }

  return 'ru';
}

/// Formats a date-time for the current interface locale.
///
/// API timestamps are converted to the device time zone by default. Set
/// [convertToLocal] to false for calendar-only values such as a due date.
String formatLocalizedDateTime(
  BuildContext context,
  DateTime value, {
  LocalizedDateTimeStyle style = LocalizedDateTimeStyle.dateTime,
  bool convertToLocal = true,
}) {
  return formatLocalizedDateTimeForLocale(
    value,
    Localizations.localeOf(context),
    style: style,
    convertToLocal: convertToLocal,
  );
}

String formatLocalizedDateTimeForLocale(
  DateTime value,
  Locale locale, {
  LocalizedDateTimeStyle style = LocalizedDateTimeStyle.dateTime,
  bool convertToLocal = true,
}) {
  final dateTime = convertToLocal ? value.toLocal() : value;
  return DateFormat(
    style.pattern,
    resolveDateTimeFormatLocale(locale),
  ).format(dateTime);
}
