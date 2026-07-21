import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// Resolves the closest number-formatting locale bundled by intl.
///
/// Tajik is not included in intl 0.20's generated number data. Tajik uses the
/// same decimal and grouping separators as the bundled Russian locale, so it
/// is the intentional fallback until intl ships native tg symbols.
String resolveNumberFormatLocale(Locale locale) {
  if (locale.languageCode == 'ru' || locale.languageCode == 'tg') {
    return 'ru';
  }

  final candidates = <String>[
    Intl.canonicalizedLocale(locale.toLanguageTag()),
    Intl.canonicalizedLocale(locale.languageCode),
  ];

  for (final candidate in candidates) {
    if (NumberFormat.localeExists(candidate)) return candidate;
  }

  return 'ru';
}

/// Creates the application's two-decimal formatter for the active UI locale.
NumberFormat localizedDecimalFormat(BuildContext context) {
  return localizedDecimalFormatForLocale(Localizations.localeOf(context));
}

@visibleForTesting
NumberFormat localizedDecimalFormatForLocale(Locale locale) {
  return localizedNumberFormatForLocale(
    locale,
    minimumFractionDigits: 2,
    maximumFractionDigits: 2,
  );
}

/// Creates a decimal formatter that follows the active UI locale.
NumberFormat localizedNumberFormat(
  BuildContext context, {
  int minimumFractionDigits = 0,
  int maximumFractionDigits = 2,
  bool useGrouping = true,
}) {
  return localizedNumberFormatForLocale(
    Localizations.localeOf(context),
    minimumFractionDigits: minimumFractionDigits,
    maximumFractionDigits: maximumFractionDigits,
    useGrouping: useGrouping,
  );
}

@visibleForTesting
NumberFormat localizedNumberFormatForLocale(
  Locale locale, {
  int minimumFractionDigits = 0,
  int maximumFractionDigits = 2,
  bool useGrouping = true,
}) {
  assert(minimumFractionDigits >= 0);
  assert(maximumFractionDigits >= minimumFractionDigits);

  final format = NumberFormat.decimalPattern(resolveNumberFormatLocale(locale))
    ..minimumFractionDigits = minimumFractionDigits
    ..maximumFractionDigits = maximumFractionDigits;
  if (!useGrouping) format.turnOffGrouping();
  return format;
}

/// Formats a value without discarding meaningful fractional digits.
String formatLocalizedNumber(
  BuildContext context,
  num value, {
  int minimumFractionDigits = 0,
  int maximumFractionDigits = 2,
  bool useGrouping = true,
}) {
  return formatLocalizedNumberForLocale(
    value,
    Localizations.localeOf(context),
    minimumFractionDigits: minimumFractionDigits,
    maximumFractionDigits: maximumFractionDigits,
    useGrouping: useGrouping,
  );
}

String formatLocalizedNumberForLocale(
  num value,
  Locale locale, {
  int minimumFractionDigits = 0,
  int maximumFractionDigits = 2,
  bool useGrouping = true,
}) {
  return localizedNumberFormatForLocale(
    locale,
    minimumFractionDigits: minimumFractionDigits,
    maximumFractionDigits: maximumFractionDigits,
    useGrouping: useGrouping,
  ).format(value);
}

/// Parses a user-entered decimal using the active UI locale.
///
/// Russian and Tajik users normally enter a comma decimal separator, while
/// some mobile keyboards still emit a dot. Both are accepted. Locale grouping
/// separators, regular spaces, non-breaking spaces and narrow non-breaking
/// spaces are ignored.
double? parseLocalizedNumber(BuildContext context, String input) {
  return parseLocalizedNumberForLocale(input, Localizations.localeOf(context));
}

@visibleForTesting
double? parseLocalizedNumberForLocale(String input, Locale locale) {
  final symbols = NumberFormat.decimalPattern(
    resolveNumberFormatLocale(locale),
  ).symbols;
  var normalized = input
      .trim()
      .replaceAll('\u2212', '-')
      .replaceAll(symbols.GROUP_SEP, '')
      .replaceAll(RegExp(r'[\s\u00A0\u202F]'), '');

  if (normalized.isEmpty) return null;

  final commaIndex = normalized.lastIndexOf(',');
  final dotIndex = normalized.lastIndexOf('.');
  final hasComma = commaIndex >= 0;
  final hasDot = dotIndex >= 0;

  String? decimalSeparator;
  if (hasComma && hasDot) {
    decimalSeparator = commaIndex > dotIndex ? ',' : '.';
  } else if (hasComma) {
    if (','.allMatches(normalized).length > 1) return null;
    decimalSeparator = ',';
  } else if (hasDot) {
    if ('.'.allMatches(normalized).length > 1) return null;
    decimalSeparator = '.';
  }

  if (decimalSeparator != null) {
    final decimalIndex = normalized.lastIndexOf(decimalSeparator);
    final buffer = StringBuffer();
    for (var index = 0; index < normalized.length; index++) {
      final character = normalized[index];
      if (character == ',' || character == '.') {
        if (index == decimalIndex) buffer.write('.');
      } else {
        buffer.write(character);
      }
    }
    normalized = buffer.toString();
  }

  if (!RegExp(r'^[+-]?(?:\d+(?:\.\d*)?|\.\d+)$').hasMatch(normalized)) {
    return null;
  }

  final value = double.tryParse(normalized);
  return value != null && value.isFinite ? value : null;
}
