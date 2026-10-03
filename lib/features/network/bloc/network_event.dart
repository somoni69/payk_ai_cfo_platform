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

  const LoadNetworkData({
    this.period = NetworkPeriod.month,
    this.forceRefresh = false,
  });

  @override
  List<Object?> get props => [period, forceRefresh];
}

class CreateStoreRequested extends NetworkEvent {
  final StoreCreateInput input;

  const CreateStoreRequested({required this.input});

  @override
  List<Object?> get props => [input];
}

class EnterStoreRequested extends NetworkEvent {
  final int storeId;

  const EnterStoreRequested({required this.storeId});

  @override
  List<Object?> get props => [storeId];
}

class LeaveStoreRequested extends NetworkEvent {
  const LeaveStoreRequested();
}

class UpdateStoreRequested extends NetworkEvent {
  final int storeId;
  final String? name;
  final String? location;
  final bool? isActive;
  final List<int>? moduleIds;

  const UpdateStoreRequested({
    required this.storeId,
    this.name,
    this.location,
    this.isActive,
    this.moduleIds,
  });

  @override
  List<Object?> get props => [storeId, name, location, isActive, moduleIds];
}

class DeleteStoreRequested extends NetworkEvent {
  final int storeId;

  const DeleteStoreRequested({required this.storeId});

  @override
  List<Object?> get props => [storeId];
}

class ResetDirectorPasswordRequested extends NetworkEvent {
  final int storeId;
  final String? username;
  final String password;

  const ResetDirectorPasswordRequested({
    required this.storeId,
    this.username,
    required this.password,
  });

  @override
  List<Object?> get props => [storeId, username, password];
}
