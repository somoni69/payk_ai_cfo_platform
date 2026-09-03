import 'package:flutter_test/flutter_test.dart';
import 'package:payk_ai_cfo_platform/features/audit/bloc/audit_bloc.dart';
import 'package:payk_ai_cfo_platform/features/audit/bloc/audit_event.dart';
import 'package:payk_ai_cfo_platform/features/audit/bloc/audit_state.dart';
import 'package:payk_ai_cfo_platform/features/audit/domain/audit_models.dart';
import 'package:payk_ai_cfo_platform/features/audit/domain/audit_repository.dart';

class MockAuditRepository implements AuditRepository {
  List<AuditLog> logs = [];
  List<AuditAlert> alerts = [];
  WeeklyAuditReport? weeklyReport;
  bool shouldThrowLogs = false;
  bool shouldThrowDetectors = false;
  bool shouldThrowResolve = false;
  bool shouldThrowWeekly = false;

  @override
  Future<List<AuditLog>> getAuditLogs({
    String? entity,
    String? action,
    DateTime? dateFrom,
    DateTime? dateTo,
  }) async {
    if (shouldThrowLogs) {
      throw Exception('Не удалось загрузить журнал аудита');
    }
    return List.from(logs);
  }

  @override
  Future<List<AuditAlert>> getAuditAlerts({bool? resolved}) async {
    if (resolved == null) {
      return List.from(alerts);
    }
    return alerts.where((a) => a.isResolved == resolved).toList();
  }

  @override
  Future<WeeklyAuditReport> getWeeklyReport({int weeksAgo = 0}) async {
    if (shouldThrowWeekly) {
      throw Exception('Еженедельный отчет недоступен');
    }
    return weeklyReport ??
        WeeklyAuditReport(
          periodFrom: DateTime.utc(2026, 8, 25),
          periodTo: DateTime.utc(2026, 9, 1),
          operationsCount: logs.length,
          incomeTotal: 150000,
          expenseTotal: 80000,
          netTotal: 70000,
          alertsCount: alerts.length,
          alertsBySeverity: {'high': 1, 'medium': 1},
        );
  }

  @override
  Future<List<AuditAlert>> runAnomalyDetectors() async {
    if (shouldThrowDetectors) {
      throw Exception('Ошибка детектора аномалий');
    }
    alerts.add(
      AuditAlert(
        id: 'alert-${alerts.length + 1}',
        type: 'UNUSUAL_VOLUME',
        severity: 'high',
        message: 'Обнаружен подозрительный всплеск транзакций',
        timestamp: DateTime.utc(2026, 9, 1, 10, 0),
        isResolved: false,
      ),
    );
    return List.from(alerts);
  }

  @override
  Future<AuditAlert> resolveAlert(String id, {bool isResolved = true}) async {
    if (shouldThrowResolve) {
      throw Exception('Не удалось обновить статус алерта');
    }
    final index = alerts.indexWhere((a) => a.id == id);
    if (index == -1) {
      throw Exception('Алерт не найден');
    }
    final existing = alerts[index];
    final updated = AuditAlert(
      id: existing.id,
      type: existing.type,
      severity: existing.severity,
      message: existing.message,
      timestamp: existing.timestamp,
      isResolved: isResolved,
    );
    alerts[index] = updated;
    return updated;
  }

  @override
  Future<List<int>> exportWeeklyReport({
    String format = 'pdf',
    int weeksAgo = 0,
  }) async => [1, 2, 3];

  @override
  Future<List<EntityHistoryItem>> getEntityHistory(
    String entity,
    String id,
  ) async => [];
}

