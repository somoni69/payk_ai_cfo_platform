import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:payk_ai_cfo_platform/core/theme/app_theme.dart';
import 'package:payk_ai_cfo_platform/core/theme/app_colors.dart';
import 'package:payk_ai_cfo_platform/core/theme/app_text_styles.dart';
import 'package:payk_ai_cfo_platform/core/theme/ledger_buttons.dart';
import 'package:payk_ai_cfo_platform/core/theme/ledger_layout.dart';
import 'package:payk_ai_cfo_platform/presentation/widgets/ledger_bottom_sheet.dart';

void main() {
  group('LedgerLayout 20:9 / 21:9', () {
    test(
      'Pova 6 class 20:9 is ultra-tall and peeks the next funnel column',
      () {
        const layout = LedgerLayout(size: Size(360, 800));
        expect(layout.aspect, closeTo(20 / 9, 0.03));
        expect(layout.isUltraTall, isTrue);
        expect(layout.isNarrow, isTrue);

        final col = layout.funnelColumnWidth(360);
        expect(col, lessThan(360 - 32));
        expect(360 - 32 - col, greaterThanOrEqualTo(48));
      },
    );

    test('21:9 is ultra-tall', () {
      const layout = LedgerLayout(size: Size(360, 840));
      expect(layout.aspect, closeTo(21 / 9, 0.02));
      expect(layout.isUltraTall, isTrue);
      expect(layout.gridChildAspect(1.7), lessThan(1.7));
    });

    test('16:9 is not treated as tall', () {
      const layout = LedgerLayout(size: Size(360, 640));
      expect(layout.isTall, isFalse);
      expect(layout.isUltraTall, isFalse);
      expect(layout.gridChildAspect(1.7), closeTo(1.7 * 0.92, 0.01));
    });
  });

  testWidgets('content modals use the AI assistant height factor as a cap', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const MediaQuery(
        data: MediaQueryData(size: Size(360, 800)),
        child: SizedBox(),
      ),
    );
    final ctx = tester.element(find.byType(SizedBox));
    expect(kLedgerModalHeightFactor, 0.88);
    expect(ledgerModalHeightOf(ctx), 800 * 0.88);
  });

  testWidgets('short content sheets wrap instead of filling 88%', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        theme: LedgerTheme.light,
        home: Align(
          alignment: Alignment.bottomCenter,
          child: Builder(
            builder: (context) {
              return LedgerBottomSheet(
                title: 'План',
                maxHeight: ledgerModalHeightOf(context),
                footer: const SizedBox(height: 48, child: Text('Создать')),
                child: const SizedBox(height: 120, child: Text('fields')),
              );
            },
          ),
        ),
      ),
    );

    final size = tester.getSize(find.byType(LedgerBottomSheet));
    expect(size.height, lessThan(800 * kLedgerModalHeightFactor));
    expect(size.height, greaterThan(120));
    expect(find.text('fields'), findsOneWidget);
    expect(find.text('Создать'), findsOneWidget);
  });

  testWidgets('tall content sheets cap at the AI assistant height', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        theme: LedgerTheme.light,
        home: Align(
          alignment: Alignment.bottomCenter,
          child: Builder(
            builder: (context) {
              return LedgerBottomSheet(
                title: 'Журнал',
                maxHeight: ledgerModalHeightOf(context),
                child: const SizedBox(height: 2000, child: Text('long')),
              );
            },
          ),
        ),
      ),
    );

    final size = tester.getSize(find.byType(LedgerBottomSheet));
    expect(size.height, closeTo(800 * kLedgerModalHeightFactor, 0.5));
    expect(find.text('long'), findsOneWidget);
  });

  group('LedgerButtons', () {
    test('screen and modal sizes stay distinct', () {
      expect(kLedgerScreenButtonHeight, 44);
      expect(kLedgerModalButtonHeight, 48);
      expect(kLedgerScreenButtonRadius, kLedgerModalButtonRadius);
      expect(kLedgerScreenButtonRadius, 12);
      expect(kLedgerScreenButtonFont, 13);
      expect(kLedgerModalButtonFont, 14);
    });

    test('screen elevated style is 44px / radius 12', () {
      const colors = LedgerColors.light;
      final text = LedgerTextStyles.generate(colors);
      final style = LedgerButtons.screenElevated(colors, text);
      expect(style.minimumSize?.resolve({}), const Size(64, 44));
      expect(style.maximumSize?.resolve({})?.height, 44);
      final shape = style.shape?.resolve({}) as RoundedRectangleBorder?;
      expect(shape?.borderRadius, BorderRadius.circular(12));
    });

    test('modal elevated style is 48px / radius 12', () {
      const colors = LedgerColors.light;
      final text = LedgerTextStyles.generate(colors);
      final style = LedgerButtons.modalElevated(colors, text);
      expect(style.minimumSize?.resolve({}), const Size(64, 48));
      expect(style.maximumSize?.resolve({})?.height, 48);
      final shape = style.shape?.resolve({}) as RoundedRectangleBorder?;
      expect(shape?.borderRadius, BorderRadius.circular(12));
    });
  });
}
