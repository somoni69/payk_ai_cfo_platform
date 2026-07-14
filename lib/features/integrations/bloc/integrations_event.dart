import 'package:equatable/equatable.dart';

abstract class IntegrationsEvent extends Equatable {
  const IntegrationsEvent();

  @override
  List<Object?> get props => [];
}

class LoadIntegrationsData extends IntegrationsEvent {}

class TriggerSyncRequested extends IntegrationsEvent {
  final String system;

  const TriggerSyncRequested(this.system);

  @override
  List<Object?> get props => [system];
}
