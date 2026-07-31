import 'package:equatable/equatable.dart';
import '../domain/checklist_models.dart';

abstract class ChecklistsState extends Equatable {
  const ChecklistsState();

  @override
  List<Object?> get props => [];
}

class ChecklistsInitial extends ChecklistsState {}

class ChecklistsLoading extends ChecklistsState {}

class ChecklistsLoaded extends ChecklistsState {
  final List<ChecklistRun> todayRuns;

  const ChecklistsLoaded({required this.todayRuns});

  @override
  List<Object?> get props => [todayRuns];
}

class ChecklistsError extends ChecklistsState {
  final String message;
  const ChecklistsError(this.message);

  @override
  List<Object?> get props => [message];
}