void main() {
  group('AuditBloc & Domain Models Unit Tests (R1-09)', () {
    late MockAuditRepository mockRepository;
    late AuditBloc auditBloc;

    final initialLogs = [
      AuditLog(
        id: 'log-1',
        timestamp: DateTime.utc(2026, 9, 1, 8, 30),
        userName: 'shams_cashier',
        action: 'cash_shift_open',
        entityType: 'shift',
        details: 'Открытие кассовой смены #102',
      ),
      AuditLog(
        id: 'log-2',
        timestamp: DateTime.utc(2026, 9, 1, 9, 15),
        userName: 'farzod_cfo',
        action: 'pnl_export',
        entityType: 'report',
        details: 'Экспорт отчета P&L за август',
      ),
    ];

    final initialAlerts = [
      AuditAlert(
        id: 'alert-1',
        type: 'CASH_DISCREPANCY',
        severity: 'medium',
        message: 'Расхождение в Z-отчете: 15 TJS',
        timestamp: DateTime.utc(2026, 9, 1, 8, 45),
        isResolved: false,
      ),
    ];

    setUp(() {
      mockRepository = MockAuditRepository();
      mockRepository.logs = List.from(initialLogs);
      mockRepository.alerts = List.from(initialAlerts);
      auditBloc = AuditBloc(mockRepository);
    });

    tearDown(() {
      auditBloc.close();
    });

    test('Initial state is AuditInitial', () {
      expect(auditBloc.state, isA<AuditInitial>());
    });

    group('LoadAuditData Event', () {
      test(
        'emits [AuditLoading, AuditLoaded] with logs, alerts, and weekly report',
        () async {
          final expected = [
            isA<AuditLoading>(),
            isA<AuditLoaded>()
                .having((s) => s.logs.length, 'logs length', 2)
                .having((s) => s.alerts.length, 'alerts length', 1)
                .having((s) => s.weekly?.operationsCount, 'operations count', 2)
                .having(
                  (s) => s.isRunningDetectors,
                  'isRunningDetectors',
                  isFalse,
                ),
          ];

          expectLater(auditBloc.stream, emitsInOrder(expected));
          auditBloc.add(const LoadAuditData());
        },
      );

      test(
        'emits [AuditLoading, AuditLoaded] even if weekly report fails to load',
        () async {
          mockRepository.shouldThrowWeekly = true;

          final expected = [
            isA<AuditLoading>(),
            isA<AuditLoaded>()
                .having((s) => s.logs.length, 'logs length', 2)
                .having((s) => s.weekly, 'weekly report is null', isNull),
          ];

          expectLater(auditBloc.stream, emitsInOrder(expected));
          auditBloc.add(const LoadAuditData());
        },
      );

      test('emits [AuditLoading, AuditError] on repository failure', () async {
        mockRepository.shouldThrowLogs = true;

        final expected = [
          isA<AuditLoading>(),
          isA<AuditError>().having(
            (s) => s.message,
            'error message',
            isNotEmpty,
          ),
        ];

        expectLater(auditBloc.stream, emitsInOrder(expected));
        auditBloc.add(const LoadAuditData());
      });

      test(
        'forceRefresh: true triggers AuditLoading when already loaded',
        () async {
          auditBloc.add(const LoadAuditData());
          await auditBloc.stream.firstWhere((s) => s is AuditLoaded);

          final expected = [isA<AuditLoading>(), isA<AuditLoaded>()];

          expectLater(auditBloc.stream, emitsInOrder(expected));
          auditBloc.add(const LoadAuditData(forceRefresh: true));
        },
      );
    });

    group('RunAnomalyDetectorsRequested Event', () {
      test(
        'emits loading indicator on loaded state and updates alerts on completion',
        () async {
          auditBloc.add(const LoadAuditData());
          await auditBloc.stream.firstWhere((s) => s is AuditLoaded);

          final expected = [
            isA<AuditLoaded>().having(
              (s) => s.isRunningDetectors,
              'running',
              isTrue,
            ),
            isA<AuditLoaded>()
                .having((s) => s.isRunningDetectors, 'running', isFalse)
                .having((s) => s.alerts.length, 'alerts length', 2)
                .having((s) => s.message, 'message', isNotEmpty),
          ];

          expectLater(auditBloc.stream, emitsInOrder(expected));
          auditBloc.add(const RunAnomalyDetectorsRequested());
        },
      );

      test('emits AuditError when anomaly detection throws', () async {
        auditBloc.add(const LoadAuditData());
        await auditBloc.stream.firstWhere((s) => s is AuditLoaded);

        mockRepository.shouldThrowDetectors = true;

        final expected = [
          isA<AuditLoaded>().having(
            (s) => s.isRunningDetectors,
            'running',
            isTrue,
          ),
          isA<AuditError>().having(
            (s) => s.message,
            'error message',
            contains('Ошибка детектора аномалий'),
          ),
        ];

        expectLater(auditBloc.stream, emitsInOrder(expected));
        auditBloc.add(const RunAnomalyDetectorsRequested());
      });
    });

    group('ResolveAlertRequested Event', () {
      test(
        'updates target alert resolution status in state immutably',
        () async {
          auditBloc.add(const LoadAuditData());
          await auditBloc.stream.firstWhere((s) => s is AuditLoaded);

          final expected = [
            isA<AuditLoaded>().having(
              (s) => s.alerts.firstWhere((a) => a.id == 'alert-1').isResolved,
              'isResolved',
              isTrue,
            ),
          ];

          expectLater(auditBloc.stream, emitsInOrder(expected));
          auditBloc.add(
            const ResolveAlertRequested('alert-1', isResolved: true),
          );
        },
      );

      test('emits AuditError when resolveAlert repository fails', () async {
        auditBloc.add(const LoadAuditData());
        await auditBloc.stream.firstWhere((s) => s is AuditLoaded);

        mockRepository.shouldThrowResolve = true;

        final expected = [
          isA<AuditError>().having(
            (s) => s.message,
            'error message',
            contains('Не удалось обновить статус алерта'),
          ),
        ];

        expectLater(auditBloc.stream, emitsInOrder(expected));
        auditBloc.add(const ResolveAlertRequested('alert-1', isResolved: true));
      });
    });

    group('Domain Models Serialization & Properties', () {
      test('AuditLog JSON deserialization and field mapping', () {
        final json = {
          'id': 'log-999',
          'created_at': '2026-09-01T12:00:00Z',
          'user_name': 'test_auditor',
          'action': 'tax_calc',
          'entity': 'tax',
          'details': 'Начисление НДС',
        };

        final model = AuditLog.fromJson(json);
        expect(model.id, 'log-999');
        expect(model.userName, 'test_auditor');
        expect(model.action, 'tax_calc');
        expect(model.entityType, 'tax');
        expect(model.details, 'Начисление НДС');

        final serialized = model.toJson();
        expect(serialized['id'], 'log-999');
        expect(serialized['user_name'], 'test_auditor');
      });

      test('AuditAlert JSON deserialization and severity handling', () {
        final json = {
          'id': 'alert-50',
          'type': 'LARGE_DISCOUNT',
          'severity': 'high',
          'message': 'Скидка 50% превышает лимит',
          'created_at': '2026-09-01T12:30:00Z',
          'is_resolved': false,
        };

        final alert = AuditAlert.fromJson(json);
        expect(alert.id, 'alert-50');
        expect(alert.severity, 'high');
        expect(alert.isResolved, isFalse);

        final serialized = alert.toJson();
        expect(serialized['id'], 'alert-50');
        expect(serialized['type'], 'LARGE_DISCOUNT');
      });

      test('EntityHistoryItem JSON deserialization', () {
        final json = {
          'id': 'hist-1',
          'action': 'update',
          'user_name': 'farzod',
          'created_at': '2026-09-01T10:00:00Z',
          'changes': 'Price updated from 10 to 12',
        };

        final item = EntityHistoryItem.fromJson(json);
        expect(item.id, 'hist-1');
        expect(item.action, 'update');
        expect(item.userName, 'farzod');
        expect(item.details, 'Price updated from 10 to 12');
      });

      test('WeeklyAuditReport default constructor values', () {
        final report = WeeklyAuditReport(
          periodFrom: DateTime.utc(2026, 8, 25),
          periodTo: DateTime.utc(2026, 9, 1),
          operationsCount: 1500,
          incomeTotal: 250000,
          expenseTotal: 100000,
          netTotal: 150000,
          alertsCount: 3,
        );
        expect(report.operationsCount, 1500);
        expect(report.netTotal, 150000);
        expect(report.alertsCount, 3);
      });
    });
  });
}
