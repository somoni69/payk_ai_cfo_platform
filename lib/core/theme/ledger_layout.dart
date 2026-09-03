import 'package:flutter/material.dart';

import 'theme_extensions.dart';

/// Max height of the AI assistant and every content sheet (88% of the screen).
/// Short forms wrap to their content; tall ones cap here and scroll.
const kLedgerModalHeightFactor = 0.88;

/// Top corners of the AI assistant and every content sheet.
const kLedgerModalTopRadius = 16.0;

/// Max height of a content modal: 88% of the screen, never taller than the
/// remaining space above the keyboard.
double ledgerModalHeightOf(BuildContext context) {
  final media = MediaQuery.of(context);
  final keyboard = media.viewInsets.bottom;
  final target = media.size.height * kLedgerModalHeightFactor;
  final maxH = media.size.height - keyboard;
  if (maxH > 0 && target > maxH) return maxH;
  return target;
}

/// Layout tokens for phones from 16:9 up to 20:9 / 21:9 (Tecno Pova 6 etc.).
class LedgerLayout {
  const LedgerLayout({
    required this.size,
    this.padding = EdgeInsets.zero,
    this.textScale = 1,
  });

  factory LedgerLayout.of(BuildContext context) {
    final mq = MediaQuery.of(context);
    return LedgerLayout(
      size: mq.size,
      padding: mq.padding,
      textScale: mq.textScaler.scale(1),
    );
  }

  final Size size;
  final EdgeInsets padding;
  final double textScale;

  /// Height / width. 16:9 ≈ 1.78, 20:9 ≈ 2.22, 21:9 ≈ 2.33.
  double get aspect => size.width <= 0 ? 1.78 : size.height / size.width;

  bool get isNarrow => size.width < 380;

  /// 18:9 and taller.
  bool get isTall => aspect >= 2.0;

  /// 20:9 / 21:9 class (Pova 6 is ~20.3:9).
  bool get isUltraTall => aspect >= 2.15;

  double get metricTileMinHeight {
    if (isNarrow) return 108;
    if (isUltraTall) return 118;
    return 124;
  }

  double get hubTileMinHeight => isNarrow ? 96 : 104;

  /// Width of one kanban / funnel column so the next stage peeks.
  double funnelColumnWidth(double viewportWidth) {
    final peek = isUltraTall ? 56.0 : 48.0;
    const horizontalPad = 32.0;
    return (viewportWidth - horizontalPad - peek).clamp(240.0, 340.0);
  }

  double get funnelBottomPadding => 16 + kLiquidNavClearance;

  /// Smaller ratio → taller cell. Tightens grids on tall/narrow phones.
  double gridChildAspect(double base) {
    var factor = 1.0;
    if (isUltraTall) factor *= 0.90;
    if (isNarrow) factor *= 0.92;
    return base * factor;
  }
}

extension LedgerLayoutX on BuildContext {
  LedgerLayout get layout => LedgerLayout.of(this);
}

/// Two hub / metric tiles of equal height — looks even on 20:9 / 21:9.
class LedgerPairRow extends StatelessWidget {
  const LedgerPairRow({
    super.key,
    required this.left,
    required this.right,
    this.gap = 10,
  });

  final Widget left;
  final Widget right;
  final double gap;

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(child: left),
          SizedBox(width: gap),
          Expanded(child: right),
        ],
      ),
    );
  }
}
