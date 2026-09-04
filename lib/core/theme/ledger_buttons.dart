import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'app_text_styles.dart';
import 'theme_extensions.dart';

/// Screen CTAs, empty states, login, branded FABs.
const kLedgerScreenButtonHeight = 44.0;
const kLedgerScreenButtonRadius = 12.0;
const kLedgerScreenButtonHPad = 16.0;
const kLedgerScreenButtonFont = 13.0;
const kLedgerScreenButtonIcon = 18.0;

/// Labeled floating buttons above the liquid nav.
const kLedgerFabSize = 52.0;
const kLedgerFabRadius = 14.0;
const kLedgerFabHPad = 18.0;
const kLedgerFabFont = 14.0;
const kLedgerFabIcon = 20.0;

/// Sheet / dialog primary and secondary actions.
const kLedgerModalButtonHeight = 48.0;
const kLedgerModalButtonRadius = 12.0;
const kLedgerModalButtonHPad = 20.0;
const kLedgerModalButtonFont = 14.0;
const kLedgerModalButtonIcon = 18.0;

/// Shared size tokens for every Elevated / Outlined / Text / FAB button.
abstract final class LedgerButtons {
  static ButtonStyle screenElevated(
    LedgerColors colors,
    LedgerTextStyles text,
  ) {
    return _elevated(colors, text, modal: false);
  }

  static ButtonStyle screenOutlined(
    LedgerColors colors,
    LedgerTextStyles text,
  ) {
    return _outlined(colors, text, modal: false);
  }

  static ButtonStyle screenText(LedgerColors colors, LedgerTextStyles text) {
    return _text(colors, text, modal: false);
  }

  static ButtonStyle modalElevated(LedgerColors colors, LedgerTextStyles text) {
    return _elevated(colors, text, modal: true);
  }

  static ButtonStyle modalOutlined(LedgerColors colors, LedgerTextStyles text) {
    return _outlined(colors, text, modal: true);
  }

  static ButtonStyle modalText(LedgerColors colors, LedgerTextStyles text) {
    return _text(colors, text, modal: true);
  }

  /// Overlay so every button inside a sheet / dialog uses modal sizes.
  static ThemeData modalOverlay(BuildContext context) {
    final colors = context.colors;
    final text = context.textStyles;
    return Theme.of(context).copyWith(
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: modalElevated(colors, text),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: modalOutlined(colors, text),
      ),
      textButtonTheme: TextButtonThemeData(style: modalText(colors, text)),
      floatingActionButtonTheme: _fabTheme(colors, text),
    );
  }

  static FloatingActionButtonThemeData screenFabTheme(
    LedgerColors colors,
    LedgerTextStyles text,
  ) {
    return _fabTheme(colors, text);
  }

  static ButtonStyle _elevated(
    LedgerColors colors,
    LedgerTextStyles text, {
    required bool modal,
  }) {
    return ElevatedButton.styleFrom(
      backgroundColor: colors.brand,
      foregroundColor: colors.surface,
      disabledBackgroundColor: colors.brand.withValues(alpha: 0.4),
      disabledForegroundColor: colors.surface,
      elevation: 0,
      shadowColor: Colors.transparent,
      minimumSize: Size(64, _height(modal)),
      maximumSize: Size(double.infinity, _height(modal)),
      padding: EdgeInsets.symmetric(horizontal: _hPad(modal)),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(_radius(modal)),
      ),
      textStyle: text.bodySans.copyWith(
        fontWeight: FontWeight.w600,
        fontSize: _font(modal),
        height: 1.2,
      ),
      iconSize: _icon(modal),
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      visualDensity: VisualDensity.standard,
    );
  }

  static ButtonStyle _outlined(
    LedgerColors colors,
    LedgerTextStyles text, {
    required bool modal,
  }) {
    return OutlinedButton.styleFrom(
      foregroundColor: colors.textPrimary,
      backgroundColor: colors.surface,
      disabledForegroundColor: colors.textSecondary,
      elevation: 0,
      side: BorderSide(color: colors.border, width: 1),
      minimumSize: Size(64, _height(modal)),
      maximumSize: Size(double.infinity, _height(modal)),
      padding: EdgeInsets.symmetric(horizontal: _hPad(modal)),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(_radius(modal)),
      ),
      textStyle: text.bodySans.copyWith(
        fontWeight: FontWeight.w600,
        fontSize: _font(modal),
        height: 1.2,
      ),
      iconSize: _icon(modal),
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      visualDensity: VisualDensity.standard,
    );
  }

  static ButtonStyle _text(
    LedgerColors colors,
    LedgerTextStyles text, {
    required bool modal,
  }) {
    return TextButton.styleFrom(
      foregroundColor: colors.brand,
      minimumSize: Size(48, modal ? 40 : 36),
      padding: EdgeInsets.symmetric(
        horizontal: modal ? 16 : 12,
        vertical: modal ? 8 : 6,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(_radius(modal)),
      ),
      textStyle: text.bodySans.copyWith(
        fontWeight: FontWeight.w500,
        fontSize: _font(modal),
        height: 1.2,
      ),
      iconSize: _icon(modal),
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      visualDensity: VisualDensity.standard,
    );
  }

  static FloatingActionButtonThemeData _fabTheme(
    LedgerColors colors,
    LedgerTextStyles text,
  ) {
    return FloatingActionButtonThemeData(
      backgroundColor: colors.brand,
      foregroundColor: colors.surface,
      elevation: 0,
      focusElevation: 0,
      hoverElevation: 0,
      highlightElevation: 0,
      disabledElevation: 0,
      extendedPadding: const EdgeInsets.symmetric(horizontal: kLedgerFabHPad),
      extendedIconLabelSpacing: 8,
      extendedSizeConstraints: const BoxConstraints.tightFor(
        height: kLedgerFabSize,
      ),
      sizeConstraints: const BoxConstraints.tightFor(
        width: kLedgerFabSize,
        height: kLedgerFabSize,
      ),
      iconSize: kLedgerFabIcon,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(kLedgerFabRadius),
      ),
      extendedTextStyle: text.bodySans.copyWith(
        fontWeight: FontWeight.w600,
        fontSize: kLedgerFabFont,
        color: colors.surface,
        height: 1.2,
      ),
    );
  }

  static double _height(bool modal) =>
      modal ? kLedgerModalButtonHeight : kLedgerScreenButtonHeight;

  static double _radius(bool modal) =>
      modal ? kLedgerModalButtonRadius : kLedgerScreenButtonRadius;

  static double _hPad(bool modal) =>
      modal ? kLedgerModalButtonHPad : kLedgerScreenButtonHPad;

  static double _font(bool modal) =>
      modal ? kLedgerModalButtonFont : kLedgerScreenButtonFont;

  static double _icon(bool modal) =>
      modal ? kLedgerModalButtonIcon : kLedgerScreenButtonIcon;
}
