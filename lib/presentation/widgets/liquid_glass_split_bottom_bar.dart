import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:flutter/services.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/theme/theme_extensions.dart';

/// One tab of [LiquidGlassSplitBottomBar].
class LiquidGlassBarItem {
  const LiquidGlassBarItem({required this.icon, required this.label});

  final IconData icon;
  final String label;
}

/// Optional round button to the right of the capsule.
class LiquidGlassBarAction {
  const LiquidGlassBarAction({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;
}

/// Geometry and physics of the bar, kept pure for tests.
abstract final class LiquidGlassMetrics {
  static const capsuleHeight = 68.0;
  static const capsuleRadius = 34.0;
  static const restPillHeight = 54.0;
  static const liftedHeight = 78.0;
  static const actionSize = 64.0;
  static const gap = 12.0;
  static const blurSigma = 15.0;
  static const maxStretch = 28.0;

  /// Inner inset so the 54 px pill sits centred in the 68 px capsule.
  static const inset = (capsuleHeight - restPillHeight) / 2;

  static const spring = SpringDescription(mass: 1, stiffness: 380, damping: 26);

  static double tabWidth(double capsuleWidth, int count) =>
      (capsuleWidth - inset * 2) / math.max(count, 1);

  /// Lens position (in tabs) under a finger at [dx] inside the capsule.
  static double positionAt(double dx, double capsuleWidth, int count) =>
      (dx - inset) / tabWidth(capsuleWidth, count) - 0.5;

  /// Past the first/last tab the lens moves with growing resistance and
  /// never travels more than ~0.35 of a tab beyond the edge.
  static double rubberBand(double position, int count) {
    final last = (count - 1).toDouble();
    double resist(double over) => 0.35 * over / (over + 0.35);
    if (position < 0) return -resist(-position);
    if (position > last) return last + resist(position - last);
    return position;
  }

  /// Tab chosen when the finger is released.
  static int nearestIndex(double position, int count) =>
      position.round().clamp(0, math.max(count - 1, 0));

  /// Lens rectangle (bar coordinates) for position, lift and velocity.
  static Rect lensRect({
    required double position,
    required double lift,
    required double velocity,
    required double capsuleWidth,
    required int count,
  }) {
    final tab = tabWidth(capsuleWidth, count);
    final restWidth = math.max(tab - 8, 24.0);
    final liftedWidth = math.min(116.0, tab + 18);
    final baseWidth = ui.lerpDouble(restWidth, liftedWidth, lift)!;
    final baseHeight = ui.lerpDouble(restPillHeight, liftedHeight, lift)!;
    final stretch = (velocity.abs() * 0.04).clamp(0.0, maxStretch) * lift;
    final width = baseWidth + stretch;
    // Area-preserving squash: wider while flying, a little flatter.
    final height = baseHeight * baseWidth / width;
    final cx = inset + (position + 0.5) * tab;
    return Rect.fromCenter(
      center: Offset(cx, capsuleHeight / 2),
      width: width,
      height: height,
    );
  }
}

/// iOS 26-style floating «Liquid Glass» tab bar: frosted capsule, a pill that
/// flies on a spring and lifts into a magnifying lens while scrubbing.
///
/// Pure Flutter SDK: refraction is approximated (scaled accent copy, R/B
/// fringes, rim and bevel), not a fragment shader.
class LiquidGlassSplitBottomBar extends StatefulWidget {
  const LiquidGlassSplitBottomBar({
    super.key,
    required this.items,
    required this.selectedIndex,
    required this.onSelected,
    this.action,
  });

  final List<LiquidGlassBarItem> items;
  final int selectedIndex;
  final ValueChanged<int> onSelected;
  final LiquidGlassBarAction? action;

  @override
  State<LiquidGlassSplitBottomBar> createState() =>
      _LiquidGlassSplitBottomBarState();
}

class _LiquidGlassSplitBottomBarState extends State<LiquidGlassSplitBottomBar>
    with TickerProviderStateMixin {
  late final AnimationController _lens = AnimationController.unbounded(
    vsync: this,
    value: widget.selectedIndex.toDouble(),
  );
  late final AnimationController _lift = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 150),
    reverseDuration: const Duration(milliseconds: 220),
  );
  late final Listenable _frame = Listenable.merge([_lens, _lift]);

