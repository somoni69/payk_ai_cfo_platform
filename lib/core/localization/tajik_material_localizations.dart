import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart';
import 'locale_number_format.dart';

/// Tajik Material strings used by Flutter's built-in dialogs and controls.
class TajikMaterialLocalizations extends MaterialLocalizationRu {
  TajikMaterialLocalizations({
    required super.fullYearFormat,
    required super.compactDateFormat,
    required super.shortDateFormat,
    required super.mediumDateFormat,
    required super.longDateFormat,
    required super.yearMonthFormat,
    required super.shortMonthDayFormat,
    required super.decimalFormat,
    required super.twoDigitZeroPaddedFormat,
  }) : super(localeName: 'tg');

  static const _months = [
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

  static const _shortWeekdays = ['Дш', 'Сш', 'Чш', 'Пш', 'Ҷм', 'Шб', 'Яш'];

  static const _weekdays = [
    'душанбе',
    'сешанбе',
    'чоршанбе',
    'панҷшанбе',
    'ҷумъа',
    'шанбе',
    'якшанбе',
  ];

  @override
  String formatYear(DateTime date) => '${date.year}';

  @override
  String formatCompactDate(DateTime date) =>
      '${date.day.toString().padLeft(2, '0')}.'
      '${date.month.toString().padLeft(2, '0')}.${date.year}';

  @override
  String formatShortDate(DateTime date) =>
      '${date.day} ${_months[date.month - 1]} ${date.year}';

  @override
  String formatMediumDate(DateTime date) =>
      '${_shortWeekdays[date.weekday - 1]}, ${date.day} '
      '${_months[date.month - 1]}';

  @override
  String formatFullDate(DateTime date) =>
      '${_weekdays[date.weekday - 1]}, ${date.day} '
      '${_months[date.month - 1]} ${date.year}';

  @override
  String formatMonthYear(DateTime date) =>
      '${_months[date.month - 1]} ${date.year}';

  @override
  String formatShortMonthDay(DateTime date) =>
      '${date.day} ${_months[date.month - 1]}';

  @override
  List<String> get narrowWeekdays => const ['Я', 'Д', 'С', 'Ч', 'П', 'Ҷ', 'Ш'];

  @override
  int get firstDayOfWeekIndex => 1;

  @override
  String get alertDialogLabel => 'Огоҳӣ';

  @override
  String get backButtonTooltip => 'Қафо';

  @override
  String get calendarModeButtonLabel => 'Гузариш ба тақвим';

  @override
  String get cancelButtonLabel => 'Бекор кардан';

  @override
  String get clearButtonTooltip => 'Пок кардани матн';

  @override
  String get closeButtonLabel => 'Пӯшидан';

  @override
  String get closeButtonTooltip => 'Пӯшидан';

  @override
  String get continueButtonLabel => 'Идома додан';

  @override
  String get copyButtonLabel => 'Нусхабардорӣ';

  @override
  String get currentDateLabel => 'Имрӯз';

  @override
  String get cutButtonLabel => 'Буридан';

  @override
  String get dateHelpText => 'рр.мм.сссс';

  @override
  String get dateInputLabel => 'Санаро ворид кунед';

  @override
  String get dateOutOfRangeLabel => 'Сана берун аз ҳудуди иҷозатшуда аст.';

  @override
  String get datePickerHelpText => 'Санаро интихоб кунед';

  @override
  String get dateRangeEndLabel => 'Санаи анҷом';

  @override
  String get dateRangePickerHelpText => 'Фосилаи санаҳоро интихоб кунед';

  @override
  String get dateRangeStartLabel => 'Санаи оғоз';

  @override
  String get deleteButtonTooltip => 'Нест кардан';

  @override
  String get dialogLabel => 'Равзанаи муколама';

  @override
  String get drawerLabel => 'Менюи паймоиш';

  @override
  String get inputDateModeButtonLabel => 'Гузариш ба воридкунии дастӣ';

  @override
  String get invalidDateFormatLabel => 'Формати сана нодуруст аст.';

  @override
  String get invalidDateRangeLabel => 'Фосилаи санаҳо нодуруст аст.';

  @override
  String get menuDismissLabel => 'Пӯшидани меню';

  @override
  String get modalBarrierDismissLabel => 'Пӯшидан';

  @override
  String get moreButtonTooltip => 'Бештар';

  @override
  String get nextMonthTooltip => 'Моҳи оянда';

  @override
  String get nextPageTooltip => 'Саҳифаи оянда';

  @override
  String get okButtonLabel => 'ХУБ';

  @override
  String get openAppDrawerTooltip => 'Кушодани менюи паймоиш';

  @override
  String get pasteButtonLabel => 'Гузоштан';

  @override
  String get previousMonthTooltip => 'Моҳи гузашта';

  @override
  String get previousPageTooltip => 'Саҳифаи гузашта';

  @override
  String get refreshIndicatorSemanticLabel => 'Навсозӣ';

  @override
  String get saveButtonLabel => 'Нигоҳ доштан';

  @override
  String get searchFieldLabel => 'Ҷустуҷӯ';

  @override
  String get selectAllButtonLabel => 'Интихоби ҳама';

  @override
  String get selectYearSemanticsLabel => 'Солро интихоб кунед';

  @override
  String get selectedDateLabel => 'Интихоб шуд';

  @override
  String get timePickerDialHelpText => 'Вақтро интихоб кунед';

  @override
  String get timePickerHourLabel => 'Соат';

  @override
  String get timePickerHourModeAnnouncement => 'Соатро интихоб кунед';

  @override
  String get timePickerInputHelpText => 'Вақтро ворид кунед';

  @override
  String get timePickerMinuteLabel => 'Дақиқа';

  @override
  String get timePickerMinuteModeAnnouncement => 'Дақиқаро интихоб кунед';

  @override
  String get showMenuTooltip => 'Намоиши меню';

  @override
  String get popupMenuLabel => 'Менюи бозшаванда';

  @override
  String get bottomSheetLabel => 'Равзанаи поёнӣ';

  @override
  String get scrimLabel => 'Пасзамина';

  @override
  String scrimOnTapHint(String modalRouteContentName) =>
      'Пӯшидани $modalRouteContentName';

  @override
  String get lookUpButtonLabel => 'Ҷустуҷӯ';

  @override
  String get searchWebButtonLabel => 'Ҷустуҷӯ дар интернет';

  @override
  String get shareButtonLabel => 'Мубодила';

  @override
  String get aboutListTileTitleRaw => r'Дар бораи $applicationName';

  @override
  String get anteMeridiemAbbreviation => 'то нисфирӯзӣ';

  @override
  String get postMeridiemAbbreviation => 'пас аз нисфирӯзӣ';

  @override
  String get collapsedHint => 'Кушода';

  @override
  String get collapsedIconTapHint => 'Кушодан';

  @override
  String get expandedHint => 'Пӯшида';

  @override
  String get expandedIconTapHint => 'Пӯшидан';

  @override
  String get expansionTileCollapsedHint =>
      'барои кушодан ду маротиба пахш кунед';

  @override
  String get expansionTileCollapsedTapHint => 'Барои дидани тафсилот кушоед';

  @override
  String get expansionTileExpandedHint =>
      'барои пӯшидан ду маротиба пахш кунед';

  @override
  String get expansionTileExpandedTapHint => 'Пӯшидан';

  @override
  String get dateRangeEndDateSemanticLabelRaw => r'Санаи анҷом: $fullDate';

  @override
  String get dateRangeStartDateSemanticLabelRaw => r'Санаи оғоз: $fullDate';

  @override
  String get dateSeparator => '.';

  @override
  String get dialModeButtonLabel => 'Гузариш ба интихоби вақти ақрабакӣ';

  @override
  String get inputTimeModeButtonLabel => 'Гузариш ба воридкунии матн';

  @override
  String get invalidTimeLabel => 'Вақти дурустро ворид кунед.';

  @override
  String get firstPageTooltip => 'Саҳифаи аввал';

  @override
  String get lastPageTooltip => 'Саҳифаи охирин';

  @override
  String get hideAccountsLabel => 'Пинҳон кардани ҳисобҳо';

  @override
  String get showAccountsLabel => 'Намоиши ҳисобҳо';

  @override
  String get keyboardKeyChannelDown => 'Канали навбатӣ';

  @override
  String get keyboardKeyChannelUp => 'Канали қаблӣ';

  @override
  String get keyboardKeyEject => 'Баровардан';

  @override
  String get keyboardKeyNumpadEnter => 'Num Enter';

  @override
  String get keyboardKeyPower => 'Қувва';

  @override
  String get keyboardKeyPowerOff => 'Хомӯш кардани дастгоҳ';

  @override
  String get keyboardKeySelect => 'Интихоб';

  @override
  String get keyboardKeySpace => 'Фосила';

  @override
  String? get licensesPackageDetailTextFew => r'$licenseCount иҷозатнома';

  @override
  String? get licensesPackageDetailTextMany => r'$licenseCount иҷозатнома';

  @override
  String? get licensesPackageDetailTextOne => '1 иҷозатнома';

  @override
  String get licensesPackageDetailTextOther => r'$licenseCount иҷозатнома';

  @override
  String? get licensesPackageDetailTextTwo => r'$licenseCount иҷозатнома';

  @override
  String? get licensesPackageDetailTextZero => 'Иҷозатнома нест';

  @override
  String get licensesPageTitle => 'Иҷозатномаҳо';

  @override
  String get viewLicensesButtonLabel => 'Дидани иҷозатномаҳо';

  @override
  String get menuBarMenuLabel => 'Менюи сатри меню';

  @override
  String get pageRowsInfoTitleRaw => r'$firstRow–$lastRow аз $rowCount';

  @override
  String get pageRowsInfoTitleApproximateRaw =>
      r'$firstRow–$lastRow аз тақрибан $rowCount';

  @override
  String? get remainingTextFieldCharacterCountFew =>
      r'$remainingCount аломат боқӣ монд';

  @override
  String? get remainingTextFieldCharacterCountMany =>
      r'$remainingCount аломат боқӣ монд';

  @override
  String? get remainingTextFieldCharacterCountOne => '1 аломат боқӣ монд';

  @override
  String get remainingTextFieldCharacterCountOther =>
      r'$remainingCount аломат боқӣ монд';

  @override
  String? get remainingTextFieldCharacterCountTwo =>
      r'$remainingCount аломат боқӣ монд';

  @override
  String? get remainingTextFieldCharacterCountZero => 'Аломат боқӣ намонд';

  @override
  String get reorderItemDown => 'Ба поён гузарондан';

  @override
  String get reorderItemLeft => 'Ба чап гузарондан';

  @override
  String get reorderItemRight => 'Ба рост гузарондан';

  @override
  String get reorderItemToEnd => 'Ба охир гузарондан';

  @override
  String get reorderItemToStart => 'Ба аввал гузарондан';

  @override
  String get reorderItemUp => 'Ба боло гузарондан';

  @override
  String get rowsPerPageTitle => 'Сатрҳо дар саҳифа:';

  @override
  String get scanTextButtonLabel => 'Скан кардани матн';

  @override
  String? get selectedRowCountTitleFew => r'$selectedRowCount сатр интихоб шуд';

  @override
  String? get selectedRowCountTitleMany =>
      r'$selectedRowCount сатр интихоб шуд';

  @override
  String? get selectedRowCountTitleOne => '1 сатр интихоб шуд';

  @override
  String get selectedRowCountTitleOther =>
      r'$selectedRowCount сатр интихоб шуд';

  @override
  String? get selectedRowCountTitleTwo => r'$selectedRowCount сатр интихоб шуд';

  @override
  String? get selectedRowCountTitleZero => 'Ягон сатр интихоб нашуд';

  @override
  String get signedInLabel => 'Ворид шуд';

  @override
  String get tabLabelRaw => r'Ҷадвали $tabIndex аз $tabCount';
  @override
  String get unspecifiedDate => 'Сана';

  @override
  String get unspecifiedDateRange => 'Фосилаи санаҳо';
}

class TajikMaterialLocalizationsDelegate
    extends LocalizationsDelegate<MaterialLocalizations> {
  const TajikMaterialLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) => locale.languageCode == 'tg';

  @override
  Future<MaterialLocalizations> load(Locale locale) async {
    await GlobalMaterialLocalizations.delegate.load(const Locale('ru'));
    final formattingLocale = resolveNumberFormatLocale(locale);

    return TajikMaterialLocalizations(
      fullYearFormat: DateFormat.y(formattingLocale),
      compactDateFormat: DateFormat.yMd(formattingLocale),
      shortDateFormat: DateFormat.yMMMd(formattingLocale),
      mediumDateFormat: DateFormat.MMMEd(formattingLocale),
      longDateFormat: DateFormat.yMMMMEEEEd(formattingLocale),
      yearMonthFormat: DateFormat.yMMMM(formattingLocale),
      shortMonthDayFormat: DateFormat.MMMd(formattingLocale),
      decimalFormat: NumberFormat.decimalPattern(formattingLocale),
      twoDigitZeroPaddedFormat: NumberFormat('00', formattingLocale),
    );
  }

  @override
  bool shouldReload(TajikMaterialLocalizationsDelegate old) => false;
}
