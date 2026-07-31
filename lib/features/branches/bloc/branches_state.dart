import 'package:equatable/equatable.dart';
import '../domain/branch_models.dart';

abstract class BranchesState extends Equatable {
  const BranchesState();

  @override
  List<Object?> get props => [];
}

class BranchesInitial extends BranchesState {}

class BranchesLoading extends BranchesState {}

class BranchesLoaded extends BranchesState {
  final List<Branch> branches;
  final String? message;

  const BranchesLoaded({required this.branches, this.message});

  @override
  List<Object?> get props => [branches, message];
}

class BranchesError extends BranchesState {
  final String message;
  const BranchesError(this.message);

  @override
  List<Object?> get props => [message];
}
