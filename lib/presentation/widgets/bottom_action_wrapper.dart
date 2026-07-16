import 'package:flutter/material.dart';

/// Универсальная обёртка для главных кнопок внизу экрана или модальных окон.
///
/// Задаёт идеальные отступы и защищает кнопку
/// от системной полосы iPhone (SafeArea).
class BottomActionWrapper extends StatelessWidget {
  final Widget child;
  final Color? backgroundColor;

  const BottomActionWrapper({
    super.key,
    required this.child,
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: backgroundColor ?? Colors.transparent,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: SizedBox(
            width: double.infinity,
            child: child,
          ),
        ),
      ),
    );
  }
}
