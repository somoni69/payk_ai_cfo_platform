import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:payk_ai_cfo_platform/core/network/expiring_request_cache.dart';
import 'package:payk_ai_cfo_platform/features/dashboard/data/api_finance_repository.dart';
import 'package:payk_ai_cfo_platform/features/notifications/data/api_notifications_repository.dart';

void main() {
  test(
    'finance overview does not invent optional forecasts or deltas',
    () async {
      final adapter = _JsonAdapter((options) {
        expect(options.path, '/finance/overview');
        return <String, dynamic>{
          'balance': 100,
          'revenue': 250,
          'expenses': 150,
          'profit': 100,
          'cashflow': <dynamic>[],
        };
      });
      final repository = ApiFinanceRepository(dio: _dio(adapter));

      final overview = await repository.getOverview();

      expect(adapter.requests, 1);
      expect(overview.metrics.cashBalance, 100);
      expect(overview.metrics.breakEvenPoint, isNull);
      expect(overview.metrics.cashForecast, isNull);
      expect(overview.metrics.cashBalanceDelta, isNull);
      expect(overview.metrics.revenueDelta, isNull);
      expect(overview.metrics.expensesDelta, isNull);
      expect(overview.metrics.netProfitDelta, isNull);
      expect(overview.metrics.cashForecastDelta, isNull);
    },
  );

  test('notifications stay empty when all real sources are empty', () async {
    final adapter = _JsonAdapter((options) {
      switch (options.path) {
        case '/audit/logs':
        case '/cash/operations':
        case '/tasks':
          return <String, dynamic>{'items': <dynamic>[]};
        default:
          fail('Unexpected request: ${options.path}');
      }
    });
    final repository = ApiNotificationsRepository(dio: _dio(adapter));

    expect(await repository.getNotifications(), isEmpty);
    expect(adapter.requests, 3);

    expect(await repository.getNotifications(), isEmpty);
    expect(adapter.requests, 3, reason: 'fresh data must be reused');

    ExpiringRequestCache.invalidateAll();
    expect(await repository.getNotifications(), isEmpty);
    expect(
      adapter.requests,
      6,
      reason: 'a new session must reload all sources',
    );
  });
}

Dio _dio(HttpClientAdapter adapter) {
  final dio = Dio(BaseOptions(baseUrl: 'https://example.test'));
  dio.httpClientAdapter = adapter;
  return dio;
}

class _JsonAdapter implements HttpClientAdapter {
  _JsonAdapter(this.handler);

  final Object Function(RequestOptions options) handler;
  int requests = 0;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests++;
    return ResponseBody.fromString(
      jsonEncode(handler(options)),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}
