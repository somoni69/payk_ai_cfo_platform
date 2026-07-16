import 'package:flutter/material.dart';
import 'package:flutter_tabler_icons/flutter_tabler_icons.dart';
import '../../core/theme/theme_extensions.dart';
import 'bottom_action_wrapper.dart';

/// Единый переиспользуемый компонент для плавающего модального окна (Bottom Sheet).
/// Отображает контент в виде парящей карточки со скругленными углами,
/// границами и отступами со всех сторон (left, right, bottom) согласно ТЗ.
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

  /// Статический метод для удобного открытия модального окна
  static Future<T?> show<T>({
    required BuildContext context,
    required String title,
    required Widget Function(BuildContext context, StateSetter setSheetState) builder,
    Widget Function(BuildContext context, StateSetter setSheetState)? footerBuilder,
    bool isDismissible = true,
    bool enableDrag = true,
  }) {
    return showModalBottomSheet<T>(
      context: context,
      isScrollControlled: true,
      useRootNavigator: true,
      useSafeArea: true,
      isDismissible: isDismissible,
      enableDrag: enableDrag,
      backgroundColor: Colors.transparent,
      elevation: 0,
      builder: (context) {
        final mediaQuery = MediaQuery.of(context);
        final screenHeight = mediaQuery.size.height;
        final keyboardHeight = mediaQuery.viewInsets.bottom;
        final topSafeArea = mediaQuery.padding.top;

        // Вычисляем доступную высоту над клавиатурой с запасом под челку
        final availableHeight = screenHeight - keyboardHeight - (topSafeArea > 0 ? topSafeArea : 24) - 48;
        final maxAvailableHeight = availableHeight * 0.92;

        return AnimatedPadding(
          duration: const Duration(milliseconds: 150),
          curve: Curves.easeOut,
          padding: EdgeInsets.only(
            bottom: keyboardHeight + 16,
            left: 16,
            right: 16,
            top: (topSafeArea > 0 ? topSafeArea : 24) + 16,
          ),
          child: StatefulBuilder(
            builder: (context, setSheetState) {
              return LedgerBottomSheet(
                title: title,
                maxHeight: maxAvailableHeight,
                footer: footerBuilder?.call(context, setSheetState),
                child: builder(context, setSheetState),
              );
            },
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final textStyles = context.textStyles;

    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: maxHeight,
      ),
      child: Container(
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: colors.border, width: 1.5),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 12),
            // Индикатор перетаскивания (Handle)
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
                style: textStyles.h2Sans.copyWith(fontWeight: FontWeight.bold),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const Divider(height: 16),
            Flexible(
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(20, 4, 20, footer == null ? 20 : 8),
                child: child,
              ),
            ),
            if (footer != null) ...[
              const Divider(height: 1),
              BottomActionWrapper(
                child: footer!,
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// Диалог подтверждения выхода без сохранения изменений (согласно дизайну)
  static Future<bool?> confirmDiscard(BuildContext context) {
    final colors = context.colors;
    final textStyles = context.textStyles;

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
                child: Icon(TablerIcons.alert_triangle, color: colors.accentAmber, size: 36),
              ),
              const SizedBox(height: 20),
              Text(
                'Изменения не сохранены',
                style: textStyles.h2Sans.copyWith(fontWeight: FontWeight.bold, fontSize: 20),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                'Если закрыть окно сейчас,\nвведённые данные будут потеряны.',
                style: textStyles.bodySans.copyWith(color: colors.textSecondary, height: 1.5, fontSize: 15),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context, false),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: colors.brand,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Text(
                    'Продолжить редактирование',
                    style: textStyles.bodySans.copyWith(color: Colors.white, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                ),
                child: Text(
                  'Закрыть без сохранения',
                  style: textStyles.bodySans.copyWith(color: colors.accentRed, fontWeight: FontWeight.w500),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
