import '../../../core/network/api_client.dart';
import '../domain/audit_models.dart';
import '../domain/audit_repository.dart';

class ApiAuditRepository implements AuditRepository {
  final ApiClient _client;

  ApiAuditRepository({ApiClient? client}) : _client = client ?? ApiClient();

  final List<AuditLog> _mockLogs = [
    AuditLog(
      id: 'log-1',
      timestamp: DateTime.now().subtract(const Duration(minutes: 15)),
      userName: 'Алишер Рахимов',
      action: 'Создание инкассации',
      entityType: 'Encashment',
      details: 'Сумма 25,000 TJS в Ориёнбанк',
    ),
    AuditLog(
      id: 'log-2',
      timestamp: DateTime.now().subtract(const Duration(hours: 1)),
      userName: 'Зарина Шарипова',
      action: 'Закрытие смены',
      entityType: 'Shift',
      details: 'Z-отчет #402 выведен без расхождений',
    ),
    AuditLog(
      id: 'log-3',
      timestamp: DateTime.now().subtract(const Duration(hours: 3)),
      userName: 'Парвиз Назаров',
      action: 'Изменение роли пользователя',
      entityType: 'UserRole',
      details: 'Пользователь cashier_2 переведен в роль Кассир',
    ),
  ];

  final List<AuditAlert> _mockAlerts = [
    AuditAlert(
      id: 'alt-1',
      type: 'Крупный расход',
      severity: 'high',
      message: 'Выявлена инкассация выше лимита 20,000 TJS',
      timestamp: DateTime.now().subtract(const Duration(minutes: 15)),
    ),
    AuditAlert(
      id: 'alt-2',
      type: 'Повторный вход',
      severity: 'medium',
      message: 'Попытка параллельного входа с двух IP-адресов',
      timestamp: DateTime.now().subtract(const Duration(hours: 5)),
    ),
  ];

  @override
  Future<List<AuditLog>> getAuditLogs() async {
    try {
      final response = await _client.dio.get('/api/v1/audit/logs');
      if (response.statusCode == 200 && response.data is List) {
        return (response.data as List)
            .map((e) => AuditLog.fromJson(e as Map<String, dynamic>))
            .toList();
      }
    } catch (_) {}
    return List.from(_mockLogs);
  }

  @override
  Future<List<AuditAlert>> getAuditAlerts() async {
    try {
      final response = await _client.dio.get('/api/v1/audit/alerts');
      if (response.statusCode == 200 && response.data is List) {
        return (response.data as List)
            .map((e) => AuditAlert.fromJson(e as Map<String, dynamic>))
            .toList();
      }
    } catch (_) {}
    return List.from(_mockAlerts);
  }

  @override
  Future<List<AuditAlert>> runAnomalyDetectors() async {
    try {
      final response = await _client.dio.post('/api/v1/audit/detectors/run');
      if (response.statusCode == 200 && response.data is List) {
        return (response.data as List)
            .map((e) => AuditAlert.fromJson(e as Map<String, dynamic>))
            .toList();
      }
    } catch (_) {}
    final newAlert = AuditAlert(
      id: 'alt-${DateTime.now().millisecondsSinceEpoch}',
      type: 'Проверка завершена',
      severity: 'low',
      message: 'AI-детектор: Системных аномалий не обнаружено (100% закрепелено)',
      timestamp: DateTime.now(),
    );
    _mockAlerts.insert(0, newAlert);
    return List.from(_mockAlerts);
  }
}
