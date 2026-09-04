import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_tabler_icons/flutter_tabler_icons.dart';
import '../../core/localization/language_cubit.dart';
import '../../core/theme/ledger_buttons.dart';
import '../../core/theme/ledger_layout.dart';
import '../../core/theme/theme_extensions.dart';
import 'bottom_action_wrapper.dart';

/// Shared chrome for the AI assistant and every content sheet: full width,
/// 16px top radius, max height 88% (same as the AI assistant).
///
/// Pass [expand] so the sheet always fills that 88% (chat). Forms omit it
/// and wrap to their content instead of leaving a blank body.
Future<T?> showLedgerModalSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool isDismissible = true,
  bool enableDrag = true,
  bool expand = false,
}) {
  return showModalBottomSheet<T>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    useSafeArea: true,
    isDismissible: isDismissible,
    enableDrag: enableDrag,
    backgroundColor: Colors.transparent,
    elevation: 0,
    builder: (ctx) {
      final height = ledgerModalHeightOf(ctx);
      final content = builder(ctx);
      final sheet = expand
          ? SizedBox(height: height, width: double.infinity, child: content)
          : ConstrainedBox(
              constraints: BoxConstraints(maxHeight: height),
              child: SizedBox(width: double.infinity, child: content),
            );
      final panel = ClipRRect(
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(kLedgerModalTopRadius),
        ),
        child: sheet,
      );

      void dismiss() {
        if (!isDismissible) return;
        Navigator.of(ctx).maybePop();
      }

      // Align fills the overlay, so the transparent area above the sheet
      // would swallow taps and never reach the modal barrier. Catch them
      // here — same as tapping outside in most mobile apps.
      return Stack(
        fit: StackFit.expand,
        children: [
          if (isDismissible)
            Positioned.fill(
              child: Semantics(
                button: true,
                label: MaterialLocalizations.of(ctx).modalBarrierDismissLabel,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: dismiss,
                  child: const ColoredBox(color: Colors.transparent),
                ),
              ),
            ),
          Align(
            alignment: Alignment.bottomCenter,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () {},
              child: panel,
            ),
          ),
        ],
      );
    },
  );
}

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
    return showLedgerModalSheet<T>(
      context: context,
      isDismissible: isDismissible,
      enableDrag: enableDrag,
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

    return Theme(
      data: LedgerButtons.modalOverlay(context),
      child: Material(
        color: colors.surface,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: maxHeight),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Semantics(
                button: true,
                label: MaterialLocalizations.of(
                  context,
                ).modalBarrierDismissLabel,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => Navigator.of(context).maybePop(),
                  child: SizedBox(
                    height: 28,
                    width: double.infinity,
                    child: Center(
                      child: Container(
                        width: 36,
                        height: 4,
                        decoration: BoxDecoration(
                          color: colors.textSecondary.withValues(alpha: 0.28),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Text(
                  title,
                  style: textStyles.h2Sans.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const Divider(height: 16),
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  padding: EdgeInsets.fromLTRB(
                    20,
                    4,
                    20,
                    footer == null ? 20 : 8,
                  ),
                  children: [child],
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
      builder: (context) => Theme(
        data: LedgerButtons.modalOverlay(context),
        child: Dialog(
          insetPadding: const EdgeInsets.symmetric(horizontal: 40),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
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
                    child: Text(language.translate('discard_continue')),
                  ),
                ),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: () => Navigator.pop(context, true),
                  style: TextButton.styleFrom(
                    foregroundColor: colors.accentRed,
                  ),
                  child: Text(language.translate('discard_close')),
                ),
              ],
            ),
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
    return PopScope(
      canPop: !_dirty || _isDiscarding,
      onPopInvokedWithResult: _handlePopInvoked,
      child: _LedgerSheetContentHost(
        title: widget.title,
        maxHeight: ledgerModalHeightOf(context),
        builder: widget.builder,
        footerBuilder: widget.footerBuilder,
      ),
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
