import 'report_models.dart';

abstract class ReportsRepository {
  Future<List<DailyReport>> getDailyReports();
  Future<DailyReport> createDailyReport({
    required String branchName,
    required double revenue,
    required double expenses,
    required double cashEndBalance,
    required double bankEndBalance,
    String? comments,
  });
  Future<void> deleteDailyReport(String id);
}
