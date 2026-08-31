import 'package:equatable/equatable.dart';

class AuditLog extends Equatable {
  final String id;
  final DateTime timestamp;
  final String userName;
  final String action;
  final String entityType;
  final String details;

  const AuditLog({
    required this.id,
    required this.timestamp,
    required this.userName,
    required this.action,
    required this.entityType,
    required this.details,
  });

  factory AuditLog.fromJson(Map<String, dynamic> json) {
    final changes = json['changes'];
    return AuditLog(
      id: (json['id'] ?? '').toString(),
      timestamp: DateTime.tryParse(
            (json['created_at'] ?? json['timestamp'] ?? '').toString(),
          ) ??
          DateTime.now(),
      userName: (json['user_name'] ?? json['userName'] ?? '').toString(),
      action: (json['action'] ?? '').toString(),
      entityType: (json['entity'] ?? json['entity_type'] ?? '').toString(),
      details: json['details']?.toString() ??
          (changes == null ? '' : changes.toString()),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'timestamp': timestamp.toIso8601String(),
      'user_name': userName,
      'action': action,
      'entity_type': entityType,
      'details': details,
    };
  }

  @override
  List<Object?> get props => [
    id,
    timestamp,
    userName,
    action,
    entityType,
    details,
  ];
}

class AuditAlert extends Equatable {
  final String id;
  final String type;
  final String severity; // 'high', 'medium', 'low'
  final String message;
  final DateTime timestamp;
  final bool isResolved;

  const AuditAlert({
    required this.id,
    required this.type,
    required this.severity,
    required this.message,
    required this.timestamp,
    this.isResolved = false,
  });

  factory AuditAlert.fromJson(Map<String, dynamic> json) {
    return AuditAlert(
      id: (json['id'] ?? '').toString(),
      type: (json['type'] ?? json['title'] ?? '').toString(),
      severity: (json['severity'] ?? 'low').toString(),
      message: (json['message'] ?? json['title'] ?? '').toString(),
      timestamp: DateTime.tryParse(
            (json['created_at'] ?? json['timestamp'] ?? '').toString(),
          ) ??
          DateTime.now(),
      isResolved: json['is_resolved'] == true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type,
      'severity': severity,
      'message': message,
      'timestamp': timestamp.toIso8601String(),
    };
  }

  @override
  List<Object?> get props => [id, type, severity, message, timestamp, isResolved];
}

class EntityHistoryItem {
  final String id;
  final String action;
  final String userName;
  final DateTime createdAt;
  final String details;

  const EntityHistoryItem({
    required this.id,
    required this.action,
    required this.userName,
    required this.createdAt,
    this.details = '',
  });

  factory EntityHistoryItem.fromJson(Map<String, dynamic> json) {
    return EntityHistoryItem(
      id: (json['id'] ?? '').toString(),
      action: (json['action'] ?? '').toString(),
      userName: (json['user_name'] ?? '').toString(),
      createdAt:
          DateTime.tryParse((json['created_at'] ?? '').toString()) ??
          DateTime.now(),
      details: json['changes']?.toString() ?? '',
    );
  }
}

class WeeklyAuditReport {
  final DateTime periodFrom;
  final DateTime periodTo;
  final int operationsCount;
  final double incomeTotal;
  final double expenseTotal;
  final double netTotal;
  final int alertsCount;
  final Map<String, int> alertsBySeverity;

  const WeeklyAuditReport({
    required this.periodFrom,
    required this.periodTo,
    this.operationsCount = 0,
    this.incomeTotal = 0,
    this.expenseTotal = 0,
    this.netTotal = 0,
    this.alertsCount = 0,
    this.alertsBySeverity = const {},
  });
}
