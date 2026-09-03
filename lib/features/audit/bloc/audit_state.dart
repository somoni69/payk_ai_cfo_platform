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
  final WeeklyAuditReport? weekly;
  final int weeksAgo;

  const AuditLoaded({
    required this.logs,
    required this.alerts,
    this.isRunningDetectors = false,
    this.message,
    this.weekly,
    this.weeksAgo = 0,
  });

  AuditLoaded copyWith({
    List<AuditLog>? logs,
    List<AuditAlert>? alerts,
    bool? isRunningDetectors,
    String? message,
    WeeklyAuditReport? weekly,
    int? weeksAgo,
  }) {
    return AuditLoaded(
      logs: logs ?? this.logs,
      alerts: alerts ?? this.alerts,
      isRunningDetectors: isRunningDetectors ?? this.isRunningDetectors,
      message: message ?? this.message,
      weekly: weekly ?? this.weekly,
      weeksAgo: weeksAgo ?? this.weeksAgo,
    );
  }

  @override
  List<Object?> get props => [
    logs,
    alerts,
    isRunningDetectors,
    message,
    weekly,
    weeksAgo,
  ];
}

class AuditError extends AuditState {
  final String message;
  const AuditError(this.message);

  @override
  List<Object?> get props => [message];
}
