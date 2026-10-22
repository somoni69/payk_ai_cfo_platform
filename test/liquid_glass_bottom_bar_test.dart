import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:payk_ai_cfo_platform/core/theme/app_theme.dart';
import 'package:payk_ai_cfo_platform/presentation/widgets/liquid_glass_split_bottom_bar.dart';

const _items = [
  LiquidGlassBarItem(icon: Icons.dashboard, label: 'Панель'),
  LiquidGlassBarItem(icon: Icons.wallet, label: 'Касса'),
  LiquidGlassBarItem(icon: Icons.check_box, label: 'Задачи'),
  LiquidGlassBarItem(icon: Icons.inventory, label: 'Склад'),
  LiquidGlassBarItem(icon: Icons.menu, label: 'Ещё'),
];

class _Host extends StatefulWidget {
  const _Host({required this.log});
  final List<int> log;
  @override
  State<_Host> createState() => _HostState();
}

class _HostState extends State<_Host> {
  var index = 0;
  @override
  Widget build(BuildContext context) => MaterialApp(
    theme: LedgerTheme.light,
    home: Scaffold(
      body: Align(
        alignment: Alignment.bottomCenter,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: LiquidGlassSplitBottomBar(
            items: _items,
            selectedIndex: index,
            onSelected: (i) {
              widget.log.add(i);
              setState(() => index = i);
            },
          ),
        ),
      ),
    ),
  );
}

Future<Rect> _pump(WidgetTester tester, List<int> log) async {
  await tester.pumpWidget(_Host(log: log));
  return tester.getRect(find.byType(LiquidGlassSplitBottomBar));
}

double _tabX(Rect bar, int i) {
  final tab = LiquidGlassMetrics.tabWidth(bar.width, 5);
  return bar.left + LiquidGlassMetrics.inset + (i + 0.5) * tab;
}

void main() {
  testWidgets('shows exactly five tabs with button semantics', (tester) async {
    await _pump(tester, []);
    for (final item in _items) {
      expect(find.bySemanticsLabel(item.label), findsOneWidget);
    }
  });

  testWidgets('tap selects immediately', (tester) async {
    final log = <int>[];
    final bar = await _pump(tester, log);
    await tester.tapAt(Offset(_tabX(bar, 3), bar.center.dy));
    expect(log, [3]);
    await tester.pumpAndSettle();
  });

  testWidgets('drag does not change the index until release, then nearest', (
    tester,
  ) async {
    final log = <int>[];
    final bar = await _pump(tester, log);
    final gesture = await tester.startGesture(
      Offset(_tabX(bar, 0), bar.center.dy),
    );
    for (var i = 1; i <= 20; i++) {
      await gesture.moveBy(
        Offset((_tabX(bar, 2) - _tabX(bar, 0)) / 20 + 0.6, 0),
      );
      await tester.pump(const Duration(milliseconds: 16));
    }
    expect(log, isEmpty, reason: 'no selection while scrubbing');
    await gesture.up();
    await tester.pumpAndSettle();
    expect(log, [2]);
  });

  testWidgets('release beyond the last tab clamps to it', (tester) async {
    final log = <int>[];
    final bar = await _pump(tester, log);
    final gesture = await tester.startGesture(
      Offset(_tabX(bar, 3), bar.center.dy),
    );
    await gesture.moveBy(const Offset(40, 0));
    await gesture.moveBy(const Offset(400, 0));
    await tester.pump();
    await gesture.up();
    await tester.pumpAndSettle();
    expect(log.last, 4);
  });

  test('rubber band resists past the edges', () {
    expect(LiquidGlassMetrics.rubberBand(2, 5), 2);
    final over = LiquidGlassMetrics.rubberBand(10, 5);
    expect(over, greaterThan(4));
    expect(over, lessThan(4.35));
    final under = LiquidGlassMetrics.rubberBand(-3, 5);
    expect(under, lessThan(0));
    expect(under, greaterThan(-0.35));
    expect(LiquidGlassMetrics.nearestIndex(over, 5), 4);
    expect(LiquidGlassMetrics.nearestIndex(under, 5), 0);
    expect(LiquidGlassMetrics.nearestIndex(1.6, 5), 2);
  });

  test('lens stretches with velocity and keeps its area', () {
    final rest = LiquidGlassMetrics.lensRect(
      position: 1,
      lift: 1,
      velocity: 0,
      capsuleWidth: 340,
      count: 5,
    );
    final fast = LiquidGlassMetrics.lensRect(
      position: 1,
      lift: 1,
      velocity: 2000,
      capsuleWidth: 340,
      count: 5,
    );
    expect(rest.height, LiquidGlassMetrics.liftedHeight);
    expect(fast.width - rest.width, LiquidGlassMetrics.maxStretch);
    expect(fast.width * fast.height, closeTo(rest.width * rest.height, 0.01));
    final pill = LiquidGlassMetrics.lensRect(
      position: 1,
      lift: 0,
      velocity: 2000,
      capsuleWidth: 340,
      count: 5,
    );
    expect(pill.height, LiquidGlassMetrics.restPillHeight);
  });
}
