import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_tabler_icons/flutter_tabler_icons.dart';
import '../../core/localization/language_cubit.dart';
import '../../core/theme/theme_extensions.dart';
import '../../features/users/bloc/users_bloc.dart';
import '../../features/users/bloc/users_event.dart';
import '../../features/users/bloc/users_state.dart';
import '../../features/users/domain/user_models.dart';
import '../../features/users/domain/users_repository.dart';
import '../widgets/ledger_card.dart';
import '../widgets/ledger_pill.dart';
import '../widgets/expansible_widget.dart';
import '../widgets/ledger_bottom_sheet.dart';
import '../widgets/ledger_collapsing_header.dart';

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
  static const _pageSize = 40;

  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  int _visibleUsers = _pageSize;
  List<UserProfile>? _lastUsers;

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
    _scrollController
      ..removeListener(_revealMoreUsers)
      ..dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final textStyles = context.textStyles;
    final language = context.watch<LanguageCubit>();

    return Scaffold(
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) {
          return [
            LedgerCollapsingHeader(
              title: language.translate('users_title'),
              pinned: true,
              floating: true,
              snap: true,
            ),
          ];
        },
        body: BlocListener<UsersBloc, UsersState>(
        listener: (context, state) {
          if (!identical(_lastUsers, state.users)) {
            _lastUsers = state.users;
            if (_visibleUsers != _pageSize) {
              setState(() => _visibleUsers = _pageSize);
            }
          }
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
                content: Text(language.translateMessage(state.successMessage!)),
                backgroundColor: colors.accentGreen,
              ),
            );
          }
        },
        child: BlocBuilder<UsersBloc, UsersState>(
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
                // Поиск пользователей
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: TextField(
                    controller: _searchController,
                    onChanged: (val) {
                      context.read<UsersBloc>().add(UsersSearchChanged(val));
                    },
                    decoration: InputDecoration(
                      hintText: language.translate('users_search_hint'),
                      prefixIcon: Icon(
                        TablerIcons.search,
                        color: colors.textSecondary,
                      ),
                      fillColor: colors.surface,
                      filled: true,
                    ),
                  ),
                ),
                if (state.isSearching)
                  const LinearProgressIndicator(minHeight: 2)
                else
                  const SizedBox(height: 2),

                Expanded(
                  child: state.isLoading
                      ? const Center(child: CircularProgressIndicator())
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
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            itemCount: state.users.isEmpty ? 1 : visibleUsers,
                            itemBuilder: (context, index) {
                              if (state.users.isEmpty) {
                                return Center(
                                  child: Padding(
                                    padding: const EdgeInsets.all(32.0),
                                    child: Text(
                                      language.translate('users_empty'),
                                    ),
                                  ),
                                );
                              }

                              final user = state.users[index];
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 12.0),
                                child: LedgerCard(
                                  padding: const EdgeInsets.all(16),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          Expanded(
                                            child: Text(
                                              user.fullName,
                                              style: textStyles.bodySans
                                                  .copyWith(
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                            ),
                                          ),
                                          _buildRolePill(
                                            context,
                                            user.role,
                                            colors,
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        language.translate(
                                          'users_login_value',
                                          params: {'value': user.username},
                                        ),
                                        style: textStyles.captionSans.copyWith(
                                          color: colors.textSecondary,
                                        ),
                                      ),
                                      if (user.email != null &&
                                          user.email!.isNotEmpty)
                                        Text(
                                          language.translate(
                                            'users_email_value',
                                            params: {'value': user.email},
                                          ),
                                          style: textStyles.captionSans
                                              .copyWith(
                                                color: colors.textSecondary,
                                              ),
                                        ),
                                      if (user.phone != null &&
                                          user.phone!.isNotEmpty)
                                        Text(
                                          language.translate(
                                            'users_phone_value',
                                            params: {'value': user.phone},
                                          ),
                                          style: textStyles.captionSans
                                              .copyWith(
                                                color: colors.textSecondary,
                                              ),
                                        ),
                                      const Divider(height: 20),
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
                                                user.active
                                                    ? language.translate(
                                                        'users_active',
                                                      )
                                                    : language.translate(
                                                        'users_blocked',
                                                      ),
                                                style: textStyles.captionSans
                                                    .copyWith(
                                                      color:
                                                          colors.textSecondary,
                                                    ),
                                              ),
                                            ],
                                          ),
                                          Row(
                                            children: [
                                              IconButton(
                                                icon: Icon(
                                                  TablerIcons.pencil,
                                                  color: colors.brand,
                                                  size: 20,
                                                ),
                                                tooltip: language.translate(
                                                  'common_edit',
                                                ),
                                                onPressed: () =>
                                                    _showUserDialog(
                                                      context,
                                                      user: user,
                                                    ),
                                              ),
                                              IconButton(
                                                icon: Icon(
                                                  TablerIcons.trash,
                                                  color: colors.accentRed,
                                                  size: 20,
                                                ),
                                                tooltip: language.translate(
                                                  'common_delete',
                                                ),
                                                onPressed: () {
                                                  _confirmDelete(
                                                    context,
                                                    user.id,
                                                  );
                                                },
                                              ),
                                            ],
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
                ),
              ],
            );
          },
        ),
      ),
    ),
      floatingActionButton: FloatingActionButton(
        tooltip: language.translate('users_new_title'),
        backgroundColor: colors.brand,
        onPressed: () => _showUserDialog(context),
        child: const Icon(TablerIcons.user_plus, color: Colors.white),
      ),
    );
  }

  Widget _buildRolePill(BuildContext context, String role, dynamic colors) {
    Color col;
    String name;

    switch (role) {
      case 'director':
        col = colors.accentGreen;
        name = context.translate('role_director');
        break;
      case 'accountant':
        col = colors.brand;
        name = context.translate('role_accountant');
        break;
      case 'seller':
        col = colors.accentAmber;
        name = context.translate('role_seller');
        break;
      default:
        col = colors.textSecondary;
        name = context.translate('role_viewer');
    }

    return LedgerPill(
      text: name.toUpperCase(),
      backgroundColor: col.withValues(alpha: 0.1),
      textColor: col,
    );
  }

  String _userRoleTranslationKey(String role) {
    return switch (role) {
      'director' => 'role_director',
      'accountant' => 'role_accountant',
      'seller' => 'role_seller',
      _ => 'role_viewer',
    };
  }

  void _confirmDelete(BuildContext context, String id) {
    final colors = context.colors;
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
              style: TextStyle(color: colors.textSecondary),
            ),
          ),
          TextButton(
            onPressed: () {
              context.read<UsersBloc>().add(DeleteUserRequested(id));
              Navigator.pop(dCtx);
            },
            child: Text(
              language.translate('common_delete'),
              style: TextStyle(color: colors.accentRed),
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
    String role = user?.role ?? 'viewer';
    bool active = user?.active ?? true;
    bool twoFactor = user?.twoFactor ?? false;

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
              TextField(
                controller: fullNameCtrl,
                decoration: InputDecoration(
                  labelText: language.translate('users_full_name'),
                ),
              ),
              const SizedBox(height: 12),
              if (!isEdit) ...[
                TextField(
                  controller: usernameCtrl,
                  decoration: InputDecoration(
                    labelText: language.translate('users_login'),
                  ),
                ),
                const SizedBox(height: 12),
              ],
              TextField(
                controller: emailCtrl,
                decoration: InputDecoration(
                  labelText: language.translate('users_email'),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: phoneCtrl,
                decoration: InputDecoration(
                  labelText: language.translate('users_phone'),
                ),
              ),
              const SizedBox(height: 12),

              // Роль
              Text(
                language.translate('users_role'),
                style: textStyles.bodySans.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              ExpansibleWidget<String>.selection(
                cardPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 4,
                ),
                title: Text(
                  language.translate(_userRoleTranslationKey(role)),
                  style: textStyles.bodySans,
                ),
                items: const ['director', 'accountant', 'seller', 'viewer'],
                selectedValue: role,
                itemLabelBuilder: (roleCode) =>
                    language.translate(_userRoleTranslationKey(roleCode)),
                onSelected: (val) {
                  setModalState(() {
                    role = val;
                  });
                },
              ),
              const SizedBox(height: 12),

              TextField(
                controller: passwordCtrl,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: isEdit
                      ? language.translate('users_new_password')
                      : language.translate('users_password'),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                language.translate('users_security_access'),
                style: textStyles.captionSans.copyWith(
                  fontWeight: FontWeight.bold,
                  color: colors.textSecondary,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 8),
              LedgerCard(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 4,
                ),
                child: Column(
                  children: [
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        language.translate('users_account_active'),
                        style: textStyles.bodySans,
                      ),
                      value: active,
                      onChanged: (val) {
                        setModalState(() {
                          active = val;
                        });
                      },
                    ),
                    Divider(color: colors.border, height: 1),
                    SwitchListTile(
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
                      value: twoFactor,
                      onChanged: (val) {
                        setModalState(() {
                          twoFactor = val;
                        });
                      },
                    ),
                  ],
                ),
              ),
            ],
          );
        },
        footerBuilder: (context, setModalState) {
          return ElevatedButton(
            onPressed: () {
              final fullName = fullNameCtrl.text.trim();
              final username = usernameCtrl.text.trim();
              final email = emailCtrl.text.trim();
              final phone = phoneCtrl.text.trim();
              final password = passwordCtrl.text.trim();

              if (fullName.isEmpty) return;

              if (isEdit) {
                context.read<UsersBloc>().add(
                  UpdateUserRequested(
                    id: user.id,
                    fullName: fullName,
                    email: email,
                    phone: phone,
                    role: role,
                    password: password.isNotEmpty ? password : null,
                    active: active,
                    twoFactor: twoFactor,
                  ),
                );
              } else {
                if (username.isEmpty || password.isEmpty) return;
                context.read<UsersBloc>().add(
                  CreateUserRequested(
                    fullName: fullName,
                    username: username,
                    email: email,
                    phone: phone,
                    role: role,
                    password: password,
                    active: active,
                    twoFactor: twoFactor,
                  ),
                );
              }

              Navigator.pop(context);
            },
            child: Text(
              isEdit
                  ? language.translate('common_save')
                  : language.translate('common_create'),
            ),
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
}
