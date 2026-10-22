import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:payk_ai_cfo_platform/features/fin_ops/data/api_fin_ops_repository.dart';

class _CaptureAdapter implements HttpClientAdapter {
  RequestOptions? lastOptions;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    lastOptions = options;
    return ResponseBody.fromString(
      '{}',
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  test('FinOps writes send an Idempotency-Key header', () async {
    final adapter = _CaptureAdapter();
    final dio = Dio(BaseOptions(baseUrl: 'https://example.test/api'))
      ..httpClientAdapter = adapter;
    final repository = ApiFinOpsRepository(dio: dio);

    await repository.deleteBank('42');

    final key = adapter.lastOptions?.headers['Idempotency-Key'];
    expect(key, isA<String>());
    expect(key, isNotEmpty);
  });
}
