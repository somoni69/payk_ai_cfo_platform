import 'package:equatable/equatable.dart';

/// Роли пользователей в системе PAYK согласно ТЗ (SYS-02 - SYS-07).
enum UserRole {
  director, // Директор: видит все, управляет всем (SYS-02)
  manager, // Менеджер: видит все, кроме системных настроек (SYS-03)
  accountant, // Бухгалтер: доступ только к кассе и финансам (SYS-04)
  cashier, // Кассир: только операции своей смены (SYS-05)
  hr, // HR: только кадры и задачи (SYS-06)
  viewer; // Только просмотр: ничего не может изменять (SYS-07)

  String get label {
    switch (this) {
      case UserRole.director:
        return 'Директор';
      case UserRole.manager:
        return 'Менеджер';
      case UserRole.accountant:
        return 'Бухгалтер';
      case UserRole.cashier:
        return 'Кассир';
      case UserRole.hr:
        return 'HR-специалист';
      case UserRole.viewer:
        return 'Наблюдатель';
    }
  }
}

abstract class AuthState extends Equatable {
  const AuthState();

  @override
  List<Object?> get props => [];
}

class AuthInitial extends AuthState {}

class AuthLoading extends AuthState {}

class AuthAuthenticated extends AuthState {
  final String username;
  final UserRole role;

  const AuthAuthenticated({required this.username, required this.role});

  @override
  List<Object?> get props => [username, role];
}

class AuthUnauthenticated extends AuthState {}

class AuthError extends AuthState {
  final String message;

  const AuthError(this.message);

  @override
  List<Object?> get props => [message];
}
