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

class _UsersViewState extends State<UsersView>
    with SingleTickerProviderStateMixin {
  static const _pageSize = 40;

  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  late final TabController _tabController;

  int _visibleUsers = _pageSize;
  List<UserProfile>? _lastUsers;
  String _selectedAccessRole = 'manager';

  static const _allModules = [
    'Дашборд',
    'Касса',
    'Отчёты',
    'Фин-операции',
    'Финансы',
    'Склад',
    'Клиенты',
    'Кадры',
    'Задачи',
    'Мои задачи',
    'Чек-листы',
    'Аудит',
    'Юр. блок',
    'Маркетинг',
    'Стратегия',
    'Интеграции',
    'Филиалы',
  ];

  // Матрица прав для вкладки "Доступ" для всех 17 разделов по всем ролям
  late final Map<String, Map<String, Map<String, bool>>> _permissionsMatrix = {
    for (final role in ['manager', 'accountant', 'cashier', 'hr', 'observer'])
      role: {
        for (final module in _allModules)
          module: {
            'view': true,
            'add': role != 'observer',
            'edit': role != 'observer',
            'del': role == 'manager' || role == 'accountant',
            'act': role != 'observer',
          },
      },
  };

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(_handleTabChange);
    _scrollController.addListener(_revealMoreUsers);
  }

  void _handleTabChange() {
    if (mounted) {
      setState(() {});
    }
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
    _tabController.removeListener(_handleTabChange);
    _tabController.dispose();
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
      floatingActionButton: _tabController.index == 0
          ? FloatingActionButton.extended(
              onPressed: () => _showUserDialog(context),
              backgroundColor: colors.brand,
              foregroundColor: Colors.white,
              icon: const Icon(TablerIcons.user_plus),
              label: Text(
                language.translate('users_new_user_btn'),
                style: textStyles.bodySans.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            )
          : null,
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) {
          return [
            LedgerCollapsingHeader(
              title: language.translate('users_title'),
              pinned: true,
              floating: true,
              snap: true,
              bottom: TabBar(
                controller: _tabController,
                indicatorColor: colors.brand,
                labelColor: colors.brand,
                unselectedLabelColor: colors.textSecondary,
                labelStyle: textStyles.bodySans.copyWith(
                  fontWeight: FontWeight.bold,
                ),
                tabs: [
                  Tab(text: language.translate('users_tab_users')),
                  Tab(text: language.translate('users_tab_access')),
                ],
              ),
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
                  content: Text(
                    language.translateMessage(state.successMessage!),
                  ),
                  backgroundColor: colors.accentGreen,
                ),
              );
            }
          },
          child: TabBarView(
            controller: _tabController,
            children: [_buildUsersTab(context), _buildAccessTab(context)],
          ),
        ),
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
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 4,
                        ),
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
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 8.0),
                            child: LedgerCard(
                              padding: const EdgeInsets.all(14),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Expanded(
                                        child: Text(
                                          user.fullName,
                                          style: textStyles.bodySans.copyWith(
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
                                      user.email!.isNotEmpty) ...[
                                    const SizedBox(height: 2),
                                    Text(
                                      language.translate(
                                        'users_email_value',
                                        params: {'value': user.email},
                                      ),
                                      style: textStyles.captionSans.copyWith(
                                        color: colors.textSecondary,
                                      ),
                                    ),
                                  ],
                                  if (user.phone != null &&
                                      user.phone!.isNotEmpty) ...[
                                    const SizedBox(height: 2),
                                    Text(
                                      language.translate(
                                        'users_phone_value',
                                        params: {'value': user.phone},
                                      ),
                                      style: textStyles.captionSans.copyWith(
                                        color: colors.textSecondary,
                                      ),
                                    ),
                                  ],
                                  const Divider(height: 16),
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
                                                  color: colors.textSecondary,
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
                                              size: 18,
                                            ),
                                            tooltip: language.translate(
                                              'common_edit',
                                            ),
                                            onPressed: () => _showUserDialog(
                                              context,
                                              user: user,
                                            ),
                                          ),
                                          IconButton(
                                            icon: Icon(
                                              TablerIcons.trash,
                                              color: colors.accentRed,
                                              size: 18,
                                            ),
                                            tooltip: language.translate(
                                              'common_delete',
                                            ),
                                            onPressed: () {
                                              _confirmDelete(context, user.id);
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
    );
  }

  /// Вкладка "Доступ" — Адаптированная матрица прав для мобильных устройств
  Widget _buildAccessTab(BuildContext context) {
    final colors = context.colors;
    final textStyles = context.textStyles;
    final language = context.watch<LanguageCubit>();

    final roles = [
      {'code': 'manager', 'label': language.translate('role_manager')},
      {'code': 'accountant', 'label': language.translate('role_accountant')},
      {'code': 'cashier', 'label': language.translate('role_cashier')},
      {'code': 'hr', 'label': language.translate('role_hr')},
      {'code': 'observer', 'label': language.translate('role_observer')},
    ];

    final currentRolePerms = _permissionsMatrix[_selectedAccessRole] ?? {};

    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        // Информационный баннер
        LedgerCard(
          backgroundColor: colors.surfaceNested,
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Icon(TablerIcons.info_circle, color: colors.brand, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Отметьте права ролей по разделам (директор — всегда полный доступ). Изменения применяются у сотрудника сразу.',
                  style: textStyles.captionSans.copyWith(
                    color: colors.textSecondary,
                    height: 1.3,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // Выбор роли для фильтрации матрицы прав на мобильном экране
        Text(
          'Выберите роль для настройки доступа:',
          style: textStyles.captionSans.copyWith(
            fontWeight: FontWeight.bold,
            color: colors.textSecondary,
          ),
        ),
        const SizedBox(height: 8),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: roles.map((r) {
              final isSelected = _selectedAccessRole == r['code'];
              return Padding(
                padding: const EdgeInsets.only(right: 8.0),
                child: ChoiceChip(
                  label: Text(r['label']!),
                  selected: isSelected,
                  selectedColor: colors.brand.withValues(alpha: 0.15),
                  labelStyle: textStyles.captionSans.copyWith(
                    color: isSelected ? colors.brand : colors.textPrimary,
                    fontWeight: isSelected
                        ? FontWeight.bold
                        : FontWeight.normal,
                  ),
                  side: BorderSide(
                    color: isSelected ? colors.brand : colors.border,
                  ),
                  onSelected: (val) {
                    if (val) setState(() => _selectedAccessRole = r['code']!);
                  },
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 14),

        // Обозначение действий: Пр (Просмотр), Доб (Добавление), Изм (Изменение), Уд (Удаление), Дей (Действия)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Модуль',
                style: textStyles.bodySans.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              Row(
                children: [
                  SizedBox(
                    width: 34,
                    child: Center(child: _buildActionLegend('Пр', 'Просмотр')),
                  ),
                  SizedBox(
                    width: 34,
                    child: Center(
                      child: _buildActionLegend('Доб', 'Добавление'),
                    ),
                  ),
                  SizedBox(
                    width: 34,
                    child: Center(
                      child: _buildActionLegend('Изм', 'Изменение'),
                    ),
                  ),
                  SizedBox(
                    width: 34,
                    child: Center(child: _buildActionLegend('Уд', 'Удаление')),
                  ),
                  SizedBox(
                    width: 34,
                    child: Center(child: _buildActionLegend('Дей', 'Действия')),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),

        // Список модулей с чекбоксами для выбранной роли
        ...currentRolePerms.entries.map((entry) {
          final moduleName = entry.key;
          final perms = entry.value;

          return Padding(
            padding: const EdgeInsets.only(bottom: 6.0),
            child: LedgerCard(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      moduleName,
                      style: textStyles.bodySans.copyWith(
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  Row(
                    children: [
                      _buildPermCheckbox(
                        'view',
                        perms['view'] ?? false,
                        moduleName,
                      ),
                      _buildPermCheckbox(
                        'add',
                        perms['add'] ?? false,
                        moduleName,
                      ),
                      _buildPermCheckbox(
                        'edit',
                        perms['edit'] ?? false,
                        moduleName,
                      ),
                      _buildPermCheckbox(
                        'del',
                        perms['del'] ?? false,
                        moduleName,
                      ),
                      _buildPermCheckbox(
                        'act',
                        perms['act'] ?? false,
                        moduleName,
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
            fontWeight: FontWeight.bold,
            color: colors.textSecondary,
          ),
        ),
      ),
    );
  }

  Widget _buildPermCheckbox(String actionKey, bool value, String moduleName) {
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
            setState(() {
              _permissionsMatrix[_selectedAccessRole]?[moduleName]?[actionKey] =
                  val;
            });
          },
        ),
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
      case 'manager':
        col = colors.brand;
        name = context.translate('role_manager');
        break;
      case 'accountant':
        col = colors.brand;
        name = context.translate('role_accountant');
        break;
      case 'cashier':
      case 'seller':
        col = colors.accentAmber;
        name = context.translate('role_cashier');
        break;
      case 'hr':
        col = colors.brand;
        name = context.translate('role_hr');
        break;
      default:
        col = colors.textSecondary;
        name = context.translate('role_observer');
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
      'manager' => 'role_manager',
      'accountant' => 'role_accountant',
      'cashier' || 'seller' => 'role_cashier',
      'hr' => 'role_hr',
      _ => 'role_observer',
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

  /// Фирменная модалка "Новый пользователь" (точный дизайн со скриншота 1)
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
    String branch = 'Без филиала';
    bool active = user?.active ?? true;
    bool twoFactor = user?.twoFactor ?? false;

    final branches = ['Без филиала', 'Главный филиал', 'Филиал №2'];
    final roles = [
      'observer',
      'manager',
      'accountant',
      'cashier',
      'hr',
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
              // 1. ФИО
              Text(
                language.translate('users_full_name'),
                style: textStyles.captionSans.copyWith(
                  fontWeight: FontWeight.bold,
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

              // 2. Логин
              if (!isEdit) ...[
                Text(
                  language.translate('users_login'),
                  style: textStyles.captionSans.copyWith(
                    fontWeight: FontWeight.bold,
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

              // 3. Email и Телефон (в ряду для планшета/широкого экрана или столбце)
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          language.translate('users_email'),
                          style: textStyles.captionSans.copyWith(
                            fontWeight: FontWeight.bold,
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
                            fontWeight: FontWeight.bold,
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

              // 4. Роль и Филиал (селекторы через ExpansibleWidget.selection)
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
                            fontWeight: FontWeight.bold,
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
                              fontWeight: FontWeight.w600,
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
                            fontWeight: FontWeight.bold,
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
                            branch,
                            style: textStyles.captionSans.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          items: branches,
                          selectedValue: branch,
                          itemLabelBuilder: (b) => b,
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

              // 5. Пароль с переключателем глазком
              Text(
                isEdit
                    ? language.translate('users_new_password')
                    : language.translate('users_password'),
                style: textStyles.captionSans.copyWith(
                  fontWeight: FontWeight.bold,
                  color: colors.textSecondary,
                ),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: passwordCtrl,
                obscureText: obscurePassword,
                style: textStyles.bodySans,
                decoration: InputDecoration(
                  hintText: 'Минимум 6 символов',
                  suffixIcon: IconButton(
                    icon: Icon(
                      obscurePassword ? TablerIcons.eye : TablerIcons.eye_off,
                      color: colors.textSecondary,
                      size: 20,
                    ),
                    onPressed: () {
                      setModalState(() => obscurePassword = !obscurePassword);
                    },
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // 6. Настройки безопасности и активности
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
                        setModalState(() => active = val);
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
                        setModalState(() => twoFactor = val);
                      },
                    ),
                  ],
                ),
              ),
            ],
          );
        },
        footerBuilder: (context, setModalState) {
          return SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
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
              style: ElevatedButton.styleFrom(
                backgroundColor: colors.brand,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                isEdit
                    ? language.translate('common_save')
                    : language.translate('common_create'),
                style: textStyles.bodySans.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
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
