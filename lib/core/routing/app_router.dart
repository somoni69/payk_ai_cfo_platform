import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'go_router_refresh_stream.dart';
import '../../features/auth/bloc/auth_bloc.dart';
import '../../features/auth/bloc/auth_state.dart';
import '../../presentation/screens/dashboard_screen.dart';
import '../../presentation/screens/cash_screen.dart';
import '../../presentation/screens/tasks_screen.dart';
import '../../presentation/screens/notifications_screen.dart';
import '../../presentation/screens/more_screen.dart';
import '../../presentation/screens/shell_screen.dart';
import '../../presentation/screens/login_screen.dart';
import '../../presentation/screens/warehouse_screen.dart';
import '../../presentation/screens/hr_screen.dart';
import '../../presentation/screens/crm_screen.dart';
import '../../presentation/screens/strategy_screen.dart';
import '../../presentation/screens/legal_screen.dart';
import '../../presentation/screens/marketing_screen.dart';
import '../../presentation/screens/integrations_screen.dart';
import '../../presentation/screens/users_screen.dart';

final GlobalKey<NavigatorState> _rootNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'root');
final GlobalKey<NavigatorState> _dashboardNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'dashboard');
final GlobalKey<NavigatorState> _cashNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'cash');
final GlobalKey<NavigatorState> _tasksNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'tasks');
final GlobalKey<NavigatorState> _warehouseNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'warehouse');
final GlobalKey<NavigatorState> _moreNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'more');

/// Фабрика роутера с внедрением состояния [AuthBloc].
///
/// Настраивает авто-редиректы при смене состояния авторизации.
GoRouter createRouter(AuthBloc authBloc) {
  return GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: '/login',
    refreshListenable: GoRouterRefreshStream(authBloc.stream),
    redirect: (context, state) {
      final authState = authBloc.state;
      final isLoggingIn = state.matchedLocation == '/login';

      // Если не авторизован, отправляем на логин
      if (authState is AuthUnauthenticated || authState is AuthInitial) {
        return '/login';
      }

      // Если авторизован и находится на странице входа, редиректим на дашборд
      if (authState is AuthAuthenticated) {
        if (isLoggingIn) {
          return '/dashboard';
        }
      }

      return null;
    },
    routes: [
      // Вход в систему (MOB-05)
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),

      // Предупреждения / Инфо (MOB-04)
      GoRoute(
        path: '/notifications',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const NotificationsScreen(),
      ),

      // Кадры и KPI (Спринт 9.2)
      GoRoute(
        path: '/hr',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const HrScreen(),
      ),

      // Сделки и Лиды (Спринт 9.3)
      GoRoute(
        path: '/crm',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const CrmScreen(),
      ),

      // Стратегия What-if и ИИ-Маркетинг (Спринт 9.4)
      GoRoute(
        path: '/strategy',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const StrategyScreen(),
      ),

      // База законов РТ и ИИ-Юрист (Спринт 9.5)
      GoRoute(
        path: '/legal',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const LegalScreen(),
      ),

      // AI-Маркетинг и Соцсети (MKT-01 / MKT-06)
      GoRoute(
        path: '/marketing',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const MarketingScreen(),
      ),

      // Внешние интеграции (INT-01 / INT-03)
      GoRoute(
        path: '/integrations',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const IntegrationsScreen(),
      ),

      // Управление доступом (SYS-02...07)
      GoRoute(
        path: '/users',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const UsersScreen(),
      ),

      // Основная оболочка приложения с BottomNavigationBar (Stateful Navigation)
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return ShellScreen(navigationShell: navigationShell);
        },
        branches: [
          // Таб 1: Панель аналитики (MOB-01)
          StatefulShellBranch(
            navigatorKey: _dashboardNavigatorKey,
            routes: [
              GoRoute(
                path: '/dashboard',
                builder: (context, state) => const DashboardScreen(),
              ),
            ],
          ),
          // Таб 2: Кассовые операции (MOB-02)
          StatefulShellBranch(
            navigatorKey: _cashNavigatorKey,
            routes: [
              GoRoute(
                path: '/cash',
                builder: (context, state) => const CashScreen(),
              ),
            ],
          ),
          // Таб 3: Задачи (MOB-03)
          StatefulShellBranch(
            navigatorKey: _tasksNavigatorKey,
            routes: [
              GoRoute(
                path: '/tasks',
                builder: (context, state) => const TasksScreen(),
              ),
            ],
          ),
          // Таб 4: Складской учет (Спринт 9.1)
          StatefulShellBranch(
            navigatorKey: _warehouseNavigatorKey,
            routes: [
              GoRoute(
                path: '/warehouse',
                builder: (context, state) => const WarehouseScreen(),
              ),
            ],
          ),
          // Таб 5: Настройки / Разное
          StatefulShellBranch(
            navigatorKey: _moreNavigatorKey,
            routes: [
              GoRoute(
                path: '/more',
                builder: (context, state) => const MoreScreen(),
              ),
            ],
          ),
        ],
      ),
    ],
  );
}
