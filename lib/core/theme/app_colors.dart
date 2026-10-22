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

  /// Text and icons on a filled brand/accent fill (selected chips, avatars).
  final Color onBrand;

  /// Full-bleed camera screens (barcode scanner): backdrop behind the preview.
  final Color cameraBackdrop;

  /// Floating glass bar: translucent fill over the blurred content.
  final Color glassFill;

  /// 1px rim of the glass bar.
  final Color glassBorder;

  /// Soft drop shadow under the glass bar.
  final Color glassShadow;

  /// Selected-tab pill at rest (no distortion).
  final Color lensRestFill;

  /// Specular rim highlight of the lifted lens.
  final Color lensHighlight;

  /// Red fringe of the lens chromatic aberration.
  final Color lensDispersionRed;

  /// Blue fringe of the lens chromatic aberration.
  final Color lensDispersionBlue;

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
    required this.onBrand,
    required this.cameraBackdrop,
    required this.glassFill,
    required this.glassBorder,
    required this.glassShadow,
    required this.lensRestFill,
    required this.lensHighlight,
    required this.lensDispersionRed,
    required this.lensDispersionBlue,
  });

  /// Светлая тема Ledger (основной режим)
  static const light = LedgerColors(
    background: Color(0xFFF7F7F4),
    surface: Color(0xFFFFFFFF),
    surfaceNested: Color(0xFFF1F1EC),
    textPrimary: Color(0xFF1A1D29),
    textSecondary: Color(0xFF5A6072),
    textTooltip: Color(0xFF606778),
    border: Color(0xFFE6E7EA),
    brand: Color(0xFF362CD1),
    accentGreen: Color(0xFF17795E),
    accentRed: Color(0xFFC0392B),
    accentAmber: Color(0xFFB7791F),
    onBrand: Color(0xFFFFFFFF),
    cameraBackdrop: Color(0xFF000000),
    glassFill: Color(0xB8FFFFFF),
    glassBorder: Color(0x1F1A1D29),
    glassShadow: Color(0x1F1A1D29),
    lensRestFill: Color(0x24362CD1),
    lensHighlight: Color(0xD9FFFFFF),
    lensDispersionRed: Color(0x59E5484D),
    lensDispersionBlue: Color(0x592F80ED),
  );

  /// Тёмная тема Ledger (системный режим).
  static const dark = LedgerColors(
    background: Color(0xFF0F1115),
    surface: Color(0xFF161A22),
    surfaceNested: Color(0xFF1E2430),
    textPrimary: Color(0xFFF2F4F8),
    textSecondary: Color(0xFFA7AFBF),
    textTooltip: Color(0xFFC5CBD6),
    border: Color(0xFF2A3140),
    brand: Color(0xFF8B84FF),
    accentGreen: Color(0xFF3DDC97),
    accentRed: Color(0xFFFF6B6B),
    accentAmber: Color(0xFFF2B84B),
    onBrand: Color(0xFFFFFFFF),
    cameraBackdrop: Color(0xFF000000),
    glassFill: Color(0xB8161A22),
    glassBorder: Color(0x33FFFFFF),
    glassShadow: Color(0x66000000),
    lensRestFill: Color(0x338B84FF),
    lensHighlight: Color(0x66FFFFFF),
    lensDispersionRed: Color(0x59FF6B6B),
    lensDispersionBlue: Color(0x596FA8FF),
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
    Color? onBrand,
    Color? cameraBackdrop,
    Color? glassFill,
    Color? glassBorder,
    Color? glassShadow,
    Color? lensRestFill,
    Color? lensHighlight,
    Color? lensDispersionRed,
    Color? lensDispersionBlue,
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
      onBrand: onBrand ?? this.onBrand,
      cameraBackdrop: cameraBackdrop ?? this.cameraBackdrop,
      glassFill: glassFill ?? this.glassFill,
      glassBorder: glassBorder ?? this.glassBorder,
      glassShadow: glassShadow ?? this.glassShadow,
      lensRestFill: lensRestFill ?? this.lensRestFill,
      lensHighlight: lensHighlight ?? this.lensHighlight,
      lensDispersionRed: lensDispersionRed ?? this.lensDispersionRed,
      lensDispersionBlue: lensDispersionBlue ?? this.lensDispersionBlue,
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
      onBrand: Color.lerp(onBrand, other.onBrand, t)!,
      cameraBackdrop: Color.lerp(cameraBackdrop, other.cameraBackdrop, t)!,
      glassFill: Color.lerp(glassFill, other.glassFill, t)!,
      glassBorder: Color.lerp(glassBorder, other.glassBorder, t)!,
      glassShadow: Color.lerp(glassShadow, other.glassShadow, t)!,
      lensRestFill: Color.lerp(lensRestFill, other.lensRestFill, t)!,
      lensHighlight: Color.lerp(lensHighlight, other.lensHighlight, t)!,
      lensDispersionRed: Color.lerp(
        lensDispersionRed,
        other.lensDispersionRed,
        t,
      )!,
      lensDispersionBlue: Color.lerp(
        lensDispersionBlue,
        other.lensDispersionBlue,
        t,
      )!,
    );
  }
}
