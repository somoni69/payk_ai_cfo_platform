import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:payk_ai_cfo_platform/core/network/api_client.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Security & Media Token Hygiene Tests (SEC-02, SEC-03, SEC-09)', () {
    late ApiClient apiClient;

    setUp(() async {
      FlutterSecureStorage.setMockInitialValues({});
      apiClient = ApiClient();
      await apiClient.clearAccessToken();
      await apiClient.clearRefreshToken();
    });

    tearDown(() async {
      await apiClient.clearAccessToken();
      await apiClient.clearRefreshToken();
    });

    group(
      'mediaUrl() token hygiene and public extension isolation (SEC-02, SEC-09)',
      () {
        test(
          'mediaUrl never leaks JWT access tokens in query parameters across all formats',
          () async {
            await apiClient.saveAccessToken('secret_jwt_access_token_12345');

            final pngUrl = apiClient.mediaUrl('/uploads/avatars/user_10.png');
            final jpgUrl = apiClient.mediaUrl('uploads/photos/receipt_99.jpg');
            final pdfUrl = apiClient.mediaUrl('/reports/z_report_2026_09.pdf');
            final excelUrl = apiClient.mediaUrl('exports/pnl_august.xlsx');

            expect(pngUrl, isNot(contains('token=')));
            expect(pngUrl, isNot(contains('secret_jwt_access_token_12345')));
            expect(pngUrl, startsWith(ApiClient.defaultBaseUrl));
            expect(pngUrl, endsWith('/uploads/avatars/user_10.png'));

            expect(jpgUrl, isNot(contains('token=')));
            expect(pdfUrl, isNot(contains('token=')));
            expect(pdfUrl, isNot(contains('secret_jwt_access_token_12345')));
            expect(excelUrl, isNot(contains('token=')));
          },
        );

        test(
          'null and whitespace paths return empty string safely without crashing',
          () {
            expect(apiClient.mediaUrl(null), '');
            expect(apiClient.mediaUrl(''), '');
            expect(apiClient.mediaUrl('   '), '');
          },
        );

        test('absolute external URLs (https://) pass through untouched', () {
          const external = 'https://s3.amazonaws.com/payk-cloud/doc.pdf';
          expect(apiClient.mediaUrl(external), external);
        });

        test(
          'insecure http URLs are upgraded to https automatically in production (SEC-09)',
          () {
            const insecure = 'http://cdn.payk.tj/images/promo.png';
            final secured = apiClient.mediaUrl(insecure);
            expect(secured, startsWith('https://'));
            expect(secured, 'https://cdn.payk.tj/images/promo.png');
          },
        );

        test(
          'leading slashes are normalized cleanly without multiple slashes in path',
          () {
            final normalized = apiClient.mediaUrl('///uploads/image.png');
            expect(normalized, endsWith('/uploads/image.png'));
            expect(normalized, isNot(contains('///')));
          },
        );
      },
    );

    group('Network Security Headers & Interceptor Behavior (SEC-05, SEC-08)', () {
      test(
        'onRequest interceptor injects Accept-Language and X-Request-ID',
        () {
          final options = RequestOptions(path: '/api/v1/cash');
          apiClient.cacheInterfaceLanguage('tg');

          final interceptor =
              apiClient.dio.interceptors.firstWhere(
                    (i) => i is InterceptorsWrapper,
                  )
                  as InterceptorsWrapper;
          interceptor.onRequest.call(options, RequestInterceptorHandler());

          expect(options.headers['Accept-Language'], 'tg');
          expect(options.headers['X-Request-ID'], isNotNull);
        },
      );

      test(
        'onRequest interceptor strips Authorization header when token is null/empty',
        () async {
          await apiClient.clearAccessToken();
          final options = RequestOptions(
            path: '/api/v1/cash',
            headers: {'Authorization': 'Bearer old_stale_token'},
          );

          final interceptor =
              apiClient.dio.interceptors.firstWhere(
                    (i) => i is InterceptorsWrapper,
                  )
                  as InterceptorsWrapper;
          interceptor.onRequest.call(options, RequestInterceptorHandler());

          expect(options.headers.containsKey('Authorization'), isFalse);
        },
      );

      test(
        'longRunningOptions applies extended timeouts for AI and report generation',
        () {
          final opts = ApiClient.longRunningOptions(
            receiveTimeout: const Duration(seconds: 120),
          );
          expect(opts.sendTimeout, const Duration(seconds: 30));
          expect(opts.receiveTimeout, const Duration(seconds: 120));
        },
      );
    });
  });
}
