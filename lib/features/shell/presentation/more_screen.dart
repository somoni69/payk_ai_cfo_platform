import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_tabler_icons/flutter_tabler_icons.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';
import '../../../core/localization/language_cubit.dart';
import '../../../core/theme/theme_extensions.dart';
import '../../../features/auth/bloc/auth_bloc.dart';
import '../../../features/auth/bloc/auth_event.dart';
import '../../../features/auth/bloc/auth_state.dart';
import '../../../features/assistant/presentation/ledger_ai_assistant.dart';
import '../../../features/auth/domain/app_access.dart';
import '../../../features/permissions/cubit/permissions_cubit.dart';
import '../../../features/permissions/domain/my_permissions.dart';
import '../../../presentation/widgets/expansible_widget.dart';
import '../../../presentation/widgets/ledger_card.dart';
import '../../../presentation/widgets/ledger_collapsing_header.dart';
import '../../../presentation/widgets/payk_logo.dart';
import '../../notifications/presentation/notification_bell.dart';

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
    context.watch<PermissionsCubit>();

    return LedgerAiAssistantHost(
      child: Builder(
        builder: (context) {
          return Scaffold(
            body: CustomScrollView(
              slivers: [
                LedgerCollapsingHeader(
                  title: context.translate('more'),
                  pinned: true,
                  floating: false,
                  snap: false,
                  actions: const [
                    NotificationBell(),
                    SizedBox(width: 8),
                    PaykLogo(height: 22),
                  ],
                ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(
                    16,
                    8,
                    16,
                    16 + kLiquidNavClearance,
                  ),
                  sliver: SliverList(
                    delegate: SliverChildListDelegate([
                      // Профиль пользователя
                      _buildProfileCard(),
                      const SizedBox(height: 16),

                      // Безопасность и настройки
                      Text(
                        context.translate('more_access_settings'),
                        style: textStyles.bodySans.copyWith(
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 6),
                      LedgerCard(
                        padding: EdgeInsets.zero,
                        child: _buildSettingsToggleRow(
                          icon: TablerIcons.fingerprint,
                          title: context.translate('biometrics'),
                          value: _biometricEnabled,
                          onChanged: _onBiometricToggleChanged,
                        ),
                      ),
                      const SizedBox(height: 12),
                      ExpansibleWidget<String>.selection(
                        cardPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 6,
                        ),
                        tilePadding: EdgeInsets.zero,
                        title: Row(
                          children: [
                            Icon(
                              TablerIcons.language,
                              color: colors.textSecondary,
                              size: 20,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                context.translate('language'),
                                style: textStyles.bodySans,
                              ),
                            ),
                          ],
                        ),
                        subtitle: Text(
                          currentLanguageLabel,
                          style: textStyles.captionSans.copyWith(
                            color: colors.textSecondary,
                          ),
                        ),
                        items: const ['ru', 'tg'],
                        selectedValue: locale.languageCode,
                        itemLabelBuilder: (code) => code == 'tg'
                            ? context.translate('language_tajik')
                            : context.translate('language_russian'),
                        onSelected: (val) {
                          context.read<LanguageCubit>().setLanguage(val);
                        },
                      ),
                      const SizedBox(height: 12),

                      LedgerCard(
                        onTap: () => LedgerAiAssistantHost.open(context),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
                        ),
                        child: Row(
                          children: [
                            Icon(
                              TablerIcons.message_circle,
                              size: 20,
                              color: colors.brand,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                context.translate('assistant_title'),
                                style: textStyles.bodySans.copyWith(
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                            Icon(
                              TablerIcons.chevron_right,
                              size: 18,
                              color: colors.textTooltip,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      if (role != null) ..._buildGroupedModules(role),

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
                      const SizedBox(height: 8),
                    ]),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  List<Widget> _buildGroupedModules(UserRole role) {
    final textStyles = context.textStyles;

    final groups = [
      (
        titleKey: 'more_group_business',
        modules: [
          (
            capability: AppCapability.hr,
            icon: TablerIcons.briefcase,
            titleKey: 'hr_menu',
            route: '/hr',
          ),
          (
            capability: AppCapability.crm,
            icon: TablerIcons.users,
            titleKey: 'crm_menu',
            route: '/crm',
          ),
          (
            capability: AppCapability.crm,
            icon: TablerIcons.brand_meta,
            titleKey: 'more_meta',
            route: '/meta',
          ),
          (
            capability: AppCapability.checklists,
            icon: TablerIcons.checkbox,
            titleKey: 'more_checklists',
            route: '/checklists',
          ),
        ],
      ),
      (
        titleKey: 'more_group_finance',
        modules: [
          (
            capability: AppCapability.finOps,
            icon: TablerIcons.businessplan,
            titleKey: 'more_fin_ops',
            route: '/fin-ops',
          ),
          (
            capability: AppCapability.reports,
            icon: TablerIcons.report_analytics,
            titleKey: 'more_reports',
            route: '/reports',
          ),
          (
            capability: AppCapability.strategy,
            icon: TablerIcons.bulb,
            titleKey: 'more_strategy',
            route: '/strategy',
          ),
          (
            capability: AppCapability.notifications,
            icon: TablerIcons.alert_triangle,
            titleKey: 'more_notifications',
            route: '/notifications',
          ),
        ],
      ),
      (
        titleKey: 'more_group_marketing',
        modules: [
          (
            capability: AppCapability.marketing,
            icon: TablerIcons.speakerphone,
            titleKey: 'more_marketing',
            route: '/marketing',
          ),
          (
            capability: AppCapability.legal,
            icon: TablerIcons.gavel,
            titleKey: 'more_legal',
            route: '/legal',
          ),
        ],
      ),
      (
        titleKey: 'more_group_system',
        modules: [
          (
            capability: AppCapability.branches,
            icon: TablerIcons.building_store,
            titleKey: 'more_branches',
            route: '/branches',
          ),
          (
            capability: AppCapability.integrations,
            icon: TablerIcons.link,
            titleKey: 'more_integrations',
            route: '/integrations',
          ),
          (
            capability: AppCapability.users,
            icon: TablerIcons.users_group,
            titleKey: 'more_users',
            route: '/users',
          ),
          (
            capability: AppCapability.audit,
            icon: TablerIcons.shield_check,
            titleKey: 'more_audit',
            route: '/audit',
          ),
        ],
      ),
    ];

    final widgets = <Widget>[];

    for (final group in groups) {
      final permissions = context.read<PermissionsCubit>();
      final allowedModules = group.modules
          .where(
            (m) => permissions.can(
              m.capability,
              action: PermAction.view,
              fallbackRole: role,
            ),
          )
          .toList();

      if (allowedModules.isEmpty) continue;

      widgets.add(
        Text(
          context.translate(group.titleKey),
          style: textStyles.bodySans.copyWith(fontWeight: FontWeight.w600),
        ),
      );
      widgets.add(const SizedBox(height: 6));
      for (var i = 0; i < allowedModules.length; i += 2) {
        widgets.add(
          Padding(
            padding: EdgeInsets.only(
              bottom: i + 2 < allowedModules.length ? 8 : 0,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _buildModuleTile(
                    icon: allowedModules[i].icon,
                    title: context.translate(allowedModules[i].titleKey),
                    onTap: () =>
                        GoRouter.of(context).push(allowedModules[i].route),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: i + 1 < allowedModules.length
                      ? _buildModuleTile(
                          icon: allowedModules[i + 1].icon,
                          title: context.translate(
                            allowedModules[i + 1].titleKey,
                          ),
                          onTap: () => GoRouter.of(
                            context,
                          ).push(allowedModules[i + 1].route),
                        )
                      : const SizedBox.shrink(),
                ),
              ],
            ),
          ),
        );
      }
      widgets.add(const SizedBox(height: 16));
    }

    return widgets;
  }

  Widget _buildModuleTile({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    final colors = context.colors;
    final textStyles = context.textStyles;
    return LedgerCard(
      onTap: onTap,
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: colors.brand),
          const SizedBox(height: 8),
          Text(
            title,
            style: textStyles.bodySans.copyWith(fontWeight: FontWeight.w500),
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildProfileCard() {
    final colors = context.colors;
    final textStyles = context.textStyles;

    // Считываем текущую роль и логин из блока
    final authState = context.watch<AuthBloc>().state;
    String profileName = context.translate('more_user');
    String roleLabel = context.translate('common_loading');

    if (authState is AuthAuthenticated) {
      // Prefer JWT `name` (local claim) — no /auth/me round-trip needed.
      profileName = authState.displayName;
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
            backgroundColor: colors.surfaceNested,
            child: Icon(TablerIcons.user, color: colors.textPrimary, size: 24),
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
      UserRole.marketer => 'role_marketer',
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
}
