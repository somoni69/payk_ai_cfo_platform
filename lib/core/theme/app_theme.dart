import 'package:flutter/material.dart';
import 'app_colors.dart';
import 'app_text_styles.dart';
import 'ledger_buttons.dart';

/// Тема оформления Ledger для Flutter (design_language.md).
/// - Нет мягких теней (блоки — 1px [LedgerColors.border])
/// - Радиус карточек: 16px; поля: 8px; кнопки экрана: 12px / 44px
/// - Кнопки в модалках: 12px / 48px (см. [LedgerButtons.modalOverlay])
/// - Начертания только w400 / w500
class LedgerTheme {
  static final ThemeData light = _buildLight();

  static ThemeData _buildLight() {
    const colors = LedgerColors.light;
    final textStyles = LedgerTextStyles.generate(colors);

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: colors.background,
      materialTapTargetSize: MaterialTapTargetSize.padded,

      // Настройка AppBar
      appBarTheme: AppBarTheme(
        backgroundColor: colors.surface,
        foregroundColor: colors.textPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        iconTheme: IconThemeData(color: colors.brand),
        actionsIconTheme: IconThemeData(color: colors.brand),
        titleTextStyle: textStyles.h1Sans.copyWith(color: colors.textPrimary),
      ),

      // Стандартная цветовая схема
      colorScheme: ColorScheme.light(
        surface: colors.surface,
        primary: colors.brand,
        onPrimary: colors.surface,
        secondary: colors.brand,
        onSurface: colors.textPrimary,
        onSurfaceVariant: colors.textSecondary,
        outline: colors.border,
        error: colors.accentRed,
      ),

      // Карточки: без тени, с границей 1px, скруглением 16px
      cardTheme: CardThemeData(
        color: colors.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: colors.border, width: 1),
        ),
        margin: EdgeInsets.zero,
      ),

      // Диалоги: скругление 16px
      dialogTheme: DialogThemeData(
        backgroundColor: colors.surface,
        surfaceTintColor: colors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),

      // Поля ввода: скругление 8px, серые границы, плоский вид
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: colors.surface,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 12,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: colors.border, width: 1),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: colors.border, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: colors.brand, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: colors.accentRed, width: 1),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: colors.accentRed, width: 1.5),
        ),
        labelStyle: textStyles.bodySans.copyWith(color: colors.textSecondary),
        hintStyle: textStyles.bodySans.copyWith(color: colors.textTooltip),
      ),

      // Кнопки на экранах: 44px, радиус 12. Модалки перекрывают через
      // [LedgerButtons.modalOverlay] (48px).
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: LedgerButtons.screenElevated(colors, textStyles),
      ),

      // Настройка иконок-кнопок
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          foregroundColor: colors.brand,
          minimumSize: const Size.square(48),
          tapTargetSize: MaterialTapTargetSize.padded,
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: LedgerButtons.screenOutlined(colors, textStyles),
      ),

      textButtonTheme: TextButtonThemeData(
        style: LedgerButtons.screenText(colors, textStyles),
      ),

      floatingActionButtonTheme: LedgerButtons.screenFabTheme(
        colors,
        textStyles,
      ),

      // Нижняя панель навигации (5 табов)
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: Colors.transparent,
        elevation: 0,
        selectedItemColor: colors.brand,
        unselectedItemColor: colors.textSecondary,
        selectedLabelStyle: textStyles.smallSans.copyWith(
          fontWeight: FontWeight.w500,
        ),
        unselectedLabelStyle: textStyles.smallSans.copyWith(
          fontWeight: FontWeight.w400,
        ),
        type: BottomNavigationBarType.fixed,
      ),

      // Разделители
      dividerTheme: DividerThemeData(
        color: colors.border,
        thickness: 1,
        space: 1,
      ),

      // Настройка чипов (фильтры)
      chipTheme: ChipThemeData(
        backgroundColor: colors.surface,
        selectedColor: colors.brand,
        disabledColor: colors.border,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        side: BorderSide(color: colors.border),
        labelStyle: textStyles.captionSans.copyWith(
          color: colors.textPrimary,
          fontWeight: FontWeight.w400,
        ),
        secondaryLabelStyle: textStyles.captionSans.copyWith(
          color: Colors.white,
          fontWeight: FontWeight.w500,
        ),
        checkmarkColor: Colors.white,
        showCheckmark: true,
      ),

      // Настройка списков и раскрывающихся панелей (без серых Material 3 оверлеев)
      listTileTheme: const ListTileThemeData(
        tileColor: Colors.transparent,
        selectedTileColor: Colors.transparent,
        contentPadding: EdgeInsets.zero,
        dense: true,
      ),

      expansionTileTheme: const ExpansionTileThemeData(
        backgroundColor: Colors.transparent,
        collapsedBackgroundColor: Colors.transparent,
        tilePadding: EdgeInsets.zero,
        shape: Border(),
        collapsedShape: Border(),
      ),

      // Подключение кастомных расширений в контекст темы
      extensions: [colors, textStyles],
    );
  }
}
