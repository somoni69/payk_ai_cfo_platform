import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_tabler_icons/flutter_tabler_icons.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/localization/language_cubit.dart';
import '../../../core/security/biometric_service.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/theme/theme_extensions.dart';
import '../../../features/auth/bloc/auth_bloc.dart';
import '../../../features/auth/bloc/auth_event.dart';
import '../../../features/auth/bloc/auth_state.dart';
import '../../../presentation/widgets/expansible_widget.dart';
import '../../../presentation/widgets/payk_logo.dart';

import '../../../core/network/api_client.dart';
import '../../../core/security/secure_storage_provider.dart';
import '../data/api_auth_repository.dart';

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

  final BiometricService _biometricService = BiometricService();
  BiometricKind _biometricKind = BiometricKind.none;

  List<LoginStore> _stores = const [];
  int? _selectedStoreId;

  bool _obscurePassword = true;
  bool _hasSavedSession = false;
  bool _showManualForm = false;

  /// Keeps the SMS form visible across [AuthLoading] while verifying the code.
  bool _showTwoFactor = false;

  @override
  void initState() {
    super.initState();
    _loadStores();
    _checkBiometrics();
  }

  Future<void> _checkBiometrics() async {
    try {
      final kind = await _biometricService.getPrimaryBiometricKind();
      final hasRefreshToken = await ApiClient().getRefreshToken() != null;
      final useBio =
          await AppSecureStorage.instance.read(key: 'use_biometrics') == 'true';
      if (!mounted) return;
      final isSaved = hasRefreshToken && useBio && kind != BiometricKind.none;
      setState(() {
        _biometricKind = kind;
        _hasSavedSession = isSaved;
        _showManualForm = !isSaved;
      });
    } catch (_) {}
  }

  Future<void> _loadStores() async {
    try {
      final stores = await ApiAuthRepository().fetchLoginStores();
      if (!mounted) return;
      setState(() {
        _stores = stores;
      });
    } catch (_) {}
  }

  String _getBiometricLabel(LanguageCubit language) {
    return switch (_biometricKind) {
      BiometricKind.faceId => 'Face ID',
      BiometricKind.touchId => 'Touch ID',
      BiometricKind.fingerprint => language.translate('biometric_fingerprint'),
      BiometricKind.faceUnlock => language.translate('biometric_face'),
      _ => language.translate('login_biometric'),
    };
  }

  IconData _getBiometricIcon() {
    return switch (_biometricKind) {
      BiometricKind.faceId || BiometricKind.faceUnlock => TablerIcons.scan,
      _ => TablerIcons.fingerprint,
    };
  }

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
      body: SafeArea(
        child: BlocConsumer<AuthBloc, AuthState>(
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
                padding: const EdgeInsets.symmetric(
                  horizontal: 24.0,
                  vertical: 16.0,
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Переключатель языка в правом верхнем углу
                    Align(
                      alignment: Alignment.topRight,
                      child: Container(
                        decoration: BoxDecoration(
                          color: colors.surface,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: colors.border),
                        ),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(20),
                            onTap: () {
                              HapticFeedback.lightImpact();
                              final next = language.state.languageCode == 'ru'
                                  ? 'tg'
                                  : 'ru';
                              context.read<LanguageCubit>().setLanguage(next);
                            },
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 6,
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    TablerIcons.world,
                                    size: 15,
                                    color: colors.brand,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    language.state.languageCode == 'ru'
                                        ? 'Русский'
                                        : 'Тоҷикӣ',
                                    style: textStyles.captionSans.copyWith(
                                      fontWeight: FontWeight.w600,
                                      color: colors.textPrimary,
                                      fontSize: 12,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  Icon(
                                    TablerIcons.chevron_down,
                                    size: 13,
                                    color: colors.textSecondary,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Премиальный блок брендинга (только логотип)
                    Center(
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: colors.surface,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: colors.border),
                          boxShadow: [
                            BoxShadow(
                              color: colors.textPrimary.withValues(alpha: 0.03),
                              blurRadius: 10,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: const PaykLogo(height: 52),
                      ),
                    ),
                    const SizedBox(height: 28),

                    // Экран разблокировки по сохраненной сессии ИЛИ форма ввода
                    if (showTwoFactor)
                      _buildTwoFactorCard(
                        context,
                        language: language,
                        textStyles: textStyles,
                        isLoading: isLoading,
                      )
                    else if (_hasSavedSession && !_showManualForm)
                      _buildBiometricUnlockCard(
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

                    // Если открыта ручная форма, но на устройстве доступна биометрия (без сохраненной сессии)
                    if (!showTwoFactor &&
                        !_hasSavedSession &&
                        _biometricKind != BiometricKind.none) ...[
                      const SizedBox(height: 20),
                      Row(
                        children: [
                          Expanded(child: Divider(color: colors.border)),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            child: Text(
                              language.translate('login_or_biometric'),
                              style: textStyles.captionSans.copyWith(
                                color: colors.textSecondary,
                                fontSize: 12,
                              ),
                            ),
                          ),
                          Expanded(child: Divider(color: colors.border)),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Container(
                        decoration: BoxDecoration(
                          color: colors.surface,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: colors.border),
                          boxShadow: [
                            BoxShadow(
                              color: colors.textPrimary.withValues(alpha: 0.03),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(14),
                            onTap: isLoading
                                ? null
                                : () {
                                    HapticFeedback.lightImpact();
                                    context.read<AuthBloc>().add(
                                      BiometricLoginRequested(),
                                    );
                                  },
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 12,
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 38,
                                    height: 38,
                                    decoration: BoxDecoration(
                                      color: colors.brand.withValues(
                                        alpha: 0.1,
                                      ),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Icon(
                                      _getBiometricIcon(),
                                      color: colors.brand,
                                      size: 22,
                                    ),
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          '${language.translate('login_biometric_action')} ${_getBiometricLabel(language)}',
                                          style: textStyles.bodySans.copyWith(
                                            fontWeight: FontWeight.w600,
                                            color: colors.textPrimary,
                                            fontSize: 14,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          language.translate(
                                            'login_security_note',
                                          ),
                                          style: textStyles.captionSans
                                              .copyWith(
                                                color: colors.textSecondary,
                                                fontSize: 11,
                                              ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Icon(
                                    TablerIcons.chevron_right,
                                    size: 18,
                                    color: colors.textSecondary,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],

                    const SizedBox(height: 28),

                    // Сквозная безопасность и Политика конфиденциальности
                    Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              TablerIcons.shield_check,
                              size: 15,
                              color: colors.textSecondary,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              language.translate('login_security_note'),
                              style: textStyles.smallSans.copyWith(
                                color: colors.textSecondary,
                                fontSize: 11.5,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Text(
                            language.translate('login_privacy_agreement'),
                            style: textStyles.smallSans.copyWith(
                              color: colors.textTooltip,
                              fontSize: 11,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                        const SizedBox(height: 4),
                        InkWell(
                          onTap: () => launchUrl(
                            Uri.parse(
                              'https://payk-ecosystem.vercel.app/privacy',
                            ),
                            mode: LaunchMode.externalApplication,
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(4.0),
                            child: Text(
                              language.translate('more_privacy_policy'),
                              style: textStyles.captionSans.copyWith(
                                color: colors.brand,
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
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
      ),
    );
  }

  /// Премиальная карточка быстрого биометрического входа при сохраненной сессии
  Widget _buildBiometricUnlockCard(
    BuildContext context, {
    required LanguageCubit language,
    required LedgerTextStyles textStyles,
    required bool isLoading,
  }) {
    final colors = context.colors;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.border),
        boxShadow: [
          BoxShadow(
            color: colors.textPrimary.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Бейдж активной защищенной сессии
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: colors.brand.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(TablerIcons.shield_check, size: 14, color: colors.brand),
                const SizedBox(width: 6),
                Text(
                  language.translate('login_session_saved'),
                  style: textStyles.captionSans.copyWith(
                    color: colors.brand,
                    fontWeight: FontWeight.w600,
                    fontSize: 11.5,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 22),

          // Большой интерактивный сенсор биометрии
          GestureDetector(
            onTap: isLoading
                ? null
                : () {
                    HapticFeedback.mediumImpact();
                    context.read<AuthBloc>().add(BiometricLoginRequested());
                  },
            child: Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                color: colors.brand.withValues(alpha: 0.07),
                shape: BoxShape.circle,
                border: Border.all(
                  color: colors.brand.withValues(alpha: 0.35),
                  width: 1.5,
                ),
              ),
              child: Center(
                child: isLoading
                    ? SizedBox(
                        width: 32,
                        height: 32,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: colors.brand,
                        ),
                      )
                    : Icon(_getBiometricIcon(), size: 44, color: colors.brand),
              ),
            ),
          ),
          const SizedBox(height: 18),

          Text(
            '${language.translate('login_tap_biometric')} ${_getBiometricLabel(language)}',
            style: textStyles.bodySans.copyWith(
              fontWeight: FontWeight.w600,
              fontSize: 15,
              color: colors.textPrimary,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 6),
          Text(
            language.translate('login_security_note'),
            style: textStyles.captionSans.copyWith(
              color: colors.textSecondary,
              fontSize: 12,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),

          // Кнопка переключения на логин/пароль
          SizedBox(
            width: double.infinity,
            height: 46,
            child: OutlinedButton.icon(
              onPressed: () {
                HapticFeedback.lightImpact();
                setState(() => _showManualForm = true);
              },
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: colors.border),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              icon: const Icon(TablerIcons.user_edit, size: 18),
              label: Text(
                language.translate('login_use_password'),
                style: textStyles.captionSans.copyWith(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPasswordCard(
    BuildContext context, {
    required LanguageCubit language,
    required LedgerTextStyles textStyles,
    required bool isLoading,
  }) {
    final colors = context.colors;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.border),
        boxShadow: [
          BoxShadow(
            color: colors.textPrimary.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(TablerIcons.lock_access, size: 18, color: colors.brand),
                const SizedBox(width: 8),
                Text(
                  language.translate('login_title'),
                  style: textStyles.bodySans.copyWith(
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                  ),
                ),
              ],
            ),
            if (_stores.isNotEmpty) ...[
              const SizedBox(height: 16),
              ExpansibleWidget<int?>.selection(
                cardPadding: EdgeInsets.zero,
                tilePadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 4,
                ),
                title: Row(
                  children: [
                    Icon(
                      TablerIcons.building_store,
                      size: 20,
                      color: context.colors.brand,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _selectedStoreId == null
                            ? language.translate('login_store_root_owner')
                            : (_stores
                                      .where((s) => s.id == _selectedStoreId)
                                      .map(
                                        (s) =>
                                            s.location != null &&
                                                s.location!.isNotEmpty
                                            ? '${s.name} (${s.location})'
                                            : s.name,
                                      )
                                      .firstOrNull ??
                                  language.translate('login_store_root_owner')),
                        style: textStyles.bodySans.copyWith(
                          fontWeight: FontWeight.w500,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                subtitle: Text(
                  language.translate('login_store_label'),
                  style: textStyles.captionSans.copyWith(
                    color: context.colors.textSecondary,
                  ),
                ),
                items: [null, ..._stores.map((s) => s.id)],
                selectedValue: _selectedStoreId,
                itemLabelBuilder: (id) {
                  if (id == null) {
                    return language.translate('login_store_root_owner');
                  }
                  final s = _stores.where((x) => x.id == id).firstOrNull;
                  if (s == null) return '#$id';
                  return s.location != null && s.location!.isNotEmpty
                      ? '${s.name} (${s.location})'
                      : s.name;
                },
                onSelected: isLoading
                    ? null
                    : (val) => setState(() => _selectedStoreId = val),
              ),
            ],
            const SizedBox(height: 16),
            TextFormField(
              controller: _usernameController,
              style: textStyles.bodySans,
              enabled: !isLoading,
              keyboardType: TextInputType.emailAddress,
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
              obscureText: _obscurePassword,
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
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscurePassword ? TablerIcons.eye_off : TablerIcons.eye,
                    size: 20,
                    color: colors.textSecondary,
                  ),
                  onPressed: () {
                    setState(() => _obscurePassword = !_obscurePassword);
                  },
                ),
              ),
            ),
            const SizedBox(height: 22),
            SizedBox(
              height: 48,
              child: ElevatedButton(
                onPressed: isLoading ? null : () => _submitPassword(context),
                style: ElevatedButton.styleFrom(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
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
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            language.translate('login_submit'),
                            style: textStyles.bodySans.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Icon(
                            TablerIcons.arrow_right,
                            size: 18,
                            color: Colors.white,
                          ),
                        ],
                      ),
              ),
            ),
            if (_hasSavedSession && _biometricKind != BiometricKind.none) ...[
              const SizedBox(height: 10),
              TextButton.icon(
                onPressed: () {
                  HapticFeedback.lightImpact();
                  setState(() => _showManualForm = false);
                },
                icon: Icon(_getBiometricIcon(), size: 18),
                label: Text(language.translate('login_back_to_biometric')),
              ),
            ],
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
    final colors = context.colors;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.border),
        boxShadow: [
          BoxShadow(
            color: colors.textPrimary.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Form(
        key: _twoFactorFormKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(TablerIcons.shield_lock, size: 18, color: colors.brand),
                const SizedBox(width: 8),
                Text(
                  language.translate('login_2fa_title'),
                  style: textStyles.bodySans.copyWith(
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              language.translate('login_2fa_hint'),
              style: textStyles.captionSans.copyWith(
                color: colors.textSecondary,
              ),
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
                prefixIcon: const Icon(TablerIcons.shield_check, size: 20),
              ),
            ),
            const SizedBox(height: 22),
            SizedBox(
              height: 48,
              child: ElevatedButton(
                onPressed: isLoading ? null : () => _submitTwoFactor(context),
                style: ElevatedButton.styleFrom(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
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
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            language.translate('login_2fa_submit'),
                            style: textStyles.bodySans.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Icon(
                            TablerIcons.arrow_right,
                            size: 18,
                            color: Colors.white,
                          ),
                        ],
                      ),
              ),
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
        storeId: _selectedStoreId,
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
