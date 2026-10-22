import 'package:dio/dio.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/user_facing_error.dart';
import '../domain/branch_models.dart';
import '../domain/branches_repository.dart';
import '../../../core/error/app_failure.dart';

/// Branches: `/branches`. Failures reach the bloc; nothing is invented offline.
class ApiBranchesRepository implements BranchesRepository {
  final Dio _dio;

  ApiBranchesRepository({ApiClient? client, Dio? dio})
    : _dio = dio ?? (client ?? ApiClient()).dio;

  static Branch _branch(Object? data) {
    if (data is! Map) throw RepositoryFailure(ErrorKeys.invalidResponse);
    return Branch.fromJson(Map<String, dynamic>.from(data));
  }

  @override
  Future<List<Branch>> getBranches() async {
    try {
      final response = await _dio.get('/branches');
      final data = response.data;
      if (data is! List) throw RepositoryFailure(ErrorKeys.invalidResponse);
      return data
          .whereType<Map>()
          .map((e) => Branch.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    } catch (e) {
      throw RepositoryFailure(
        userFacingError(e, fallback: ErrorKeys.loadFailed),
      );
    }
  }

  @override
  Future<Branch> createBranch({
    required String name,
    String? code,
    required String address,
    required String phone,
  }) async {
    try {
      final response = await _dio.post(
        '/branches',
        data: {'name': name, 'code': ?code, 'address': address, 'phone': phone},
      );
      return _branch(response.data);
    } catch (e) {
      throw RepositoryFailure(
        userFacingError(e, fallback: ErrorKeys.saveFailed),
      );
    }
  }

  @override
  Future<Branch> updateBranch({
    required String id,
    required String name,
    String? code,
    required String address,
    required String phone,
    required bool isActive,
  }) async {
    try {
      final response = await _dio.patch(
        '/branches/$id',
        data: {
          'name': name,
          'code': ?code,
          'address': address,
          'phone': phone,
          'is_active': isActive,
        },
      );
      return _branch(response.data);
    } catch (e) {
      throw RepositoryFailure(
        userFacingError(e, fallback: ErrorKeys.saveFailed),
      );
    }
  }

  @override
  Future<void> deleteBranch(String id) async {
    try {
      await _dio.delete('/branches/$id');
    } catch (e) {
      throw RepositoryFailure(
        userFacingError(e, fallback: ErrorKeys.saveFailed),
      );
    }
  }
}
