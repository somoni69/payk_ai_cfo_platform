import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:payk_ai_cfo_platform/core/localization/language_cubit.dart';
import 'package:payk_ai_cfo_platform/core/theme/app_colors.dart';
import 'package:payk_ai_cfo_platform/core/theme/app_theme.dart';
import 'package:payk_ai_cfo_platform/features/auth/bloc/auth_bloc.dart';
import 'package:payk_ai_cfo_platform/features/auth/bloc/auth_event.dart';
import 'package:payk_ai_cfo_platform/features/auth/bloc/auth_state.dart';
import 'package:payk_ai_cfo_platform/features/auth/presentation/login_screen.dart';
import 'package:payk_ai_cfo_platform/presentation/widgets/payk_logo.dart';

class _MockAuthBloc extends MockBloc<AuthEvent, AuthState>
    implements AuthBloc {}

String _extractAssetName(Image image) {
  final provider = image.image;
  final inner = provider is ResizeImage ? provider.imageProvider : provider;
  return (inner as AssetImage).assetName;
}

void main() {
  group('PaykLogo', () {
    testWidgets('uses lightAssetPath without tint in light theme', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: LedgerTheme.light,
          home: const Scaffold(
            body: PaykLogo(
              height: 52,
              lightAssetPath: 'assets/images/payk_logo.png',
              darkAssetPath: 'assets/images/payk_logo_transparent.png',
            ),
          ),
        ),
      );
      await tester.pump();

      final image = tester.widget<Image>(find.byType(Image));
      expect(_extractAssetName(image), 'assets/images/payk_logo.png');
      expect(image.color, isNull);
      expect(find.text('PAYK'), findsNothing);
    });

    testWidgets('uses darkAssetPath with high-contrast tint in dark theme', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: LedgerTheme.dark,
          home: const Scaffold(
            body: PaykLogo(
              height: 52,
              lightAssetPath: 'assets/images/payk_logo.png',
              darkAssetPath: 'assets/images/payk_logo_transparent.png',
            ),
          ),
        ),
      );
      await tester.pump();

      final image = tester.widget<Image>(find.byType(Image));
      expect(
        _extractAssetName(image),
        'assets/images/payk_logo_transparent.png',
      );
      expect(image.color, LedgerColors.dark.textPrimary);
      expect(find.text('PAYK'), findsNothing);
    });
  });

  group('LoginScreen logo integration', () {
    late _MockAuthBloc authBloc;
    late LanguageCubit languageCubit;

    setUp(() {
      authBloc = _MockAuthBloc();
      when(() => authBloc.state).thenReturn(AuthUnauthenticated());
      languageCubit = LanguageCubit(initialLanguageCode: 'ru');
    });

    tearDown(() async {
      await authBloc.close();
      await languageCubit.close();
    });

    Widget buildLogin(ThemeData theme) {
      return MultiBlocProvider(
        providers: [
          BlocProvider<AuthBloc>.value(value: authBloc),
          BlocProvider<LanguageCubit>.value(value: languageCubit),
        ],
        child: MaterialApp(theme: theme, home: const LoginScreen()),
      );
    }

    testWidgets('renders payk_logo.png on LoginScreen in light theme', (
      tester,
    ) async {
      await tester.pumpWidget(buildLogin(LedgerTheme.light));
      await tester.pump();

      final logoImage = tester.widget<Image>(
        find.descendant(
          of: find.byType(PaykLogo),
          matching: find.byType(Image),
        ),
      );
      expect(_extractAssetName(logoImage), 'assets/images/payk_logo.png');
      expect(logoImage.color, isNull);
      expect(find.text('PAYK'), findsNothing);
    });

    testWidgets(
      'renders tinted payk_logo_transparent.png on LoginScreen in dark theme',
      (tester) async {
        await tester.pumpWidget(buildLogin(LedgerTheme.dark));
        await tester.pump();

        final logoImage = tester.widget<Image>(
          find.descendant(
            of: find.byType(PaykLogo),
            matching: find.byType(Image),
          ),
        );
        expect(
          _extractAssetName(logoImage),
          'assets/images/payk_logo_transparent.png',
        );
        expect(logoImage.color, LedgerColors.dark.textPrimary);
        expect(find.text('PAYK'), findsNothing);
      },
    );
  });
}
