import 'package:flutter/material.dart';
import 'app_colors.dart';
import 'app_text_styles.dart';

/// Расширение [BuildContext] для простого и лаконичного доступа
/// к токенам дизайн-системы Ledger в виджетах.
extension LedgerThemeExtensions on BuildContext {
  /// Получить общую тему
  ThemeData get theme => Theme.of(this);

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
    return textStylesExt ?? LedgerTextStyles.generate(LedgerColors.light);
  }
}
