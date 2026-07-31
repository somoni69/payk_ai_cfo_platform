import 'package:flutter/material.dart';
import '../../core/theme/theme_extensions.dart';
import 'ledger_card.dart';

/// Reusable expansion panel with lazy selection options.
class ExpansibleWidget<T> extends StatefulWidget {
  final Widget title;
  final Widget? subtitle;
  final List<Widget>? children;
  final List<T>? items;
  final T? selectedValue;
  final String Function(T)? itemLabelBuilder;
  final ValueChanged<T>? onSelected;
  final EdgeInsetsGeometry cardPadding;
  final EdgeInsetsGeometry tilePadding;
  final ExpansibleController? controller;
  final bool initiallyExpanded;
  final double? borderRadius;

  const ExpansibleWidget({
    super.key,
    required this.title,
    required this.children,
    this.subtitle,
    this.cardPadding = const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
    this.tilePadding = EdgeInsets.zero,
    this.controller,
    this.initiallyExpanded = false,
    this.borderRadius,
  }) : items = null,
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
    this.borderRadius,
  }) : children = null;

  @override
  State<ExpansibleWidget<T>> createState() => _ExpansibleWidgetState<T>();
}

class _ExpansibleWidgetState<T> extends State<ExpansibleWidget<T>> {
  static const _selectionSearchThreshold = 12;
  late ExpansibleController _controller;
  late bool _showChildren;
  int _expansionGeneration = 0;

  @override
  void initState() {
    super.initState();
    _controller = widget.controller ?? ExpansibleController();
    _showChildren = widget.initiallyExpanded;
  }

  @override
  void didUpdateWidget(ExpansibleWidget<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.controller != null &&
        widget.controller != oldWidget.controller) {
      _controller = widget.controller!;
    }
    if (oldWidget.initiallyExpanded != widget.initiallyExpanded) {
      _showChildren = widget.initiallyExpanded;
    }
  }

  void _handleExpansionChanged(bool expanded) {
    final generation = ++_expansionGeneration;
    if (expanded) {
      if (!_showChildren) setState(() => _showChildren = true);
      return;
    }

    Future<void>.delayed(kThemeAnimationDuration, () {
      if (!mounted || generation != _expansionGeneration || !_showChildren) {
        return;
      }
      setState(() => _showChildren = false);
    });
  }

  void _handleOptionSelected(T item) {
    widget.onSelected?.call(item);
    if (_controller.isExpanded) {
      _controller.collapse();
    }
  }

  List<Widget> _buildClassicChildren(BuildContext context) {
    final children = widget.children;
    if (!_showChildren || children == null || children.isEmpty) return const [];
    final colors = context.colors;

    return [
      Divider(
        color: colors.border.withValues(alpha: 0.3),
        height: 1,
        thickness: 1,
      ),
      for (var index = 0; index < children.length; index++) ...[
        if (index > 0)
          Divider(
            color: colors.border.withValues(alpha: 0.3),
            height: 1,
            thickness: 1,
          ),
        children[index],
      ],
    ];
  }

  List<Widget> _buildSelectionChildren(BuildContext context) {
    final items = widget.items;
    final itemLabelBuilder = widget.itemLabelBuilder;
    if (!_showChildren ||
        items == null ||
        itemLabelBuilder == null ||
        widget.onSelected == null) {
      return const [];
    }

    return [
      Divider(
        color: context.colors.border.withValues(alpha: 0.3),
        height: 1,
        thickness: 1,
      ),
      _SelectionOptions<T>(
        items: items,
        selectedValue: widget.selectedValue,
        itemLabelBuilder: itemLabelBuilder,
        onSelected: _handleOptionSelected,
        searchable: items.length > _selectionSearchThreshold,
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final textStyles = context.textStyles;
    final computedChildren = widget.items != null
        ? _buildSelectionChildren(context)
        : _buildClassicChildren(context);

    return LedgerCard(
      padding: widget.cardPadding,
      borderRadius: widget.borderRadius ?? 16,
      child: Material(
        type: MaterialType.transparency,
        child: ExpansionTile(
          shape: const Border(),
          collapsedShape: const Border(),
          backgroundColor: Colors.transparent,
          collapsedBackgroundColor: Colors.transparent,
          dense: true,
          controller: _controller,
          initiallyExpanded: widget.initiallyExpanded,
          onExpansionChanged: _handleExpansionChanged,
          tilePadding: widget.tilePadding,
          title: DefaultTextStyle.merge(
            style: textStyles.bodySans.copyWith(
              fontWeight: FontWeight.w600,
              color: colors.textPrimary,
            ),
            child: widget.title,
          ),
          subtitle: widget.subtitle,
          iconColor: colors.textSecondary,
          collapsedIconColor: colors.textSecondary,
          children: computedChildren,
        ),
      ),
    );
  }
}

class _SelectionOptions<T> extends StatefulWidget {
  final List<T> items;
  final T? selectedValue;
  final String Function(T) itemLabelBuilder;
  final ValueChanged<T> onSelected;
  final bool searchable;

  const _SelectionOptions({
    required this.items,
    required this.selectedValue,
    required this.itemLabelBuilder,
    required this.onSelected,
    required this.searchable,
  });

  @override
  State<_SelectionOptions<T>> createState() => _SelectionOptionsState<T>();
}

class _SelectionOptionsState<T> extends State<_SelectionOptions<T>> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final normalizedQuery = _query.trim().toLowerCase();
    final filteredItems = normalizedQuery.isEmpty
        ? widget.items
        : widget.items
              .where((item) {
                return widget
                    .itemLabelBuilder(item)
                    .toLowerCase()
                    .contains(normalizedQuery);
              })
              .toList(growable: false);

    final list = ListView.separated(
      padding: EdgeInsets.zero,
      shrinkWrap: !widget.searchable,
      physics: widget.searchable
          ? const ClampingScrollPhysics()
          : const NeverScrollableScrollPhysics(),
      itemCount: filteredItems.length,
      separatorBuilder: (context, index) => Divider(
        color: context.colors.border.withValues(alpha: 0.3),
        height: 1,
        thickness: 1,
        indent: 0,
        endIndent: 0,
      ),
      itemBuilder: (context, index) =>
          _buildOption(context, filteredItems[index]),
    );

    if (!widget.searchable) return list;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(0, 8, 0, 6),
          child: TextField(
            style: context.textStyles.bodySans,
            decoration: InputDecoration(
              isDense: true,
              hintText: MaterialLocalizations.of(context).searchFieldLabel,
              prefixIcon: const Icon(Icons.search, size: 18),
            ),
            onChanged: (value) => setState(() => _query = value),
          ),
        ),
        SizedBox(
          height: 280,
          child: filteredItems.isEmpty
              ? const Center(child: Icon(Icons.search_off, size: 20))
              : list,
        ),
      ],
    );
  }

  Widget _buildOption(BuildContext context, T item) {
    final colors = context.colors;
    final textStyles = context.textStyles;
    final isSelected = item == widget.selectedValue;

    return ListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      splashColor: Colors.transparent,
      focusColor: Colors.transparent,
      hoverColor: Colors.transparent,
      tileColor: Colors.transparent,
      selectedTileColor: Colors.transparent,
      title: Text(
        widget.itemLabelBuilder(item),
        style: textStyles.bodySans.copyWith(
          color: isSelected ? colors.brand : colors.textPrimary,
          fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
        ),
      ),
      trailing: isSelected
          ? Icon(Icons.check, color: colors.brand, size: 18)
          : null,
      onTap: () => widget.onSelected(item),
    );
  }
}
