import '../../../core/network/api_client.dart';
import '../domain/report_models.dart';
import '../domain/reports_repository.dart';

class ApiReportsRepository implements ReportsRepository {
  final ApiClient _client;

  ApiReportsRepository({ApiClient? client}) : _client = client ?? ApiClient();

  final List<DailyReport> _mockReports = [
    DailyReport(
      id: 'rep-1',
      branchName: 'Филиал «Центральный»',
      date: DateTime.now(),
      revenue: 48500.0,
      expenses: 12400.0,
      netProfit: 36100.0,
      cashEndBalance: 15200.0,
      bankEndBalance: 145000.0,
      status: 'verified',
      comments: 'Выручка превысила план на 12%',
    ),
    DailyReport(
      id: 'rep-2',
      branchName: 'Филиал «Сомони»',
      date: DateTime.now().subtract(const Duration(days: 1)),
      revenue: 32000.0,
      expenses: 8900.0,
      netProfit: 23100.0,
      cashEndBalance: 9800.0,
      bankEndBalance: 89000.0,
      status: 'submitted',
      comments: 'Все смены закрыты вовремя',
    ),
    DailyReport(
      id: 'rep-3',
      branchName: 'Точка «Худжанд»',
      date: DateTime.now().subtract(const Duration(days: 2)),
      revenue: 18500.0,
      expenses: 4200.0,
      netProfit: 14300.0,
      cashEndBalance: 6400.0,
      bankEndBalance: 62000.0,
      status: 'verified',
      comments: 'Инкассация проведена',
    ),
  ];

  @override
  Future<List<DailyReport>> getDailyReports() async {
    try {
      final response = await _client.dio.get('/api/v1/reports/daily');
      if (response.statusCode == 200 && response.data is List) {
        return (response.data as List)
            .map((e) => DailyReport.fromJson(e as Map<String, dynamic>))
            .toList();
      }
    } catch (_) {}
    return List.from(_mockReports);
  }

  @override
  Future<DailyReport> createDailyReport({
    required String branchName,
    required double revenue,
    required double expenses,
    required double cashEndBalance,
    required double bankEndBalance,
    String? comments,
  }) async {
    final report = DailyReport(
      id: 'rep-${DateTime.now().millisecondsSinceEpoch}',
      branchName: branchName,
      date: DateTime.now(),
      revenue: revenue,
      expenses: expenses,
      netProfit: revenue - expenses,
      cashEndBalance: cashEndBalance,
      bankEndBalance: bankEndBalance,
      status: 'submitted',
      comments: comments ?? '',
    );
    try {
      await _client.dio.post('/api/v1/reports/daily', data: report.toJson());
    } catch (_) {}

    _mockReports.insert(0, report);
    return report;
  }

  @override
  Future<void> deleteDailyReport(String id) async {
    try {
      await _client.dio.delete('/api/v1/reports/daily/$id');
    } catch (_) {}
    _mockReports.removeWhere((r) => r.id == id);
  }
}
