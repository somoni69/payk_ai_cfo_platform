import 'package:equatable/equatable.dart';

abstract class AuditEvent extends Equatable {
  const AuditEvent();

  @override
  List<Object?> get props => [];
}

class LoadAuditData extends AuditEvent {
  final bool forceRefresh;
  const LoadAuditData({this.forceRefresh = false});

  @override
  List<Object?> get props => [forceRefresh];
}

class RunAnomalyDetectorsRequested extends AuditEvent {
  const RunAnomalyDetectorsRequested();
}

class ResolveAlertRequested extends AuditEvent {
  final String id;
  final bool isResolved;

  const ResolveAlertRequested(this.id, {this.isResolved = true});

  @override
  List<Object?> get props => [id, isResolved];
}
