import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';

/// Tajik strings for Cupertino widgets and accessibility semantics.
class TajikCupertinoLocalizations extends DefaultCupertinoLocalizations {
  const TajikCupertinoLocalizations();

  static const _weekdays = <String>[
    'душ',
    'сеш',
    'чор',
    'пан',
    'ҷум',
    'шан',
    'якш',
  ];

  static const _months = <String>[
    'январ',
    'феврал',
    'март',
    'апрел',
    'май',
    'июн',
    'июл',
    'август',
    'сентябр',
    'октябр',
    'ноябр',
    'декабр',
  ];

  @override
  String datePickerYear(int yearIndex) => yearIndex.toString();

  @override
  String datePickerMonth(int monthIndex) => _months[monthIndex - 1];

  @override
  String datePickerStandaloneMonth(int monthIndex) => _months[monthIndex - 1];

  @override
  String datePickerDayOfMonth(int dayIndex, [int? weekDay]) {
    return weekDay == null
        ? dayIndex.toString()
        : '${_weekdays[weekDay - DateTime.monday]} $dayIndex';
  }

  @override
  String datePickerMediumDate(DateTime date) {
    return '${_weekdays[date.weekday - DateTime.monday]} '
        '${date.day} ${_months[date.month - DateTime.january]}';
  }

  @override
  String datePickerHour(int hour) => hour.toString();

  @override
  String datePickerHourSemanticsLabel(int hour) => '$hour соат';

  @override
  String datePickerMinute(int minute) => minute.toString().padLeft(2, '0');

  @override
  String datePickerMinuteSemanticsLabel(int minute) => '$minute дақиқа';

  @override
  DatePickerDateOrder get datePickerDateOrder => DatePickerDateOrder.dmy;

  @override
  DatePickerDateTimeOrder get datePickerDateTimeOrder =>
      DatePickerDateTimeOrder.date_time_dayPeriod;

  @override
  String get anteMeridiemAbbreviation => 'п.н.';

  @override
  String get postMeridiemAbbreviation => 'п.з.';

  @override
  String get todayLabel => 'Имрӯз';

  @override
  String get alertDialogLabel => 'Огоҳӣ';

  @override
  String tabSemanticsLabel({required int tabIndex, required int tabCount}) {
    assert(tabIndex >= 1);
    assert(tabCount >= 1);
    return 'Ҷадвали $tabIndex аз $tabCount';
  }

  @override
  String timerPickerHour(int hour) => hour.toString();

  @override
  String timerPickerMinute(int minute) => minute.toString();

  @override
  String timerPickerSecond(int second) => second.toString();

  @override
  String timerPickerHourLabel(int hour) => 'соат';

  @override
  List<String> get timerPickerHourLabels => const ['соат'];

  @override
  String timerPickerMinuteLabel(int minute) => 'дақ.';

  @override
  List<String> get timerPickerMinuteLabels => const ['дақ.'];

  @override
  String timerPickerSecondLabel(int second) => 'сон.';

  @override
  List<String> get timerPickerSecondLabels => const ['сон.'];

  @override
  String get cutButtonLabel => 'Буридан';

  @override
  String get copyButtonLabel => 'Нусха бардоштан';

  @override
  String get pasteButtonLabel => 'Гузоштан';

  @override
  String get clearButtonLabel => 'Тоза кардан';

  @override
  String get noSpellCheckReplacementsLabel => 'Ивазкунанда ёфт нашуд';

  @override
  String get selectAllButtonLabel => 'Ҳамаро интихоб кардан';

  @override
  String get lookUpButtonLabel => 'Ҷустуҷӯ';

  @override
  String get searchWebButtonLabel => 'Ҷустуҷӯ дар интернет';

  @override
  String get shareButtonLabel => 'Мубодила';

  @override
  String get searchTextFieldPlaceholderLabel => 'Ҷустуҷӯ';

  @override
  String get modalBarrierDismissLabel => 'Пӯшидан';

  @override
  String get menuDismissLabel => 'Пӯшидани меню';

  @override
  String get cancelButtonLabel => 'Бекор кардан';

  @override
  String get backButtonLabel => 'Бозгашт';

  @override
  String get expansionTileExpandedHint =>
      'барои пӯшидан ду маротиба пахш кунед';

  @override
  String get expansionTileCollapsedHint =>
      'барои кушодан ду маротиба пахш кунед';

  @override
  String get expansionTileExpandedTapHint => 'Пӯшидан';

  @override
  String get expansionTileCollapsedTapHint => 'Барои тафсилоти бештар кушоед';

  @override
  String get expandedHint => 'Пӯшида';

  @override
  String get collapsedHint => 'Кушода';
}

class TajikCupertinoLocalizationsDelegate
    extends LocalizationsDelegate<CupertinoLocalizations> {
  const TajikCupertinoLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) => locale.languageCode == 'tg';

  @override
  Future<CupertinoLocalizations> load(Locale locale) =>
      SynchronousFuture(const TajikCupertinoLocalizations());

  @override
  bool shouldReload(TajikCupertinoLocalizationsDelegate old) => false;
}
