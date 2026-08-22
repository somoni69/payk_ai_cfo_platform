import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_tabler_icons/flutter_tabler_icons.dart';
import 'package:go_router/go_router.dart';

import '../../../core/localization/language_cubit.dart';
import '../../../core/network/expiring_request_cache.dart';
import '../../../core/theme/theme_extensions.dart';
import '../../../features/auth/bloc/auth_bloc.dart';
import '../../../features/auth/bloc/auth_state.dart';
import '../../../features/auth/domain/app_access.dart';
import '../../../features/permissions/cubit/permissions_cubit.dart';
import '../../../features/permissions/domain/my_permissions.dart';

import '../../../features/dashboard/bloc/dashboard_bloc.dart';
import '../../../features/dashboard/bloc/dashboard_event.dart';
import '../../../features/dashboard/domain/finance_repository.dart';
import '../../../features/cash/bloc/cash_bloc.dart';
import '../../../features/cash/bloc/cash_event.dart';
import '../../../features/cash/domain/cash_repository.dart';
import '../../../features/tasks/bloc/tasks_bloc.dart';
import '../../../features/tasks/bloc/tasks_event.dart';
import '../../../features/tasks/domain/tasks_repository.dart';
import '../../../features/warehouse/bloc/warehouse_bloc.dart';
import '../../../features/warehouse/bloc/warehouse_event.dart';
import '../../../features/warehouse/domain/warehouse_repository.dart';
import '../../../features/assistant/presentation/ledger_ai_assistant.dart';

class TabItem {
  const TabItem({
    required this.branchIndex,
    required this.icon,
    required this.labelKey,
    this.capability,
  });

  final int branchIndex;
  final IconData icon;
  final String labelKey;
  final AppCapability? capability;
}

const List<TabItem> _allTabs = [
  TabItem(
    branchIndex: 0,
    icon: TablerIcons.layout_dashboard,
    labelKey: 'nav_dashboard',
    capability: AppCapability.dashboard,
  ),
  TabItem(
    branchIndex: 1,
    icon: TablerIcons.wallet,
    labelKey: 'nav_cash',
    capability: AppCapability.cash,
  ),
  TabItem(
    branchIndex: 2,
    icon: TablerIcons.checkbox,
    labelKey: 'nav_tasks',
    capability: AppCapability.tasks,
  ),
  TabItem(
    branchIndex: 3,
    icon: TablerIcons.package,
    labelKey: 'nav_warehouse',
    capability: AppCapability.warehouse,
  ),
  TabItem(branchIndex: 4, icon: TablerIcons.menu_2, labelKey: 'nav_more'),
];

class ShellScreen extends StatelessWidget {
  const ShellScreen({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider<DashboardBloc>(
          create: (context) => DashboardBloc(context.read<FinanceRepository>()),
        ),
        BlocProvider<CashBloc>(
          create: (context) => CashBloc(context.read<CashRepository>()),
        ),
        BlocProvider<TasksBloc>(
          create: (context) => TasksBloc(context.read<TasksRepository>()),
        ),
        BlocProvider<WarehouseBloc>(
          create: (context) =>
              WarehouseBloc(context.read<WarehouseRepository>()),
        ),
      ],
      child: _ShellScaffold(navigationShell: navigationShell),
    );
  }
}

class _ShellScaffold extends StatelessWidget {
  const _ShellScaffold({required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context) {
    return BlocListener<AuthBloc, AuthState>(
      listenWhen: (previous, current) {
        if (previous is AuthAuthenticated && current is AuthAuthenticated) {
          return previous.storeId != current.storeId ||
              previous.storeName != current.storeName;
        }
        return false;
      },
      listener: (context, state) {
        // Auto-refresh all module BLoCs and permissions on branch/store switch
        ExpiringRequestCache.invalidateAll();
        try {
          context.read<DashboardBloc>().add(
            const LoadDashboardData(forceRefresh: true, clearCache: true),
          );
        } catch (_) {}
        try {
          context.read<CashBloc>().add(const LoadCashData());
        } catch (_) {}
        try {
          context.read<WarehouseBloc>().add(LoadWarehouseData());
        } catch (_) {}
        try {
          context.read<TasksBloc>().add(const LoadTasks(forceRefresh: true));
        } catch (_) {}
        try {
          context.read<PermissionsCubit>().load();
        } catch (_) {}
      },
      child: LedgerAiAssistantHost(
        child: Scaffold(
          extendBody: true,
          body: RepaintBoundary(child: navigationShell),
          bottomNavigationBar: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: SafeArea(
              top: false,
              minimum: const EdgeInsets.only(bottom: 8),
              child: _ShellNavOverlay(navigationShell: navigationShell),
            ),
          ),
        ),
      ),
    );
  }
}

