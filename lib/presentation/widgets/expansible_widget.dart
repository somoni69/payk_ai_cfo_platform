import 'package:flutter/material.dart';
import 'ledger_card.dart';

/// Единый переиспользуемый компонент для раскрывающихся списков (ExpansionTile)
/// с встроенной оберткой LedgerCard и настройкой тем оформления.
class ExpansibleWidget extends StatelessWidget {
  final Widget title;
  final Widget? subtitle;
  final List<Widget> children;
  final EdgeInsetsGeometry cardPadding;
  final EdgeInsetsGeometry tilePadding;

  const ExpansibleWidget({
    super.key,
    required this.title,
    required this.children,
    this.subtitle,
    this.cardPadding = const EdgeInsets.all(14),
    this.tilePadding = EdgeInsets.zero,
  });

  @override
  Widget build(BuildContext context) {
    return LedgerCard(
      padding: cardPadding,
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: tilePadding,
          title: title,
          subtitle: subtitle,
          children: children,
        ),
      ),
    );
  }
}
