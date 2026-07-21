import 'package:flutter_bloc/flutter_bloc.dart';
import '../domain/notification_model.dart';
import '../domain/notifications_repository.dart';
import 'notifications_event.dart';
import 'notifications_state.dart';

class NotificationsBloc extends Bloc<NotificationsEvent, NotificationsState> {
  final NotificationsRepository _repository;
  Future<List<AppNotification>>? _loadRequest;
  bool _loadRequestIsRefresh = false;
  final Set<String> _confirmedReadIds = {};
  final Set<String> _markRequests = {};

  NotificationsBloc(this._repository) : super(NotificationsLoading()) {
    on<LoadNotifications>(_onLoadNotifications);
    on<MarkNotificationAsRead>(_onMarkNotificationAsRead);
  }

  Future<void> _onLoadNotifications(
    LoadNotifications event,
    Emitter<NotificationsState> emit,
  ) async {
    final previous = state is NotificationsLoaded
        ? state as NotificationsLoaded
        : null;
    var request = _loadRequest;
    final shouldSupersede =
        event.forceRefresh && request != null && !_loadRequestIsRefresh;
    final ownsRequest = request == null || shouldSupersede;

    if (ownsRequest) {
      if (previous == null && request == null) {
        emit(NotificationsLoading());
      }
      request = event.forceRefresh
          ? _repository.refreshNotifications()
          : _repository.getNotifications();
      _loadRequest = request;
      _loadRequestIsRefresh = event.forceRefresh;
    }
    final activeRequest = request;

    try {
      final notifications = await activeRequest;
      if (!ownsRequest || emit.isDone || !identical(_loadRequest, activeRequest)) return;
      emit(NotificationsLoaded(_reconcileConfirmedReads(notifications)));
    } catch (_) {
      if (!ownsRequest || emit.isDone || !identical(_loadRequest, activeRequest)) return;
      const message = 'Не удалось загрузить уведомления. Проверьте соединение.';
      if (previous != null) {
        emit(previous.copyWith(errorMessage: message));
      } else {
        emit(const NotificationsError(message));
      }
    } finally {
      if (ownsRequest && identical(_loadRequest, activeRequest)) {
        _loadRequest = null;
        _loadRequestIsRefresh = false;
      }
      final completion = event.completion;
      if (completion != null && !completion.isCompleted) {
        completion.complete();
      }
    }
  }

  List<AppNotification> _reconcileConfirmedReads(
    List<AppNotification> notifications,
  ) {
    return notifications.map((notification) {
      if (_confirmedReadIds.contains(notification.id) && !notification.isRead) {
        return notification.copyWith(isRead: true);
      }
      return notification;
    }).toList(growable: false);
  }

  Future<void> _onMarkNotificationAsRead(
    MarkNotificationAsRead event,
    Emitter<NotificationsState> emit,
  ) async {
    if (state is! NotificationsLoaded) return;
    if (!_markRequests.add(event.id)) return;

    try {
      await _repository.markAsRead(event.id);
      _confirmedReadIds.add(event.id);
      if (emit.isDone || state is! NotificationsLoaded) return;
      final current = state as NotificationsLoaded;

      final updatedList = current.notifications.map((notification) {
        return notification.id == event.id
            ? notification.copyWith(isRead: true)
            : notification;
      }).toList(growable: false);

      emit(current.copyWith(notifications: updatedList, clearError: true));
    } catch (_) {
      if (emit.isDone) return;
      final current = state is NotificationsLoaded
          ? state as NotificationsLoaded
          : null;
      if (current == null) return;
      emit(
        current.copyWith(
          errorMessage:
              'Не удалось отметить уведомление прочитанным. Повторите попытку.',
        ),
      );
    } finally {
      _markRequests.remove(event.id);
    }
  }
}
