import 'package:equatable/equatable.dart';
import '../domain/my_permissions.dart';

/// Holds effective rights from `GET /permissions/me`.
///
/// Implements [Equatable] to eliminate redundant UI rebuilds on 30s timer polling.
class PermissionsState extends Equatable {
  final MyPermissions? data;
  final bool loading;
  final String? error;

  const PermissionsState({this.data, this.loading = false, this.error});

  static const initial = PermissionsState();

  PermissionsState copyWith({
    MyPermissions? data,
    bool? loading,
    String? error,
    bool clearData = false,
    bool clearError = false,
  }) {
    return PermissionsState(
      data: clearData ? null : (data ?? this.data),
      loading: loading ?? this.loading,
      error: clearError ? null : (error ?? this.error),
    );
  }

  @override
  List<Object?> get props => [data, loading, error];
}
