import 'package:flutter/material.dart';
import 'app_colors.dart';

/// Дизайн-токены типографики Ledger для PAYK.
///
/// Основные правила:
/// - системный sans-serif для интерфейса без сетевой загрузки шрифтов
/// - системный monospace с [FontFeature.tabularFigures] для сумм и цифр
/// - Начертания строго w400 (Regular) и w500 (Medium)
class LedgerTextStyles extends ThemeExtension<LedgerTextStyles> {
  final TextStyle displayMono; // 30px - Крупные суммы (mono, tabular)
  final TextStyle h1Sans; // 24px - Заголовки экранов
  final TextStyle h1Mono; // 24px - Крупные балансы
  final TextStyle h2Sans; // 20px - Заголовки карточек
  final TextStyle bodySans; // 16px - Основной текст
  final TextStyle bodyMono; // 16px - Суммы в строках
  final TextStyle captionSans; // 14px - Вторичный текст
  final TextStyle smallSans; // 13px - Пилюли / лейблы
  final TextStyle smallMono; // 13px - Дельты / даты

  const LedgerTextStyles({
    required this.displayMono,
    required this.h1Sans,
    required this.h1Mono,
    required this.h2Sans,
    required this.bodySans,
    required this.bodyMono,
    required this.captionSans,
    required this.smallSans,
    required this.smallMono,
  });

  /// Генерация текстовых стилей на основе цветовой темы
  factory LedgerTextStyles.generate(LedgerColors colors) {
    const baseMonoFeatures = [FontFeature.tabularFigures()];

    return LedgerTextStyles(
      displayMono: TextStyle(
        fontFamily: 'monospace',
        fontSize: 30,
        fontWeight: FontWeight.w500,
        color: colors.textPrimary,
        fontFeatures: baseMonoFeatures,
        height: 1.2,
      ),
      h1Sans: TextStyle(
        fontSize: 24,
        fontWeight: FontWeight.w500,
        color: colors.textPrimary,
        height: 1.25,
      ),
      h1Mono: TextStyle(
        fontFamily: 'monospace',
        fontSize: 24,
        fontWeight: FontWeight.w500,
        color: colors.textPrimary,
        fontFeatures: baseMonoFeatures,
        height: 1.25,
      ),
      h2Sans: TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.w500,
        color: colors.textPrimary,
        height: 1.3,
      ),
      bodySans: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w400,
        color: colors.textPrimary,
        height: 1.4,
      ),
      bodyMono: TextStyle(
        fontFamily: 'monospace',
        fontSize: 16,
        fontWeight: FontWeight.w400,
        color: colors.textPrimary,
        fontFeatures: baseMonoFeatures,
        height: 1.4,
      ),
      captionSans: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        color: colors.textSecondary,
        height: 1.4,
      ),
      smallSans: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w500,
        color: colors.textTooltip,
        height: 1.3,
      ),
      smallMono: TextStyle(
        fontFamily: 'monospace',
        fontSize: 13,
        fontWeight: FontWeight.w400,
        color: colors.textTooltip,
        fontFeatures: baseMonoFeatures,
        height: 1.3,
      ),
    );
  }

  @override
  ThemeExtension<LedgerTextStyles> copyWith({
    TextStyle? displayMono,
    TextStyle? h1Sans,
    TextStyle? h1Mono,
    TextStyle? h2Sans,
    TextStyle? bodySans,
    TextStyle? bodyMono,
    TextStyle? captionSans,
    TextStyle? smallSans,
    TextStyle? smallMono,
  }) {
    return LedgerTextStyles(
      displayMono: displayMono ?? this.displayMono,
      h1Sans: h1Sans ?? this.h1Sans,
      h1Mono: h1Mono ?? this.h1Mono,
      h2Sans: h2Sans ?? this.h2Sans,
      bodySans: bodySans ?? this.bodySans,
      bodyMono: bodyMono ?? this.bodyMono,
      captionSans: captionSans ?? this.captionSans,
      smallSans: smallSans ?? this.smallSans,
      smallMono: smallMono ?? this.smallMono,
    );
  }

  @override
  ThemeExtension<LedgerTextStyles> lerp(
    covariant ThemeExtension<LedgerTextStyles>? other,
    double t,
  ) {
    if (other is! LedgerTextStyles) return this;
    return LedgerTextStyles(
      displayMono: TextStyle.lerp(displayMono, other.displayMono, t)!,
      h1Sans: TextStyle.lerp(h1Sans, other.h1Sans, t)!,
      h1Mono: TextStyle.lerp(h1Mono, other.h1Mono, t)!,
      h2Sans: TextStyle.lerp(h2Sans, other.h2Sans, t)!,
      bodySans: TextStyle.lerp(bodySans, other.bodySans, t)!,
      bodyMono: TextStyle.lerp(bodyMono, other.bodyMono, t)!,
      captionSans: TextStyle.lerp(captionSans, other.captionSans, t)!,
      smallSans: TextStyle.lerp(smallSans, other.smallSans, t)!,
      smallMono: TextStyle.lerp(smallMono, other.smallMono, t)!,
    );
  }

  static LedgerTextStyles? _cached;
  static LedgerTextStyles? _cachedBase;
  static double _cachedFactor = 0;

  /// Reuses the last scaled instance when the theme and factor did not change.
  static LedgerTextStyles cachedScaled(LedgerTextStyles base, double factor) {
    if (identical(_cachedBase, base) &&
        _cached != null &&
        (_cachedFactor - factor).abs() < 0.005) {
      return _cached!;
    }
    _cachedBase = base;
    _cachedFactor = factor;
    _cached = (factor - 1.0).abs() < 0.005 ? base : base.scaled(factor);
    return _cached!;
  }

  /// Width-based scale for 6.1" → Pro Max. Does not replace accessibility textScaler.
  LedgerTextStyles scaled(double factor) {
    if ((factor - 1.0).abs() < 0.005) return this;
    TextStyle scale(TextStyle style) {
      final size = style.fontSize;
      if (size == null) return style;
      return style.copyWith(fontSize: size * factor);
    }

    return copyWith(
          displayMono: scale(displayMono),
          h1Sans: scale(h1Sans),
          h1Mono: scale(h1Mono),
          h2Sans: scale(h2Sans),
          bodySans: scale(bodySans),
          bodyMono: scale(bodyMono),
          captionSans: scale(captionSans),
          smallSans: scale(smallSans),
          smallMono: scale(smallMono),
        )
        as LedgerTextStyles;
  }
}
