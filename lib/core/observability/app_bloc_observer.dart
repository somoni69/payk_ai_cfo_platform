import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'app_error_reporter.dart';

/// Global BlocObserver routing state transitions and unhandled bloc errors
/// into [AppErrorReporter] telemetry while providing safe debug logging.
class AppBlocObserver extends BlocObserver {
  @override
  void onEvent(Bloc bloc, Object? event) {
    super.onEvent(bloc, event);
    if (kDebugMode) {
      debugPrint('[BlocEvent] ${bloc.runtimeType} -> ${event.runtimeType}');
    }
  }

  @override
  void onChange(BlocBase bloc, Change change) {
    super.onChange(bloc, change);
    if (kDebugMode) {
      debugPrint(
        '[BlocChange] ${bloc.runtimeType} -> ${change.nextState.runtimeType}',
      );
    }
  }

  @override
  void onTransition(Bloc bloc, Transition transition) {
    super.onTransition(bloc, transition);
    if (kDebugMode) {
      debugPrint(
        '[BlocTransition] ${bloc.runtimeType} Event: ${transition.event.runtimeType} -> NextState: ${transition.nextState.runtimeType}',
      );
    }
  }

  @override
  void onError(BlocBase bloc, Object error, StackTrace stackTrace) {
    AppErrorReporter.capture(
      error,
      stackTrace,
      context: 'bloc:${bloc.runtimeType}',
    );
    super.onError(bloc, error, stackTrace);
  }
}