  var _dragging = false;
  var _dragVelocity = 0.0;
  double _capsuleWidth = 0;

  bool get _reduceMotion => MediaQuery.disableAnimationsOf(context);

  @override
  void didUpdateWidget(LiquidGlassSplitBottomBar old) {
    super.didUpdateWidget(old);
    final target = widget.selectedIndex.toDouble();
    if (!_dragging && _lens.value != target && !_lens.isAnimating) {
      _flyTo(widget.selectedIndex);
    }
  }

  @override
  void dispose() {
    _lens.dispose();
    _lift.dispose();
    super.dispose();
  }

  void _flyTo(int index, {double velocity = 0}) {
    final target = index.toDouble();
    if (_reduceMotion) {
      _lens.value = target;
      return;
    }
    _lens.animateWith(
      SpringSimulation(
        LiquidGlassMetrics.spring,
        _lens.value,
        target,
        velocity,
      ),
    );
  }

  void _select(int index) {
    if (index != widget.selectedIndex) {
      HapticFeedback.selectionClick();
    }
    widget.onSelected(index);
  }

  void _onTapUp(TapUpDetails details) {
    final count = widget.items.length;
    final index = LiquidGlassMetrics.nearestIndex(
      LiquidGlassMetrics.positionAt(
        details.localPosition.dx,
        _capsuleWidth,
        count,
      ),
      count,
    );
    _select(index);
    _flyTo(index);
    if (!_reduceMotion) {
      _lift.forward().whenCompleteOrCancel(() {
        if (!_dragging && mounted) _lift.reverse();
      });
    }
  }

  void _onDragStart(DragStartDetails details) {
    _dragging = true;
    _lens.stop();
    if (!_reduceMotion) _lift.forward();
    _moveLens(details.localPosition.dx);
  }

  void _onDragUpdate(DragUpdateDetails details) {
    _dragVelocity = (details.primaryDelta ?? details.delta.dx) * 60;
    _moveLens(details.localPosition.dx);
  }

  void _moveLens(double dx) {
    final count = widget.items.length;
    _lens.value = LiquidGlassMetrics.rubberBand(
      LiquidGlassMetrics.positionAt(dx, _capsuleWidth, count),
      count,
    );
  }

  void _onDragEnd(DragEndDetails details) {
    _dragging = false;
    _dragVelocity = 0;
    final count = widget.items.length;
    final index = LiquidGlassMetrics.nearestIndex(_lens.value, count);
    final tab = LiquidGlassMetrics.tabWidth(_capsuleWidth, count);
    _select(index);
    _flyTo(
      index,
      velocity: details.primaryVelocity == null || tab == 0
          ? 0
          : details.primaryVelocity! / tab,
    );
    _lift.reverse();
  }

  void _onDragCancel() {
    if (!_dragging) return;
    _dragging = false;
    _dragVelocity = 0;
    _flyTo(widget.selectedIndex);
    _lift.reverse();
  }

