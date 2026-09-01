import 'package:equatable/equatable.dart';
import '../domain/system_repository.dart';

class BackupsState extends Equatable {
  final List<BackupFile> files;
  final bool isLoading;
  final bool isCreating;
  final String? error;
  final String? createdFileName;

  const BackupsState({
    this.files = const [],
    this.isLoading = false,
    this.isCreating = false,
    this.error,
    this.createdFileName,
  });

  static const initial = BackupsState();

  BackupsState copyWith({
    List<BackupFile>? files,
    bool? isLoading,
    bool? isCreating,
    String? error,
    String? createdFileName,
    bool clearError = false,
    bool clearCreatedFileName = false,
  }) {
    return BackupsState(
      files: files ?? this.files,
      isLoading: isLoading ?? this.isLoading,
      isCreating: isCreating ?? this.isCreating,
      error: clearError ? null : (error ?? this.error),
      createdFileName: clearCreatedFileName
          ? null
          : (createdFileName ?? this.createdFileName),
    );
  }

  @override
  List<Object?> get props => [
    files,
    isLoading,
    isCreating,
    error,
    createdFileName,
  ];
}
