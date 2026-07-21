import 'dart:math';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:payk_ai_cfo_platform/core/network/safe_retry_interceptor.dart';

void main() {
  test(
    'transient GET is retried and preserves a successful response',
    () async {
      final dio = Dio(BaseOptions(baseUrl: 'https://example.test'));
      final adapter = _SequenceAdapter([503, 200]);
      dio.httpClientAdapter = adapter;
      dio.interceptors.add(
        SafeRetryInterceptor(dio: dio, delay: (_) async {}, random: Random(1)),
      );

      final response = await dio.get<Map<String, dynamic>>('/health');

      expect(response.statusCode, 200);
      expect(adapter.requests, 2);
    },
  );

  test('mutating requests are never retried automatically', () async {
    final dio = Dio(BaseOptions(baseUrl: 'https://example.test'));
    final adapter = _SequenceAdapter([503, 200]);
    dio.httpClientAdapter = adapter;
    dio.interceptors.add(
      SafeRetryInterceptor(dio: dio, delay: (_) async {}, random: Random(1)),
    );

    await expectLater(
      dio.post<void>('/cash/operations'),
      throwsA(isA<DioException>()),
    );
    expect(adapter.requests, 1);
  });

  test('a request from an invalidated session is not retried', () async {
    final dio = Dio(BaseOptions(baseUrl: 'https://example.test'));
    final adapter = _SequenceAdapter([503, 200]);
    dio.httpClientAdapter = adapter;
    dio.interceptors.add(
      SafeRetryInterceptor(
        dio: dio,
        delay: (_) async {},
        isSessionCurrent: (_) => false,
        random: Random(1),
      ),
    );

    await expectLater(dio.get<void>('/private'), throwsA(isA<DioException>()));
    expect(adapter.requests, 1);
  });
}

class _SequenceAdapter implements HttpClientAdapter {
  _SequenceAdapter(this.statusCodes);

  final List<int> statusCodes;
  int requests = 0;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final index = requests < statusCodes.length
        ? requests
        : statusCodes.length - 1;
    final statusCode = statusCodes[index];
    requests++;
    return ResponseBody.fromString(
      '{}',
      statusCode,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}
