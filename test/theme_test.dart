import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:payk_ai_cfo_platform/core/theme/app_colors.dart';
import 'package:payk_ai_cfo_platform/core/theme/app_theme.dart';

void main() {
  test('dark theme exposes the dark Ledger palette', () {
    final theme = LedgerTheme.dark;

    expect(theme.brightness, Brightness.dark);
    expect(theme.scaffoldBackgroundColor, LedgerColors.dark.background);
    expect(theme.extension<LedgerColors>(), LedgerColors.dark);
    expect(theme.colorScheme.primary, LedgerColors.dark.brand);
    expect(theme.colorScheme.onSurface, LedgerColors.dark.textPrimary);
  });

  test('light theme remains the light Ledger palette', () {
    final theme = LedgerTheme.light;

    expect(theme.brightness, Brightness.light);
    expect(theme.scaffoldBackgroundColor, LedgerColors.light.background);
    expect(theme.extension<LedgerColors>(), LedgerColors.light);
  });
}
