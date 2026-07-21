import 'package:equatable/equatable.dart';
import '../domain/notification_model.dart';

abstract class NotificationsState extends Equatable {
  const NotificationsState();

  @override
  List<Object?> get props => [];
}

class NotificationsLoading extends NotificationsState {}

class NotificationsLoaded extends NotificationsState {
  final List<AppNotification> notifications;
  final String? errorMessage;

  const NotificationsLoaded(this.notifications, {this.errorMessage});

  NotificationsLoaded copyWith({
    List<AppNotification>? notifications,
    String? errorMessage,
    bool clearError = false,
  }) {
    return NotificationsLoaded(
      notifications ?? this.notifications,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }

  @override
  List<Object?> get props => [notifications, errorMessage];
}

class NotificationsError extends NotificationsState {
  final String message;

  const NotificationsError(this.message);

  @override
  List<Object?> get props => [message];
}
