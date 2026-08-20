import 'package:flutter/material.dart';
import 'app_colors.dart';
import 'app_text_styles.dart';

/// Height of the floating liquid pill plus gap, excluding the system inset.
const kLiquidNavClearance = 80.0;

/// Расширение [BuildContext] для простого и лаконичного доступа
/// к токенам дизайн-системы Ledger в виджетах.
extension LedgerThemeExtensions on BuildContext {
  /// Получить общую тему
  ThemeData get theme => Theme.of(this);

  /// 1.0 on 6.1" (~390 dp), up to ~1.08 on Pro Max (~430 dp).
  double get typeScale {
    final width = MediaQuery.maybeSizeOf(this)?.width ?? 390;
    if (width >= 600) return 1.0;
    if (width >= 428) return 1.08;
    if (width >= 400) return 1.04;
    return 1.0;
  }

  /// Design px scaled for the current phone size.
  double fontSize(double base) => base * typeScale;

  /// Доступ к цветам Ledger: `context.colors.brand`
  LedgerColors get colors {
    final colorsExt = Theme.of(this).extension<LedgerColors>();
    assert(
      colorsExt != null,
      'LedgerColors extension not found in current Theme.',
    );
    return colorsExt ?? LedgerColors.light;
  }

  /// Доступ к текстовым стилям Ledger: `context.textStyles.bodySans`
  LedgerTextStyles get textStyles {
    final textStylesExt = Theme.of(this).extension<LedgerTextStyles>();
    assert(
      textStylesExt != null,
      'LedgerTextStyles extension not found in current Theme.',
    );
    final base = textStylesExt ?? LedgerTextStyles.generate(LedgerColors.light);
    return LedgerTextStyles.cachedScaled(base, typeScale);
  }
}
