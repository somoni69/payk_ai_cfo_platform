import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';
import 'app_text_styles.dart';

/// Тема оформления Ledger для Flutter.
/// Настраивает стандартные компоненты Material 3 под требования дизайна PAYK:
/// - Нет мягких теней (все разделено тонкими границами [LedgerColors.border])
/// - Радиус карточек: 10px
/// - Радиус полей ввода и кнопок: 8px
/// - Цветовые семантические акценты (зеленый/красный/янтарь/индиго)
class LedgerTheme {
  static ThemeData get light {
    const colors = LedgerColors.light;
    final textStyles = LedgerTextStyles.generate(colors);

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      fontFamily: GoogleFonts.ibmPlexSans().fontFamily,
      scaffoldBackgroundColor: colors.background,
      
      // Настройка AppBar
      appBarTheme: AppBarTheme(
        backgroundColor: colors.surface,
        foregroundColor: colors.textPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        iconTheme: IconThemeData(color: colors.brand),
        actionsIconTheme: IconThemeData(color: colors.brand),
      ),
      
      // Стандартная цветовая схема
      colorScheme: ColorScheme.light(
        surface: colors.surface,
        primary: colors.brand,
        onPrimary: colors.surface,
        secondary: colors.brand,
        outline: colors.border,
        error: colors.accentRed,
      ),

      // Карточки: без тени, с границей 1px, скруглением 16px
      cardTheme: CardThemeData(
        color: colors.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: colors.border,
            width: 1,
          ),
        ),
        margin: EdgeInsets.zero,
      ),

      // Диалоги: скругление 16px
      dialogTheme: DialogThemeData(
        backgroundColor: colors.surface,
        surfaceTintColor: colors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),

      // Поля ввода: скругление 8px, серые границы, плоский вид
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: colors.surface,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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

      // Основные кнопки: скругление 8px, без теней
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: colors.brand,
          foregroundColor: colors.surface,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          textStyle: textStyles.bodySans.copyWith(fontWeight: FontWeight.w500),
        ),
      ),

      // Настройка иконок-кнопок
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          foregroundColor: colors.brand,
        ),
      ),

      // Вторичные кнопки с границами: скругление 8px
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: colors.brand,
          elevation: 0,
          side: BorderSide(color: colors.brand, width: 1.5),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          textStyle: textStyles.bodySans.copyWith(fontWeight: FontWeight.w500),
        ),
      ),

      // Текстовые кнопки
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: colors.brand,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          textStyle: textStyles.bodySans.copyWith(fontWeight: FontWeight.w500),
        ),
      ),

      // Нижняя панель навигации (5 табов)
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: colors.surface,
        selectedItemColor: colors.brand,
        unselectedItemColor: colors.textSecondary,
        selectedLabelStyle: textStyles.smallSans.copyWith(fontWeight: FontWeight.w500),
        unselectedLabelStyle: textStyles.smallSans.copyWith(fontWeight: FontWeight.w400),
        type: BottomNavigationBarType.fixed,
        elevation: 0,
      ),

      // Разделители
      dividerTheme: DividerThemeData(
        color: colors.border,
        thickness: 1,
        space: 1,
      ),

      // Подключение кастомных расширений в контекст темы
      extensions: [
        colors,
        textStyles,
      ],
    );
  }
}
