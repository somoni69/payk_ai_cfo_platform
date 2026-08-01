import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:payk_ai_cfo_platform/core/network/user_facing_error.dart';

void main() {
  test('maps transport failures to stable keys', () {
    expect(userFacingError(TimeoutException('x')), ErrorKeys.timeout);
    expect(
      userFacingError(
        DioException(
          requestOptions: RequestOptions(path: '/'),
          type: DioExceptionType.connectionError,
        ),
      ),
      ErrorKeys.offline,
    );
    expect(
      userFacingError(
        DioException(
          requestOptions: RequestOptions(path: '/'),
          type: DioExceptionType.badResponse,
          response: Response(
            requestOptions: RequestOptions(path: '/'),
            statusCode: 401,
          ),
        ),
      ),
      ErrorKeys.sessionExpired,
    );
  });
}
