import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:payk_ai_cfo_platform/core/theme/app_theme.dart';
import 'package:payk_ai_cfo_platform/presentation/widgets/ledger_card.dart';
import 'package:payk_ai_cfo_platform/presentation/widgets/ledger_pill.dart';

void main() {
  group('Ledger Design System Widgets Tests', () {
    testWidgets('LedgerPill displays text and uses given colors', (WidgetTester tester) async {
      const pillText = 'Test Pill';
      const bgColor = Colors.yellow;
      const txColor = Colors.purple;

      await tester.pumpWidget(
        MaterialApp(
          theme: LedgerTheme.light,
          home: const Scaffold(
            body: LedgerPill(
              text: pillText,
              backgroundColor: bgColor,
              textColor: txColor,
            ),
          ),
        ),
      );

      // Verify text is rendered
      expect(find.text(pillText), findsOneWidget);

      // Verify Container uses backgroundColor
      final containerFinder = find.byType(Container);
      expect(containerFinder, findsOneWidget);
      final container = tester.widget<Container>(containerFinder);
      final decoration = container.decoration as BoxDecoration;
      expect(decoration.color, bgColor);
      expect(decoration.borderRadius, BorderRadius.circular(999));
    });

    testWidgets('LedgerCard displays child content and default styles', (WidgetTester tester) async {
      const cardContent = 'Card Content Text';

      await tester.pumpWidget(
        MaterialApp(
          theme: LedgerTheme.light,
          home: const Scaffold(
            body: LedgerCard(
              child: Text(cardContent),
            ),
          ),
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
