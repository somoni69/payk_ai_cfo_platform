import 'dart:typed_data';

import 'package:dio/dio.dart';

// ignore_for_file: use_null_aware_elements

import '../../../core/error/app_failure.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_error_detail.dart';
import '../../../core/network/user_facing_error.dart';
import '../domain/showcase_models.dart';
import '../domain/showcase_repository.dart';

class ApiShowcaseRepository implements ShowcaseRepository {
  ApiShowcaseRepository({Dio? dio}) : _dio = dio ?? ApiClient().dio;

  final Dio _dio;

  Future<T> _call<T>(
    Future<T> Function() action, {
    required String fallback,
  }) async {
    try {
      return await action();
    } catch (error) {
      if (error is RepositoryFailure) rethrow;
      throw repositoryFailure(error, fallback: fallback);
    }
  }

  @override
  Future<ShowcaseList> list() => _call(() async {
    final response = await _dio.get<Map<String, dynamic>>('/showcase');
    return ShowcaseList.fromJson(response.data ?? const {});
  }, fallback: ErrorKeys.loadFailed);

  @override
  Future<void> create(Map<String, dynamic> input) => _call(() async {
    await _dio.post<dynamic>('/showcase', data: input);
  }, fallback: ErrorKeys.saveFailed);

  @override
  Future<void> update(int id, Map<String, dynamic> input) => _call(() async {
    await _dio.put<dynamic>('/showcase/$id', data: input);
  }, fallback: ErrorKeys.saveFailed);

  @override
  Future<void> setActive(int id, {required bool active}) => _call(() async {
    await _dio.patch<dynamic>(
      '/showcase/$id/active',
      data: {'is_active': active},
    );
  }, fallback: ErrorKeys.saveFailed);

  @override
  Future<int> setAllActive({required bool active}) => _call(() async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/showcase/bulk',
      data: {'is_active': active},
    );
    final changed = response.data?['changed'];
    return changed is num ? changed.toInt() : 0;
  }, fallback: ErrorKeys.saveFailed);

  @override
  Future<void> reorder(List<int> ids) => _call(() async {
    await _dio.put<dynamic>('/showcase/order', data: {'ids': ids});
  }, fallback: ErrorKeys.saveFailed);

  @override
  Future<void> delete(int id) => _call(() async {
    await _dio.delete<dynamic>('/showcase/$id');
  }, fallback: ErrorKeys.saveFailed);

  @override
  Future<ShowcaseImage> uploadImage({
    required Uint8List bytes,
    required String filename,
  }) => _call(() async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/showcase/image',
      data: FormData.fromMap({
        'file': MultipartFile.fromBytes(bytes, filename: filename),
      }),
    );
    return ShowcaseImage.fromJson(response.data ?? const {});
  }, fallback: ErrorKeys.saveFailed);
}
