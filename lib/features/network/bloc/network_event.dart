import 'dart:async';
import 'package:equatable/equatable.dart';
import '../domain/network_models.dart';

enum NetworkPeriod { today, month, all }

abstract class NetworkEvent extends Equatable {
  const NetworkEvent();

  @override
  List<Object?> get props => [];
}

class LoadNetworkData extends NetworkEvent {
  final NetworkPeriod period;
  final bool forceRefresh;
  final Completer<void>? completion;

  const LoadNetworkData({
    this.period = NetworkPeriod.month,
    this.forceRefresh = false,
    this.completion,
  });

  @override
  List<Object?> get props => [period, forceRefresh];
}

class CreateStoreRequested extends NetworkEvent {
  final StoreCreateInput input;
  final Completer<bool>? completion;

  const CreateStoreRequested({required this.input, this.completion});

  @override
  List<Object?> get props => [input];
}

class EnterStoreRequested extends NetworkEvent {
  final int storeId;
  final Completer<ActingStore>? completion;

  const EnterStoreRequested({required this.storeId, this.completion});

  @override
  List<Object?> get props => [storeId];
}

class LeaveStoreRequested extends NetworkEvent {
  final Completer<void>? completion;

  const LeaveStoreRequested({this.completion});
}

class UpdateStoreRequested extends NetworkEvent {
  final int storeId;
  final String? name;
  final String? location;
  final bool? isActive;
  final Completer<bool>? completion;

  const UpdateStoreRequested({
    required this.storeId,
    this.name,
    this.location,
    this.isActive,
    this.completion,
  });

  @override
  List<Object?> get props => [storeId, name, location, isActive];
}

class DeleteStoreRequested extends NetworkEvent {
  final int storeId;
  final Completer<bool>? completion;

  const DeleteStoreRequested({required this.storeId, this.completion});

  @override
  List<Object?> get props => [storeId];
}

class ResetDirectorPasswordRequested extends NetworkEvent {
  final int storeId;
  final String? username;
  final String password;
  final Completer<bool>? completion;

  const ResetDirectorPasswordRequested({
    required this.storeId,
    this.username,
    required this.password,
    this.completion,
  });

  @override
  List<Object?> get props => [storeId, username, password];
}
