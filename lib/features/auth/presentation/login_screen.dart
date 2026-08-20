import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_tabler_icons/flutter_tabler_icons.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/localization/language_cubit.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/theme/theme_extensions.dart';
import '../../../features/auth/bloc/auth_bloc.dart';
import '../../../features/auth/bloc/auth_event.dart';
import '../../../features/auth/bloc/auth_state.dart';
import '../../../presentation/widgets/ledger_card.dart';
import '../../../presentation/widgets/payk_logo.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _twoFactorFormKey = GlobalKey<FormState>();
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _twoFactorController = TextEditingController();

  /// Keeps the SMS form visible across [AuthLoading] while verifying the code.
  bool _showTwoFactor = false;

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    _twoFactorController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final textStyles = context.textStyles;
    final language = context.watch<LanguageCubit>();

    return Scaffold(
      backgroundColor: colors.background,
      body: BlocConsumer<AuthBloc, AuthState>(
        listener: (context, state) {
          if (state is AuthError) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  language.resolveMessage(state.message),
                  style: textStyles.bodySans.copyWith(color: colors.surface),
                ),
                backgroundColor: colors.accentRed,
              ),
            );
          }
          if (state is AuthTwoFactorRequired) {
            setState(() => _showTwoFactor = true);
            _twoFactorController.clear();
          } else if (state is AuthAuthenticated ||
              state is AuthUnauthenticated) {
            if (_showTwoFactor) {
              setState(() => _showTwoFactor = false);
            }
          }
        },
        builder: (context, state) {
          final isLoading = state is AuthLoading;
          final showTwoFactor =
              _showTwoFactor || state is AuthTwoFactorRequired;

          return Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Center(child: PaykLogo(height: 52)),
                  const SizedBox(height: 32),
                  if (showTwoFactor)
                    _buildTwoFactorCard(
                      context,
                      language: language,
                      textStyles: textStyles,
                      isLoading: isLoading,
                    )
                  else
                    _buildPasswordCard(
                      context,
                      language: language,
                      textStyles: textStyles,
                      isLoading: isLoading,
                    ),
                  if (!showTwoFactor) ...[
                    const SizedBox(height: 20),
                    if (!isLoading)
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          OutlinedButton.icon(
                            onPressed: () {
                              context.read<AuthBloc>().add(
                                BiometricLoginRequested(),
                              );
                            },
                            icon: const Icon(TablerIcons.fingerprint),
                            label: Text(language.translate('login_biometric')),
                          ),
                        ],
                      ),
                  ],
                  const SizedBox(height: 32),
                  // Privacy Policy Link (Moderation requirement)
                  Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Text(
                          language.translate('login_privacy_agreement'),
                          style: textStyles.smallSans.copyWith(
                            color: colors.textTooltip,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      const SizedBox(height: 8),
                      InkWell(
                        onTap: () => launchUrl(
                          Uri.parse(
                            'https://payk-ecosystem.vercel.app/privacy',
                          ),
                          mode: LaunchMode.externalApplication,
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Text(
                            language.translate('more_privacy_policy'),
                            style: textStyles.captionSans.copyWith(
                              color: colors.textSecondary,
                              decoration: TextDecoration.underline,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildPasswordCard(
    BuildContext context, {
    required LanguageCubit language,
    required LedgerTextStyles textStyles,
    required bool isLoading,
  }) {
    return LedgerCard(
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              language.translate('login_title'),
              style: textStyles.bodySans.copyWith(fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _usernameController,
              style: textStyles.bodySans,
              enabled: !isLoading,
              textInputAction: TextInputAction.next,
              validator: (val) => val == null || val.trim().isEmpty
                  ? language.translate('login_username_required')
                  : null,
              decoration: InputDecoration(
                labelText: language.translate('login_username_label'),
                prefixIcon: const Icon(TablerIcons.user, size: 20),
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _passwordController,
              obscureText: true,
              style: textStyles.bodySans,
              enabled: !isLoading,
              textInputAction: TextInputAction.done,
              onFieldSubmitted: (_) => _submitPassword(context),
              validator: (val) => val == null || val.trim().isEmpty
                  ? language.translate('login_password_required')
                  : null,
              decoration: InputDecoration(
                labelText: language.translate('login_password_label'),
                prefixIcon: const Icon(TablerIcons.lock, size: 20),
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: isLoading ? null : () => _submitPassword(context),
              child: isLoading
                  ? SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          context.colors.surface,
                        ),
                      ),
                    )
                  : Text(language.translate('login_submit')),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTwoFactorCard(
    BuildContext context, {
    required LanguageCubit language,
    required LedgerTextStyles textStyles,
    required bool isLoading,
  }) {
    return LedgerCard(
      child: Form(
        key: _twoFactorFormKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              language.translate('login_2fa_title'),
              style: textStyles.bodySans.copyWith(fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 8),
            Text(
              language.translate('login_2fa_hint'),
              style: textStyles.captionSans,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _twoFactorController,
              style: textStyles.bodySans,
              enabled: !isLoading,
              keyboardType: TextInputType.number,
              textInputAction: TextInputAction.done,
              autofocus: true,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(8),
              ],
              onFieldSubmitted: (_) => _submitTwoFactor(context),
              validator: (val) => val == null || val.trim().isEmpty
                  ? language.translate('login_2fa_code_required')
                  : null,
              decoration: InputDecoration(
                labelText: language.translate('login_2fa_code_label'),
                prefixIcon: const Icon(TablerIcons.shield_lock, size: 20),
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: isLoading ? null : () => _submitTwoFactor(context),
              child: isLoading
                  ? SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          context.colors.surface,
                        ),
                      ),
                    )
                  : Text(language.translate('login_2fa_submit')),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: isLoading
                  ? null
                  : () {
                      setState(() => _showTwoFactor = false);
                      context.read<AuthBloc>().add(const TwoFactorCancelled());
                    },
              child: Text(language.translate('login_2fa_back')),
            ),
          ],
        ),
      ),
    );
  }

  void _submitPassword(BuildContext context) {
    if (!_formKey.currentState!.validate()) return;
    context.read<AuthBloc>().add(
      LoginSubmitted(
        username: _usernameController.text,
        password: _passwordController.text,
      ),
    );
  }

  void _submitTwoFactor(BuildContext context) {
    if (!_twoFactorFormKey.currentState!.validate()) return;
    context.read<AuthBloc>().add(
      TwoFactorSubmitted(code: _twoFactorController.text),
    );
  }
}
