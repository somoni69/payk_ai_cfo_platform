import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_tabler_icons/flutter_tabler_icons.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';
import '../../core/localization/language_cubit.dart';
import '../../core/theme/theme_extensions.dart';
import '../../features/auth/bloc/auth_bloc.dart';
import '../../features/auth/bloc/auth_event.dart';
import '../../features/auth/bloc/auth_state.dart';
import '../../features/auth/domain/app_access.dart';
import '../widgets/ledger_card.dart';
import '../widgets/ledger_collapsing_header.dart';
import '../widgets/payk_logo.dart';

class MoreScreen extends StatefulWidget {
  const MoreScreen({super.key});

  @override
  State<MoreScreen> createState() => _MoreScreenState();
}

class _MoreScreenState extends State<MoreScreen> {
  final _storage = const FlutterSecureStorage();
  bool _biometricEnabled = false;

  @override
  void initState() {
    super.initState();
    _loadBiometricSettings();
  }

  Future<void> _loadBiometricSettings() async {
    try {
      final value = await _storage.read(key: 'use_biometrics');
      if (!mounted) return;
      setState(() => _biometricEnabled = value == 'true');
    } catch (_) {
      if (!mounted) return;
      setState(() => _biometricEnabled = false);
    }
  }

  void _onBiometricToggleChanged(bool val) async {
    final biometricReason = context.translate('more_biometric_reason');

    if (val) {
      final localAuth = LocalAuthentication();
      try {
        final isAvailable = await localAuth.canCheckBiometrics;
        final isDeviceSupported = await localAuth.isDeviceSupported();

        if (!isAvailable || !isDeviceSupported) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(context.translate('more_biometric_unavailable')),
              ),
            );
          }
          return;
        }

        final authenticated = await localAuth.authenticate(
          localizedReason: biometricReason,
          biometricOnly: true,
          persistAcrossBackgrounding: true,
        );

        if (authenticated) {
          await _storage.write(key: 'use_biometrics', value: 'true');
          if (mounted) {
            setState(() {
              _biometricEnabled = true;
            });
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(context.translate('more_biometric_enabled')),
              ),
            );
          }
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(context.translate('more_biometric_cancelled')),
              ),
            );
          }
        }
      } catch (_) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(context.translate('more_biometric_error'))),
          );
        }
      }
    } else {
      try {
        await _storage.write(key: 'use_biometrics', value: 'false');
        if (!mounted) return;
        setState(() => _biometricEnabled = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.translate('more_biometric_disabled'))),
        );
      } catch (_) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.translate('more_biometric_error'))),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final textStyles = context.textStyles;

    final locale = context.watch<LanguageCubit>().state;
    final currentLanguageLabel = locale.languageCode == 'tg'
        ? context.translate('language_tajik')
        : context.translate('language_russian');
    final authState = context.watch<AuthBloc>().state;
    final role = authState is AuthAuthenticated ? authState.role : null;
    final moduleRows = role == null ? <Widget>[] : _buildModuleRows(role);

    return Scaffold(
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) {
          return [
            LedgerCollapsingHeader(
              title: context.translate('more'),
              pinned: true,
              floating: true,
              snap: true,
              actions: const [
                PaykLogo(height: 22),
              ],
            ),
          ];
        },
        body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Профиль пользователя
              _buildProfileCard(),
              const SizedBox(height: 20),

              // Безопасность и настройки
              Text(
                context.translate('more_access_settings'),
                style: textStyles.bodySans.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              LedgerCard(
                padding: EdgeInsets.zero,
                child: Column(
                  children: [
                    _buildSettingsToggleRow(
                      icon: TablerIcons.fingerprint,
                      title: context.translate('biometrics'),
                      value: _biometricEnabled,
                      onChanged: _onBiometricToggleChanged,
                    ),
                    const Divider(),
                    _buildSettingsActionRow(
                      icon: TablerIcons.language,
                      title: context.translate('language'),
                      value: currentLanguageLabel,
                      onTap: _showLanguageSelector,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              if (moduleRows.isNotEmpty) ...[
                Text(
                  context.translate('more_additional_modules'),
                  style: textStyles.bodySans.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                LedgerCard(
                  padding: EdgeInsets.zero,
                  child: Column(children: moduleRows),
                ),
                const SizedBox(height: 32),
              ],

              // Выход (Смена сессии)
              OutlinedButton(
                onPressed: () {
                  context.read<AuthBloc>().add(LogoutRequested());
                },
                style: OutlinedButton.styleFrom(
                  foregroundColor: colors.accentRed,
                  side: BorderSide(
                    color: colors.accentRed.withValues(alpha: 0.5),
                  ),
                ),
                child: Text(context.translate('logout')),
              ),
            ],
          ),
        ),
      ),
    ),
  );
  }

  List<Widget> _buildModuleRows(UserRole role) {
    final modules =
        <
          ({
            AppCapability capability,
            IconData icon,
            String title,
            String route,
          })
        >[
          (
            capability: AppCapability.notifications,
            icon: TablerIcons.alert_triangle,
            title: context.translate('more_notifications'),
            route: '/notifications',
          ),
          (
            capability: AppCapability.hr,
            icon: TablerIcons.briefcase,
            title: context.translate('hr_menu'),
            route: '/hr',
          ),
          (
            capability: AppCapability.crm,
            icon: TablerIcons.users,
            title: context.translate('crm_menu'),
            route: '/crm',
          ),
          (
            capability: AppCapability.strategy,
            icon: TablerIcons.bulb,
            title: context.translate('more_strategy'),
            route: '/strategy',
          ),
          (
            capability: AppCapability.marketing,
            icon: TablerIcons.speakerphone,
            title: context.translate('more_marketing'),
            route: '/marketing',
          ),
          (
            capability: AppCapability.legal,
            icon: TablerIcons.gavel,
            title: context.translate('more_legal'),
            route: '/legal',
          ),
          (
            capability: AppCapability.integrations,
            icon: TablerIcons.link,
            title: context.translate('more_integrations'),
            route: '/integrations',
          ),
          (
            capability: AppCapability.users,
            icon: TablerIcons.users_group,
            title: context.translate('more_users'),
            route: '/users',
          ),
        ];

    final rows = <Widget>[];
    for (final module in modules) {
      if (!role.can(module.capability)) continue;
      if (rows.isNotEmpty) rows.add(const Divider());
      rows.add(
        _buildSettingsNavigationRow(
          icon: module.icon,
          title: module.title,
          onTap: () => GoRouter.of(context).push(module.route),
        ),
      );
    }
    return rows;
  }

  Widget _buildProfileCard() {
    final colors = context.colors;
    final textStyles = context.textStyles;

    // Считываем текущую роль и логин из блока
    final authState = context.watch<AuthBloc>().state;
    String profileName = context.translate('more_user');
    String roleLabel = context.translate('common_loading');

    if (authState is AuthAuthenticated) {
      profileName = authState.username;
      roleLabel = context.translate(
        'more_role_value',
        params: {
          'role': context.translate(_roleTranslationKey(authState.role)),
        },
      );
    }

    return LedgerCard(
      child: Row(
        children: [
          CircleAvatar(
            radius: 24,
            backgroundColor: colors.brand.withValues(alpha: 0.1),
            child: Icon(TablerIcons.user, color: colors.brand, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(profileName, style: textStyles.h2Sans),
                const SizedBox(height: 2),
                Text(roleLabel, style: textStyles.captionSans),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _roleTranslationKey(UserRole role) {
    return switch (role) {
      UserRole.director => 'role_director',
      UserRole.manager => 'role_manager',
      UserRole.accountant => 'role_accountant',
      UserRole.cashier => 'role_cashier',
      UserRole.hr => 'role_hr',
      UserRole.viewer => 'role_viewer',
    };
  }

  Widget _buildSettingsToggleRow({
    required IconData icon,
    required String title,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    final colors = context.colors;
    final textStyles = context.textStyles;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
      child: Row(
        children: [
          Icon(icon, color: colors.textSecondary, size: 20),
          const SizedBox(width: 12),
          Expanded(child: Text(title, style: textStyles.bodySans)),
          const SizedBox(width: 8),
          Switch.adaptive(
            value: value,
            onChanged: onChanged,
            activeTrackColor: colors.brand,
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsActionRow({
    required IconData icon,
    required String title,
    required String value,
    required VoidCallback onTap,
  }) {
    final colors = context.colors;
    final textStyles = context.textStyles;

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 14.0),
        child: Row(
          children: [
            Icon(icon, color: colors.textSecondary, size: 20),
            const SizedBox(width: 12),
            Expanded(child: Text(title, style: textStyles.bodySans)),
            const SizedBox(width: 8),
            Text(
              value,
              style: textStyles.captionSans.copyWith(
                color: colors.textSecondary,
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              TablerIcons.chevron_right,
              color: colors.textTooltip,
              size: 16,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSettingsNavigationRow({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    final colors = context.colors;
    final textStyles = context.textStyles;

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 14.0),
        child: Row(
          children: [
            Icon(icon, color: colors.textSecondary, size: 20),
            const SizedBox(width: 12),
            Expanded(child: Text(title, style: textStyles.bodySans)),
            Icon(
              TablerIcons.chevron_right,
              color: colors.textTooltip,
              size: 16,
            ),
          ],
        ),
      ),
    );
  }

  void _showLanguageSelector() {
    final colors = context.colors;
    final textStyles = context.textStyles;
    final currentLanguage = context.read<LanguageCubit>().state.languageCode;

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: colors.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: colors.border),
          ),
          title: Text(
            context.translate('language_dialog_title'),
            style: textStyles.h2Sans,
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                selected: currentLanguage == 'ru',
                title: Text(
                  context.translate('language_russian'),
                  style: textStyles.bodySans,
                ),
                trailing: currentLanguage == 'ru'
                    ? const Icon(TablerIcons.check)
                    : null,
                onTap: () {
                  context.read<LanguageCubit>().setLanguage('ru');
                  Navigator.pop(context);
                },
              ),
              const Divider(),
              ListTile(
                selected: currentLanguage == 'tg',
                title: Text(
                  context.translate('language_tajik'),
                  style: textStyles.bodySans,
                ),
                trailing: currentLanguage == 'tg'
                    ? const Icon(TablerIcons.check)
                    : null,
                onTap: () {
                  context.read<LanguageCubit>().setLanguage('tg');
                  Navigator.pop(context);
                },
              ),
            ],
          ),
        );
      },
    );
  }
}