  Widget _tabsRow({required Color color, required bool semantics}) {
    final textStyles = context.textStyles;
    final items = widget.items;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: LiquidGlassMetrics.inset),
      child: Row(
        children: [
          for (var i = 0; i < items.length; i++)
            Expanded(
              child: _tab(
                items[i],
                color,
                textStyles,
                selected: i == widget.selectedIndex,
                semantics: semantics,
                onTap: () {
                  _select(i);
                  _flyTo(i);
                },
              ),
            ),
        ],
      ),
    );
  }

  Widget _tab(
    LiquidGlassBarItem item,
    Color color,
    LedgerTextStyles textStyles, {
    required bool selected,
    required bool semantics,
    required VoidCallback onTap,
  }) {
    final content = Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(item.icon, size: 22, color: color),
        const SizedBox(height: 2),
        Text(
          item.label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: textStyles.smallSans.copyWith(
            fontSize: context.fontSize(11),
            fontWeight: FontWeight.w600,
            color: color,
          ),
        ),
      ],
    );
    if (!semantics) return ExcludeSemantics(child: content);
    return Semantics(
      button: true,
      selected: selected,
      label: item.label,
      onTap: onTap,
      excludeSemantics: true,
      child: content,
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final action = widget.action;
    return SizedBox(
      height: LiquidGlassMetrics.capsuleHeight,
      child: Row(
        children: [
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                _capsuleWidth = constraints.maxWidth;
                return _capsule(colors);
              },
            ),
          ),
          if (action != null) ...[
            const SizedBox(width: LiquidGlassMetrics.gap),
            _actionButton(colors, action),
          ],
        ],
      ),
    );
  }

  Widget _glass(LedgerColors colors, BorderRadius radius, Widget child) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: radius,
        boxShadow: [
          BoxShadow(
            color: colors.glassShadow,
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: radius,
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(
            sigmaX: LiquidGlassMetrics.blurSigma,
            sigmaY: LiquidGlassMetrics.blurSigma,
          ),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: colors.glassFill,
              borderRadius: radius,
              border: Border.all(color: colors.glassBorder),
            ),
            child: child,
          ),
        ),
      ),
    );
  }

  Widget _capsule(LedgerColors colors) {
    final count = widget.items.length;
    // Built once per widget build, reused every animation frame.
    final restTabs = RepaintBoundary(
      child: _tabsRow(color: colors.textSecondary, semantics: true),
    );
    final accentTabs = RepaintBoundary(
      child: _tabsRow(color: colors.brand, semantics: false),
    );
    final redTabs = RepaintBoundary(
      child: _tabsRow(color: colors.lensDispersionRed, semantics: false),
    );
    final blueTabs = RepaintBoundary(
      child: _tabsRow(color: colors.lensDispersionBlue, semantics: false),
    );
    final radius = BorderRadius.circular(LiquidGlassMetrics.capsuleRadius);

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapUp: _onTapUp,
      onHorizontalDragStart: _onDragStart,
      onHorizontalDragUpdate: _onDragUpdate,
      onHorizontalDragEnd: _onDragEnd,
      onHorizontalDragCancel: _onDragCancel,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            child: RepaintBoundary(
              child: _glass(colors, radius, const SizedBox.expand()),
            ),
          ),
          Positioned.fill(
            child: RepaintBoundary(
              child: AnimatedBuilder(
                animation: _frame,
                builder: (context, _) {
                  final reduce = _reduceMotion;
                  final lift = reduce ? 0.0 : _lift.value;
                  final velocity = _dragging
                      ? _dragVelocity
                      : _lens.velocity *
                            LiquidGlassMetrics.tabWidth(_capsuleWidth, count);
                  final lens = LiquidGlassMetrics.lensRect(
                    position: _lens.value,
                    lift: lift,
                    velocity: velocity,
                    capsuleWidth: _capsuleWidth,
                    count: count,
                  );
                  final lensShape = RRect.fromRectAndRadius(
                    lens,
                    Radius.circular(lens.shortestSide / 2),
                  );
                  final scale = ui.lerpDouble(1, 1.28, lift)!;
                  final dispersion = 1.5 * lift;
                  Widget magnified(Widget child, double dx) => Transform(
                    transform: Matrix4.identity()
                      ..translateByDouble(
                        lens.center.dx + dx,
                        lens.center.dy,
                        0,
                        1,
                      )
                      ..scaleByDouble(scale, scale, 1, 1)
                      ..translateByDouble(
                        -lens.center.dx,
                        -lens.center.dy,
                        0,
                        1,
                      ),
                    child: child,
                  );
                  return Stack(
                    clipBehavior: Clip.none,
                    children: [
                      // Layer 1: tabs at 1.0×, lens area cut out.
                      Positioned.fill(
                        child: ClipPath(
                          clipper: _CutOutClipper(lensShape),
                          child: restTabs,
                        ),
                      ),
                      // Lens body under the magnified copy.
                      Positioned.fill(
                        child: CustomPaint(
                          painter: _LensPainter(
                            shape: lensShape,
                            lift: lift,
                            rest: colors.lensRestFill,
                            glass: colors.glassFill,
                            highlight: colors.lensHighlight,
                            shadow: colors.glassShadow,
                          ),
                        ),
                      ),
                      // Layer 2: accent tabs magnified inside the lens with
                      // R/B fringes as an approximate chromatic aberration.
                      Positioned.fill(
                        child: ClipRRect(
                          clipper: _RRectClipper(lensShape),
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              if (dispersion > 0) ...[
                                magnified(redTabs, -dispersion),
                                magnified(blueTabs, dispersion),
                              ],
                              magnified(accentTabs, 0),
                            ],
                          ),
                        ),
                      ),
                      if (lift > 0)
                        Positioned.fill(
                          child: IgnorePointer(
                            child: CustomPaint(
                              painter: _RimPainter(
                                shape: lensShape,
                                lift: lift,
                                highlight: colors.lensHighlight,
                              ),
                            ),
                          ),
                        ),
                    ],
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _actionButton(LedgerColors colors, LiquidGlassBarAction action) {
    final radius = BorderRadius.circular(LiquidGlassMetrics.actionSize / 2);
    return SizedBox.square(
      dimension: LiquidGlassMetrics.actionSize,
      child: _glass(
        colors,
        radius,
        Material(
          type: MaterialType.transparency,
          child: IconButton(
            tooltip: action.tooltip,
            onPressed: action.onPressed,
            icon: Icon(action.icon, color: colors.brand, size: 26),
          ),
        ),
      ),
    );
  }
}

class _CutOutClipper extends CustomClipper<Path> {
  _CutOutClipper(this.hole);

  final RRect hole;

  @override
  Path getClip(Size size) => Path.combine(
    PathOperation.difference,
    Path()..addRect(Offset.zero & size),
    Path()..addRRect(hole),
  );

  @override
  bool shouldReclip(_CutOutClipper old) => old.hole != hole;
}

class _RRectClipper extends CustomClipper<RRect> {
  _RRectClipper(this.shape);

  final RRect shape;

  @override
  RRect getClip(Size size) => shape;

  @override
  bool shouldReclip(_RRectClipper old) => old.shape != shape;
}

/// Fill of the pill / lens: brand tint at rest, brighter glass when lifted,
/// with an inner bevel shadow along the lower edge.
class _LensPainter extends CustomPainter {
  _LensPainter({
    required this.shape,
    required this.lift,
    required this.rest,
    required this.glass,
    required this.highlight,
    required this.shadow,
  });

  final RRect shape;
  final double lift;
  final Color rest;
  final Color glass;
  final Color highlight;
  final Color shadow;

  @override
  void paint(Canvas canvas, Size size) {
    final fill = Color.lerp(rest, glass, lift)!;
    canvas.drawRRect(shape, Paint()..color = fill);
    if (lift <= 0) return;
    // Inner bevel: dark crescent at the bottom, light at the top.
    canvas.save();
    canvas.clipRRect(shape);
    final bevel = Paint()
      ..shader = ui.Gradient.linear(
        shape.outerRect.topCenter,
        shape.outerRect.bottomCenter,
        [
          highlight.withValues(alpha: highlight.a * 0.35 * lift),
          highlight.withValues(alpha: 0),
          shadow.withValues(alpha: 0),
          shadow.withValues(alpha: shadow.a * lift),
        ],
        const [0, 0.35, 0.7, 1],
      );
    canvas.drawRRect(shape, bevel);
    canvas.restore();
  }

  @override
  bool shouldRepaint(_LensPainter old) =>
      old.shape != shape ||
      old.lift != lift ||
      old.rest != rest ||
      old.glass != glass;
}

/// Specular rim: a thin bright stroke, strongest on the upper-left arc.
class _RimPainter extends CustomPainter {
  _RimPainter({
    required this.shape,
    required this.lift,
    required this.highlight,
  });

  final RRect shape;
  final double lift;
  final Color highlight;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = shape.outerRect;
    final rim = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..shader = ui.Gradient.linear(
        rect.topLeft,
        rect.bottomRight,
        [
          highlight.withValues(alpha: highlight.a * lift),
          highlight.withValues(alpha: highlight.a * 0.15 * lift),
          highlight.withValues(alpha: highlight.a * 0.6 * lift),
        ],
        const [0, 0.55, 1],
      );
    canvas.drawRRect(shape.deflate(0.6), rim);
  }

  @override
  bool shouldRepaint(_RimPainter old) =>
      old.shape != shape || old.lift != lift || old.highlight != highlight;
}
