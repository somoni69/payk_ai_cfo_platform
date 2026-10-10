import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:payk_ai_cfo_platform/features/audit/data/api_audit_repository.dart';
import 'package:payk_ai_cfo_platform/features/branches/data/api_branches_repository.dart';
import 'package:payk_ai_cfo_platform/features/fin_ops/data/api_fin_ops_repository.dart';

/// Answers every request with [status] and [body]; counts requests.
class _Adapter implements HttpClientAdapter {
  _Adapter(this.status, [this.body = const <String, dynamic>{}]);

  final int status;
  final Object body;
  final paths = <String>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    paths.add('${options.method} ${options.path}');
    return ResponseBody.fromString(
      jsonEncode(body),
      status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

Dio _dio(_Adapter adapter) =>
    Dio(BaseOptions(baseUrl: 'https://example.test'))
      ..httpClientAdapter = adapter;

Matcher _failsWith(String key) =>
    throwsA(predicate((e) => e.toString().contains(key), 'error key $key'));

void main() {
  group('ApiFinOpsRepository', () {
    test('load failures surface instead of mock banks and transfers', () async {
      final repo = ApiFinOpsRepository(dio: _dio(_Adapter(500)));

      await expectLater(repo.getBankAccounts(), _failsWith('error_'));
      await expectLater(repo.getEncashments(), _failsWith('error_'));
      await expectLater(repo.getStoreTransfers(), _failsWith('error_'));
      await expectLater(repo.getFinancialAids(), _failsWith('error_'));
      await expectLater(repo.getBranchBalances(), _failsWith('error_'));
    });

    test('a non-list answer is an invalid response, not mock data', () async {
      final repo = ApiFinOpsRepository(dio: _dio(_Adapter(200, {'x': 1})));

      await expectLater(repo.getBankAccounts(), _failsWith('error_'));
    });

    test('write failures surface instead of a local fake success', () async {
      final repo = ApiFinOpsRepository(dio: _dio(_Adapter(500)));

      await expectLater(repo.createBank(name: 'Alif'), _failsWith('error_'));
      await expectLater(repo.deleteBank('1'), _failsWith('error_'));
      await expectLater(repo.cancelStoreTransfer('1'), _failsWith('error_'));
      await expectLater(
        repo.updateTransferStatus(transferId: '1', status: 'receive'),
        _failsWith('error_'),
      );
      await expectLater(
        repo.repayFinancialAid(aidId: '1', amount: 10),
        _failsWith('error_'),
      );
      await expectLater(
        repo.createStoreTransfer(fromBranch: '1', toBranch: '2', amount: 5),
        _failsWith('error_'),
      );
    });

    test('an empty server list stays empty', () async {
      final repo = ApiFinOpsRepository(dio: _dio(_Adapter(200, <dynamic>[])));
      expect(await repo.getBankAccounts(), isEmpty);
      expect(await repo.getStoreTransfers(), isEmpty);
    });
  });

  group('ApiBranchesRepository', () {
    test('failures surface instead of three mock branches', () async {
      final repo = ApiBranchesRepository(dio: _dio(_Adapter(503)));

      await expectLater(repo.getBranches(), _failsWith('error_'));
      await expectLater(
        repo.createBranch(name: 'A', address: 'B', phone: 'C'),
        _failsWith('error_'),
      );
      await expectLater(repo.deleteBranch('1'), _failsWith('error_'));
    });

    test('an empty list stays empty', () async {
      final repo = ApiBranchesRepository(dio: _dio(_Adapter(200, <dynamic>[])));
      expect(await repo.getBranches(), isEmpty);
    });
  });

  group('ApiAuditRepository', () {
    test('failures surface instead of mock logs and alerts', () async {
      final repo = ApiAuditRepository(dio: _dio(_Adapter(500)));

      await expectLater(repo.getAuditLogs(), _failsWith('error_'));
      await expectLater(repo.getAuditAlerts(), _failsWith('error_'));
      await expectLater(repo.runAnomalyDetectors(), _failsWith('error_'));
    });

    test('an empty journal is shown as empty, not replaced by mocks', () async {
      final repo = ApiAuditRepository(
        dio: _dio(_Adapter(200, {'items': <dynamic>[]})),
      );
      expect(await repo.getAuditLogs(), isEmpty);
      expect(await repo.getAuditAlerts(), isEmpty);
    });
  });
}
