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

class UsersSearchChanged extends UsersEvent {
  final String query;

  const UsersSearchChanged(this.query);

  @override
  List<Object?> get props => [query];
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
  List<Object?> get props => [
    fullName,
    username,
    email,
    phone,
    role,
    active,
    twoFactor,
  ];
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
  List<Object?> get props => [
    id,
    fullName,
    email,
    phone,
    role,
    active,
    twoFactor,
  ];
}

class DeleteUserRequested extends UsersEvent {
  final String id;

  const DeleteUserRequested(this.id);

  @override
  List<Object?> get props => [id];
}

class LoadPermissionsMatrix extends UsersEvent {
  final bool forceRefresh;

  const LoadPermissionsMatrix({this.forceRefresh = false});

  @override
  List<Object?> get props => [forceRefresh];
}

/// Toggle one permission bit; auto-saves via API (web AccessTab parity).
class TogglePermissionRequested extends UsersEvent {
  final String role;
  final String module;

  /// One of: view, create, edit, delete, action
  final String field;
  final bool value;

  const TogglePermissionRequested({
    required this.role,
    required this.module,
    required this.field,
    required this.value,
  });

  @override
  List<Object?> get props => [role, module, field, value];
}
