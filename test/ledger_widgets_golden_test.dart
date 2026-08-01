import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:payk_ai_cfo_platform/core/theme/app_theme.dart';
import 'package:payk_ai_cfo_platform/core/theme/theme_extensions.dart';
import 'package:payk_ai_cfo_platform/presentation/widgets/ledger_ai_card.dart';
import 'package:payk_ai_cfo_platform/presentation/widgets/ledger_card.dart';
import 'package:payk_ai_cfo_platform/presentation/widgets/ledger_operation_row.dart';
import 'package:payk_ai_cfo_platform/presentation/widgets/ledger_pill.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Widget wrap(Widget child) {
    return MaterialApp(
      theme: LedgerTheme.light,
      home: Scaffold(
        body: Center(child: SizedBox(width: 360, child: child)),
      ),
    );
  }

  testWidgets('LedgerCard matches golden', (tester) async {
    await tester.pumpWidget(
      wrap(const LedgerCard(child: Text('Ledger card content'))),
    );
    await expectLater(
      find.byType(LedgerCard),
      matchesGoldenFile('goldens/ledger_card.png'),
    );
  });

  testWidgets('LedgerOperationRow matches golden', (tester) async {
    await tester.pumpWidget(
      wrap(
        Builder(
          builder: (context) {
            final colors = context.colors;
            return LedgerOperationRow(
              title: 'Sale',
              category: 'Retail',
              amount: '+1 200',
              isIncome: true,
              pillText: 'paid',
              pillColor: colors.surfaceNested,
              pillTextColor: colors.textSecondary,
            );
          },
        ),
      ),
    );
    await expectLater(
      find.byType(LedgerOperationRow),
      matchesGoldenFile('goldens/ledger_operation_row.png'),
    );
  });

  testWidgets('LedgerAICard and pill render without errors', (tester) async {
    await tester.pumpWidget(
      wrap(
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const LedgerAICard(
              title: 'AI insight',
              content: 'Cash gap is unlikely this week.',
            ),
            const SizedBox(height: 8),
            Builder(
              builder: (context) {
                final colors = context.colors;
                return LedgerPill(
                  text: 'active',
                  backgroundColor: colors.accentGreen.withValues(alpha: 0.12),
                  textColor: colors.accentGreen,
                );
              },
            ),
          ],
        ),
      ),
    );
    expect(find.text('AI insight'), findsOneWidget);
    expect(find.text('active'), findsOneWidget);
  });
}
