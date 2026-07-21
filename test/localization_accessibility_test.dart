import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:payk_ai_cfo_platform/core/localization/language_cubit.dart';
import 'package:payk_ai_cfo_platform/core/localization/locale_number_format.dart';
import 'package:payk_ai_cfo_platform/core/localization/tajik_cupertino_localizations.dart';
import 'package:payk_ai_cfo_platform/core/localization/tajik_material_localizations.dart';
import 'package:payk_ai_cfo_platform/core/theme/app_colors.dart';
import 'package:payk_ai_cfo_platform/core/theme/app_theme.dart';
import 'package:payk_ai_cfo_platform/presentation/screens/tasks_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'Tajik Material localizations do not fall back to visible Russian text',
    () async {
      final localizations = await const TajikMaterialLocalizationsDelegate()
          .load(const Locale('tg'));

      expect(localizations.aboutListTileTitle('PAYK'), 'Дар бораи PAYK');
      expect(localizations.collapsedIconTapHint, 'Кушодан');
      expect(localizations.expansionTileExpandedTapHint, 'Пӯшидан');
      expect(localizations.firstPageTooltip, 'Саҳифаи аввал');
      expect(localizations.lastPageTooltip, 'Саҳифаи охирин');
      expect(localizations.invalidTimeLabel, 'Вақти дурустро ворид кунед.');
      expect(localizations.rowsPerPageTitle, 'Сатрҳо дар саҳифа:');
      expect(localizations.licensesPageTitle, 'Иҷозатномаҳо');
      expect(localizations.signedInLabel, 'Ворид шуд');
      expect(
        localizations.tabLabel(tabIndex: 1, tabCount: 3),
        'Ҷадвали 1 аз 3',
      );
    },
  );

  test('Tajik Cupertino localizations cover built-in controls', () async {
    const delegate = TajikCupertinoLocalizationsDelegate();
    final localizations = await delegate.load(const Locale('tg'));

    expect(delegate.isSupported(const Locale('tg')), isTrue);
    expect(delegate.isSupported(const Locale('ru')), isFalse);
    expect(localizations.cancelButtonLabel, 'Бекор кардан');
    expect(localizations.backButtonLabel, 'Бозгашт');
    expect(localizations.datePickerMonth(1), 'январ');
    expect(
      localizations.tabSemanticsLabel(tabIndex: 2, tabCount: 5),
      'Ҷадвали 2 аз 5',
    );
  });
  test('number formatter resolves the active locale safely', () {
    expect(resolveNumberFormatLocale(const Locale('ru', 'RU')), 'ru');
    // intl 0.20 has no native Tajik symbols; the documented fallback uses
    // the same decimal and grouping separators.
    expect(resolveNumberFormatLocale(const Locale('tg')), 'ru');

    final formatted = localizedDecimalFormatForLocale(
      const Locale('tg'),
    ).format(1234.5);
    expect(formatted, contains(','));
    expect(formatted, endsWith('50'));
  });

  test('secondary and hint colors meet WCAG AA on application surfaces', () {
    const colors = LedgerColors.light;

    expect(
      _contrastRatio(colors.textSecondary, colors.surface),
      greaterThanOrEqualTo(4.5),
    );
    expect(
      _contrastRatio(colors.textSecondary, colors.background),
      greaterThanOrEqualTo(4.5),
    );
    expect(
      _contrastRatio(colors.textTooltip, colors.surface),
      greaterThanOrEqualTo(4.5),
    );
    expect(
      _contrastRatio(colors.textTooltip, colors.background),
      greaterThanOrEqualTo(4.5),
    );
  });

  test('icon actions keep a minimum 48 by 48 logical-pixel target', () {
    final minimumSize = LedgerTheme.light.iconButtonTheme.style?.minimumSize
        ?.resolve(const <WidgetState>{});

    expect(minimumSize, const Size.square(48));
    expect(
      LedgerTheme.light.materialTapTargetSize,
      MaterialTapTargetSize.padded,
    );
  });

  testWidgets('task checkbox exposes checked, enabled, and tap semantics', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    bool? changedValue;

    await tester.pumpWidget(
      MaterialApp(
        theme: LedgerTheme.light,
        home: Scaffold(
          body: AnimatedCheckbox(
            value: false,
            semanticLabel: 'Quarterly report',
            pendingSemanticLabel: 'Loading',
            onChanged: (value) => changedValue = value,
          ),
        ),
      ),
    );

    final checkbox = find.byType(AnimatedCheckbox);
    expect(tester.getSize(checkbox), const Size.square(48));
    expect(
      tester.getSemantics(checkbox),
      matchesSemantics(
        label: 'Quarterly report',
        hasCheckedState: true,
        hasEnabledState: true,
        isEnabled: true,
        hasTapAction: true,
      ),
    );

    await tester.tap(checkbox);
    expect(changedValue, isTrue);
    semantics.dispose();
  });

  testWidgets('locale switches and disposes the app tree cleanly', (
    tester,
  ) async {
    final language = LanguageCubit();
    addTearDown(language.close);

    await tester.pumpWidget(
      BlocProvider<LanguageCubit>.value(
        value: language,
        child: BlocBuilder<LanguageCubit, Locale>(
          builder: (context, locale) {
            return MaterialApp(
              locale: locale,
              supportedLocales: const [Locale('ru'), Locale('tg')],
              localizationsDelegates: const [
                TajikMaterialLocalizationsDelegate(),
                TajikCupertinoLocalizationsDelegate(),
                GlobalMaterialLocalizations.delegate,
                GlobalWidgetsLocalizations.delegate,
                GlobalCupertinoLocalizations.delegate,
              ],
              home: Text(locale.languageCode, key: const Key('locale')),
            );
          },
        ),
      ),
    );

    expect(find.text('ru'), findsOneWidget);
    await language.setLanguage('tg');
    await tester.pumpAndSettle();
    expect(find.text('tg'), findsOneWidget);

    await language.setLanguage('ru');
    await tester.pumpAndSettle();
    await language.setLanguage('tg');
    await tester.pumpAndSettle();
    expect(find.text('tg'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}

double _contrastRatio(Color foreground, Color background) {
  final foregroundLuminance = foreground.computeLuminance();
  final backgroundLuminance = background.computeLuminance();
  final lighter = foregroundLuminance > backgroundLuminance
      ? foregroundLuminance
      : backgroundLuminance;
  final darker = foregroundLuminance > backgroundLuminance
      ? backgroundLuminance
      : foregroundLuminance;
  return (lighter + 0.05) / (darker + 0.05);
}
