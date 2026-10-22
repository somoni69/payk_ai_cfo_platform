import 'package:dio/dio.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/user_facing_error.dart';
import '../domain/lead_models.dart';
import '../domain/leads_repository.dart';
import '../../../core/error/app_failure.dart';

class ApiLeadsRepository implements LeadsRepository {
  ApiLeadsRepository({Dio? dio}) : _dio = dio ?? ApiClient().dio;

  final Dio _dio;

  Map<String, dynamic> _filters({String? query, String? status}) {
    final q = query?.trim();
    return {
      if (q != null && q.isNotEmpty) 'q': q,
      if (status != null && status.isNotEmpty) 'status': status,
    };
  }

  @override
  Future<LeadSummary> getSummary() async {
    try {
      final response = await _dio.get<Map<String, dynamic>>('/leads/summary');
      return LeadSummary.fromJson(response.data ?? const {});
    } catch (error) {
      throw RepositoryFailure(
        userFacingError(error, fallback: ErrorKeys.loadFailed),
      );
    }
  }

  @override
  Future<List<LeadRow>> listLeads({String? query, String? status}) async {
    try {
      final response = await _dio.get<List<dynamic>>(
        '/leads',
        queryParameters: _filters(query: query, status: status),
      );
      return [
        for (final item in response.data ?? const <dynamic>[])
          if (item is Map) LeadRow.fromJson(Map<String, dynamic>.from(item)),
      ];
    } catch (error) {
      throw RepositoryFailure(
        userFacingError(error, fallback: ErrorKeys.loadFailed),
      );
    }
  }

  @override
  Future<LeadDetail> getLead(int id) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>('/leads/$id');
      return LeadDetail.fromJson(response.data ?? const {});
    } catch (error) {
      throw RepositoryFailure(
        userFacingError(error, fallback: ErrorKeys.loadFailed),
      );
    }
  }

  @override
  Future<LeadDetail> updateLead(
    int id, {
    required String status,
    required String comment,
  }) async {
    try {
      final response = await _dio.patch<Map<String, dynamic>>(
        '/leads/$id',
        data: {'status': status, 'comment': comment},
      );
      return LeadDetail.fromJson(response.data ?? const {});
    } catch (error) {
      throw RepositoryFailure(
        userFacingError(error, fallback: ErrorKeys.saveFailed),
      );
    }
  }

  @override
  Future<void> deleteLead(int id) async {
    try {
      await _dio.delete<void>('/leads/$id');
    } catch (error) {
      throw RepositoryFailure(
        userFacingError(error, fallback: ErrorKeys.saveFailed),
      );
    }
  }

  @override
  Future<List<int>> exportXlsx({String? query, String? status}) async {
    try {
      final response = await _dio.get<List<int>>(
        '/leads/export.xlsx',
        queryParameters: _filters(query: query, status: status),
        options: Options(responseType: ResponseType.bytes),
      );
      return response.data ?? const <int>[];
    } catch (error) {
      throw RepositoryFailure(
        userFacingError(error, fallback: ErrorKeys.loadFailed),
      );
    }
  }

  @override
  Future<DemoBank> getBank() async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '/public/demo/bank',
      );
      return DemoBank.fromJson(response.data ?? const {});
    } catch (error) {
      throw RepositoryFailure(
        userFacingError(error, fallback: ErrorKeys.loadFailed),
      );
    }
  }
}
