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
    return AuditLog(
      id: json['id'] as String? ?? '',
      timestamp: json['timestamp'] != null
          ? DateTime.parse(json['timestamp'] as String)
          : DateTime.now(),
      userName: json['user_name'] as String? ?? '',
      action: json['action'] as String? ?? '',
      entityType: json['entity_type'] as String? ?? '',
      details: json['details'] as String? ?? '',
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

  const AuditAlert({
    required this.id,
    required this.type,
    required this.severity,
    required this.message,
    required this.timestamp,
  });

  factory AuditAlert.fromJson(Map<String, dynamic> json) {
    return AuditAlert(
      id: json['id'] as String? ?? '',
      type: json['type'] as String? ?? '',
      severity: json['severity'] as String? ?? 'low',
      message: json['message'] as String? ?? '',
      timestamp: json['timestamp'] != null
          ? DateTime.parse(json['timestamp'] as String)
          : DateTime.now(),
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
  List<Object?> get props => [id, type, severity, message, timestamp];
}
