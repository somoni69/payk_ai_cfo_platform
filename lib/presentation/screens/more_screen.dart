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
import '../widgets/ledger_card.dart';

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

  void _loadBiometricSettings() async {
    final val = await _storage.read(key: 'use_biometrics');
    if (mounted) {
      setState(() {
        _biometricEnabled = val == 'true';
      });
    }
  }

  void _onBiometricToggleChanged(bool val) async {
    if (val) {
      final localAuth = LocalAuthentication();
      try {
        final isAvailable = await localAuth.canCheckBiometrics;
        final isDeviceSupported = await localAuth.isDeviceSupported();

        if (!isAvailable || !isDeviceSupported) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Биометрическая аутентификация недоступна на этом устройстве')),
            );
          }
          return;
        }

        final authenticated = await localAuth.authenticate(
          localizedReason: 'Подтвердите личность для включения входа по Face ID / Touch ID',
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
              const SnackBar(content: Text('Вход по биометрии успешно включен')),
            );
          }
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Аутентификация отменена или не пройдена')),
            );
          }
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Ошибка настройки биометрии: $e')),
          );
        }
      }
    } else {
      await _storage.write(key: 'use_biometrics', value: 'false');
      if (mounted) {
        setState(() {
          _biometricEnabled = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Вход по биометрии отключен')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final textStyles = context.textStyles;

    final locale = context.watch<LanguageCubit>().state;
    final String currentLanguageLabel = locale.languageCode == 'tg' ? 'Тоҷикӣ' : 'Русский';

    return Scaffold(
      appBar: AppBar(
        backgroundColor: colors.surface,
        scrolledUnderElevation: 0,
        title: Text(context.translate('more'), style: textStyles.h1Sans),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1.0),
          child: Container(
            color: colors.border,
            height: 1.0,
          ),
        ),
      ),
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
              Text('НАСТРОЙКИ ДОСТУПА', style: textStyles.bodySans.copyWith(fontWeight: FontWeight.bold)),
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

              // Системные блоки
              Text('ДОПОЛНИТЕЛЬНЫЕ МОДУЛИ', style: textStyles.bodySans.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              LedgerCard(
                padding: EdgeInsets.zero,
                child: Column(
                  children: [
                    _buildSettingsNavigationRow(
                      icon: TablerIcons.alert_triangle,
                      title: 'Уведомления и предупреждения',
                      onTap: () => GoRouter.of(context).push('/notifications'),
                    ),
                    const Divider(),
                    _buildSettingsNavigationRow(
                      icon: TablerIcons.briefcase,
                      title: context.translate('hr_menu'),
                      onTap: () => GoRouter.of(context).push('/hr'),
                    ),
                    const Divider(),
                    _buildSettingsNavigationRow(
                      icon: TablerIcons.users,
                      title: context.translate('crm_menu'),
                      onTap: () => GoRouter.of(context).push('/crm'),
                    ),
                    const Divider(),
                    _buildSettingsNavigationRow(
                      icon: TablerIcons.bulb,
                      title: 'Аналитика What-if и Сценарии',
                      onTap: () => GoRouter.of(context).push('/strategy'),
                    ),
                    const Divider(),
                    _buildSettingsNavigationRow(
                      icon: TablerIcons.speakerphone,
                      title: 'AI-Маркетинг и Соцсети',
                      onTap: () => GoRouter.of(context).push('/marketing'),
                    ),
                    const Divider(),
                    _buildSettingsNavigationRow(
                      icon: TablerIcons.gavel,
                      title: 'База законов РТ и шаблоны',
                      onTap: () => GoRouter.of(context).push('/legal'),
                    ),
                    const Divider(),
                    _buildSettingsNavigationRow(
                      icon: TablerIcons.link,
                      title: 'Внешние интеграции',
                      onTap: () => GoRouter.of(context).push('/integrations'),
                    ),
                    const Divider(),
                    _buildSettingsNavigationRow(
                      icon: TablerIcons.users_group,
                      title: 'Пользователи и Роли',
                      onTap: () => GoRouter.of(context).push('/users'),
                    ),
                    const Divider(),
                    _buildSettingsNavigationRow(
                      icon: TablerIcons.database,
                      title: 'Резервные копии базы',
                      onTap: () {},
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),

              // Выход (Смена сессии)
              OutlinedButton(
                onPressed: () {
                  context.read<AuthBloc>().add(LogoutRequested());
                },
                style: OutlinedButton.styleFrom(
                  foregroundColor: colors.accentRed,
                  side: BorderSide(color: colors.accentRed.withValues(alpha: 0.5)),
                ),
                child: Text(context.translate('logout')),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProfileCard() {
    final colors = context.colors;
    final textStyles = context.textStyles;

    // Считываем текущую роль и логин из блока
    final authState = context.watch<AuthBloc>().state;
    String profileName = 'Пользователь';
    String roleLabel = 'Загрузка...';

    if (authState is AuthAuthenticated) {
      profileName = authState.username;
      roleLabel = '${context.translate('role')}: ${authState.role.label}';
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
          Expanded(
            child: Text(title, style: textStyles.bodySans),
          ),
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
            Expanded(
              child: Text(title, style: textStyles.bodySans),
            ),
            const SizedBox(width: 8),
            Text(
              value,
              style: textStyles.captionSans.copyWith(color: colors.textSecondary),
            ),
            const SizedBox(width: 4),
            Icon(TablerIcons.chevron_right, color: colors.textTooltip, size: 16),
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
            Expanded(
              child: Text(title, style: textStyles.bodySans),
            ),
            Icon(TablerIcons.chevron_right, color: colors.textTooltip, size: 16),
          ],
        ),
      ),
    );
  }

  void _showLanguageSelector() {
    final colors = context.colors;
    final textStyles = context.textStyles;

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: colors.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: colors.border),
          ),
          title: Text('Язык интерфейса', style: textStyles.h2Sans),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                title: Text('Русский', style: textStyles.bodySans),
                onTap: () {
                  context.read<LanguageCubit>().setLanguage('ru');
                  Navigator.pop(context);
                },
              ),
              const Divider(),
              ListTile(
                title: Text('Тоҷикӣ', style: textStyles.bodySans),
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
