import 'dart:typed_data';

import 'package:dio/dio.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/user_facing_error.dart';
import '../domain/report_models.dart';
import '../domain/reports_repository.dart';

/// Reports API — `/reports/daily` (web Payk-Ecosystem parity).
class ApiReportsRepository implements ReportsRepository {
  ApiReportsRepository({Dio? dio}) : _dio = dio ?? ApiClient().dio;

  final Dio _dio;

  @override
  Future<List<DailyReport>> getDailyReports({
    DailyReportFilters filters = const DailyReportFilters(),
    bool forceRefresh = false,
  }) async {
    try {
      final response = await _dio.get(
        '/reports/daily',
        queryParameters: filters.toQuery(),
      );
      final data = response.data;
      if (data is! List) {
        throw const FormatException(ErrorKeys.invalidResponse);
      }
      return data
          .whereType<Map>()
          .map((e) => DailyReport.fromJson(Map<String, dynamic>.from(e)))
          .toList(growable: false);
    } catch (e) {
      throw userFacingError(e, fallback: ErrorKeys.loadFailed);
    }
  }

  @override
  Future<DailyReport> createDailyReport(DailyReportInput input) async {
    try {
      final response = await _dio.post(
        '/reports/daily',
        data: input.toCreateJson(),
      );
      final data = response.data;
      if (data is! Map) {
        throw const FormatException(ErrorKeys.invalidResponse);
      }
      return DailyReport.fromJson(Map<String, dynamic>.from(data));
    } catch (e) {
      throw userFacingError(e, fallback: ErrorKeys.saveFailed);
    }
  }

  @override
  Future<DailyReport> updateDailyReport(int id, DailyReportInput input) async {
    if (id <= 0) throw StateError(ErrorKeys.invalidId);
    try {
      final response = await _dio.patch(
        '/reports/daily/$id',
        data: input.toUpdateJson(),
      );
      final data = response.data;
      if (data is! Map) {
        throw const FormatException(ErrorKeys.invalidResponse);
      }
      return DailyReport.fromJson(Map<String, dynamic>.from(data));
    } catch (e) {
      throw userFacingError(e, fallback: ErrorKeys.saveFailed);
    }
  }

  @override
  Future<void> deleteDailyReport(int id) async {
    if (id <= 0) throw StateError(ErrorKeys.invalidId);
    try {
      await _dio.delete('/reports/daily/$id');
    } catch (e) {
      throw userFacingError(e, fallback: ErrorKeys.saveFailed);
    }
  }

  @override
  Future<Uint8List> exportDailyReport(int id, {required String format}) async {
    if (id <= 0) throw StateError(ErrorKeys.invalidId);
    final fmt = format == 'docx' ? 'docx' : 'pdf';
    try {
      final response = await _dio.get<List<int>>(
        '/reports/daily/$id/export',
        queryParameters: {'fmt': fmt},
        options: Options(responseType: ResponseType.bytes),
      );
      final bytes = response.data;
      if (bytes == null || bytes.isEmpty) {
        throw const FormatException(ErrorKeys.invalidResponse);
      }
      return Uint8List.fromList(bytes);
    } catch (e) {
      throw userFacingError(e, fallback: ErrorKeys.loadFailed);
    }
  }
}
