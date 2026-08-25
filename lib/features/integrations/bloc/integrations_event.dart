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

class TestSmsRequested extends IntegrationsEvent {
  final String phone;

  const TestSmsRequested(this.phone);

  @override
  List<Object?> get props => [phone];
}

class TestAiRequested extends IntegrationsEvent {
  const TestAiRequested();
}

class LoadTelegramLinkRequested extends IntegrationsEvent {
  const LoadTelegramLinkRequested();
}
