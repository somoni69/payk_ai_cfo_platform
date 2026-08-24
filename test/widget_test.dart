import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:payk_ai_cfo_platform/core/theme/app_theme.dart';
import 'package:payk_ai_cfo_platform/presentation/widgets/ledger_card.dart';
import 'package:payk_ai_cfo_platform/presentation/widgets/ledger_segmented_control.dart';

void main() {
  group('Ledger Design System Widgets Tests', () {
    testWidgets(
      'LedgerSegmentedControl displays segments and handles selection',
      (WidgetTester tester) async {
        int selected = 0;
        final segments = [
          const LedgerSegmentItem(value: 0, label: 'Day'),
          const LedgerSegmentItem(value: 1, label: 'Month'),
          const LedgerSegmentItem(value: 2, label: 'Year'),
        ];

        await tester.pumpWidget(
          MaterialApp(
            theme: LedgerTheme.light,
            home: Scaffold(
              body: StatefulBuilder(
                builder: (context, setState) {
                  return LedgerSegmentedControl<int>(
                    segments: segments,
                    selectedValue: selected,
                    onValueChanged: (v) => setState(() => selected = v),
                  );
                },
              ),
            ),
          ),
        );

        expect(find.text('Day'), findsOneWidget);
        expect(find.text('Month'), findsOneWidget);
        expect(find.text('Year'), findsOneWidget);

        await tester.tap(find.text('Month'));
        await tester.pumpAndSettle();
        expect(selected, 1);
      },
    );

    testWidgets('LedgerCard displays child content and default styles', (
      WidgetTester tester,
    ) async {
      const cardContent = 'Card Content Text';

      await tester.pumpWidget(
        MaterialApp(
          theme: LedgerTheme.light,
          home: const Scaffold(body: LedgerCard(child: Text(cardContent))),
        ),
      );

      // Verify child content is rendered
      expect(find.text(cardContent), findsOneWidget);

      // Verify card layout decoration (border, border-radius)
      final containerFinder = find.byType(Container);
      expect(containerFinder, findsOneWidget);
      final container = tester.widget<Container>(containerFinder);
      final decoration = container.decoration as BoxDecoration;
      expect(decoration.borderRadius, BorderRadius.circular(16));
      expect(decoration.border, isNotNull);
    });
  });
}
