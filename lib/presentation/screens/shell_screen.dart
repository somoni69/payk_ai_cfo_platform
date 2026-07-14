import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_tabler_icons/flutter_tabler_icons.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/theme_extensions.dart';
import '../../features/auth/bloc/auth_bloc.dart';
import '../../features/auth/bloc/auth_state.dart';

class TabItem {
  final int branchIndex;
  final IconData icon;
  final String label;
  final List<UserRole> permittedRoles;

  const TabItem({
    required this.branchIndex,
    required this.icon,
    required this.label,
    required this.permittedRoles,
  });
}

/// Все доступные вкладки и правила разграничения доступа согласно ТЗ.
final List<TabItem> _allTabs = [
  const TabItem(
    branchIndex: 0,
    icon: TablerIcons.layout_dashboard,
    label: 'Панель',
    permittedRoles: [UserRole.director, UserRole.manager, UserRole.accountant, UserRole.viewer],
  ),
  const TabItem(
    branchIndex: 1,
    icon: TablerIcons.wallet,
    label: 'Касса',
    permittedRoles: [UserRole.director, UserRole.manager, UserRole.accountant, UserRole.cashier],
  ),
  const TabItem(
    branchIndex: 2,
    icon: TablerIcons.checkbox,
    label: 'Задачи',
    permittedRoles: [UserRole.director, UserRole.manager, UserRole.hr],
  ),
  const TabItem(
    branchIndex: 3,
    icon: TablerIcons.package,
    label: 'Склад',
    permittedRoles: [UserRole.director, UserRole.manager, UserRole.accountant],
  ),
  const TabItem(
    branchIndex: 4,
    icon: TablerIcons.menu_2,
    label: 'Еще',
    permittedRoles: UserRole.values, // Доступно всем
  ),
];

class ShellScreen extends StatelessWidget {
  final StatefulNavigationShell navigationShell;

  const ShellScreen({
    super.key,
    required this.navigationShell,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    // Считываем текущую роль
    final authState = context.watch<AuthBloc>().state;
    final userRole = authState is AuthAuthenticated ? authState.role : UserRole.viewer;

    // Фильтруем вкладки под роль пользователя
    final visibleTabs = _allTabs.where((tab) => tab.permittedRoles.contains(userRole)).toList();

    // Находим текущий индекс в отфильтрованном списке
    int activeNavbarIndex = visibleTabs.indexWhere(
      (tab) => tab.branchIndex == navigationShell.currentIndex,
    );
    if (activeNavbarIndex == -1) {
      activeNavbarIndex = 0;
    }

    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          border: Border(
            top: BorderSide(color: colors.border, width: 1.0),
          ),
        ),
        child: BottomNavigationBar(
          currentIndex: activeNavbarIndex,
          onTap: (index) {
            final targetTab = visibleTabs[index];
            navigationShell.goBranch(
              targetTab.branchIndex,
              initialLocation: targetTab.branchIndex == navigationShell.currentIndex,
            );
          },
          items: visibleTabs.map((tab) {
            return BottomNavigationBarItem(
              icon: Icon(tab.icon),
              activeIcon: Icon(tab.icon),
              label: tab.label,
            );
          }).toList(),
        ),
      ),
    );
  }
}
