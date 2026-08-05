import 'dart:typed_data';

import 'report_models.dart';

abstract class ReportsRepository {
  Future<List<DailyReport>> getDailyReports({
    DailyReportFilters filters = const DailyReportFilters(),
    bool forceRefresh = false,
  });

  Future<DailyReport> createDailyReport(DailyReportInput input);

  Future<DailyReport> updateDailyReport(int id, DailyReportInput input);

  Future<void> deleteDailyReport(int id);

  /// Download export bytes (pdf | docx).
  Future<Uint8List> exportDailyReport(int id, {required String format});
}
