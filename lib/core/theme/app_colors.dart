import 'package:flutter/material.dart';

/// Eдиная цветовая палитра Ledger для PAYK CFO Platform.
/// Предоставляется в виде [ThemeExtension] для строгого соблюдения
/// дизайн-токенов без хардкода.
class LedgerColors extends ThemeExtension<LedgerColors> {
  final Color background;
  final Color surface;
  final Color surfaceNested;
  final Color textPrimary;
  final Color textSecondary;
  final Color textTooltip;
  final Color border;
  final Color brand;
  final Color accentGreen;
  final Color accentRed;
  final Color accentAmber;

  const LedgerColors({
    required this.background,
    required this.surface,
    required this.surfaceNested,
    required this.textPrimary,
    required this.textSecondary,
    required this.textTooltip,
    required this.border,
    required this.brand,
    required this.accentGreen,
    required this.accentRed,
    required this.accentAmber,
  });

  /// Светлая тема Ledger (основной режим)
  static const light = LedgerColors(
    background: Color(0xFFF7F7F4),
    surface: Color(0xFFFFFFFF),
    surfaceNested: Color(0xFFF1F1EC),
    textPrimary: Color(0xFF1A1D29),
    textSecondary: Color(0xFF5A6072),
    textTooltip: Color(0xFF9AA0AE),
    border: Color(0xFFE6E7EA),
    brand: Color(0xFF343B8F),
    accentGreen: Color(0xFF17795E),
    accentRed: Color(0xFFC0392B),
    accentAmber: Color(0xFFB7791F),
  );

  @override
  ThemeExtension<LedgerColors> copyWith({
    Color? background,
    Color? surface,
    Color? surfaceNested,
    Color? textPrimary,
    Color? textSecondary,
    Color? textTooltip,
    Color? border,
    Color? brand,
    Color? accentGreen,
    Color? accentRed,
    Color? accentAmber,
  }) {
    return LedgerColors(
      background: background ?? this.background,
      surface: surface ?? this.surface,
      surfaceNested: surfaceNested ?? this.surfaceNested,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      textTooltip: textTooltip ?? this.textTooltip,
      border: border ?? this.border,
      brand: brand ?? this.brand,
      accentGreen: accentGreen ?? this.accentGreen,
      accentRed: accentRed ?? this.accentRed,
      accentAmber: accentAmber ?? this.accentAmber,
    );
  }

  @override
  ThemeExtension<LedgerColors> lerp(
    covariant ThemeExtension<LedgerColors>? other,
    double t,
  ) {
    if (other is! LedgerColors) return this;
    return LedgerColors(
      background: Color.lerp(background, other.background, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      surfaceNested: Color.lerp(surfaceNested, other.surfaceNested, t)!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      textTooltip: Color.lerp(textTooltip, other.textTooltip, t)!,
      border: Color.lerp(border, other.border, t)!,
      brand: Color.lerp(brand, other.brand, t)!,
      accentGreen: Color.lerp(accentGreen, other.accentGreen, t)!,
      accentRed: Color.lerp(accentRed, other.accentRed, t)!,
      accentAmber: Color.lerp(accentAmber, other.accentAmber, t)!,
    );
  }
}
