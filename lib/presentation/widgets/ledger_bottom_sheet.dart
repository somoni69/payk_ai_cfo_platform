import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_tabler_icons/flutter_tabler_icons.dart';
import '../../core/localization/language_cubit.dart';
import '../../core/theme/theme_extensions.dart';
import 'bottom_action_wrapper.dart';

/// Единый переиспользуемый компонент для плавающего модального окна (Bottom Sheet).
class LedgerBottomSheet extends StatelessWidget {
  final String title;
  final Widget child;
  final double maxHeight;
  final Widget? footer;

  const LedgerBottomSheet({
    super.key,
    required this.title,
    required this.child,
    required this.maxHeight,
    this.footer,
  });

  /// Opens a modal bottom sheet.
  ///
  /// [isDirty]: when provided, Android-back / blocked pops ask for discard.
  /// Swipe-to-dismiss is handled by first dropping the [PopScope] guard, then
  /// popping on the next frame — avoids `_dependents.isEmpty` crashes.
  static Future<T?> show<T>({
    required BuildContext context,
    required String title,
    required Widget Function(BuildContext context, StateSetter setSheetState)
    builder,
    Widget Function(BuildContext context, StateSetter setSheetState)?
    footerBuilder,
    bool Function()? isDirty,
    bool isDismissible = true,
    bool enableDrag = true,
  }) {
    return showModalBottomSheet<T>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      useRootNavigator: true,
      isDismissible: isDismissible,
      enableDrag: enableDrag,
      backgroundColor: Colors.transparent,
      elevation: 0,
      builder: (sheetContext) {
        return _LedgerSheetHost<T>(
          title: title,
          builder: builder,
          footerBuilder: footerBuilder,
          isDirty: isDirty,
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final textStyles = context.textStyles;

    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: maxHeight),
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(24),
          // Ledger: borders over shadows (design_language.md)
          border: Border.all(color: colors.border, width: 1.5),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 12),
            Center(
              child: Container(
                width: 32,
                height: 3,
                decoration: BoxDecoration(
                  color: colors.textSecondary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(1.5),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                title,
                style: textStyles.h2Sans.copyWith(fontWeight: FontWeight.w500),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const Divider(height: 16),
            Flexible(
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(
                  20,
                  4,
                  20,
                  footer == null ? 20 : 8,
                ),
                child: child,
              ),
            ),
            if (footer != null) ...[
              const Divider(height: 1),
              BottomActionWrapper(
                backgroundColor: colors.surface,
                child: footer!,
              ),
            ],
          ],
        ),
      ),
    );
  }

  static Future<bool?> confirmDiscard(BuildContext context) {
    final colors = context.colors;
    final textStyles = context.textStyles;
    final language = context.read<LanguageCubit>();

    return showDialog<bool>(
      context: context,
      useRootNavigator: true,
      barrierDismissible: false,
      builder: (context) => Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 40),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        backgroundColor: colors.surface,
        elevation: 0,
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: colors.accentAmber.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  TablerIcons.alert_triangle,
                  color: colors.accentAmber,
                  size: 36,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                language.translate('discard_title'),
                style: textStyles.h2Sans.copyWith(
                  fontWeight: FontWeight.w500,
                  fontSize: 20,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                language.translate('discard_message'),
                style: textStyles.bodySans.copyWith(
                  color: colors.textSecondary,
                  height: 1.5,
                  fontSize: 15,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context, false),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: colors.brand,
                    foregroundColor: colors.surface,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    language.translate('discard_continue'),
                    style: textStyles.bodySans.copyWith(
                      color: colors.surface,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    vertical: 8,
                    horizontal: 16,
                  ),
                ),
                child: Text(
                  language.translate('discard_close'),
                  style: textStyles.bodySans.copyWith(
                    color: colors.accentRed,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Host that owns sheet state + safe pop pipeline.
class _LedgerSheetHost<T> extends StatefulWidget {
  const _LedgerSheetHost({
    required this.title,
    required this.builder,
    this.footerBuilder,
    this.isDirty,
  });

  final String title;
  final Widget Function(BuildContext context, StateSetter setSheetState)
  builder;
  final Widget Function(BuildContext context, StateSetter setSheetState)?
  footerBuilder;
  final bool Function()? isDirty;

  @override
  State<_LedgerSheetHost<T>> createState() => _LedgerSheetHostState<T>();
}

class _LedgerSheetHostState<T> extends State<_LedgerSheetHost<T>> {
  bool _isDiscarding = false;
  bool _busy = false;

  bool get _dirty => widget.isDirty?.call() ?? false;

  Future<void> _handlePopInvoked(bool didPop, Object? result) async {
    // If route already popped cleanly, do nothing.
    if (didPop || _isDiscarding || _busy || !mounted) return;

    // Only intercept if there are unsaved changes.
    if (_dirty) {
      _busy = true;
      try {
        final shouldClose = await LedgerBottomSheet.confirmDiscard(context);
        if (shouldClose == true && mounted) {
          _isDiscarding = true;
          Navigator.of(context).pop();
        }
      } finally {
        _busy = false;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.sizeOf(context);
    final viewInsets = MediaQuery.viewInsetsOf(context);
    final padding = MediaQuery.paddingOf(context);

    final keyboardHeight = viewInsets.bottom;
    final topSafeArea = padding.top;

    final availableHeight =
        screenSize.height -
        keyboardHeight -
        (topSafeArea > 0 ? topSafeArea : 24) -
        48;
    final maxAvailableHeight = availableHeight * 0.92;

    final childWidget = Padding(
      padding: EdgeInsets.only(
        bottom: keyboardHeight + 16,
        left: 16,
        right: 16,
        top: (topSafeArea > 0 ? topSafeArea : 24) + 16,
      ),
      child: _LedgerSheetContentHost(
        title: widget.title,
        maxHeight: maxAvailableHeight,
        builder: widget.builder,
        footerBuilder: widget.footerBuilder,
      ),
    );

    return PopScope(
      canPop: !_dirty || _isDiscarding,
      onPopInvokedWithResult: _handlePopInvoked,
      child: childWidget,
    );
  }
}

class _LedgerSheetContentHost extends StatefulWidget {
  final String title;
  final double maxHeight;
  final Widget Function(BuildContext context, StateSetter setSheetState)
  builder;
  final Widget Function(BuildContext context, StateSetter setSheetState)?
  footerBuilder;

  const _LedgerSheetContentHost({
    required this.title,
    required this.maxHeight,
    required this.builder,
    this.footerBuilder,
  });

  @override
  State<_LedgerSheetContentHost> createState() =>
      _LedgerSheetContentHostState();
}

class _LedgerSheetContentHostState extends State<_LedgerSheetContentHost> {
  @override
  Widget build(BuildContext context) {
    return LedgerBottomSheet(
      title: widget.title,
      maxHeight: widget.maxHeight,
      footer: widget.footerBuilder?.call(context, setState),
      child: widget.builder(context, setState),
    );
  }
}
