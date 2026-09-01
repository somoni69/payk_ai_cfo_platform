import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_tabler_icons/flutter_tabler_icons.dart';
import 'package:go_router/go_router.dart';
import '../../../core/localization/language_cubit.dart';
import '../../../core/network/expiring_request_cache.dart';
import '../../../core/security/biometric_service.dart';
import '../../../core/security/secure_storage_provider.dart';
import '../../../core/theme/theme_extensions.dart';
import '../../network/domain/network_repository.dart';
import '../../../features/auth/bloc/auth_bloc.dart';
import '../../../features/auth/bloc/auth_event.dart';
import '../../../features/auth/bloc/auth_state.dart';
import '../../../features/assistant/presentation/ledger_ai_assistant.dart';
import '../../../features/auth/domain/app_access.dart';
import '../../../features/permissions/cubit/permissions_cubit.dart';
import '../../../features/permissions/domain/my_permissions.dart';
import '../../../presentation/widgets/expansible_widget.dart';
import '../../../presentation/widgets/ledger_shimmer.dart';
import '../../cash/bloc/cash_bloc.dart';
import '../../cash/bloc/cash_event.dart';
import '../../dashboard/bloc/dashboard_bloc.dart';
import '../../dashboard/bloc/dashboard_event.dart';
import '../../tasks/bloc/tasks_bloc.dart';
import '../../tasks/bloc/tasks_event.dart';
import '../../warehouse/bloc/warehouse_bloc.dart';
import '../../warehouse/bloc/warehouse_event.dart';

class MoreScreen extends StatefulWidget {
  const MoreScreen({super.key});

  @override
  State<MoreScreen> createState() => _MoreScreenState();
}

class _MoreScreenState extends State<MoreScreen> {
  final _storage = AppSecureStorage.instance;
  final _biometricService = BiometricService();
  BiometricKind _biometricKind = BiometricKind.none;
  bool _biometricEnabled = false;

  @override
  void initState() {
    super.initState();
    _loadBiometricSettings();
  }

  Future<void> _handleRefresh() async {
    await _loadBiometricSettings();
    if (!mounted) return;
    _refreshAllBlocs(context);
  }

  void _refreshAllBlocs(BuildContext ctx) {
    try {
      ctx.read<PermissionsCubit>().load();
    } catch (_) {}
    try {
      ctx.read<DashboardBloc>().add(LoadDashboardData(forceRefresh: true));
    } catch (_) {}
    try {
      ctx.read<CashBloc>().add(const LoadCashData());
    } catch (_) {}
    try {
      ctx.read<WarehouseBloc>().add(LoadWarehouseData());
    } catch (_) {}
    try {
      ctx.read<TasksBloc>().add(const LoadTasks(forceRefresh: true));
    } catch (_) {}
  }

  Future<void> _loadBiometricSettings() async {
    try {
      final value = await _storage.read(key: 'use_biometrics');
      final kind = await _biometricService.getPrimaryBiometricKind();
      if (!mounted) return;
      setState(() {
        _biometricEnabled = value == 'true';
        _biometricKind = kind;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _biometricEnabled = false);
    }
  }

  void _onBiometricToggleChanged(bool val) async {
    final biometricReason = context.translate('more_biometric_reason');
    final langCode = context.read<LanguageCubit>().state.languageCode;

    if (val) {
      try {
        final isAvailable = await _biometricService.isBiometricsAvailable();
        if (!isAvailable) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(context.translate('more_biometric_unavailable')),
              ),
            );
          }
          return;
        }

