import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

/// Назад по стеку. Если экрана под текущим нет, уходим на [fallback],
/// а не закрываем приложение. Без [fallback] с корня стека приложение закрывается.
void paykBack(BuildContext context, {String? fallback}) {
  final router = GoRouter.of(context);
  if (router.canPop()) {
    router.pop();
    return;
  }
  final path = router.state.uri.path;
  if (fallback != null && path != fallback) {
    router.go(fallback);
    return;
  }
  SystemNavigator.pop();
}

/// Перехватывает системный жест «назад».
///
/// [nested] — экран внутри нижней панели. Жест там не видит страницу
/// на корневом навигаторе и закрывает приложение. Тогда снимаем верхнюю
/// страницу корня сами.
class PaykBackScope extends StatefulWidget {
  const PaykBackScope({
    super.key,
    required this.child,
    this.fallback,
    this.nested = false,
  });

  final Widget child;
  final String? fallback;
  final bool nested;

  @override
  State<PaykBackScope> createState() => _PaykBackScopeState();
}

class _PaykBackScopeState extends State<PaykBackScope> {
  var _busy = false;

  void _onPop(bool didPop) {
    if (didPop || _busy) return;
    _busy = true;
    if (widget.nested) {
      final root = Navigator.of(context, rootNavigator: true);
      if (root.canPop()) {
        root.pop();
      } else if (widget.fallback != null) {
        GoRouter.of(context).go(widget.fallback!);
      } else {
        SystemNavigator.pop();
      }
    } else {
      paykBack(context, fallback: widget.fallback);
    }
    _busy = false;
  }

  @override
  Widget build(BuildContext context) {
    final canPop = widget.nested ? false : GoRouter.of(context).canPop();
    return PopScope(
      canPop: canPop,
      onPopInvokedWithResult: (didPop, _) => _onPop(didPop),
      child: widget.child,
    );
  }
}

class PaykBackButton extends StatelessWidget {
  const PaykBackButton({super.key, this.fallback});

  final String? fallback;

  @override
  Widget build(BuildContext context) {
    final show = GoRouter.of(context).canPop() || fallback != null;
    if (!show) return const SizedBox.shrink();
    return IconButton(
      tooltip: MaterialLocalizations.of(context).backButtonTooltip,
      onPressed: () => paykBack(context, fallback: fallback),
      icon: const BackButtonIcon(),
    );
  }
}
