import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_tabler_icons/flutter_tabler_icons.dart';
import 'package:go_router/go_router.dart';

import '../../../core/localization/language_cubit.dart';
import '../../../core/theme/theme_extensions.dart';
import '../../../presentation/widgets/ledger_segmented_control.dart';
import '../../auth/bloc/auth_bloc.dart';
import '../../auth/bloc/auth_state.dart';

/// Корень сети владельца: шапка с фирменным переключателем разделов.
///
/// Плашка та же, что у «Сегодня / Месяц / Всё время». Нижней капсулы нет,
/// поэтому вокруг неё не появляется вторая рамка.
class OwnerRootShell extends StatelessWidget {
  const OwnerRootShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  static const _titles = ['network_title', 'leads_title', 'modules_title'];

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthBloc>().state;
    final isOwner = auth is AuthAuthenticated && auth.role == UserRole.owner;
    if (!isOwner) return navigationShell;

    final colors = context.colors;
    final textStyles = context.textStyles;
    final language = context.watch<LanguageCubit>();
    final index = navigationShell.currentIndex.clamp(0, _titles.length - 1);

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        backgroundColor: colors.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        automaticallyImplyLeading: false,
        title: Text(
          language.translate(_titles[index]),
          style: textStyles.h2Sans.copyWith(
            fontSize: 19,
            fontWeight: FontWeight.w600,
            color: colors.textPrimary,
          ),
        ),
        actions: [
          IconButton(
            tooltip: language.translate('settings_title'),
            onPressed: () => context.push('/settings'),
            icon: const Icon(TablerIcons.settings),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(49),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                child: LedgerSegmentedControl<int>(
                  segments: [
                    LedgerSegmentItem(
                      value: 0,
                      label: language.translate('nav_network'),
                    ),
                    LedgerSegmentItem(
                      value: 1,
                      label: language.translate('leads_title'),
                    ),
                    LedgerSegmentItem(
                      value: 2,
                      label: language.translate('modules_title'),
                    ),
                  ],
                  selectedValue: index,
                  onValueChanged: (next) {
                    if (next == index) return;
                    HapticFeedback.selectionClick();
                    navigationShell.goBranch(next);
                  },
                ),
              ),
              Container(height: 1, color: colors.border),
            ],
          ),
        ),
      ),
      body: _BranchFade(index: index, child: navigationShell),
    );
  }
}

/// Мягкое появление раздела. Стек веток не пересоздаётся, плашка в шапке едет.
class _BranchFade extends StatefulWidget {
  const _BranchFade({required this.index, required this.child});

  final int index;
  final Widget child;

  @override
  State<_BranchFade> createState() => _BranchFadeState();
}

class _BranchFadeState extends State<_BranchFade>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  var _direction = 1.0;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
    )..value = 1;
  }

  @override
  void didUpdateWidget(covariant _BranchFade oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.index == widget.index) return;
    _direction = widget.index >= oldWidget.index ? 1 : -1;
    if (MediaQuery.disableAnimationsOf(context)) {
      _controller.value = 1;
      return;
    }
    _controller.forward(from: 0);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final animation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    );
    return FadeTransition(
      opacity: animation,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: Offset(0.04 * _direction, 0),
          end: Offset.zero,
        ).animate(animation),
        child: widget.child,
      ),
    );
  }
}
