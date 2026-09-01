import 'package:payk_ai_cfo_platform/features/integrations/domain/integrations_models.dart';
import 'package:payk_ai_cfo_platform/features/integrations/domain/integrations_repository.dart';

class MockIntegrationsRepository implements IntegrationsRepository {
  final List<IntegrationInfo> _statusList = [
    const IntegrationInfo(
      system: '1c',
      name: '1С:Предприятие',
      available: true,
      canSync: true,
    ),
    const IntegrationInfo(
      system: 'wildberries',
      name: 'Wildberries',
      available: false,
      canSync: false,
    ),
    const IntegrationInfo(
      system: 'alif',
      name: 'Алиф Банк',
      available: true,
      canSync: true,
    ),
  ];

  final List<SyncLog> _logs = [
    SyncLog(
      id: '1',
      system: '1c',
      direction: 'inflow',
      success: true,
      records: 12,
      message: 'Импортировано 12 контрагентов и 8 счетов.',
      finishedAt: DateTime.now().subtract(const Duration(hours: 1)),
      createdAt: DateTime.now().subtract(const Duration(hours: 1, minutes: 5)),
    ),
    SyncLog(
      id: '2',
      system: 'alif',
      direction: 'outflow',
      success: false,
      records: 0,
      message: 'Ошибка подключения: Неверный API-токен партнера.',
      finishedAt: DateTime.now().subtract(const Duration(hours: 3)),
      createdAt: DateTime.now().subtract(const Duration(hours: 3, minutes: 2)),
    ),
  ];

  @override
  Future<List<IntegrationInfo>> getIntegrationsStatus({
    bool forceRefresh = false,
  }) async {
    return _statusList;
  }

  @override
  Future<List<SyncLog>> getSyncLogs({bool forceRefresh = false}) async {
    return _logs;
  }

  @override
  Future<SyncResult> triggerSync(String system) async {
    if (system == 'wildberries') {
      return const SyncResult(
        system: 'wildberries',
        success: false,
        records: 0,
        message: 'Невозможно запустить синхронизацию: интеграция неактивна.',
      );
    }

    final newLog = SyncLog(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      system: system,
      direction: 'inflow',
      success: true,
      records: 4,
      message: 'Успешно синхронизировано. Получено 4 новые записи.',
      finishedAt: DateTime.now(),
      createdAt: DateTime.now(),
    );
    _logs.insert(0, newLog);

    return const SyncResult(
      system: '1c',
      success: true,
      records: 4,
      message: 'Синхронизация завершена успешно.',
    );
  }

  @override
  Future<SmsTestResult> testSms(String phone) async {
    return SmsTestResult(ok: true, phone: phone);
  }

  @override
  Future<AiProbeResult> testAi() async {
    return const AiProbeResult(
      ok: true,
      model: 'claude-3-5-sonnet',
      code: 'success',
    );
  }

  @override
  Future<TelegramLinkInfo> getTelegramLink() async {
    return const TelegramLinkInfo(
      url: 'https://t.me/payk_bot?start=mock_token_123',
      appUrl: 'tg://resolve?domain=payk_bot&start=mock_token_123',
      bot: 'payk_bot',
      token: 'mock_token_123',
      connected: false,
      available: true,
    );
  }
}
