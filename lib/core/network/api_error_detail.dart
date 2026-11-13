import 'package:dio/dio.dart';

import '../error/app_failure.dart';
import 'user_facing_error.dart';

/// Текст ошибки API, который сервер уже написал для человека.
String? apiErrorDetail(Object error) {
  if (error is! DioException) return null;
  final data = error.response?.data;
  if (data is! Map) return null;
  final detail = data['detail'];
  if (detail is String && detail.trim().isNotEmpty) return detail.trim();
  if (detail is List) {
    for (final item in detail) {
      if (item is Map && item['msg'] != null) {
        final msg = item['msg'].toString().trim();
        if (msg.isNotEmpty) return msg;
      }
    }
  }
  return null;
}

RepositoryFailure repositoryFailure(
  Object error, {
  String fallback = ErrorKeys.loadFailed,
}) {
  final detail = apiErrorDetail(error);
  if (detail != null) return RepositoryFailure(detail);
  return RepositoryFailure(userFacingError(error, fallback: fallback));
}
