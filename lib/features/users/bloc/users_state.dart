import 'package:equatable/equatable.dart';
import '../domain/user_models.dart';

class UsersState extends Equatable {
  final List<UserProfile> users;
  final bool isLoading;
  final bool isSearching;
  final bool isRefreshing;
  final bool isSubmitting;
  final String? errorMessage;
  final String? successMessage;

  final PermissionMatrix? permissionMatrix;
  final bool isPermissionsLoading;
  final bool isPermissionSaving;
  final String? permissionsError;

  const UsersState({
    this.users = const [],
    this.isLoading = false,
    this.isSearching = false,
    this.isRefreshing = false,
    this.isSubmitting = false,
    this.errorMessage,
    this.successMessage,
    this.permissionMatrix,
    this.isPermissionsLoading = false,
    this.isPermissionSaving = false,
    this.permissionsError,
  });

  UsersState copyWith({
    List<UserProfile>? users,
    bool? isLoading,
    bool? isSearching,
    bool? isRefreshing,
    bool? isSubmitting,
    String? errorMessage,
    String? successMessage,
    bool clearError = false,
    bool clearSuccess = false,
    PermissionMatrix? permissionMatrix,
    bool? isPermissionsLoading,
    bool? isPermissionSaving,
    String? permissionsError,
    bool clearPermissionsError = false,
  }) {
    return UsersState(
      users: users ?? this.users,
      isLoading: isLoading ?? this.isLoading,
      isSearching: isSearching ?? this.isSearching,
      isRefreshing: isRefreshing ?? this.isRefreshing,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      successMessage: clearSuccess
          ? null
          : (successMessage ?? this.successMessage),
      permissionMatrix: permissionMatrix ?? this.permissionMatrix,
      isPermissionsLoading: isPermissionsLoading ?? this.isPermissionsLoading,
      isPermissionSaving: isPermissionSaving ?? this.isPermissionSaving,
      permissionsError: clearPermissionsError
          ? null
          : (permissionsError ?? this.permissionsError),
    );
  }

  @override
  List<Object?> get props => [
    users,
    isLoading,
    isSearching,
    isRefreshing,
    isSubmitting,
    errorMessage,
    successMessage,
    permissionMatrix,
    isPermissionsLoading,
    isPermissionSaving,
    permissionsError,
  ];
}
