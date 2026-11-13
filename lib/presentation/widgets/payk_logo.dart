import 'package:flutter/material.dart';
import '../../core/theme/theme_extensions.dart';

/// Переиспользуемый виджет брендового логотипа PAYK из Брендбука.
class PaykLogo extends StatelessWidget {
  final double height;
  final Color? color;
  final int? cacheHeight;
  final int? cacheWidth;
  final String lightAssetPath;
  final String darkAssetPath;

  const PaykLogo({
    super.key,
    this.height = 26.0,
    this.color,
    this.cacheHeight,
    this.cacheWidth,
    this.lightAssetPath = 'assets/images/payk_logo_transparent.png',
    this.darkAssetPath = 'assets/images/payk_logo_transparent.png',
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final textStyles = context.textStyles;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final dpr = MediaQuery.maybeDevicePixelRatioOf(context) ?? 2.0;
    final calculatedCacheHeight =
        cacheHeight ?? (height * dpr).round().clamp(1, 10000);
    final assetPath = isDark ? darkAssetPath : lightAssetPath;
    final effectiveColor = color ?? (isDark ? colors.textPrimary : null);

    return Image.asset(
      assetPath,
      height: height,
      cacheHeight: calculatedCacheHeight,
      cacheWidth: cacheWidth,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.medium,
      color: effectiveColor,
      semanticLabel: 'PAYK',
      errorBuilder: (context, error, stackTrace) {
        final fallbackColor = effectiveColor ?? colors.brand;
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: fallbackColor,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                'P',
                style: textStyles.captionSans.copyWith(
                  color:
                      effectiveColor != null ? colors.surface : colors.onBrand,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              'PAYK',
              style: textStyles.bodySans.copyWith(
                fontWeight: FontWeight.w500,
                fontSize: height * 0.65,
                color: fallbackColor,
                letterSpacing: 1.0,
              ),
            ),
          ],
        );
      },
    );
  }
}
