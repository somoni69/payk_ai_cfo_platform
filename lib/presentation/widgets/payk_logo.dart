import 'package:flutter/material.dart';
import '../../core/theme/theme_extensions.dart';

/// Переиспользуемый виджет брендового логотипа PAYK из Брендбука.
class PaykLogo extends StatelessWidget {
  final double height;
  final Color? color;

  const PaykLogo({super.key, this.height = 26.0, this.color});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final textStyles = context.textStyles;

    return Image.asset(
      'assets/images/payk_logo_transparent.png',
      height: height,
      fit: BoxFit.contain,
      color: color,
      errorBuilder: (context, error, stackTrace) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: colors.brand,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                'P',
                style: textStyles.captionSans.copyWith(
                  color: colors.surface,
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
                color: colors.brand,
                letterSpacing: 1.0,
              ),
            ),
          ],
        );
      },
    );
  }
}
