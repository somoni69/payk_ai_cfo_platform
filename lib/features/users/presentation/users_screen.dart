import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_tabler_icons/flutter_tabler_icons.dart';
import '../../../core/localization/language_cubit.dart';
import '../../../core/theme/theme_extensions.dart';
import '../../../features/users/bloc/users_bloc.dart';
import '../../../features/users/bloc/users_event.dart';
import '../../../features/users/bloc/users_state.dart';
import '../../../features/users/domain/user_models.dart';
import '../../../features/users/domain/users_repository.dart';
import '../../../presentation/widgets/expansible_widget.dart';
import '../../../presentation/widgets/ledger_bottom_sheet.dart';
import '../../../presentation/widgets/ledger_shimmer.dart';

enum UsersSection { usersList, permissionsMatrix }

String _usersSectionTitle(LanguageCubit language, UsersSection section) {
  return language.translate(switch (section) {
    UsersSection.usersList => 'users_tab_users',
    UsersSection.permissionsMatrix => 'users_tab_access',
  });
}

void _openUsersSection(BuildContext context, UsersSection section) {
  final bloc = context.read<UsersBloc>();
  if (section == UsersSection.permissionsMatrix) {
    bloc.add(const LoadPermissionsMatrix());
  }
  Navigator.of(context, rootNavigator: true).push(
    MaterialPageRoute(
      builder: (_) => BlocProvider.value(
        value: bloc,
        child: UsersSectionScreen(section: section),
      ),
    ),
  );
}

class UsersScreen extends StatelessWidget {
  const UsersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider<UsersBloc>(
      create: (context) =>
          UsersBloc(context.read<UsersRepository>())
            ..add(const LoadUsersData()),
      child: const UsersView(),
    );
  }
}

class UsersView extends StatefulWidget {
  const UsersView({super.key});

  @override
  State<UsersView> createState() => _UsersViewState();
}

