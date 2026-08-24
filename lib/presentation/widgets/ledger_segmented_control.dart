import 'package:flutter/material.dart';
import '../../core/theme/theme_extensions.dart';

class LedgerSegmentItem<T> {
  const LedgerSegmentItem({
    required this.value,
    required this.label,
    this.icon,
  });

  final T value;
  final String label;
  final IconData? icon;
}

/// Анимированный сегментированный переключатель с плавной скользящей капсулой (физика и анимация как у нижнего navigation bar).
class LedgerSegmentedControl<T> extends StatelessWidget {
  const LedgerSegmentedControl({
    super.key,
    required this.segments,
    required this.selectedValue,
    required this.onValueChanged,
    this.height = 38,
    this.backgroundColor,
    this.indicatorColor,
  });

  final List<LedgerSegmentItem<T>> segments;
  final T selectedValue;
  final ValueChanged<T> onValueChanged;
  final double height;
  final Color? backgroundColor;
  final Color? indicatorColor;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final count = segments.length;
    final selectedIndex = segments.indexWhere((s) => s.value == selectedValue);
    final validIndex = selectedIndex >= 0 ? selectedIndex : 0;

    final bubbleAlign = count <= 1
        ? Alignment.center
        : Alignment(-1.0 + (2.0 * validIndex / (count - 1)), 0);

    return Container(
      height: height,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: backgroundColor ?? colors.surfaceNested,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: colors.border),
      ),
      child: RepaintBoundary(
        child: Stack(
          children: [
            // Скользящая анимированная плашка с плавным ускорением/замедлением easeOutCubic
            AnimatedAlign(
              duration: const Duration(milliseconds: 380),
              curve: Curves.easeOutCubic,
              alignment: bubbleAlign,
              child: FractionallySizedBox(
                widthFactor: count > 0 ? 1 / count : 1,
                heightFactor: 1,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: indicatorColor ?? colors.surface,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: colors.border),
                    boxShadow: [
                      BoxShadow(
                        color: colors.textPrimary.withValues(alpha: 0.04),
                        blurRadius: 4,
                        offset: const Offset(0, 1),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Элементы переключателя с динамической шкалой и типографикой
            Row(
              children: [
                for (var i = 0; i < count; i++)
                  Expanded(
                    child: _SegmentItemView<T>(
                      item: segments[i],
                      selected: i == validIndex,
                      onTap: () {
                        if (segments[i].value != selectedValue) {
                          onValueChanged(segments[i].value);
                        }
                      },
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SegmentItemView<T> extends StatelessWidget {
  const _SegmentItemView({
    required this.item,
    required this.selected,
    required this.onTap,
  });

  final LedgerSegmentItem<T> item;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final textStyles = context.textStyles;
    final foreground = selected ? colors.brand : colors.textSecondary;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      splashColor: colors.brand.withValues(alpha: 0.08),
      highlightColor: Colors.transparent,
      child: Center(
        child: AnimatedScale(
          scale: selected ? 1.03 : 1.0,
          duration: const Duration(milliseconds: 240),
          curve: Curves.easeOutCubic,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (item.icon != null) ...[
                Icon(item.icon, size: 16, color: foreground),
                const SizedBox(width: 6),
              ],
              AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 240),
                curve: Curves.easeOutCubic,
                style: textStyles.captionSans.copyWith(
                  fontSize: 13,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                  color: foreground,
                ),
                child: Text(
                  item.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