class _ShellNavOverlay extends StatelessWidget {
  const _ShellNavOverlay({required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context) {
    final userRole = context.select<AuthBloc, UserRole>((bloc) {
      final state = bloc.state;
      return state is AuthAuthenticated ? state.role : UserRole.viewer;
    });
    final permissions = context.watch<PermissionsCubit>();

    final visibleTabs = _allTabs
        .where((tab) {
          final capability = tab.capability;
          if (capability == null) return true;
          return permissions.can(
            capability,
            action: PermAction.view,
            fallbackRole: userRole,
          );
        })
        .toList(growable: false);

    var activeNavbarIndex = visibleTabs.indexWhere(
      (tab) => tab.branchIndex == navigationShell.currentIndex,
    );
    if (activeNavbarIndex == -1) activeNavbarIndex = 0;

    return _LiquidBottomNav(
      tabs: visibleTabs,
      currentIndex: activeNavbarIndex,
      onTap: (index) {
        HapticFeedback.selectionClick();
        final targetTab = visibleTabs[index];
        navigationShell.goBranch(
          targetTab.branchIndex,
          initialLocation:
              targetTab.branchIndex == navigationShell.currentIndex,
        );
      },
    );
  }
}

/// Floating frosted capsule: one sliding liquid pill, not a per-tab fill.
class _LiquidBottomNav extends StatelessWidget {
  const _LiquidBottomNav({
    required this.tabs,
    required this.currentIndex,
    required this.onTap,
  });

  final List<TabItem> tabs;
  final int currentIndex;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final language = context.watch<LanguageCubit>();
    final count = tabs.length;
    final bubbleAlign = count <= 1
        ? Alignment.center
        : Alignment(-1.0 + (2.0 * currentIndex / (count - 1)), 0);

    return Material(
      type: MaterialType.transparency,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: colors.border),
          boxShadow: [
            BoxShadow(
              color: colors.textPrimary.withValues(alpha: 0.06),
              blurRadius: 12,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: RepaintBoundary(
          child: Padding(
            padding: const EdgeInsets.all(4),
            child: SizedBox(
              height: 52,
              child: Stack(
                children: [
                  AnimatedAlign(
                    duration: const Duration(milliseconds: 420),
                    curve: Curves.easeOutCubic,
                    alignment: bubbleAlign,
                    child: FractionallySizedBox(
                      widthFactor: 1 / count,
                      heightFactor: 1,
                      child: Padding(
                        padding: const EdgeInsets.all(2),
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: colors.brand.withValues(alpha: 0.16),
                            borderRadius: BorderRadius.circular(22),
                          ),
                        ),
                      ),
                    ),
                  ),
                  Row(
                    children: [
                      for (var i = 0; i < count; i++)
                        Expanded(
                          child: _LiquidNavItem(
                            icon: tabs[i].icon,
                            label: language.translate(tabs[i].labelKey),
                            selected: i == currentIndex,
                            onTap: () => onTap(i),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _LiquidNavItem extends StatelessWidget {
  const _LiquidNavItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final textStyles = context.textStyles;
    final foreground = selected ? colors.brand : colors.textSecondary;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(22),
      splashColor: colors.brand.withValues(alpha: 0.08),
      highlightColor: Colors.transparent,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          AnimatedScale(
            scale: selected ? 1.08 : 1.0,
            duration: const Duration(milliseconds: 240),
            curve: Curves.easeOutCubic,
            child: Icon(icon, size: 22, color: foreground),
          ),
          const SizedBox(height: 2),
          AnimatedDefaultTextStyle(
            duration: const Duration(milliseconds: 240),
            curve: Curves.easeOutCubic,
            style: textStyles.smallSans.copyWith(
              fontSize: context.fontSize(11),
              fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
              color: foreground,
            ),
            child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
          ),
        ],
      ),
    );
  }
}
