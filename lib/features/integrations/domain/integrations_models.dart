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

class SmsTestResult {
  final bool ok;
  final String? reason;
  final String phone;

  const SmsTestResult({required this.ok, this.reason, required this.phone});

  factory SmsTestResult.fromJson(Map<String, dynamic> json, String phone) {
    return SmsTestResult(
      ok: json['ok'] == true,
      reason: json['reason']?.toString() ?? json['error']?.toString(),
      phone: phone,
    );
  }
}

class AiProbeResult {
  final bool ok;
  final String? code;
  final String? model;
  final String? error;

  const AiProbeResult({required this.ok, this.code, this.model, this.error});

  factory AiProbeResult.fromJson(Map<String, dynamic> json) {
    return AiProbeResult(
      ok: json['ok'] == true,
      code: json['code']?.toString(),
      model: json['model']?.toString(),
      error: json['error']?.toString() ?? json['reason']?.toString(),
    );
  }
}

class TelegramLinkInfo {
  final String url;
  final String appUrl;
  final String? bot;
  final String token;
  final bool connected;
  final bool available;

  const TelegramLinkInfo({
    required this.url,
    required this.appUrl,
    this.bot,
    required this.token,
    required this.connected,
    required this.available,
  });

  factory TelegramLinkInfo.fromJson(Map<String, dynamic> json) {
    return TelegramLinkInfo(
      url: (json['url'] ?? '').toString(),
      appUrl: (json['app_url'] ?? '').toString(),
      bot: json['bot']?.toString(),
      token: (json['token'] ?? '').toString(),
      connected: json['connected'] == true,
      available: json['available'] == true,
    );
  }
}
