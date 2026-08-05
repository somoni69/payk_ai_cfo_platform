import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:go_router/go_router.dart';
import 'package:payk_ai_cfo_platform/core/observability/app_error_reporter.dart';
import 'package:payk_ai_cfo_platform/core/di/app_repositories.dart';
import 'package:payk_ai_cfo_platform/core/localization/language_cubit.dart';
import 'package:payk_ai_cfo_platform/core/localization/tajik_cupertino_localizations.dart';
import 'package:payk_ai_cfo_platform/core/localization/tajik_material_localizations.dart';
import 'package:payk_ai_cfo_platform/core/routing/app_router.dart';
import 'package:payk_ai_cfo_platform/core/routing/go_router_refresh_stream.dart';
import 'package:payk_ai_cfo_platform/core/theme/app_theme.dart';
import 'package:payk_ai_cfo_platform/features/auth/bloc/auth_bloc.dart';
import 'package:payk_ai_cfo_platform/features/auth/bloc/auth_event.dart';
import 'package:payk_ai_cfo_platform/core/network/api_client.dart';

void main() {
  runZonedGuarded(
    () async {
      WidgetsFlutterBinding.ensureInitialized();

      // Debug: console + ring buffer. Release: ring buffer only.
      // Replace with Crashlytics/company telemetry via installSink when ready.
      AppErrorReporter.installDefaultSinks();

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
    return AppRepositories.multiProvider(
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
