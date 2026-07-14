import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';

/// Дизайн-токены типографики Ledger для PAYK.
///
/// Основные правила:
/// - IBM Plex Sans для интерфейса
/// - IBM Plex Mono с [FontFeature.tabularFigures] для денежных сумм и цифр
/// - Начертания строго w400 (Regular) и w500 (Medium)
class LedgerTextStyles extends ThemeExtension<LedgerTextStyles> {
  final TextStyle displayMono; // 28px - Крупные суммы
  final TextStyle h1Sans;      // 22px - Заголовки экранов
  final TextStyle h1Mono;      // 22px - Крупные суммы / счета
  final TextStyle h2Sans;      // 18px - Заголовки карточек
  final TextStyle bodySans;    // 15px - Основной текст
  final TextStyle bodyMono;    // 15px - Денежные значения в строках
  final TextStyle captionSans; // 13px - Вторичный текст / подписи
  final TextStyle smallSans;   // 12px - Подсказки / лейблы
  final TextStyle smallMono;   // 12px - Мелкие цифры / дельты

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
      displayMono: GoogleFonts.ibmPlexMono(
        fontSize: 28,
        fontWeight: FontWeight.w500,
        color: colors.textPrimary,
        fontFeatures: baseMonoFeatures,
        height: 1.2,
      ),
      h1Sans: GoogleFonts.ibmPlexSans(
        fontSize: 22,
        fontWeight: FontWeight.w500,
        color: colors.textPrimary,
        height: 1.25,
      ),
      h1Mono: GoogleFonts.ibmPlexMono(
        fontSize: 22,
        fontWeight: FontWeight.w500,
        color: colors.textPrimary,
        fontFeatures: baseMonoFeatures,
        height: 1.25,
      ),
      h2Sans: GoogleFonts.ibmPlexSans(
        fontSize: 18,
        fontWeight: FontWeight.w500,
        color: colors.textPrimary,
        height: 1.3,
      ),
      bodySans: GoogleFonts.ibmPlexSans(
        fontSize: 15,
        fontWeight: FontWeight.w400,
        color: colors.textPrimary,
        height: 1.4,
      ),
      bodyMono: GoogleFonts.ibmPlexMono(
        fontSize: 15,
        fontWeight: FontWeight.w400,
        color: colors.textPrimary,
        fontFeatures: baseMonoFeatures,
        height: 1.4,
      ),
      captionSans: GoogleFonts.ibmPlexSans(
        fontSize: 13,
        fontWeight: FontWeight.w400,
        color: colors.textSecondary,
        height: 1.4,
      ),
      smallSans: GoogleFonts.ibmPlexSans(
        fontSize: 12,
        fontWeight: FontWeight.w500,
        color: colors.textTooltip,
        height: 1.3,
      ),
      smallMono: GoogleFonts.ibmPlexMono(
        fontSize: 12,
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
}
