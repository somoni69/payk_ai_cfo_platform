import 'package:flutter_test/flutter_test.dart';
import 'package:payk_ai_cfo_platform/core/error/app_failure.dart';
import 'package:payk_ai_cfo_platform/core/error/result.dart';
import 'package:payk_ai_cfo_platform/core/network/user_facing_error.dart';

void main() {
  group(
    'AppFailure Sealed Hierarchy Tests (Tier 1 Isolation & Tier 2 Boundary)',
    () {
      test(
        'NetworkFailure defaults to ErrorKeys.offline and stores debug metadata',
        () {
          final st = StackTrace.current;
          final failure = NetworkFailure(
            debugMessage: 'Socket closed prematurely by host',
            stackTrace: st,
          );

          expect(failure.translationKey, ErrorKeys.offline);
          expect(failure.debugMessage, 'Socket closed prematurely by host');
          expect(failure.stackTrace, st);
          expect(failure.toString(), ErrorKeys.offline);
          expect(failure.props, [
            ErrorKeys.offline,
            'Socket closed prematurely by host',
          ]);
        },
      );

      test(
        'ServerFailure captures HTTP status code and custom translation keys',
        () {
          const failure500 = ServerFailure(
            statusCode: 500,
            debugMessage: 'Internal server error in Laravel backend',
          );
          expect(failure500.translationKey, ErrorKeys.server);
          expect(failure500.statusCode, 500);
          expect(failure500.props, [
            ErrorKeys.server,
            500,
            'Internal server error in Laravel backend',
          ]);

          const failure503 = ServerFailure(
            translationKey: 'server_maintenance',
            statusCode: 503,
          );
          expect(failure503.translationKey, 'server_maintenance');
          expect(failure503.statusCode, 503);
        },
      );

      test('AuthFailure defaults to ErrorKeys.sessionExpired', () {
        const failure = AuthFailure(
          debugMessage: 'Expired JWT refresh rejected',
        );
        expect(failure.translationKey, ErrorKeys.sessionExpired);
        expect(failure.debugMessage, 'Expired JWT refresh rejected');
      });

      test('RepositoryFailure keeps a localization key as a typed failure', () {
        const failure = RepositoryFailure(
          ErrorKeys.loadFailed,
          debugMessage: 'Dio payload',
        );
        expect(failure, isA<Exception>());
        expect(failure, isA<AppFailure>());
        expect(failure.translationKey, ErrorKeys.loadFailed);
        expect(failure.toString(), ErrorKeys.loadFailed);
        expect(userFacingError(failure), ErrorKeys.loadFailed);
      });

      test('ValidationFailure holds structured field errors map', () {
        const fieldErrors = {
          'amount': [
            'Сумма должна быть больше нуля',
            'Недопустимый формат числа',
          ],
          'category': ['Категория обязательна для заполнения'],
        };

        const failure = ValidationFailure(
          fieldErrors: fieldErrors,
          debugMessage: 'Form validation rejected with 422',
        );

        expect(failure.translationKey, ErrorKeys.validation);
        expect(failure.fieldErrors.length, 2);
        expect(failure.fieldErrors['amount']?.length, 2);
        expect(failure.props, [
          ErrorKeys.validation,
          fieldErrors,
          'Form validation rejected with 422',
        ]);
      });

      test('TimeoutFailure defaults to ErrorKeys.timeout', () {
        const failure = TimeoutFailure(
          debugMessage: 'Connection timeout after 15s',
        );
        expect(failure.translationKey, ErrorKeys.timeout);
        expect(failure.debugMessage, 'Connection timeout after 15s');
      });

      test('NotFoundFailure defaults to ErrorKeys.noResource', () {
        const failure = NotFoundFailure(
          debugMessage: 'Transaction #999 not found',
        );
        expect(failure.translationKey, ErrorKeys.noResource);
        expect(failure.debugMessage, 'Transaction #999 not found');
      });

      test('CacheFailure defaults to ErrorKeys.loadFailed', () {
        const failure = CacheFailure(debugMessage: 'Disk cache corrupted');
        expect(failure.translationKey, ErrorKeys.loadFailed);
      });

      test('GenericFailure defaults to ErrorKeys.generic', () {
        const failure = GenericFailure(
          debugMessage: 'Unhandled platform exception',
        );
        expect(failure.translationKey, ErrorKeys.generic);
      });

      test('Value equality across identical AppFailures', () {
        const f1 = NetworkFailure(debugMessage: 'err');
        const f2 = NetworkFailure(debugMessage: 'err');
        const f3 = NetworkFailure(debugMessage: 'other');

        expect(f1, equals(f2));
        expect(f1.hashCode, equals(f2.hashCode));
        expect(f1, isNot(equals(f3)));
      });
    },
  );

  group('Monadic Result<T> Tests (Tier 1 & Tier 2)', () {
    group('Success<T> Branch', () {
      const result = Result.success(42);

      test('inspectors and getters', () {
        expect(result.isSuccess, isTrue);
        expect(result.isFailure, isFalse);
        expect(result.dataOrNull, 42);
        expect(result.failureOrNull, isNull);
        expect(result.getOrThrow(), 42);
        expect(result.toString(), 'Success(42)');
      });

      test('when & fold transformations', () {
        final transformed = result.when(
          onSuccess: (data) => 'Result is $data',
          onFailure: (failure) => 'Error',
        );
        expect(transformed, 'Result is 42');

        final folded = result.fold((failure) => -1, (data) => data * 2);
        expect(folded, 84);
      });

      test('map and flatMap functors', () {
        final mapped = result.map((data) => 'value_$data');
        expect(mapped.isSuccess, isTrue);
        expect(mapped.dataOrNull, 'value_42');

        final flatMappedSuccess = result.flatMap(
          (data) => Result.success(data + 10),
        );
        expect(flatMappedSuccess.isSuccess, isTrue);
        expect(flatMappedSuccess.dataOrNull, 52);

        final flatMappedFailure = result.flatMap<String>(
          (data) => const Result.failure(
            NetworkFailure(debugMessage: 'downstream fail'),
          ),
        );
        expect(flatMappedFailure.isFailure, isTrue);
        expect(flatMappedFailure.failureOrNull, isA<NetworkFailure>());
      });

      test('value equality and hashCode', () {
        const s1 = Result.success('test');
        const s2 = Result.success('test');
        const s3 = Result.success('other');

        expect(s1, equals(s2));
        expect(s1.hashCode, equals(s2.hashCode));
        expect(s1, isNot(equals(s3)));
      });
    });

    group('FailureResult<T> Branch', () {
      const failureObj = ServerFailure(
        statusCode: 500,
        debugMessage: 'Backend crash',
      );
      const result = Result<int>.failure(failureObj);

      test('inspectors and getters', () {
        expect(result.isSuccess, isFalse);
        expect(result.isFailure, isTrue);
        expect(result.dataOrNull, isNull);
        expect(result.failureOrNull, equals(failureObj));
        expect(() => result.getOrThrow(), throwsA(isA<ServerFailure>()));
        expect(result.toString(), contains('FailureResult'));
      });

      test('when & fold transformations', () {
        final handled = result.when(
          onSuccess: (data) => 'Success: $data',
          onFailure: (failure) => 'Failed with ${failure.translationKey}',
        );
        expect(handled, 'Failed with ${ErrorKeys.server}');

        final folded = result.fold(
          (failure) => failure.props.first.toString(),
          (data) => 'data',
        );
        expect(folded, ErrorKeys.server);
      });

      test('map and flatMap bypass and propagate failure', () {
        final mapped = result.map((data) => data * 100);
        expect(mapped.isFailure, isTrue);
        expect(mapped.failureOrNull, equals(failureObj));

        final flatMapped = result.flatMap((data) => Result.success('new data'));
        expect(flatMapped.isFailure, isTrue);
        expect(flatMapped.failureOrNull, equals(failureObj));
      });

      test('value equality and hashCode', () {
        const f1 = Result<String>.failure(AuthFailure());
        const f2 = Result<String>.failure(AuthFailure());
        const f3 = Result<String>.failure(TimeoutFailure());

        expect(f1, equals(f2));
        expect(f1.hashCode, equals(f2.hashCode));
        expect(f1, isNot(equals(f3)));
      });
    });
  });
}
