import 'package:equatable/equatable.dart';
import '../domain/audit_models.dart';

abstract class AuditState extends Equatable {
  const AuditState();

  @override
  List<Object?> get props => [];
}

class AuditInitial extends AuditState {}

class AuditLoading extends AuditState {}

class AuditLoaded extends AuditState {
  final List<AuditLog> logs;
  final List<AuditAlert> alerts;
  final bool isRunningDetectors;
  final String? message;

  const AuditLoaded({
    required this.logs,
    required this.alerts,
    this.isRunningDetectors = false,
    this.message,
  });

  @override
  List<Object?> get props => [logs, alerts, isRunningDetectors, message];
}

class AuditError extends AuditState {
  final String message;
  const AuditError(this.message);

  @override
  List<Object?> get props => [message];
}
