import 'dart:async';

import 'package:equatable/equatable.dart';

abstract class NotificationsEvent extends Equatable {
  const NotificationsEvent();

  @override
  List<Object?> get props => [];
}

class LoadNotifications extends NotificationsEvent {
  final bool forceRefresh;
  final Completer<void>? completion;

  const LoadNotifications({this.forceRefresh = false, this.completion});

  @override
  List<Object?> get props => [forceRefresh];
}

class MarkNotificationAsRead extends NotificationsEvent {
  final String id;

  const MarkNotificationAsRead(this.id);

  @override
  List<Object?> get props => [id];
}
