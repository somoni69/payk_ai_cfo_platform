import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:go_router/go_router.dart';
import 'package:payk_ai_cfo_platform/core/security/secure_storage_provider.dart';
import 'package:payk_ai_cfo_platform/core/observability/app_error_reporter.dart';
import 'package:payk_ai_cfo_platform/core/observability/app_bloc_observer.dart';
import 'package:payk_ai_cfo_platform/core/di/app_repositories.dart';
import 'package:payk_ai_cfo_platform/core/localization/language_cubit.dart';
import 'package:payk_ai_cfo_platform/core/localization/tajik_cupertino_localizations.dart';
import 'package:payk_ai_cfo_platform/core/localization/tajik_material_localizations.dart';
import 'package:payk_ai_cfo_platform/core/routing/app_router.dart';
import 'package:payk_ai_cfo_platform/core/routing/go_router_refresh_stream.dart';
import 'package:payk_ai_cfo_platform/core/theme/app_theme.dart';
import 'package:payk_ai_cfo_platform/features/auth/bloc/auth_bloc.dart';
import 'package:payk_ai_cfo_platform/features/auth/bloc/auth_event.dart';
import 'package:payk_ai_cfo_platform/features/auth/bloc/auth_state.dart';
import 'package:payk_ai_cfo_platform/features/auth/data/api_auth_repository.dart';
import 'package:payk_ai_cfo_platform/features/meta/cubit/chat_live_cubit.dart';
import 'package:payk_ai_cfo_platform/features/meta/data/api_meta_repository.dart';
import 'package:payk_ai_cfo_platform/features/meta/data/chat_live_client.dart';
import 'package:payk_ai_cfo_platform/features/network/data/api_network_repository.dart';
import 'package:payk_ai_cfo_platform/core/network/api_client.dart';
import 'package:payk_ai_cfo_platform/features/permissions/cubit/permissions_cubit.dart';
import 'package:payk_ai_cfo_platform/features/permissions/data/api_permissions_repository.dart';

void main() {
  runZonedGuarded(
    () async {
      WidgetsFlutterBinding.ensureInitialized();

      // Debug: console + ring buffer. Release: ring buffer only.
      // Replace with Crashlytics/company telemetry via installSink when ready.
      AppErrorReporter.installDefaultSinks();
      Bloc.observer = AppBlocObserver();

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

class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  late final AuthBloc _authBloc;
  late final PermissionsCubit _permissionsCubit;
  late final ChatLiveCubit _chatLive;
  late final GoRouterRefreshStream _routerRefresh;
  late final GoRouter _router;
  StreamSubscription<AuthState>? _authSub;

  @override
  void initState() {
    super.initState();
    _authBloc = AuthBloc(
      authRepository: ApiAuthRepository(),
      networkRepository: ApiNetworkRepository(),
    );
    _permissionsCubit = PermissionsCubit(ApiPermissionsRepository());
    // One chat socket for the app: «Ещё» badge and the open chat share it.
    _chatLive = ChatLiveCubit(
      repository: ApiMetaRepository(),
      client: ChatLiveClient(
        url: chatSocketUri(),
        token: ApiClient().getAccessToken,
      ),
    );
    WidgetsBinding.instance.addObserver(this);
    _routerRefresh = GoRouterRefreshStream.merge([
      _authBloc.stream,
      _permissionsCubit.stream,
    ]);
    _router = createRouter(
      _authBloc,
      refreshListenable: _routerRefresh,
      permissions: _permissionsCubit,
    );
    ApiClient().onUnauthorized = () {
      _authBloc.add(LogoutRequested());
    };
    _authSub = _authBloc.stream.listen((state) {
      final storeId = state is AuthAuthenticated ? state.storeId : null;
      if (storeId != null) {
        _chatLive.activate(storeId);
      } else {
        _chatLive.deactivate();
      }
      if (state is AuthAuthenticated) {
        unawaited(
          _permissionsCubit.load().then((_) {
            _permissionsCubit.startPolling();
          }),
        );
      } else if (state is AuthUnauthenticated ||
          state is AuthInitial ||
          state is AuthTwoFactorRequired) {
        _permissionsCubit.clear();
      }
    });

    _authBloc.add(CheckAuthStatus());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
        _chatLive.setForeground(true);
        _permissionsCubit.setForeground(true);
      case AppLifecycleState.paused ||
          AppLifecycleState.hidden ||
          AppLifecycleState.detached:
        _chatLive.setForeground(false);
        _permissionsCubit.setForeground(false);
      case AppLifecycleState.inactive:
        break;
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    unawaited(_chatLive.close());
    ApiClient().onUnauthorized = null;
    unawaited(_authSub?.cancel() ?? Future<void>.value());
    _router.dispose();
    _routerRefresh.dispose();
    unawaited(_permissionsCubit.close());
    unawaited(_authBloc.close());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppRepositories.multiProvider(
      child: MultiBlocProvider(
        providers: [
          BlocProvider<AuthBloc>.value(value: _authBloc),
          BlocProvider<PermissionsCubit>.value(value: _permissionsCubit),
          BlocProvider<ChatLiveCubit>.value(value: _chatLive),
          BlocProvider<LanguageCubit>(
            create: (context) => LanguageCubit(
              storage: AppSecureStorage.instance,
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
              builder: (context, child) {
                final mq = MediaQuery.of(context);
                return MediaQuery(
                  data: mq.copyWith(
                    textScaler: mq.textScaler.clamp(
                      minScaleFactor: 0.9,
                      maxScaleFactor: 1.15,
                    ),
                  ),
                  child: child ?? const SizedBox.shrink(),
                );
              },
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
