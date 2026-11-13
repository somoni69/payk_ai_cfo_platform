import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/localization/language_cubit.dart';
import '../../../core/theme/theme_extensions.dart';
import '../../auth/bloc/auth_bloc.dart';
import '../../auth/bloc/auth_state.dart';
import '../../auth/domain/app_access.dart';
import '../../permissions/cubit/permissions_cubit.dart';
import '../../permissions/domain/my_permissions.dart';
import '../domain/loyalty_models.dart';
import '../domain/loyalty_repository.dart';
import 'loyalty_office.dart';
import 'loyalty_pos_tab.dart';

class LoyaltyScreen extends StatefulWidget {
  const LoyaltyScreen({super.key});

  @override
  State<LoyaltyScreen> createState() => _LoyaltyScreenState();
}

class _LoyaltyScreenState extends State<LoyaltyScreen> {
  var _loading = true;
  String? _error;
  LoyaltyProgramState? _state;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = _state == null;
      _error = null;
    });
    try {
      final state = await context.read<LoyaltyRepository>().program();
      if (!mounted) return;
      setState(() {
        _state = state;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final language = context.watch<LanguageCubit>();
    final auth = context.watch<AuthBloc>().state;
    final role = auth is AuthAuthenticated ? auth.role : UserRole.viewer;
    final perms = context.watch<PermissionsCubit>();
    final data = perms.state.data;
    final canPos = data == null
        ? role.canManage(AppCapability.loyalty)
        : data.isDirector || data.can('loyalty', PermAction.create);
    final office = switch (role) {
      UserRole.owner ||
      UserRole.director ||
      UserRole.manager ||
      UserRole.accountant ||
      UserRole.viewer => true,
      _ => false,
    };
    final canManage = role.canManage(AppCapability.loyalty);
    final canEdit =
        role == UserRole.owner ||
        role == UserRole.director ||
        data?.isDirector == true;
    final state = _state;
    final tabs = <_Tab>[
      if (canPos) _Tab('loyalty_tab_pos', const SizedBox.shrink()),
      if (office) ...[
        _Tab('loyalty_tab_members', LoyaltyMembersTab(canManage: canManage)),
        const _Tab('loyalty_tab_birthdays', LoyaltyBirthdaysTab()),
        const _Tab('loyalty_tab_messages', LoyaltyMessagesTab()),
        const _Tab('loyalty_tab_reports', LoyaltyReportsTab()),
        _Tab(
          'loyalty_tab_settings',
          state == null
              ? const SizedBox.shrink()
              : LoyaltySettingsTab(
                  state: state,
                  canEdit: canEdit,
                  onChanged: _load,
                ),
        ),
      ],
    ];
    if (canPos && state != null) {
      final index = tabs.indexWhere((tab) => tab.keyName == 'loyalty_tab_pos');
      if (index >= 0) {
        tabs[index] = _Tab(
          'loyalty_tab_pos',
          LoyaltyPosTab(
            terminals: state.terminals,
            programEnabled: state.program?.enabled ?? false,
            canManage: switch (role) {
              UserRole.owner || UserRole.director || UserRole.manager => true,
              _ => false,
            },
          ),
        );
      }
    }

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        backgroundColor: colors.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        title: Text(
          state?.program == null
              ? language.translate('loyalty_title')
              : language.translate(
                  'loyalty_title_named',
                  params: {'name': state!.program!.title},
                ),
        ),
      ),
      body: _loading && state == null
          ? const Center(child: CircularProgressIndicator())
          : _error != null && state == null
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(language.resolveMessage(_error!)),
                  TextButton(
                    onPressed: _load,
                    child: Text(language.translate('common_retry')),
                  ),
                ],
              ),
            )
          : tabs.isEmpty
          ? Center(child: Text(language.translate('loyalty_no_program')))
          : DefaultTabController(
              length: tabs.length,
              child: Column(
                children: [
                  if (state?.program != null && office)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                      child: Text(
                        '${language.translate('loyalty_stat_members')}: ${state!.members}',
                        style: context.textStyles.captionSans.copyWith(
                          color: colors.textSecondary,
                        ),
                      ),
                    ),
                  if (tabs.length > 1)
                    TabBar(
                      isScrollable: true,
                      tabAlignment: TabAlignment.start,
                      tabs: [
                        for (final tab in tabs)
                          Tab(text: language.translate(tab.keyName)),
                      ],
                    ),
                  Expanded(
                    child: TabBarView(
                      children: [for (final tab in tabs) tab.child],
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}

class _Tab {
  const _Tab(this.keyName, this.child);

  final String keyName;
  final Widget child;
}
