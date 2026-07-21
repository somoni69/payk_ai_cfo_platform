import 'dart:async';

import 'package:dio/dio.dart';

/// Converts infrastructure failures into short messages that are safe to show
/// to a user. Raw response bodies, URLs, tokens and stack traces stay out of UI.
String userFacingError(Object error, {required String fallback}) {
  if (error is TimeoutException) {
    return 'Сервер отвечает слишком долго. Повторите попытку.';
  }

  if (error is! DioException) return fallback;

  switch (error.type) {
    case DioExceptionType.connectionTimeout:
    case DioExceptionType.sendTimeout:
    case DioExceptionType.receiveTimeout:
    case DioExceptionType.transformTimeout:
      return 'Сервер отвечает слишком долго. Повторите попытку.';
    case DioExceptionType.connectionError:
      return 'Нет соединения с сервером. Проверьте интернет.';
    case DioExceptionType.cancel:
      return 'Операция отменена.';
    case DioExceptionType.badCertificate:
      return 'Не удалось установить защищённое соединение.';
    case DioExceptionType.badResponse:
      final statusCode = error.response?.statusCode;
      if (statusCode == 401) {
        return 'Сессия истекла. Войдите в приложение снова.';
      }
      if (statusCode == 403) {
        return 'Недостаточно прав для этой операции.';
      }
      if (statusCode == 409) {
        return 'Данные уже изменились. Обновите экран и повторите.';
      }
      if (statusCode == 422) {
        return 'Проверьте введённые данные.';
      }
      if (statusCode == 429) {
        return 'Слишком много запросов. Повторите немного позже.';
      }
      if (statusCode != null && statusCode >= 500) {
        return 'Сервис временно недоступен. Повторите позже.';
      }
      return fallback;
    case DioExceptionType.unknown:
      return fallback;
  }
}