        final authenticated = await _biometricService.authenticate(
          localizedReason: biometricReason,
          languageCode: langCode,
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
        final authenticated = await _biometricService.authenticate(
          localizedReason: biometricReason,
          languageCode: langCode,
        );

        if (authenticated) {
          await _storage.write(key: 'use_biometrics', value: 'false');
          if (!mounted) return;
          setState(() => _biometricEnabled = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(context.translate('more_biometric_disabled')),
            ),
          );
        } else {
          if (!mounted) return;
          setState(() => _biometricEnabled = true);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(context.translate('more_biometric_cancelled')),
            ),
          );
        }
      } catch (_) {
        if (!mounted) return;
        setState(() => _biometricEnabled = true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.translate('more_biometric_error'))),
        );
      }
    }
  }

  String _getBiometricTitle(BuildContext context) {
    return switch (_biometricKind) {
      BiometricKind.faceId => 'Face ID',
      BiometricKind.touchId => 'Touch ID',
      BiometricKind.fingerprint => context.translate('biometric_fingerprint'),
      BiometricKind.faceUnlock => context.translate('biometric_face'),
      _ => context.translate('biometrics'),
    };
  }

  IconData _getBiometricIcon() {
    return switch (_biometricKind) {
      BiometricKind.faceId || BiometricKind.faceUnlock => TablerIcons.scan,
      _ => TablerIcons.fingerprint,
    };
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
    if (authState is AuthLoading || authState is AuthInitial) {
      return const Scaffold(body: MoreOverviewShimmer());
    }
    context.watch<PermissionsCubit>();

    return Scaffold(
      floatingActionButtonLocation: kLedgerShellFabLocation,
      floatingActionButton: const LedgerAiFloatingButton(),
      body: RefreshIndicator(
        onRefresh: _handleRefresh,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverAppBar(
              pinned: true,
              backgroundColor: colors.surface,
              surfaceTintColor: Colors.transparent,
              elevation: 0,
              title: Text(
                context.translate('more_title'),
                style: textStyles.h2Sans.copyWith(
                  fontSize: 19,
                  fontWeight: FontWeight.w600,
                  color: colors.textPrimary,
                ),
              ),
              bottom: PreferredSize(
                preferredSize: const Size.fromHeight(1),
                child: Container(height: 1, color: colors.border),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 88),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  // Профиль пользователя
                  _buildProfileCard(),
                  const SizedBox(height: 16),

                  // Безопасность и настройки
                  if (_biometricKind != BiometricKind.none) ...[
                    Text(
                      context.translate('more_access_settings'),
                      style: textStyles.bodySans.copyWith(
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      decoration: BoxDecoration(
                        color: colors.surface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: colors.border),
                      ),
                      child: _buildSettingsToggleRow(
                        icon: _getBiometricIcon(),
                        title: _getBiometricTitle(context),
                        value: _biometricEnabled,
                        onChanged: _onBiometricToggleChanged,
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
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
                          color: colors.brand,
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
            capability: AppCapability.network,
            icon: TablerIcons.building_store,
            titleKey: 'more_network',
            route: '/network',
          ),
          (
            capability: AppCapability.branches,
            icon: TablerIcons.map_pin,
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
          (
            capability: AppCapability.backups,
            icon: TablerIcons.database,
            titleKey: 'more_backups',
            route: '/backups',
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
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
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
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(12),
        constraints: const BoxConstraints(minHeight: 74),
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: colors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 20, color: colors.brand),
            const SizedBox(height: 8),
            Text(
              title,
              style: textStyles.bodySans.copyWith(
                fontWeight: FontWeight.w500,
                height: 1.2,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
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

    final storeName = authState is AuthAuthenticated
        ? authState.storeName
        : null;
    final storeId = authState is AuthAuthenticated ? authState.storeId : null;
    final isOwner =
        authState is AuthAuthenticated && authState.role == UserRole.owner;
    final hasActingStore =
        storeId != null || (storeName != null && storeName.isNotEmpty);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
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
                    if (isOwner || hasActingStore) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(
                            TablerIcons.building_store,
                            size: 14,
                            color: colors.brand,
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              hasActingStore
                                  ? (storeName?.isNotEmpty == true
                                        ? storeName!
                                        : '#$storeId')
                                  : context.translate('network_root_badge'),
                              style: textStyles.captionSans.copyWith(
                                color: colors.brand,
                                fontWeight: FontWeight.w500,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          if (isOwner && hasActingStore) ...[
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () async {
                try {
                  await context.read<NetworkRepository>().leaveStore();
                } catch (_) {}
                if (!mounted) return;
                ExpiringRequestCache.invalidateAll();
                context.read<AuthBloc>().add(const ActingStoreUpdated());
                GoRouter.of(context).go('/network');
              },
              icon: Icon(
                TablerIcons.arrow_back_up,
                size: 16,
                color: colors.brand,
              ),
              label: Text(
                context.translate('more_leave_store'),
                style: textStyles.captionSans.copyWith(
                  color: colors.brand,
                  fontWeight: FontWeight.w600,
                ),
              ),
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: colors.border),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _roleTranslationKey(UserRole role) {
    return switch (role) {
      UserRole.owner => 'role_owner',
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
          Icon(icon, color: colors.brand, size: 20),
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
