import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:payk_ai_cfo_platform/core/theme/app_theme.dart';
import 'package:payk_ai_cfo_platform/presentation/widgets/expansible_widget.dart';

void main() {
  testWidgets(
    'selection options are built lazily and large lists are searchable',
    (tester) async {
      var labelBuildCount = 0;
      final items = List<int>.generate(30, (index) => index);

      await tester.pumpWidget(
        MaterialApp(
          theme: LedgerTheme.light,
          home: Scaffold(
            body: SingleChildScrollView(
              child: ExpansibleWidget<int>.selection(
                title: const Text('Choose item'),
                items: items,
                selectedValue: 0,
                itemLabelBuilder: (item) {
                  labelBuildCount++;
                  return 'Item $item';
                },
                onSelected: (_) {},
              ),
            ),
          ),
        ),
      );

      expect(labelBuildCount, 0);
      expect(find.byType(TextField), findsNothing);

      await tester.tap(find.text('Choose item'));
      await tester.pumpAndSettle();

      expect(find.byType(TextField), findsOneWidget);
      expect(labelBuildCount, greaterThan(0));
      expect(labelBuildCount, lessThan(items.length));

      await tester.enterText(find.byType(TextField), 'Item 29');
      await tester.pump();

      expect(find.widgetWithText(ListTile, 'Item 29'), findsOneWidget);
      expect(find.widgetWithText(ListTile, 'Item 1'), findsNothing);
    },
  );
}
