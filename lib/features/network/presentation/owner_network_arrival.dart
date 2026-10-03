import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/network/expiring_request_cache.dart';
import '../../auth/bloc/auth_bloc.dart';
import '../../auth/bloc/auth_event.dart';
import '../../auth/bloc/auth_state.dart';
import '../domain/network_repository.dart';

/// Приход на «Сеть» или «Заявки» выводит владельца из магазина.
///
/// Выход срабатывает один раз, в момент открытия экрана. «Войти в магазин»
/// на уже открытой «Сети» магазин не сбрасывает: выбор появляется раньше,
/// чем сменится адрес.
Future<void> leaveOwnerStoreOnNetworkArrival(BuildContext context) async {
  final auth = context.read<AuthBloc>().state;
  if (auth is! AuthAuthenticated ||
      auth.role != UserRole.owner ||
      auth.storeId == null) {
    return;
  }
  try {
    await context.read<NetworkRepository>().leaveStore();
  } catch (_) {
    return;
  }
  if (!context.mounted) return;
  ExpiringRequestCache.invalidateAll();
  context.read<AuthBloc>().add(const ActingStoreUpdated());
}
