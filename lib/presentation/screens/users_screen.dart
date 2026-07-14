import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_tabler_icons/flutter_tabler_icons.dart';
import '../../core/theme/theme_extensions.dart';
import '../../features/users/bloc/users_bloc.dart';
import '../../features/users/bloc/users_event.dart';
import '../../features/users/bloc/users_state.dart';
import '../../features/users/domain/user_models.dart';
import '../../features/users/domain/users_repository.dart';
import '../widgets/ledger_card.dart';
import '../widgets/ledger_pill.dart';

class UsersScreen extends StatelessWidget {
  const UsersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider<UsersBloc>(
      create: (context) => UsersBloc(context.read<UsersRepository>())..add(const LoadUsersData()),
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
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final textStyles = context.textStyles;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: colors.surface,
        elevation: 0,
        title: Text(
          'Управление доступом (SYS)',
          style: textStyles.h2Sans.copyWith(fontWeight: FontWeight.w500),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: colors.brand,
        onPressed: () => _showUserDialog(context),
        child: const Icon(TablerIcons.user_plus, color: Colors.white),
      ),
      body: BlocListener<UsersBloc, UsersState>(
        listener: (context, state) {
          if (state.errorMessage != null) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.errorMessage!),
                backgroundColor: colors.accentRed,
              ),
            );
          }
          if (state.successMessage != null) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.successMessage!),
                backgroundColor: colors.accentGreen,
              ),
            );
          }
        },
        child: BlocBuilder<UsersBloc, UsersState>(
          builder: (context, state) {
            return Column(
              children: [
                // Поиск пользователей
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: TextField(
                    controller: _searchController,
                    onChanged: (val) {
                      context.read<UsersBloc>().add(LoadUsersData(search: val.trim()));
                    },
                    decoration: InputDecoration(
                      hintText: 'Поиск по логину или имени',
                      prefixIcon: Icon(TablerIcons.search, color: colors.textSecondary),
                      fillColor: colors.surface,
                      filled: true,
                    ),
                  ),
                ),

                Expanded(
                  child: state.isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : RefreshIndicator(
                          onRefresh: () async {
                            context.read<UsersBloc>().add(LoadUsersData(search: _searchController.text.trim()));
                          },
                          child: ListView(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            children: [
                              if (state.users.isEmpty)
                                const Center(
                                  child: Padding(
                                    padding: EdgeInsets.all(32.0),
                                    child: Text('Пользователей не найдено'),
                                  ),
                                )
                              else
                                ...state.users.map((user) {
                                  return Padding(
                                    padding: const EdgeInsets.only(bottom: 12.0),
                                    child: LedgerCard(
                                      padding: const EdgeInsets.all(16),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                            children: [
                                              Expanded(
                                                child: Text(
                                                  user.fullName,
                                                  style: textStyles.bodySans.copyWith(fontWeight: FontWeight.bold),
                                                ),
                                              ),
                                              _buildRolePill(user.role, colors),
                                            ],
                                          ),
                                          const SizedBox(height: 6),
                                          Text(
                                            'Логин: ${user.username}',
                                            style: textStyles.captionSans.copyWith(color: colors.textSecondary),
                                          ),
                                          if (user.email != null && user.email!.isNotEmpty)
                                            Text(
                                              'Email: ${user.email}',
                                              style: textStyles.captionSans.copyWith(color: colors.textSecondary),
                                            ),
                                          if (user.phone != null && user.phone!.isNotEmpty)
                                            Text(
                                              'Телефон: ${user.phone}',
                                              style: textStyles.captionSans.copyWith(color: colors.textSecondary),
                                            ),
                                          const Divider(height: 20),
                                          Row(
                                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                            children: [
                                              Row(
                                                children: [
                                                  Container(
                                                    width: 8,
                                                    height: 8,
                                                    decoration: BoxDecoration(
                                                      color: user.active ? colors.accentGreen : colors.accentRed,
                                                      shape: BoxShape.circle,
                                                    ),
                                                  ),
                                                  const SizedBox(width: 6),
                                                  Text(
                                                    user.active ? 'Активен' : 'Заблокирован',
                                                    style: textStyles.captionSans.copyWith(color: colors.textSecondary),
                                                  ),
                                                ],
                                              ),
                                              Row(
                                                children: [
                                                  IconButton(
                                                    icon: Icon(TablerIcons.pencil, color: colors.brand, size: 20),
                                                    onPressed: () => _showUserDialog(context, user: user),
                                                  ),
                                                  IconButton(
                                                    icon: Icon(TablerIcons.trash, color: colors.accentRed, size: 20),
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
                                }),
                            ],
                          ),
                        ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildRolePill(String role, dynamic colors) {
    Color col;
    String name;

    switch (role) {
      case 'director':
        col = colors.accentGreen;
        name = 'Директор';
        break;
      case 'accountant':
        col = colors.brand;
        name = 'Бухгалтер';
        break;
      case 'seller':
        col = colors.accentAmber;
        name = 'Продавец';
        break;
      default:
        col = colors.textSecondary;
        name = 'Наблюдатель';
    }

    return LedgerPill(
      text: name.toUpperCase(),
      backgroundColor: col.withValues(alpha: 0.1),
      textColor: col,
    );
  }

  void _confirmDelete(BuildContext context, String id) {
    final colors = context.colors;
    showDialog(
      context: context,
      builder: (dCtx) => AlertDialog(
        title: const Text('Удалить пользователя?'),
        content: const Text('Пользователь потеряет доступ к системе. Это действие необратимо.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dCtx),
            child: Text('Отмена', style: TextStyle(color: colors.textSecondary)),
          ),
          TextButton(
            onPressed: () {
              context.read<UsersBloc>().add(DeleteUserRequested(id));
              Navigator.pop(dCtx);
            },
            child: Text('Удалить', style: TextStyle(color: colors.accentRed)),
          ),
        ],
      ),
    );
  }

  void _showUserDialog(BuildContext context, {UserProfile? user}) {
    final colors = context.colors;
    final textStyles = context.textStyles;

    final isEdit = user != null;
    final fullNameCtrl = TextEditingController(text: user?.fullName);
    final usernameCtrl = TextEditingController(text: user?.username);
    final emailCtrl = TextEditingController(text: user?.email);
    final phoneCtrl = TextEditingController(text: user?.phone);
    final passwordCtrl = TextEditingController();
    String role = user?.role ?? 'viewer';
    bool active = user?.active ?? true;
    bool twoFactor = user?.twoFactor ?? false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: colors.surface,
      builder: (bCtx) {
        return StatefulBuilder(
          builder: (sCtx, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
                left: 16,
                right: 16,
                top: 16,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(isEdit ? 'Изменить пользователя' : 'Новый пользователь', style: textStyles.h2Sans),
                    const SizedBox(height: 16),
                    TextField(
                      controller: fullNameCtrl,
                      decoration: const InputDecoration(labelText: 'ФИО'),
                    ),
                    const SizedBox(height: 12),
                    if (!isEdit) ...[
                      TextField(
                        controller: usernameCtrl,
                        decoration: const InputDecoration(labelText: 'Логин'),
                      ),
                      const SizedBox(height: 12),
                    ],
                    TextField(
                      controller: emailCtrl,
                      decoration: const InputDecoration(labelText: 'Email'),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: phoneCtrl,
                      decoration: const InputDecoration(labelText: 'Телефон'),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: role,
                      items: const [
                        DropdownMenuItem(value: 'director', child: Text('Директор')),
                        DropdownMenuItem(value: 'accountant', child: Text('Бухгалтер')),
                        DropdownMenuItem(value: 'seller', child: Text('Продавец')),
                        DropdownMenuItem(value: 'viewer', child: Text('Наблюдатель')),
                      ],
                      onChanged: (val) {
                        if (val != null) {
                          setModalState(() {
                            role = val;
                          });
                        }
                      },
                      decoration: const InputDecoration(labelText: 'Роль'),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: passwordCtrl,
                      obscureText: true,
                      decoration: InputDecoration(
                        labelText: isEdit ? 'Новый пароль (оставьте пустым)' : 'Пароль',
                      ),
                    ),
                    const SizedBox(height: 12),
                    SwitchListTile(
                      title: const Text('Учетная запись активна'),
                      value: active,
                      onChanged: (val) {
                        setModalState(() {
                          active = val;
                        });
                      },
                    ),
                    SwitchListTile(
                      title: const Text('Двухфакторная аутентификация (2FA)'),
                      subtitle: const Text('SMS-код при входе'),
                      value: twoFactor,
                      onChanged: (val) {
                        setModalState(() {
                          twoFactor = val;
                        });
                      },
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton(
                      onPressed: () {
                        final fullName = fullNameCtrl.text.trim();
                        final username = usernameCtrl.text.trim();
                        final email = emailCtrl.text.trim();
                        final phone = phoneCtrl.text.trim();
                        final password = passwordCtrl.text.trim();

                        if (fullName.isEmpty) return;

                        if (isEdit) {
                          context.read<UsersBloc>().add(UpdateUserRequested(
                                id: user.id,
                                fullName: fullName,
                                email: email,
                                phone: phone,
                                role: role,
                                password: password.isNotEmpty ? password : null,
                                active: active,
                                twoFactor: twoFactor,
                              ));
                        } else {
                          if (username.isEmpty || password.isEmpty) return;
                          context.read<UsersBloc>().add(CreateUserRequested(
                                fullName: fullName,
                                username: username,
                                email: email,
                                phone: phone,
                                role: role,
                                password: password,
                                active: active,
                                twoFactor: twoFactor,
                              ));
                        }

                        Navigator.pop(bCtx);
                      },
                      child: Text(isEdit ? 'Сохранить' : 'Создать'),
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}
