class IntegrationInfo {
  final String system;
  final String name;
  final bool available;
  final bool canSync;

  const IntegrationInfo({
    required this.system,
    required this.name,
    required this.available,
    required this.canSync,
  });
}

class SyncLog {
  final String id;
  final String system;
  final String direction;
  final bool success;
  final int records;
  final String? message;
  final DateTime? finishedAt;
  final DateTime createdAt;

  const SyncLog({
    required this.id,
    required this.system,
    required this.direction,
    required this.success,
    required this.records,
    this.message,
    this.finishedAt,
    required this.createdAt,
  });
}

class SyncResult {
  final String system;
  final bool success;
  final int records;
  final String message;

  const SyncResult({
    required this.system,
    required this.success,
    required this.records,
    required this.message,
  });
}
