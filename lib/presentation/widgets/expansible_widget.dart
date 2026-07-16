import 'package:flutter/material.dart';
import '../../core/theme/theme_extensions.dart';
import 'ledger_card.dart';

/// Единый переиспользуемый компонент для раскрывающихся списков (ExpansionTile)
/// с встроенной оберткой LedgerCard и настройкой тем оформления.
class ExpansibleWidget<T> extends StatelessWidget {
  final Widget title;
  final Widget? subtitle;
  final List<Widget>? children;

  // Параметры для режима выбора (selection)
  final List<T>? items;
  final T? selectedValue;
  final String Function(T)? itemLabelBuilder;
  final ValueChanged<T>? onSelected;

  final EdgeInsetsGeometry cardPadding;
  final EdgeInsetsGeometry tilePadding;
  final ExpansibleController? controller;
  final bool initiallyExpanded;

  const ExpansibleWidget({
    super.key,
    required this.title,
    required this.children,
    this.subtitle,
    this.cardPadding = const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
    this.tilePadding = EdgeInsets.zero,
    this.controller,
    this.initiallyExpanded = false,
  })  : items = null,
        selectedValue = null,
        itemLabelBuilder = null,
        onSelected = null;

  const ExpansibleWidget.selection({
    super.key,
    required this.title,
    required this.items,
    required this.selectedValue,
    required this.itemLabelBuilder,
    required this.onSelected,
    this.subtitle,
    this.cardPadding = const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
    this.tilePadding = EdgeInsets.zero,
    this.controller,
    this.initiallyExpanded = false,
  }) : children = null;

  List<Widget> _buildClassicChildren(BuildContext context) {
    if (children == null) return [];
    final List<Widget> list = [];
    final colors = context.colors;

    list.add(Divider(
      color: colors.border.withValues(alpha: 0.5),
      height: 1,
      thickness: 1,
    ));

    for (int i = 0; i < children!.length; i++) {
      if (i > 0) {
        list.add(Divider(
          color: colors.border.withValues(alpha: 0.5),
          height: 1,
          thickness: 1,
        ));
      }
      list.add(children![i]);
    }
    return list;
  }

  List<Widget> _buildSelectionChildren(BuildContext context) {
    if (items == null || onSelected == null || itemLabelBuilder == null) return [];
    
    final List<Widget> list = [];
    final colors = context.colors;
    final textStyles = context.textStyles;

    list.add(Divider(
      color: colors.border.withValues(alpha: 0.5),
      height: 1,
      thickness: 1,
    ));

    for (int i = 0; i < items!.length; i++) {
      final item = items![i];
      final label = itemLabelBuilder!(item);
      final isSelected = item == selectedValue;

      if (i > 0) {
        list.add(Divider(
          color: colors.border.withValues(alpha: 0.5),
          height: 1,
          thickness: 1,
        ));
      }

      list.add(
        ListTile(
          dense: true,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16),
          title: Text(
            label,
            style: textStyles.bodySans.copyWith(
              color: isSelected ? colors.brand : colors.textPrimary,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
          trailing: isSelected
              ? Icon(Icons.check, color: colors.brand, size: 18)
              : null,
          onTap: () {
            onSelected!(item);
          },
        ),
      );
    }
    return list;
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final textStyles = context.textStyles;

    final computedChildren = items != null 
        ? _buildSelectionChildren(context) 
        : _buildClassicChildren(context);

    return LedgerCard(
      padding: cardPadding,
      child: Theme(
        data: Theme.of(context).copyWith(
          dividerColor: Colors.transparent,
          hoverColor: Colors.transparent,
          splashColor: Colors.transparent,
        ),
        child: ListTileTheme.merge(
          dense: true,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16),
          child: ExpansionTile(
            controller: controller,
            initiallyExpanded: initiallyExpanded,
            tilePadding: const EdgeInsets.symmetric(horizontal: 16),
            title: DefaultTextStyle.merge(
              style: textStyles.bodySans.copyWith(
                fontWeight: FontWeight.w600,
                color: colors.textPrimary,
              ),
              child: title,
            ),
            subtitle: subtitle,
            iconColor: colors.textSecondary,
            collapsedIconColor: colors.textSecondary,
            children: computedChildren,
          ),
        ),
      ),
    );
  }
}
