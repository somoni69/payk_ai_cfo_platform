import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:payk_ai_cfo_platform/core/theme/app_theme.dart';
import 'package:payk_ai_cfo_platform/presentation/widgets/ledger_card.dart';
import 'package:payk_ai_cfo_platform/presentation/widgets/ledger_segmented_control.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    final comparator = goldenFileComparator;
    if (comparator is LocalFileComparator) {
      goldenFileComparator = _TolerantGoldenFileComparator(
        Uri.parse('${comparator.basedir}dummy.dart'),
        precisionTolerance: 0.08,
      );
      addTearDown(() => goldenFileComparator = comparator);
    }
  });

  Widget wrap(Widget child) {
    return MaterialApp(
      theme: LedgerTheme.light,
      home: Scaffold(
        body: Center(child: SizedBox(width: 360, child: child)),
      ),
    );
  }

  Future<void> pumpGolden(WidgetTester tester, Widget child) async {
    tester.view.physicalSize = const Size(800, 600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(wrap(child));
  }

  testWidgets('LedgerCard matches golden', (tester) async {
    await pumpGolden(
      tester,
      const LedgerCard(child: Text('Ledger card content')),
    );
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/ledger_card.png'),
    );
  });

  testWidgets('LedgerSegmentedControl renders properly and selects value', (
    tester,
  ) async {
    int selected = 0;
    final segments = [
      const LedgerSegmentItem(value: 0, label: 'Today'),
      const LedgerSegmentItem(value: 1, label: 'Month'),
      const LedgerSegmentItem(value: 2, label: 'All'),
    ];

    await tester.pumpWidget(
      wrap(
        StatefulBuilder(
          builder: (context, setState) {
            return LedgerSegmentedControl<int>(
              segments: segments,
              selectedValue: selected,
              onValueChanged: (v) => setState(() => selected = v),
            );
          },
        ),
      ),
    );

    expect(find.text('Today'), findsOneWidget);
    expect(find.text('Month'), findsOneWidget);
    expect(find.text('All'), findsOneWidget);

    await tester.tap(find.text('Month'));
    await tester.pumpAndSettle();
    expect(selected, 1);
  });
}

class _TolerantGoldenFileComparator extends LocalFileComparator {
  _TolerantGoldenFileComparator(
    super.testFile, {
    required double precisionTolerance,
  }) : assert(
         0 <= precisionTolerance && precisionTolerance <= 1,
         'precisionTolerance must be between 0 and 1',
       ),
       _precisionTolerance = precisionTolerance;

  final double _precisionTolerance;

  @override
  Future<bool> compare(Uint8List imageBytes, Uri golden) async {
    final result = await GoldenFileComparator.compareLists(
      imageBytes,
      await getGoldenBytes(golden),
    );

    final passed = result.passed || result.diffPercent <= _precisionTolerance;
    if (passed) {
      result.dispose();
      return true;
    }

    final error = await generateFailureOutput(result, golden, basedir);
    result.dispose();
    throw FlutterError(error);
  }
}