class _UsersViewState extends State<UsersView> {
  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final textStyles = context.textStyles;
    final language = context.watch<LanguageCubit>();

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        backgroundColor: colors.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        title: Text(
          language.translate('users_title'),
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
      body: BlocListener<UsersBloc, UsersState>(
        listener: (context, state) {
          if (state.errorMessage != null) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(language.translateMessage(state.errorMessage!)),
                backgroundColor: colors.accentRed,
              ),
            );
          }
          if (state.successMessage != null) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  language.translateMessage(state.successMessage!),
                ),
                backgroundColor: colors.accentGreen,
              ),
            );
          }
        },
        child: BlocBuilder<UsersBloc, UsersState>(
          builder: (context, state) {
            if (state.isLoading && state.users.isEmpty) {
              return const Padding(
                padding: EdgeInsets.all(16),
                child: LedgerListShimmer(itemCount: 5),
              );
            }
            return _buildUsersOverviewHub(context, state);
          },
        ),
      ),
    );
  }

  Widget _buildUsersOverviewHub(BuildContext context, UsersState state) {
    final colors = context.colors;
    final textStyles = context.textStyles;
    final language = context.watch<LanguageCubit>();

    final totalUsers = state.users.length;
    final activeUsers = state.users.where((u) => u.active).length;
    final inactiveUsers = totalUsers - activeUsers;

    return RefreshIndicator(
      onRefresh: () async {
        await context.read<UsersBloc>().refresh();
      },
      child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        children: [
          // 1. Hero Card: Users & Access Overview
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: colors.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: colors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        language.translate('users_hero_title'),
                        style: textStyles.captionSans.copyWith(
                          color: colors.textSecondary,
                          fontWeight: FontWeight.w500,
                          fontSize: 13.5,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: colors.brand.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(TablerIcons.users, size: 13, color: colors.brand),
                          const SizedBox(width: 4),
                          Text(
                            language.translate(
                              'users_count',
                              params: {'count': '$totalUsers'},
                            ),
                            style: textStyles.captionSans.copyWith(
                              color: colors.brand,
                              fontWeight: FontWeight.w600,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  '$totalUsers пользователей системы',
                  style: textStyles.h2Sans.copyWith(
                    fontWeight: FontWeight.w700,
                    fontSize: 20,
                    color: colors.textPrimary,
                  ),
                ),
                const SizedBox(height: 12),
                Container(height: 1, color: colors.border),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Icon(TablerIcons.shield_lock, size: 16, color: colors.brand),
                    const SizedBox(width: 6),
                    Text(
                      '$activeUsers ${language.translate('users_active').toLowerCase()}',
                      style: textStyles.captionSans.copyWith(
                        color: colors.textPrimary,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '• ${state.permissionMatrix?.roles.length ?? 6} ролей RBAC',
                      style: textStyles.captionSans.copyWith(
                        color: colors.textSecondary,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // 2. Actionable Attention Card
          InkWell(
            onTap: () => _openUsersSection(
              context,
              inactiveUsers > 0
                  ? UsersSection.usersList
                  : UsersSection.permissionsMatrix,
            ),
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: colors.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: inactiveUsers > 0
                      ? colors.accentAmber.withValues(alpha: 0.5)
                      : colors.accentGreen.withValues(alpha: 0.4),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: inactiveUsers > 0
                          ? colors.accentAmber.withValues(alpha: 0.1)
                          : colors.accentGreen.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      inactiveUsers > 0
                          ? TablerIcons.user_off
                          : TablerIcons.circle_check,
                      color: inactiveUsers > 0
                          ? colors.accentAmber
                          : colors.accentGreen,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          language.translate('users_attention_title'),
                          style: textStyles.bodySans.copyWith(
                            fontWeight: FontWeight.w600,
                            fontSize: 14.5,
                            color: colors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          inactiveUsers > 0
                              ? language.translate(
                                  'users_attention_inactive',
                                  params: {'count': '$inactiveUsers'},
                                )
                              : language.translate('users_attention_ok'),
                          style: textStyles.captionSans.copyWith(
                            color: colors.textSecondary,
                            fontSize: 13,
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
          const SizedBox(height: 12),

          // 3. Quick Action Buttons Row
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 44,
                  child: ElevatedButton.icon(
                    onPressed: () => _showUserDialog(context),
                    icon: const Icon(TablerIcons.user_plus, size: 17),
                    label: Text(
                      language.translate('users_action_new'),
                      style: textStyles.captionSans.copyWith(
                        color: colors.surface,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: colors.brand,
                      foregroundColor: colors.surface,
                      elevation: 0,
                      minimumSize: const Size.fromHeight(44),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 10,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: SizedBox(
                  height: 44,
                  child: OutlinedButton.icon(
                    onPressed: () => _openUsersSection(
                      context,
                      UsersSection.permissionsMatrix,
                    ),
                    icon: const Icon(TablerIcons.shield_lock, size: 17),
                    label: Text(
                      language.translate('users_action_matrix'),
                      style: textStyles.captionSans.copyWith(
                        color: colors.brand,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: colors.brand,
                      side: BorderSide(color: colors.border),
                      minimumSize: const Size.fromHeight(44),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 10,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // 4. Main 2x2 Navigation Grid
          Row(
            children: [
              Expanded(
                child: _buildHubCard(
                  context,
                  title: language.translate('users_tab_users'),
                  subtitle: '$totalUsers аккаунтов · $activeUsers активных',
                  icon: TablerIcons.users,
                  onTap: () => _openUsersSection(
                    context,
                    UsersSection.usersList,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildHubCard(
                  context,
                  title: language.translate('users_tab_access'),
                  subtitle: 'Матрица прав & RBAC',
                  icon: TablerIcons.shield_lock,
                  onTap: () => _openUsersSection(
                    context,
                    UsersSection.permissionsMatrix,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // 5. Recent Users Feed
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                language.translate('users_recent_users'),
                style: textStyles.h2Sans.copyWith(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: colors.textPrimary,
                ),
              ),
              TextButton(
                onPressed: () => _openUsersSection(
                  context,
                  UsersSection.usersList,
                ),
                style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Row(
                  children: [
                    Text(
                      language.translate('users_all_users'),
                      style: textStyles.captionSans.copyWith(
                        color: colors.brand,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      TablerIcons.chevron_right,
                      size: 14,
                      color: colors.brand,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          if (state.users.isEmpty)
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: colors.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: colors.border),
              ),
              alignment: Alignment.center,
              child: Text(
                language.translate('users_empty'),
                style: textStyles.captionSans.copyWith(
                  color: colors.textSecondary,
                  fontSize: 13.5,
                ),
              ),
            )
          else
            ...state.users.take(5).map((user) {
              final initial = user.fullName.isNotEmpty
                  ? user.fullName[0].toUpperCase()
                  : (user.username.isNotEmpty
                        ? user.username[0].toUpperCase()
                        : '?');

              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: InkWell(
                  onTap: () => _showUserDialog(context, user: user),
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.all(13),
                    decoration: BoxDecoration(
                      color: colors.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: colors.border),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: colors.surfaceNested,
                            shape: BoxShape.circle,
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            initial,
                            style: textStyles.bodySans.copyWith(
                              fontWeight: FontWeight.w700,
                              color: colors.brand,
                              fontSize: 15,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      user.fullName,
                                      style: textStyles.bodySans.copyWith(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 14.5,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  _buildRoleBadge(
                                    context,
                                    user.role,
                                    colors,
                                    language,
                                  ),
                                ],
                              ),
                              const SizedBox(height: 2),
                              Row(
                                children: [
                                  Text(
                                    '@${user.username}',
                                    style: textStyles.captionSans.copyWith(
                                      color: colors.textSecondary,
                                      fontSize: 12.5,
                                    ),
                                  ),
                                  if (user.email != null &&
                                      user.email!.isNotEmpty) ...[
                                    Text(
                                      ' • ${user.email}',
                                      style: textStyles.captionSans.copyWith(
                                        color: colors.textSecondary,
                                        fontSize: 12.5,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }),
        ],
      ),
    );
  }

  Widget _buildHubCard(
    BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    final colors = context.colors;
    final textStyles = context.textStyles;

    return Material(
      color: colors.surface,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: colors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: colors.brand.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(icon, size: 20, color: colors.brand),
                  ),
                  Icon(
                    TablerIcons.chevron_right,
                    size: 16,
                    color: colors.textSecondary,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                title,
                style: textStyles.bodySans.copyWith(
                  fontWeight: FontWeight.w600,
                  fontSize: 14.5,
                  color: colors.textPrimary,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: textStyles.captionSans.copyWith(
                  color: colors.textSecondary,
                  fontSize: 12.5,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class UsersSectionScreen extends StatefulWidget {
  final UsersSection section;

  const UsersSectionScreen({super.key, required this.section});

  @override
  State<UsersSectionScreen> createState() => _UsersSectionScreenState();
}

class _UsersSectionScreenState extends State<UsersSectionScreen> {
  static const _pageSize = 40;
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  int _visibleUsers = _pageSize;
  List<UserProfile>? _lastUsers;
  String? _selectedAccessRole;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_revealMoreUsers);
  }

  void _revealMoreUsers() {
    if (!_scrollController.hasClients ||
        _scrollController.position.extentAfter > 600) {
      return;
    }
    final total = context.read<UsersBloc>().state.users.length;
    if (_visibleUsers >= total) return;
    final next = _visibleUsers + _pageSize;
    setState(() => _visibleUsers = next < total ? next : total);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final textStyles = context.textStyles;
    final language = context.watch<LanguageCubit>();

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        backgroundColor: colors.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: const BackButton(),
        title: Text(
          _usersSectionTitle(language, widget.section),
          style: textStyles.h2Sans.copyWith(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: colors.textPrimary,
          ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: colors.border),
        ),
      ),
      floatingActionButton: widget.section == UsersSection.usersList
          ? FloatingActionButton.extended(
              heroTag: null,
              onPressed: () => _showUserDialog(context),
              backgroundColor: colors.brand,
              foregroundColor: colors.surface,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              icon: const Icon(TablerIcons.user_plus),
              label: Text(
                language.translate('users_new_user_btn'),
                style: textStyles.bodySans.copyWith(
                  color: colors.surface,
                  fontWeight: FontWeight.w600,
                ),
              ),
            )
          : null,
      body: BlocListener<UsersBloc, UsersState>(
        listener: (context, state) {
          if (!identical(_lastUsers, state.users)) {
            _lastUsers = state.users;
            if (_visibleUsers != _pageSize) {
              setState(() => _visibleUsers = _pageSize);
            }
          }
        },
        child: switch (widget.section) {
          UsersSection.usersList => _buildUsersTab(context),
          UsersSection.permissionsMatrix => _buildAccessTab(context),
        },
      ),
    );
  }

  Widget _buildUsersTab(BuildContext context) {
    final colors = context.colors;
    final textStyles = context.textStyles;
    final language = context.watch<LanguageCubit>();

    return BlocBuilder<UsersBloc, UsersState>(
      buildWhen: (previous, current) =>
          previous.users != current.users ||
          previous.isLoading != current.isLoading ||
          previous.isSearching != current.isSearching ||
          previous.isRefreshing != current.isRefreshing,
      builder: (context, state) {
        final visibleUsers = _visibleUsers < state.users.length
            ? _visibleUsers
            : state.users.length;

        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(12.0),
              child: TextField(
                controller: _searchController,
                style: textStyles.bodySans,
                onChanged: (val) {
                  context.read<UsersBloc>().add(UsersSearchChanged(val));
                },
                decoration: InputDecoration(
                  hintText: language.translate('users_search_hint'),
                  prefixIcon: Icon(
                    TablerIcons.search,
                    color: colors.textSecondary,
                    size: 20,
                  ),
                ),
              ),
            ),
            if (state.isSearching)
              const LinearProgressIndicator(minHeight: 2)
            else
              const SizedBox(height: 2),

            Expanded(
              child: state.isLoading
                  ? const UsersOverviewShimmer()
                  : RefreshIndicator(
                      onRefresh: () async {
                        _visibleUsers = _pageSize;
                        await context.read<UsersBloc>().refresh(
                          search: _searchController.text,
                        );
                      },
                      child: ListView.builder(
                        controller: _scrollController,
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 88),
                        itemCount: state.users.isEmpty ? 1 : visibleUsers,
                        itemBuilder: (context, index) {
                          if (state.users.isEmpty) {
                            return Center(
                              child: Padding(
                                padding: const EdgeInsets.all(32.0),
                                child: Text(
                                  language.translate('users_empty'),
                                  style: textStyles.bodySans.copyWith(
                                    color: colors.textSecondary,
                                  ),
                                ),
                              ),
                            );
                          }

                          final user = state.users[index];
                          final initial = user.fullName.isNotEmpty
                              ? user.fullName[0].toUpperCase()
                              : (user.username.isNotEmpty
                                    ? user.username[0].toUpperCase()
                                    : '?');

                          return Padding(
                            padding: const EdgeInsets.only(bottom: 10.0),
                            child: InkWell(
                              onTap: () => _showUserDialog(context, user: user),
                              borderRadius: BorderRadius.circular(12),
                              child: Container(
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: colors.surface,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: colors.border),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Container(
                                          width: 42,
                                          height: 42,
                                          decoration: BoxDecoration(
                                            color: colors.surfaceNested,
                                            shape: BoxShape.circle,
                                          ),
                                          alignment: Alignment.center,
                                          child: Text(
                                            initial,
                                            style: textStyles.bodySans.copyWith(
                                              fontWeight: FontWeight.w700,
                                              color: colors.brand,
                                              fontSize: 16,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                user.fullName,
                                                style: textStyles.bodySans
                                                    .copyWith(
                                                      fontWeight: FontWeight.w600,
                                                      fontSize: 15,
                                                    ),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                              const SizedBox(height: 2),
                                              Text(
                                                '@${user.username}',
                                                style: textStyles.captionSans
                                                    .copyWith(
                                                      color: colors.textSecondary,
                                                    ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        _buildRoleBadge(
                                          context,
                                          user.role,
                                          colors,
                                          language,
                                        ),
                                      ],
                                    ),
                                    if ((user.email != null &&
                                            user.email!.isNotEmpty) ||
                                        (user.phone != null &&
                                            user.phone!.isNotEmpty)) ...[
                                      const SizedBox(height: 10),
                                      Wrap(
                                        spacing: 12,
                                        runSpacing: 4,
                                        children: [
                                          if (user.email != null &&
                                              user.email!.isNotEmpty)
                                            Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Icon(
                                                  TablerIcons.mail,
                                                  size: 13,
                                                  color: colors.textTooltip,
                                                ),
                                                const SizedBox(width: 4),
                                                Text(
                                                  user.email!,
                                                  style: textStyles.captionSans
                                                      .copyWith(
                                                        color:
                                                            colors.textSecondary,
                                                      ),
                                                ),
                                              ],
                                            ),
                                          if (user.phone != null &&
                                              user.phone!.isNotEmpty)
                                            Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Icon(
                                                  TablerIcons.phone,
                                                  size: 13,
                                                  color: colors.textTooltip,
                                                ),
                                                const SizedBox(width: 4),
                                                Text(
                                                  user.phone!,
                                                  style: textStyles.captionSans
                                                      .copyWith(
                                                        color:
                                                            colors.textSecondary,
                                                      ),
                                                ),
                                              ],
                                            ),
                                        ],
                                      ),
                                    ],
                                    const SizedBox(height: 10),
                                    const Divider(height: 1),
                                    const SizedBox(height: 8),
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Row(
                                          children: [
                                            Container(
                                              width: 8,
                                              height: 8,
                                              decoration: BoxDecoration(
                                                color: user.active
                                                    ? colors.accentGreen
                                                    : colors.accentRed,
                                                shape: BoxShape.circle,
                                              ),
                                            ),
                                            const SizedBox(width: 6),
                                            Text(
                                              language.translate(
                                                user.active
                                                    ? 'users_status_active'
                                                    : 'users_status_inactive',
                                              ),
                                              style: textStyles.captionSans
                                                  .copyWith(
                                                    color: colors.textSecondary,
                                                    fontWeight: FontWeight.w500,
                                                  ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
            ),
          ],
        );
      },
    );
  }

  String _moduleLabel(LanguageCubit language, String module) {
    final key = 'perm_module_${module.replaceAll('-', '_')}';
    final translated = language.translate(key);
    return translated == key ? module : translated;
  }

  String _roleLabel(LanguageCubit language, String role) {
    final key = switch (role) {
      'manager' => 'role_manager',
      'accountant' => 'role_accountant',
      'cashier' => 'role_cashier',
      'hr' => 'role_hr',
      'viewer' || 'observer' => 'role_viewer',
      'marketer' => 'role_marketer',
      _ => 'role_viewer',
    };
    return language.translate(key);
  }

  Widget _buildAccessTab(BuildContext context) {
    final colors = context.colors;
    final textStyles = context.textStyles;
    final language = context.watch<LanguageCubit>();

    return BlocBuilder<UsersBloc, UsersState>(
      buildWhen: (p, c) =>
          p.permissionMatrix != c.permissionMatrix ||
          p.isPermissionsLoading != c.isPermissionsLoading ||
          p.isPermissionSaving != c.isPermissionSaving ||
          p.permissionsError != c.permissionsError,
      builder: (context, state) {
        if (state.isPermissionsLoading && state.permissionMatrix == null) {
          return const UsersOverviewShimmer();
        }

        if (state.permissionMatrix == null) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    language.translateMessage(
                      state.permissionsError ?? 'error_load_failed',
                    ),
                    textAlign: TextAlign.center,
                    style: textStyles.bodySans,
                  ),
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: () => context.read<UsersBloc>().add(
                      const LoadPermissionsMatrix(forceRefresh: true),
                    ),
                    child: Text(language.translate('common_retry')),
                  ),
                ],
              ),
            ),
          );
        }

        final matrix = state.permissionMatrix!;
        final selectedRole =
            _selectedAccessRole ??
            (matrix.roles.isNotEmpty ? matrix.roles.first : null);
        if (selectedRole == null) {
          return Center(
            child: Text(
              language.translate('users_matrix_empty'),
              style: textStyles.bodySans,
            ),
          );
        }

        final cellMap = matrix.cellMap;

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: colors.surfaceNested,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: colors.border),
              ),
              child: Row(
                children: [
                  Icon(TablerIcons.info_circle, color: colors.brand, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      language.translate('users_matrix_hint'),
                      style: textStyles.captionSans.copyWith(
                        color: colors.textSecondary,
                        height: 1.3,
                      ),
                    ),
                  ),
                  if (state.isPermissionSaving)
                    SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: colors.brand,
                      ),
                    ),
                ],
              ),
            ),
            if (state.permissionsError != null) ...[
              const SizedBox(height: 8),
              Text(
                language.translateMessage(state.permissionsError!),
                style: textStyles.captionSans.copyWith(color: colors.accentRed),
              ),
            ],
            const SizedBox(height: 14),
            Text(
              language.translate('users_matrix_legend_title'),
              style: textStyles.captionSans.copyWith(
                fontWeight: FontWeight.w600,
                color: colors.textSecondary,
              ),
            ),
            const SizedBox(height: 8),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: matrix.roles.map((role) {
                  final isSelected = selectedRole == role;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8.0),
                    child: ChoiceChip(
                      label: Text(_roleLabel(language, role)),
                      selected: isSelected,
                      selectedColor: colors.brand,
                      labelStyle: textStyles.captionSans.copyWith(
                        color: isSelected ? Colors.white : colors.textPrimary,
                        fontWeight: isSelected
                            ? FontWeight.w600
                            : FontWeight.w400,
                      ),
                      checkmarkColor: Colors.white,
                      side: BorderSide(
                        color: isSelected ? colors.brand : colors.border,
                      ),
                      onSelected: (val) {
                        if (val) {
                          setState(() => _selectedAccessRole = role);
                        }
                      },
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 14),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    language.translate('users_module'),
                    style: textStyles.bodySans.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Row(
                    children: [
                      SizedBox(
                        width: 34,
                        child: Center(
                          child: _buildActionLegend(
                            'R',
                            language.translate('users_matrix_read'),
                          ),
                        ),
                      ),
                      SizedBox(
                        width: 34,
                        child: Center(
                          child: _buildActionLegend(
                            'C',
                            language.translate('users_matrix_create'),
                          ),
                        ),
                      ),
                      SizedBox(
                        width: 34,
                        child: Center(
                          child: _buildActionLegend(
                            'U',
                            language.translate('users_matrix_update'),
                          ),
                        ),
                      ),
                      SizedBox(
                        width: 34,
                        child: Center(
                          child: _buildActionLegend(
                            'D',
                            language.translate('users_matrix_delete'),
                          ),
                        ),
                      ),
                      SizedBox(
                        width: 34,
                        child: Center(
                          child: _buildActionLegend(
                            'A',
                            language.translate('users_matrix_action'),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            ...matrix.modules.map((module) {
              final cell =
                  cellMap[PermissionCell.keyOf(selectedRole, module)] ??
                  PermissionCell(
                    role: selectedRole,
                    module: module,
                    canView: false,
                    canCreate: false,
                    canEdit: false,
                    canDelete: false,
                    canAction: false,
                  );

              return Padding(
                padding: const EdgeInsets.only(bottom: 6.0),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: colors.surface,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: colors.border),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          _moduleLabel(language, module),
                          style: textStyles.bodySans.copyWith(
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      Row(
                        children: [
                          _buildPermCheckbox(
                            field: 'view',
                            value: cell.canView,
                            role: selectedRole,
                            module: module,
                          ),
                          _buildPermCheckbox(
                            field: 'create',
                            value: cell.canCreate,
                            role: selectedRole,
                            module: module,
                          ),
                          _buildPermCheckbox(
                            field: 'edit',
                            value: cell.canEdit,
                            role: selectedRole,
                            module: module,
                          ),
                          _buildPermCheckbox(
                            field: 'delete',
                            value: cell.canDelete,
                            role: selectedRole,
                            module: module,
                          ),
                          _buildPermCheckbox(
                            field: 'action',
                            value: cell.canAction,
                            role: selectedRole,
                            module: module,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            }),
          ],
        );
      },
    );
  }

  Widget _buildActionLegend(String shortLabel, String tooltip) {
    final colors = context.colors;
    final textStyles = context.textStyles;

    return Tooltip(
      message: tooltip,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        decoration: BoxDecoration(
          color: colors.surfaceNested,
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          shortLabel,
          style: textStyles.smallSans.copyWith(
            fontSize: 9.5,
            fontWeight: FontWeight.w500,
            color: colors.textSecondary,
          ),
        ),
      ),
    );
  }

  Widget _buildPermCheckbox({
    required String field,
    required bool value,
    required String role,
    required String module,
  }) {
    final colors = context.colors;

    return SizedBox(
      width: 34,
      height: 34,
      child: Center(
        child: Checkbox(
          value: value,
          activeColor: colors.brand,
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          onChanged: (val) {
            if (val == null) return;
            context.read<UsersBloc>().add(
              TogglePermissionRequested(
                role: role,
                module: module,
                field: field,
                value: val,
              ),
            );
          },
        ),
      ),
    );
  }
}

Widget _buildRoleBadge(
  BuildContext context,
  String role,
  dynamic colors,
  LanguageCubit language,
) {
  Color col;
  String name;

  switch (role) {
    case 'director':
      col = colors.accentGreen;
      name = language.translate('role_director');
      break;
    case 'manager':
      col = colors.brand;
      name = language.translate('role_manager');
      break;
    case 'accountant':
      col = colors.brand;
      name = language.translate('role_accountant');
      break;
    case 'cashier':
    case 'seller':
      col = colors.accentAmber;
      name = language.translate('role_cashier');
      break;
    case 'hr':
      col = colors.brand;
      name = language.translate('role_hr');
      break;
    default:
      col = colors.textSecondary;
      name = language.translate('role_observer');
  }

  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
    decoration: BoxDecoration(
      color: col.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(6),
    ),
    child: Text(
      name.toUpperCase(),
      style: TextStyle(
        color: col,
        fontSize: 11,
        fontWeight: FontWeight.w600,
      ),
    ),
  );
}

String _userRoleTranslationKey(String role) {
  return switch (role) {
    'director' => 'role_director',
    'manager' => 'role_manager',
    'accountant' => 'role_accountant',
    'cashier' || 'seller' => 'role_cashier',
    'hr' => 'role_hr',
    _ => 'role_observer',
  };
}

void _confirmDelete(BuildContext context, String id) {
  final colors = context.colors;
  final textStyles = context.textStyles;
  final language = context.read<LanguageCubit>();
  showDialog(
    context: context,
    builder: (dCtx) => AlertDialog(
      title: Text(language.translate('users_delete_title')),
      content: Text(language.translate('users_delete_message')),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dCtx),
          child: Text(
            language.translate('common_cancel'),
            style: textStyles.captionSans.copyWith(
              color: colors.textSecondary,
            ),
          ),
        ),
        TextButton(
          onPressed: () {
            context.read<UsersBloc>().add(DeleteUserRequested(id));
            Navigator.pop(dCtx);
          },
          child: Text(
            language.translate('common_delete'),
            style: textStyles.captionSans.copyWith(color: colors.accentRed),
          ),
        ),
      ],
    ),
  );
}

Future<void> _showUserDialog(
  BuildContext context, {
  UserProfile? user,
}) async {
  final colors = context.colors;
  final textStyles = context.textStyles;
  final language = context.read<LanguageCubit>();

  final isEdit = user != null;
  final fullNameCtrl = TextEditingController(text: user?.fullName);
  final usernameCtrl = TextEditingController(text: user?.username);
  final emailCtrl = TextEditingController(text: user?.email);
  final phoneCtrl = TextEditingController(text: user?.phone);
  final passwordCtrl = TextEditingController();

  bool obscurePassword = true;
  String role = user?.role ?? 'observer';
  String branch = 'users_branch_none';
  bool active = user?.active ?? true;
  bool twoFactor = user?.twoFactor ?? false;

  final branches = [
    'users_branch_none',
    'users_branch_center',
    'users_branch_kassa2',
  ];
  final roles = [
    'observer',
    'manager',
    'accountant',
    'cashier',
    'hr',
    'marketer',
    'director',
  ];

  try {
    await LedgerBottomSheet.show(
      context: context,
      title: isEdit
          ? language.translate('users_edit_title')
          : language.translate('users_new_title'),
      builder: (context, setModalState) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              language.translate('users_full_name'),
              style: textStyles.captionSans.copyWith(
                fontWeight: FontWeight.w500,
                color: colors.textSecondary,
              ),
            ),
            const SizedBox(height: 6),
            TextField(
              controller: fullNameCtrl,
              style: textStyles.bodySans,
              decoration: const InputDecoration(
                hintText: 'Иванов Иван Иванович',
              ),
            ),
            const SizedBox(height: 14),

            if (!isEdit) ...[
              Text(
                language.translate('users_login'),
                style: textStyles.captionSans.copyWith(
                  fontWeight: FontWeight.w500,
                  color: colors.textSecondary,
                ),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: usernameCtrl,
                style: textStyles.bodySans,
                decoration: const InputDecoration(hintText: 'ivanov'),
              ),
              const SizedBox(height: 14),
            ],

            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        language.translate('users_email'),
                        style: textStyles.captionSans.copyWith(
                          fontWeight: FontWeight.w500,
                          color: colors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 6),
                      TextField(
                        controller: emailCtrl,
                        style: textStyles.bodySans,
                        decoration: const InputDecoration(
                          hintText: 'user@example.com',
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        language.translate('users_phone'),
                        style: textStyles.captionSans.copyWith(
                          fontWeight: FontWeight.w500,
                          color: colors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 6),
                      TextField(
                        controller: phoneCtrl,
                        style: textStyles.bodySans,
                        decoration: const InputDecoration(
                          hintText: '+992 900 00 00 00',
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        language.translate('users_role'),
                        style: textStyles.captionSans.copyWith(
                          fontWeight: FontWeight.w500,
                          color: colors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 6),
                      ExpansibleWidget<String>.selection(
                        cardPadding: const EdgeInsets.symmetric(
                          horizontal: 4,
                          vertical: 0,
                        ),
                        tilePadding: const EdgeInsets.symmetric(
                          horizontal: 8,
                        ),
                        title: Text(
                          language.translate(_userRoleTranslationKey(role)),
                          style: textStyles.captionSans.copyWith(
                            fontWeight: FontWeight.w500,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        items: roles,
                        selectedValue: role,
                        itemLabelBuilder: (rCode) => language.translate(
                          _userRoleTranslationKey(rCode),
                        ),
                        onSelected: (val) {
                          setModalState(() => role = val);
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        language.translate('users_branch'),
                        style: textStyles.captionSans.copyWith(
                          fontWeight: FontWeight.w500,
                          color: colors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 6),
                      ExpansibleWidget<String>.selection(
                        cardPadding: const EdgeInsets.symmetric(
                          horizontal: 4,
                          vertical: 0,
                        ),
                        tilePadding: const EdgeInsets.symmetric(
                          horizontal: 8,
                        ),
                        title: Text(
                          language.translateMessage(branch),
                          style: textStyles.captionSans.copyWith(
                            fontWeight: FontWeight.w500,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        items: branches,
                        selectedValue: branch,
                        itemLabelBuilder: (b) => language.translateMessage(b),
                        onSelected: (val) {
                          setModalState(() => branch = val);
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            Text(
              isEdit
                  ? language.translate('users_new_password')
                  : language.translate('users_password'),
              style: textStyles.captionSans.copyWith(
                fontWeight: FontWeight.w500,
                color: colors.textSecondary,
              ),
            ),
            const SizedBox(height: 6),
            TextField(
              controller: passwordCtrl,
              obscureText: obscurePassword,
              style: textStyles.bodySans,
              decoration: InputDecoration(
                hintText: language.translate('users_password_hint'),
                suffixIcon: IconButton(
                  icon: Icon(
                    obscurePassword ? TablerIcons.eye : TablerIcons.eye_off,
                    size: 20,
                  ),
                  onPressed: () {
                    setModalState(() {
                      obscurePassword = !obscurePassword;
                    });
                  },
                ),
              ),
            ),
            const SizedBox(height: 20),

            Text(
              language.translate('users_security_access'),
              style: textStyles.captionSans.copyWith(
                fontWeight: FontWeight.w600,
                color: colors.textSecondary,
              ),
            ),
            const SizedBox(height: 8),
            SwitchListTile.adaptive(
              value: active,
              contentPadding: EdgeInsets.zero,
              title: Text(
                language.translate('users_account_active'),
                style: textStyles.bodySans,
              ),
              onChanged: (val) => setModalState(() => active = val),
            ),
            SwitchListTile.adaptive(
              value: twoFactor,
              contentPadding: EdgeInsets.zero,
              title: Text(
                language.translate('users_two_factor'),
                style: textStyles.bodySans,
              ),
              subtitle: Text(
                language.translate('users_two_factor_hint'),
                style: textStyles.captionSans.copyWith(
                  color: colors.textSecondary,
                ),
              ),
              onChanged: (val) => setModalState(() => twoFactor = val),
            ),
            const SizedBox(height: 24),

            SizedBox(
              height: 48,
              child: ElevatedButton(
                onPressed: () {
                  final fn = fullNameCtrl.text.trim();
                  final un = usernameCtrl.text.trim();
                  final em = emailCtrl.text.trim();
                  final ph = phoneCtrl.text.trim();
                  final pw = passwordCtrl.text.trim();

                  if (isEdit) {
                    context.read<UsersBloc>().add(
                      UpdateUserRequested(
                        id: user.id,
                        fullName: fn.isNotEmpty ? fn : user.fullName,
                        email: em.isNotEmpty ? em : user.email,
                        phone: ph.isNotEmpty ? ph : user.phone,
                        role: role,
                        active: active,
                        twoFactor: twoFactor,
                        password: pw.isNotEmpty ? pw : null,
                      ),
                    );
                  } else {
                    if (fn.isEmpty || un.isEmpty || pw.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            language.translate('error_fields_required'),
                          ),
                          backgroundColor: colors.accentRed,
                        ),
                      );
                      return;
                    }
                    context.read<UsersBloc>().add(
                      CreateUserRequested(
                        fullName: fn,
                        username: un,
                        email: em.isNotEmpty ? em : null,
                        phone: ph.isNotEmpty ? ph : null,
                        role: role,
                        active: active,
                        twoFactor: twoFactor,
                        password: pw,
                      ),
                    );
                  }
                  Navigator.pop(context);
                },
                child: Text(
                  language.translate(
                    isEdit ? 'common_save' : 'common_create',
                  ),
                ),
              ),
            ),
            if (isEdit) ...[
              const SizedBox(height: 12),
              SizedBox(
                height: 48,
                child: OutlinedButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    _confirmDelete(context, user.id);
                  },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: colors.accentRed,
                    side: BorderSide(
                      color: colors.accentRed.withValues(alpha: 0.5),
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  icon: const Icon(TablerIcons.trash, size: 18),
                  label: Text(language.translate('common_delete')),
                ),
              ),
            ],
          ],
        );
      },
    );
  } finally {
    fullNameCtrl.dispose();
    usernameCtrl.dispose();
    emailCtrl.dispose();
    phoneCtrl.dispose();
    passwordCtrl.dispose();
  }
}
