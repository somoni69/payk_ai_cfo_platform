import 'package:equatable/equatable.dart';

abstract class IntegrationsEvent extends Equatable {
  const IntegrationsEvent();

  @override
  List<Object?> get props => [];
}

class LoadIntegrationsData extends IntegrationsEvent {
  final bool forceRefresh;

  const LoadIntegrationsData({this.forceRefresh = false});

  @override
  List<Object?> get props => [forceRefresh];
}

class TriggerSyncRequested extends IntegrationsEvent {
  final String system;

  const TriggerSyncRequested(this.system);

  @override
  List<Object?> get props => [system];
}
