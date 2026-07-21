import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:payk_ai_cfo_platform/features/cash/data/api_cash_repository.dart';
import 'package:payk_ai_cfo_platform/features/cash/domain/transaction_model.dart';

void main() {
  Transaction transaction({String? registerId}) => Transaction(
    id: '',
    title: 'Sale',
    category: 'sales',
    amount: 10,
    isIncome: true,
    paymentMethod: PaymentMethod.cash,
    dateTime: DateTime(2026),
    cashierName: 'cashier',
    registerId: registerId,
  );

  test('rejects an invalid explicit register without sending a request', () {
    final adapter = _RoutingAdapter((_) => _jsonResponse(200, const {}));
    final repository = ApiCashRepository(dio: _dio(adapter));

    expect(
      repository.addTransaction(transaction(registerId: 'not-a-number')),
      throwsA(isA<Exception>()),
    );
    expect(adapter.requests, isEmpty);
  });

  test('fails closed when no valid register is available', () async {
    final adapter = _RoutingAdapter((options) {
      expect(options.path, '/cash/registers');
      return _jsonResponse(200, const <dynamic>[]);
    });
    final repository = ApiCashRepository(dio: _dio(adapter));

    await expectLater(
      repository.addTransaction(transaction()),
      throwsA(isA<Exception>()),
    );
    expect(adapter.requests, hasLength(1));
    expect(adapter.requests.single.method, 'GET');
  });

  test('unknown active-shift errors are not converted to no active shift', () {
    final adapter = _RoutingAdapter((_) => _jsonResponse(503, const {}));
    final repository = ApiCashRepository(dio: _dio(adapter));

    expect(repository.getActiveShift(), throwsA(isA<Exception>()));
  });

  test('404 is the only API response interpreted as no active shift', () async {
    final adapter = _RoutingAdapter((_) => _jsonResponse(404, const {}));
    final repository = ApiCashRepository(dio: _dio(adapter));

    expect(await repository.getActiveShift(), isNull);
  });

  test('cash writes carry a unique idempotency key', () async {
    final adapter = _RoutingAdapter((options) {
      expect(options.path, '/cash/operations');
      return _jsonResponse(200, <String, dynamic>{
        'id': 7,
        'category': 'sales',
        'amount': '10.00',
        'type': 'income',
        'payment_method': 'cash',
        'occurred_at': '2026-07-18T10:00:00Z',
      });
    });
    final repository = ApiCashRepository(dio: _dio(adapter));

    await repository.addTransaction(transaction(registerId: '42'));

    final request = adapter.requests.single;
    expect(request.data['register_id'], 42);
    final key = request.headers['Idempotency-Key'];
    expect(key, isA<String>());
    expect((key as String).length, greaterThan(32));
  });
}

Dio _dio(HttpClientAdapter adapter) {
  final dio = Dio(
    BaseOptions(
      baseUrl: 'https://example.test',
      validateStatus: (status) => status != null && status < 400,
    ),
  );
  dio.httpClientAdapter = adapter;
  return dio;
}

ResponseBody _jsonResponse(int statusCode, Object data) {
  return ResponseBody.fromString(
    jsonEncode(data),
    statusCode,
    headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
    },
  );
}

class _RoutingAdapter implements HttpClientAdapter {
  _RoutingAdapter(this.handler);

  final ResponseBody Function(RequestOptions options) handler;
  final List<RequestOptions> requests = [];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    return handler(options);
  }

  @override
  void close({bool force = false}) {}
}
