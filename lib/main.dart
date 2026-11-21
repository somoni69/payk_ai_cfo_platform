import 'dart:async';
import 'dart:ui';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:go_router/go_router.dart';
import 'package:payk_ai_cfo_platform/core/notifications/push_notification_service.dart';
import 'package:payk_ai_cfo_platform/core/notifications/push_token_sync.dart';
import 'package:payk_ai_cfo_platform/core/security/secure_storage_provider.dart';
import 'package:payk_ai_cfo_platform/core/observability/app_error_reporter.dart';
import 'package:payk_ai_cfo_platform/core/observability/app_bloc_observer.dart';
import 'package:payk_ai_cfo_platform/core/observability/file_error_sink.dart';
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
import 'package:payk_ai_cfo_platform/features/notifications/data/api_notifications_repository.dart';
import 'package:payk_ai_cfo_platform/core/network/api_client.dart';
import 'package:payk_ai_cfo_platform/features/permissions/cubit/permissions_cubit.dart';
import 'package:payk_ai_cfo_platform/features/permissions/data/api_permissions_repository.dart';
import 'package:payk_ai_cfo_platform/firebase_options.dart';

void main() {
  runZonedGuarded(
    () async {
      WidgetsFlutterBinding.ensureInitialized();

      // Debug: console + ring buffer. Release: ring buffer only.
      // Replace with Crashlytics/company telemetry via installSink when ready.
      AppErrorReporter.installDefaultSinks();
      unawaited(
        installFileErrorSink().catchError((Object _, StackTrace _) {
          // Local diagnostics are optional; never block startup.
        }),
      );
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

      // Do not block the first frame on secure-storage reads. Auth and chat
      // await the shared bootstrap themselves when they need the session.
      unawaited(ApiClient().bootstrap());
      if (DefaultFirebaseOptions.isSupportedPlatform) {
        try {
          if (Firebase.apps.isEmpty) {
            await Firebase.initializeApp(
              options: DefaultFirebaseOptions.currentPlatform,
            );
          }
        } catch (e) {
          if (kDebugMode) {
            debugPrint('[Firebase] Init error or skipped: $e');
          }
        }
      }
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
  const MyApp({super.key, this.pushService});

  final PushNotificationService? pushService;

  @override
  State<MyApp> createState() => _MyAppState();
}

class _PrivacyShield extends StatelessWidget {
  const _PrivacyShield();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return AbsorbPointer(
      child: ColoredBox(
        color: Theme.of(context).scaffoldBackgroundColor,
        child: Center(
          child: Image.asset(
            isDark
                ? 'assets/images/payk_white_badge.png'
                : 'assets/images/payk_logo.png',
            width: 96,
            cacheWidth: 192,
            semanticLabel: 'PAYK',
          ),
        ),
      ),
    );
  }
}

class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  late final AuthBloc _authBloc;
  late final PermissionsCubit _permissionsCubit;
  late final ChatLiveCubit _chatLive;
  late final GoRouterRefreshStream _routerRefresh;
  late final GoRouter _router;
  late final PushNotificationService _pushService;
  late final PushTokenSync _pushTokenSync;
  StreamSubscription<AuthState>? _authSub;
  var _privacyShield = false;
  String? _pendingNotificationRoute;
  var _flushNotificationScheduled = false;

  static const Set<String> _shellTabRoutes = {
    '/dashboard',
    '/cash',
    '/tasks',
    '/warehouse',
    '/more',
    '/network',
    '/leads',
    '/showcase',
    '/modules',
  };

  @override
  void initState() {
    super.initState();
    _pushService = widget.pushService ?? PushNotificationService.instance;
    _pushTokenSync = PushTokenSync(
      repository: ApiNotificationsRepository(),
      tokenProvider: _pushService.getToken,
      hasAuthToken: () async =>
          (await ApiClient().getAccessToken())?.isNotEmpty == true,
    );
    _authBloc = AuthBloc(
      authRepository: ApiAuthRepository(),
      networkRepository: ApiNetworkRepository(),
      onBeforeLogout: _pushTokenSync.unregisterBeforeLogout,
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
        unawaited(
          _pushTokenSync.onAuthenticated('${state.id ?? state.username}'),
        );
        _flushPendingNotification();
      } else if (state is AuthUnauthenticated ||
          state is AuthInitial ||
          state is AuthTwoFactorRequired) {
        _permissionsCubit.clear();
        if (state is AuthUnauthenticated || state is AuthTwoFactorRequired) {
          _pushTokenSync.onSignedOut();
          _pendingNotificationRoute = null;
        }
      }
    });

    if (!kIsWeb) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        unawaited(_initNotifications());
      });
    }

    _authBloc.add(CheckAuthStatus());
  }

  Future<void> _initNotifications() async {
    await _pushService.initialize(
      onNotificationTap: _handleNotificationTap,
      onTokenUpdate: _pushTokenSync.onTokenUpdate,
    );
  }

  void _handleNotificationTap(String route) {
    if (!mounted) return;
    final target = PushNotificationService.normalizeRoute(route);
    if (_authBloc.state is! AuthAuthenticated) {
      _pendingNotificationRoute = target;
      return;
    }
    _openNotificationRoute(target);
  }

  void _flushPendingNotification() {
    if (_pendingNotificationRoute == null ||
        _flushNotificationScheduled ||
        !mounted) {
      return;
    }
    if (_authBloc.state is! AuthAuthenticated) return;

    _flushNotificationScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _flushNotificationScheduled = false;
      if (!mounted || _authBloc.state is! AuthAuthenticated) return;
      final target = _pendingNotificationRoute;
      if (target == null) return;
      _pendingNotificationRoute = null;
      _openNotificationRoute(target);
    });
  }

  void _openNotificationRoute(String target) {
    final currentPath = _router.routerDelegate.currentConfiguration.uri.path;
    if (currentPath == target) return;
    if (_shellTabRoutes.contains(target)) {
      _router.go(target);
    } else {
      _router.push(target);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
        _setPrivacyShield(false);
        _chatLive.setForeground(true);
        _permissionsCubit.setForeground(true);
        unawaited(_pushTokenSync.retryIfNeeded());
      case AppLifecycleState.paused ||
          AppLifecycleState.hidden ||
          AppLifecycleState.detached:
        _setPrivacyShield(true);
        _chatLive.setForeground(false);
        _permissionsCubit.setForeground(false);
      case AppLifecycleState.inactive:
        _setPrivacyShield(true);
        break;
    }
  }

  void _setPrivacyShield(bool visible) {
    if (!mounted || _privacyShield == visible) return;
    setState(() => _privacyShield = visible);
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
              // Restore the saved locale asynchronously; bootstrap no longer
              // blocks the first frame.
              initialLanguageCode: null,
            ),
          ),
        ],
        child: BlocBuilder<LanguageCubit, Locale>(
          builder: (context, locale) {
            return MaterialApp.router(
              title: 'Payk Business',
              theme: LedgerTheme.light,
              darkTheme: LedgerTheme.dark,
              themeMode: ThemeMode.system,
              routerConfig: _router,
              debugShowCheckedModeBanner: false,
              builder: (context, child) {
                return Stack(
                  fit: StackFit.expand,
                  children: [
                    child ?? const SizedBox.shrink(),
                    if (_privacyShield) const _PrivacyShield(),
                  ],
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
