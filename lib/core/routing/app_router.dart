import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../features/auth/bloc/auth_bloc.dart';
import '../../features/auth/bloc/auth_state.dart';
import '../../features/auth/domain/app_access.dart';
import '../../features/auth/presentation/login_screen.dart';
import '../../features/permissions/cubit/permissions_cubit.dart';
import '../../features/audit/presentation/audit_screen.dart';
import '../../features/branches/presentation/branches_screen.dart';
import '../../features/cash/presentation/cash_screen.dart';
import '../../features/checklists/presentation/checklists_screen.dart';
import '../../features/crm/presentation/crm_screen.dart';
import '../../features/dashboard/presentation/dashboard_screen.dart';
import '../../features/fin_ops/presentation/fin_ops_screen.dart';
import '../../features/hr/presentation/hr_screen.dart';
import '../../features/integrations/presentation/integrations_screen.dart';
import '../../features/legal/presentation/legal_screen.dart';
import '../../features/marketing/presentation/marketing_screen.dart';
import '../../features/meta/presentation/meta_screen.dart';
import '../../features/network/presentation/network_screen.dart';
import '../../features/notifications/presentation/inbox_screen.dart';
import '../../features/notifications/presentation/notifications_screen.dart';
import '../../features/reports/presentation/reports_screen.dart';
import '../../features/shell/presentation/more_screen.dart';
import '../../features/shell/presentation/shell_screen.dart';
import '../../features/strategy/presentation/strategy_screen.dart';
import '../../features/system/presentation/backups_screen.dart';
import '../../features/tasks/presentation/tasks_screen.dart';
import '../../features/users/presentation/users_screen.dart';
import '../../features/warehouse/presentation/warehouse_screen.dart';

final GlobalKey<NavigatorState> _rootNavigatorKey = GlobalKey<NavigatorState>(
  debugLabel: 'root',
);
final GlobalKey<NavigatorState> _dashboardNavigatorKey =
    GlobalKey<NavigatorState>(debugLabel: 'dashboard');
final GlobalKey<NavigatorState> _cashNavigatorKey = GlobalKey<NavigatorState>(
  debugLabel: 'cash',
);
final GlobalKey<NavigatorState> _tasksNavigatorKey = GlobalKey<NavigatorState>(
  debugLabel: 'tasks',
);
final GlobalKey<NavigatorState> _warehouseNavigatorKey =
    GlobalKey<NavigatorState>(debugLabel: 'warehouse');
final GlobalKey<NavigatorState> _moreNavigatorKey = GlobalKey<NavigatorState>(
  debugLabel: 'more',
);

/// Фабрика роутера с внедрением состояния [AuthBloc].
///
/// Настраивает авто-редиректы при смене состояния авторизации.
/// Optional [permissions] enables `GET /permissions/me` for route guards.
GoRouter createRouter(
  AuthBloc authBloc, {
  required Listenable refreshListenable,
  PermissionsCubit? permissions,
}) {
  return GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: '/splash',
    refreshListenable: refreshListenable,
    redirect: (context, state) {
      final authState = authBloc.state;
      final location = state.matchedLocation;
      final isLoggingIn = location == '/login';
      final isBootstrapping = location == '/splash';

      if (authState is AuthInitial) {
        return isBootstrapping ? null : '/splash';
      }

      // Keep the current page while login/logout is actively being processed.
      if (authState is AuthLoading) {
        return null;
      }

      // Password ok, waiting for SMS code — stay on the login route.
      if (authState is AuthTwoFactorRequired) {
        return isLoggingIn ? null : '/login';
      }

      if (authState is AuthUnauthenticated || authState is AuthError) {
        return isLoggingIn ? null : '/login';
      }

      if (authState is AuthAuthenticated) {
        final landingLocation = authState.role.landingLocation;
        if (isLoggingIn || isBootstrapping) {
          return landingLocation;
        }

        final effective = permissions?.state.data;
        if (!AppAccess.canOpenEffective(
          authState.role,
          location,
          effective: effective,
        )) {
          return landingLocation;
        }
      }

      return null;
    },
    routes: [
      GoRoute(
        path: '/splash',
        builder: (context, state) => const _BootstrapScreen(),
      ),

      // Вход в систему (MOB-05)
      GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),

      // Сеть магазинов «Пайк» (Multistore Root)
      GoRoute(
        path: '/network',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const NetworkScreen(),
      ),

      // Предупреждения / Инфо (MOB-04)
      GoRoute(
        path: '/notifications',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const NotificationsScreen(),
      ),

      GoRoute(
        path: '/inbox',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const InboxScreen(),
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

      // Чаты Meta (Facebook / Instagram / WhatsApp) — под правом CRM
      GoRoute(
        path: '/meta',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const MetaScreen(),
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

      GoRoute(
        path: '/backups',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const BackupsScreen(),
      ),

      // Управление доступом (SYS-02...07)
      GoRoute(
        path: '/users',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const UsersScreen(),
      ),

      // Филиалы и точки
      GoRoute(
        path: '/branches',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const BranchesScreen(),
      ),

      // Операционные чек-листы
      GoRoute(
        path: '/checklists',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const ChecklistsScreen(),
      ),

      // Финансовые операции
      GoRoute(
        path: '/fin-ops',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const FinOpsScreen(),
      ),

      // Финансовые отчеты
      GoRoute(
        path: '/reports',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const ReportsScreen(),
      ),

      // Аудит решений и безопасность
      GoRoute(
        path: '/audit',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const AuditScreen(),
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

class _BootstrapScreen extends StatelessWidget {
  const _BootstrapScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: SizedBox.square(
          dimension: 28,
          child: CircularProgressIndicator(strokeWidth: 2.5),
        ),
      ),
    );
  }
}
