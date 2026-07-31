import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:go_router/go_router.dart';
import 'package:payk_ai_cfo_platform/core/observability/app_error_reporter.dart';
import 'package:payk_ai_cfo_platform/core/localization/language_cubit.dart';
import 'package:payk_ai_cfo_platform/core/localization/tajik_cupertino_localizations.dart';
import 'package:payk_ai_cfo_platform/core/localization/tajik_material_localizations.dart';
import 'package:payk_ai_cfo_platform/core/routing/app_router.dart';
import 'package:payk_ai_cfo_platform/core/routing/go_router_refresh_stream.dart';
import 'package:payk_ai_cfo_platform/core/theme/app_theme.dart';
import 'package:payk_ai_cfo_platform/features/auth/bloc/auth_bloc.dart';
import 'package:payk_ai_cfo_platform/features/auth/bloc/auth_event.dart';
import 'package:payk_ai_cfo_platform/features/dashboard/domain/finance_repository.dart';
import 'package:payk_ai_cfo_platform/features/dashboard/data/api_finance_repository.dart';
import 'package:payk_ai_cfo_platform/features/cash/domain/cash_repository.dart';
import 'package:payk_ai_cfo_platform/features/cash/data/api_cash_repository.dart';
import 'package:payk_ai_cfo_platform/features/tasks/domain/tasks_repository.dart';
import 'package:payk_ai_cfo_platform/features/tasks/data/api_tasks_repository.dart';
import 'package:payk_ai_cfo_platform/features/notifications/domain/notifications_repository.dart';
import 'package:payk_ai_cfo_platform/features/notifications/data/api_notifications_repository.dart';

import 'package:payk_ai_cfo_platform/core/network/api_client.dart';
import 'package:payk_ai_cfo_platform/features/warehouse/domain/warehouse_repository.dart';
import 'package:payk_ai_cfo_platform/features/warehouse/data/api_warehouse_repository.dart';
import 'package:payk_ai_cfo_platform/features/hr/domain/hr_repository.dart';
import 'package:payk_ai_cfo_platform/features/hr/data/api_hr_repository.dart';
import 'package:payk_ai_cfo_platform/features/crm/domain/crm_repository.dart';
import 'package:payk_ai_cfo_platform/features/crm/data/api_crm_repository.dart';
import 'package:payk_ai_cfo_platform/features/strategy/domain/strategy_repository.dart';
import 'package:payk_ai_cfo_platform/features/strategy/data/api_strategy_repository.dart';
import 'package:payk_ai_cfo_platform/features/legal/domain/legal_repository.dart';
import 'package:payk_ai_cfo_platform/features/legal/data/api_legal_repository.dart';
import 'package:payk_ai_cfo_platform/features/marketing/domain/marketing_repository.dart';
import 'package:payk_ai_cfo_platform/features/marketing/data/api_marketing_repository.dart';
import 'package:payk_ai_cfo_platform/features/integrations/domain/integrations_repository.dart';
import 'package:payk_ai_cfo_platform/features/integrations/data/api_integrations_repository.dart';
import 'package:payk_ai_cfo_platform/features/users/domain/users_repository.dart';
import 'package:payk_ai_cfo_platform/features/users/data/api_users_repository.dart';
import 'package:payk_ai_cfo_platform/features/branches/domain/branches_repository.dart';
import 'package:payk_ai_cfo_platform/features/branches/data/api_branches_repository.dart';
import 'package:payk_ai_cfo_platform/features/checklists/domain/checklists_repository.dart';
import 'package:payk_ai_cfo_platform/features/checklists/data/api_checklists_repository.dart';
import 'package:payk_ai_cfo_platform/features/fin_ops/domain/fin_ops_repository.dart';
import 'package:payk_ai_cfo_platform/features/fin_ops/data/api_fin_ops_repository.dart';
import 'package:payk_ai_cfo_platform/features/reports/domain/reports_repository.dart';
import 'package:payk_ai_cfo_platform/features/reports/data/api_reports_repository.dart';
import 'package:payk_ai_cfo_platform/features/audit/domain/audit_repository.dart';
import 'package:payk_ai_cfo_platform/features/audit/data/api_audit_repository.dart';

