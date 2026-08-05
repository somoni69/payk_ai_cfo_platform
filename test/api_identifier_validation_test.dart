import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:payk_ai_cfo_platform/core/network/api_client.dart';
import 'package:payk_ai_cfo_platform/features/crm/data/api_crm_repository.dart';
import 'package:payk_ai_cfo_platform/features/hr/data/api_hr_repository.dart';
import 'package:payk_ai_cfo_platform/features/legal/data/api_legal_repository.dart';
import 'package:payk_ai_cfo_platform/features/warehouse/data/api_warehouse_repository.dart';

void main() {
  test('invalid domain identifiers never reach the API', () async {
    final adapter = _FailingAdapter();
    ApiClient().dio.httpClientAdapter = adapter;

    await expectLater(
      ApiCrmRepository().createDeal(
        clientId: '0',
        title: 'Deal',
        amount: 10,
        stage: 'lead',
      ),
      throwsA(isA<Exception>()),
    );
    await expectLater(
      ApiWarehouseRepository().createMovement(
        'not-an-id',
        'income',
        1,
        10,
        null,
      ),
      throwsA(isA<Exception>()),
    );
    await expectLater(
      ApiHrRepository().recalcSalary(employeeId: '-1', period: '2026-07'),
      throwsA(isA<Exception>()),
    );
    await expectLater(
      ApiLegalRepository().generateContract('', const {}),
      throwsA(isA<Exception>()),
    );
    await expectLater(
      ApiLegalRepository().updateDeadlineStatus('0', true),
      throwsA(isA<Exception>()),
    );

    expect(adapter.requests, 0);
  });
}

class _FailingAdapter implements HttpClientAdapter {
  int requests = 0;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) {
    requests++;
    return Future<ResponseBody>.error(
      StateError('Invalid IDs must be rejected before this request'),
    );
  }

  @override
  void close({bool force = false}) {}
}
