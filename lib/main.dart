import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:payk_ai_cfo_platform/core/localization/language_cubit.dart';
import 'package:payk_ai_cfo_platform/core/routing/app_router.dart';
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

void main() {
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  late final AuthBloc _authBloc;
  late final GoRouter _router;

  @override
  void initState() {
    super.initState();
    _authBloc = AuthBloc()..add(CheckAuthStatus());
    _router = createRouter(_authBloc);
    ApiClient().onUnauthorized = () {
      _authBloc.add(LogoutRequested());
    };
  }

  @override
  void dispose() {
    _authBloc.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiRepositoryProvider(
      providers: [
        RepositoryProvider<FinanceRepository>(create: (context) => ApiFinanceRepository()),
        RepositoryProvider<CashRepository>(create: (context) => ApiCashRepository()),
        RepositoryProvider<TasksRepository>(create: (context) => ApiTasksRepository()),
        RepositoryProvider<NotificationsRepository>(create: (context) => ApiNotificationsRepository()),
        RepositoryProvider<WarehouseRepository>(create: (context) => ApiWarehouseRepository()),
        RepositoryProvider<HrRepository>(create: (context) => ApiHrRepository()),
        RepositoryProvider<CrmRepository>(create: (context) => ApiCrmRepository()),
        RepositoryProvider<StrategyRepository>(create: (context) => ApiStrategyRepository()),
        RepositoryProvider<LegalRepository>(create: (context) => ApiLegalRepository()),
        RepositoryProvider<MarketingRepository>(create: (context) => ApiMarketingRepository()),
        RepositoryProvider<IntegrationsRepository>(create: (context) => ApiIntegrationsRepository()),
        RepositoryProvider<UsersRepository>(create: (context) => ApiUsersRepository()),
      ],
      child: MultiBlocProvider(
        providers: [
          BlocProvider<AuthBloc>.value(value: _authBloc),
          BlocProvider<LanguageCubit>(create: (context) => LanguageCubit()),
        ],
        child: BlocBuilder<LanguageCubit, Locale>(
          builder: (context, locale) {
            return MaterialApp.router(
              title: 'PAYK CFO Platform',
              theme: LedgerTheme.light,
              routerConfig: _router,
              debugShowCheckedModeBanner: false,
              locale: locale,
              builder: (context, child) {
                final mediaQueryData = MediaQuery.of(context);
                final width = mediaQueryData.size.width;
                // Базовая ширина дизайна: 375 pt (iPhone 13 mini)
                // Рассчитываем коэффициент масштабирования в пределах [0.85, 1.1]
                final double scale = (width / 375.0).clamp(0.85, 1.1);

                return MediaQuery(
                  data: mediaQueryData.copyWith(
                    textScaler: TextScaler.linear(scale),
                  ),
                  child: child!,
                );
              },
            );
          },
        ),
      ),
    );
  }
}
