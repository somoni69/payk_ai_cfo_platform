import 'package:equatable/equatable.dart';

abstract class UsersEvent extends Equatable {
  const UsersEvent();

  @override
  List<Object?> get props => [];
}

class LoadUsersData extends UsersEvent {
  final String? search;

  const LoadUsersData({this.search});

  @override
  List<Object?> get props => [search];
}

class CreateUserRequested extends UsersEvent {
  final String fullName;
  final String username;
  final String? email;
  final String? phone;
  final String role;
  final String password;
  final bool active;
  final bool twoFactor;

  const CreateUserRequested({
    required this.fullName,
    required this.username,
    this.email,
    this.phone,
    required this.role,
    required this.password,
    required this.active,
    required this.twoFactor,
  });

  @override
  List<Object?> get props => [fullName, username, email, phone, role, password, active, twoFactor];
}

class UpdateUserRequested extends UsersEvent {
  final String id;
  final String? fullName;
  final String? email;
  final String? phone;
  final String? role;
  final String? password;
  final bool? active;
  final bool? twoFactor;

  const UpdateUserRequested({
    required this.id,
    this.fullName,
    this.email,
    this.phone,
    this.role,
    this.password,
    this.active,
    this.twoFactor,
  });

  @override
  List<Object?> get props => [id, fullName, email, phone, role, password, active, twoFactor];
}

class DeleteUserRequested extends UsersEvent {
  final String id;

  const DeleteUserRequested(this.id);

  @override
  List<Object?> get props => [id];
}
