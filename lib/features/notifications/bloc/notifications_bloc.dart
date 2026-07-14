import 'package:flutter_bloc/flutter_bloc.dart';
import '../domain/notifications_repository.dart';
import 'notifications_event.dart';
import 'notifications_state.dart';

class NotificationsBloc extends Bloc<NotificationsEvent, NotificationsState> {
  final NotificationsRepository _repository;

  NotificationsBloc(this._repository) : super(NotificationsLoading()) {
    on<LoadNotifications>(_onLoadNotifications);
    on<MarkNotificationAsRead>(_onMarkNotificationAsRead);
  }

  void _onLoadNotifications(LoadNotifications event, Emitter<NotificationsState> emit) async {
    emit(NotificationsLoading());
    try {
      final notifications = await _repository.getNotifications();
      emit(NotificationsLoaded(notifications));
    } catch (e) {
      emit(NotificationsError('Не удалось загрузить уведомления: ${e.toString()}'));
    }
  }

  void _onMarkNotificationAsRead(MarkNotificationAsRead event, Emitter<NotificationsState> emit) async {
    if (state is! NotificationsLoaded) return;
    final currentNotifications = (state as NotificationsLoaded).notifications;

    try {
      await _repository.markAsRead(event.id);
      
      final updatedList = currentNotifications.map((n) {
        return n.id == event.id ? n.copyWith(isRead: true) : n;
      }).toList();

      emit(NotificationsLoaded(updatedList));
    } catch (e) {
      emit(NotificationsError('Ошибка отметки уведомления как прочитанного: ${e.toString()}'));
    }
  }
}
