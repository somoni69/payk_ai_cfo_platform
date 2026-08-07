import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_tabler_icons/flutter_tabler_icons.dart';
import 'package:go_router/go_router.dart';

import '../../../core/localization/language_cubit.dart';
import '../../../core/theme/theme_extensions.dart';
import '../../../features/auth/bloc/auth_bloc.dart';
import '../../../features/auth/bloc/auth_state.dart';
import '../../../features/auth/domain/app_access.dart';

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
    final colors = context.colors;
    final language = context.watch<LanguageCubit>();
    final authState = context.watch<AuthBloc>().state;
    final userRole = authState is AuthAuthenticated
        ? authState.role
        : UserRole.viewer;

    final visibleTabs = _allTabs
        .where((tab) {
          final capability = tab.capability;
          return capability == null || userRole.can(capability);
        })
        .toList(growable: false);

    var activeNavbarIndex = visibleTabs.indexWhere(
      (tab) => tab.branchIndex == navigationShell.currentIndex,
    );
    if (activeNavbarIndex == -1) activeNavbarIndex = 0;

    return MultiBlocProvider(
      providers: [
        BlocProvider<DashboardBloc>(
          create: (context) => DashboardBloc(context.read<FinanceRepository>())
            ..add(LoadDashboardData()),
        ),
        BlocProvider<CashBloc>(
          create: (context) => CashBloc(context.read<CashRepository>())
            ..add(LoadCashData()),
        ),
        BlocProvider<TasksBloc>(
          create: (context) => TasksBloc(context.read<TasksRepository>())
            ..add(LoadTasks()),
        ),
        BlocProvider<WarehouseBloc>(
          create: (context) => WarehouseBloc(context.read<WarehouseRepository>())
            ..add(LoadWarehouseData()),
        ),
      ],
      child: Scaffold(
        body: navigationShell,
        bottomNavigationBar: Container(
          decoration: BoxDecoration(
            border: Border(top: BorderSide(color: colors.border)),
          ),
          child: BottomNavigationBar(
            currentIndex: activeNavbarIndex,
            onTap: (index) {
              final targetTab = visibleTabs[index];
              navigationShell.goBranch(
                targetTab.branchIndex,
                initialLocation:
                    targetTab.branchIndex == navigationShell.currentIndex,
              );
            },
            items: visibleTabs
                .map((tab) {
                  return BottomNavigationBarItem(
                    icon: Icon(tab.icon),
                    activeIcon: Icon(tab.icon),
                    label: language.translate(tab.labelKey),
                  );
                })
                .toList(growable: false),
          ),
        ),
      ),
    );
  }
}
