import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_tabler_icons/flutter_tabler_icons.dart';
import '../../core/theme/theme_extensions.dart';
import '../../features/auth/bloc/auth_bloc.dart';
import '../../features/auth/bloc/auth_event.dart';
import '../../features/auth/bloc/auth_state.dart';
import '../widgets/ledger_card.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final textStyles = context.textStyles;

    return Scaffold(
      backgroundColor: colors.background,
      body: BlocConsumer<AuthBloc, AuthState>(
        listener: (context, state) {
          if (state is AuthError) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  state.message,
                  style: textStyles.bodySans.copyWith(color: colors.surface),
                ),
                backgroundColor: colors.accentRed,
              ),
            );
          }
        },
        builder: (context, state) {
          final isLoading = state is AuthLoading;

          return Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Логотип / Название системы
                  Icon(TablerIcons.wallet, size: 48, color: colors.brand),
                  const SizedBox(height: 12),
                  Text(
                    'PAYK LEDGER',
                    style: textStyles.h1Sans.copyWith(
                      fontWeight: FontWeight.w500,
                      letterSpacing: 2.0,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  Text(
                    'AI CFO Platform',
                    style: textStyles.captionSans,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 32),

                  // Форма входа
                  LedgerCard(
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text('ВХОД В СИСТЕМУ (MOB-05)', style: textStyles.smallSans),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _usernameController,
                            style: textStyles.bodySans,
                            enabled: !isLoading,
                            validator: (val) => val == null || val.trim().isEmpty ? 'Введите логин' : null,
                            decoration: const InputDecoration(
                              labelText: 'Имя пользователя или Email',
                              prefixIcon: Icon(TablerIcons.user, size: 20),
                            ),
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _passwordController,
                            obscureText: true,
                            style: textStyles.bodySans,
                            enabled: !isLoading,
                            validator: (val) => val == null || val.trim().isEmpty ? 'Введите пароль' : null,
                            decoration: const InputDecoration(
                              labelText: 'Пароль',
                              prefixIcon: Icon(TablerIcons.lock, size: 20),
                            ),
                          ),
                          const SizedBox(height: 24),
                          ElevatedButton(
                            onPressed: isLoading
                                ? null
                                : () {
                                    if (_formKey.currentState!.validate()) {
                                      context.read<AuthBloc>().add(
                                            LoginSubmitted(
                                              username: _usernameController.text,
                                              password: _passwordController.text,
                                            ),
                                          );
                                    }
                                  },
                            child: isLoading
                                ? const SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                    ),
                                  )
                                : const Text('Войти'),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Биометрия
                  if (!isLoading)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        OutlinedButton.icon(
                          onPressed: () {
                            context.read<AuthBloc>().add(BiometricLoginRequested());
                          },
                          icon: const Icon(TablerIcons.fingerprint),
                          label: const Text('Войти с Face ID / Touch ID'),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
