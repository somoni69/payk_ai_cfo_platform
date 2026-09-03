import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:payk_ai_cfo_platform/core/theme/ledger_layout.dart';

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
}