void main() {
  runZonedGuarded(
    () async {
      WidgetsFlutterBinding.ensureInitialized();

      FlutterError.onError = (details) {
        FlutterError.presentError(details);
        unawaited(AppErrorReporter.captureFlutterError(details));
      };
      PlatformDispatcher.instance.onError = (error, stackTrace) {
        unawaited(
          AppErrorReporter.capture(
            error,
            stackTrace,
            context: 'platform-dispatcher',
          ),
        );
        return true;
      };

      await ApiClient().bootstrap();
      runApp(const MyApp());
    },
    (error, stackTrace) {
      unawaited(
        AppErrorReporter.capture(error, stackTrace, context: 'root-zone'),
      );
    },
  );
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  late final AuthBloc _authBloc;
  late final GoRouterRefreshStream _routerRefresh;
  late final GoRouter _router;

  @override
  void initState() {
    super.initState();
    _authBloc = AuthBloc();
    _routerRefresh = GoRouterRefreshStream(_authBloc.stream);
    _router = createRouter(_authBloc, refreshListenable: _routerRefresh);
    ApiClient().onUnauthorized = () {
      _authBloc.add(LogoutRequested());
    };
    _authBloc.add(CheckAuthStatus());
  }

  @override
  void dispose() {
    ApiClient().onUnauthorized = null;
    _router.dispose();
    _routerRefresh.dispose();
    unawaited(_authBloc.close());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiRepositoryProvider(
      providers: [
        RepositoryProvider<FinanceRepository>(
          create: (context) => ApiFinanceRepository(),
        ),
        RepositoryProvider<CashRepository>(
          create: (context) => ApiCashRepository(),
        ),
        RepositoryProvider<TasksRepository>(
          create: (context) => ApiTasksRepository(),
        ),
        RepositoryProvider<NotificationsRepository>(
          create: (context) => ApiNotificationsRepository(),
        ),
        RepositoryProvider<WarehouseRepository>(
          create: (context) => ApiWarehouseRepository(),
        ),
        RepositoryProvider<HrRepository>(
          create: (context) => ApiHrRepository(),
        ),
        RepositoryProvider<CrmRepository>(
          create: (context) => ApiCrmRepository(),
        ),
        RepositoryProvider<StrategyRepository>(
          create: (context) => ApiStrategyRepository(),
        ),
        RepositoryProvider<LegalRepository>(
          create: (context) => ApiLegalRepository(),
        ),
        RepositoryProvider<MarketingRepository>(
          create: (context) => ApiMarketingRepository(),
        ),
        RepositoryProvider<IntegrationsRepository>(
          create: (context) => ApiIntegrationsRepository(),
        ),
        RepositoryProvider<UsersRepository>(
          create: (context) => ApiUsersRepository(),
        ),
        RepositoryProvider<BranchesRepository>(
          create: (context) => ApiBranchesRepository(),
        ),
        RepositoryProvider<ChecklistsRepository>(
          create: (context) => ApiChecklistsRepository(),
        ),
        RepositoryProvider<FinOpsRepository>(
          create: (context) => ApiFinOpsRepository(),
        ),
        RepositoryProvider<ReportsRepository>(
          create: (context) => ApiReportsRepository(),
        ),
        RepositoryProvider<AuditRepository>(
          create: (context) => ApiAuditRepository(),
        ),
      ],
      child: MultiBlocProvider(
        providers: [
          BlocProvider<AuthBloc>.value(value: _authBloc),
          BlocProvider<LanguageCubit>(
            create: (context) => LanguageCubit(
              storage: const FlutterSecureStorage(),
              initialLanguageCode: ApiClient().interfaceLanguage,
            ),
          ),
        ],
        child: BlocBuilder<LanguageCubit, Locale>(
          builder: (context, locale) {
            return MaterialApp.router(
              title: 'PAYK CFO Platform',
              theme: LedgerTheme.light,
              routerConfig: _router,
              debugShowCheckedModeBanner: false,
              locale: locale,
              supportedLocales: const [Locale('ru'), Locale('tg')],
              localizationsDelegates: const [
                TajikMaterialLocalizationsDelegate(),
                TajikCupertinoLocalizationsDelegate(),
                GlobalMaterialLocalizations.delegate,
                GlobalWidgetsLocalizations.delegate,
                GlobalCupertinoLocalizations.delegate,
              ],
            );
          },
        ),
      ),
    );
  }
}
