import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_tabler_icons/flutter_tabler_icons.dart';
import 'package:go_router/go_router.dart';

import '../../../core/localization/language_cubit.dart';
import '../../../core/network/expiring_request_cache.dart';
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
import '../../../presentation/widgets/liquid_glass_split_bottom_bar.dart';

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
          create: (context) =>
              DashboardBloc(context.read<FinanceRepository>())
                ..add(const LoadDashboardData()),
        ),
        // Касса, задачи и склад грузятся, когда вкладка впервые становится
        // видимой (см. TickerMode в экранах). Иначе IndexedStack поднимает
        // все четыре модуля в один кадр и забивает сеть до первой отрисовки.
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
        // These blocs come from ShellScreen right above; PermissionsCubit is
        // app-wide. Reads cannot miss, so no guards.
        context.read<DashboardBloc>().add(
          const LoadDashboardData(forceRefresh: true, clearCache: true),
        );
        context.read<CashBloc>().add(const LoadCashData());
        context.read<WarehouseBloc>().add(LoadWarehouseData());
        context.read<TasksBloc>().add(const LoadTasks(forceRefresh: true));
        context.read<PermissionsCubit>().load();
      },
      child: LedgerAiAssistantHost(
        child: Builder(
          builder: (context) {
            final path = GoRouterState.of(context).uri.path;
            final auth = context.watch<AuthBloc>().state;
            final ownerAtRoot =
                auth is AuthAuthenticated &&
                auth.role == UserRole.owner &&
                auth.storeId == null;
            // В корне сети «Ещё» — меню настроек, а не вкладка.
            final showBar =
                !ownerAtRoot && (path == '/more' || !path.startsWith('/more/'));
            return Scaffold(
              extendBody: true,
              body: RepaintBoundary(child: navigationShell),
              bottomNavigationBar: showBar
                  ? Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                      child: SafeArea(
                        top: false,
                        child: _ShellNavOverlay(
                          navigationShell: navigationShell,
                        ),
                      ),
                    )
                  : null,
            );
          },
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
    final storeId = context.select<AuthBloc, int?>((bloc) {
      final state = bloc.state;
      return state is AuthAuthenticated ? state.storeId : null;
    });
    final ownerAtRoot = userRole == UserRole.owner && storeId == null;
    final permissions = context.watch<PermissionsCubit>();

    final visibleTabs = _allTabs
        .where((tab) {
          final capability = tab.capability;
          if (ownerAtRoot && capability != null) return false;
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

    final language = context.watch<LanguageCubit>();
    // No shell-wide scanner action exists (the scanner returns a code into a
    // field on Cash / Warehouse), so the round side button is omitted.
    return LiquidGlassSplitBottomBar(
      items: [
        for (final tab in visibleTabs)
          LiquidGlassBarItem(
            icon: tab.icon,
            label: language.translate(tab.labelKey),
          ),
      ],
      selectedIndex: activeNavbarIndex,
      onSelected: (index) {
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
