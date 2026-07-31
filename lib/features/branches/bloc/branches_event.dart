import 'package:equatable/equatable.dart';

abstract class BranchesEvent extends Equatable {
  const BranchesEvent();

  @override
  List<Object?> get props => [];
}

class LoadBranches extends BranchesEvent {
  final bool forceRefresh;
  const LoadBranches({this.forceRefresh = false});

  @override
  List<Object?> get props => [forceRefresh];
}

class CreateBranchRequested extends BranchesEvent {
  final String name;
  final String address;
  final String phone;

  const CreateBranchRequested({
    required this.name,
    required this.address,
    required this.phone,
  });

  @override
  List<Object?> get props => [name, address, phone];
}

class UpdateBranchRequested extends BranchesEvent {
  final String id;
  final String name;
  final String address;
  final String phone;
  final bool isActive;

  const UpdateBranchRequested({
    required this.id,
    required this.name,
    required this.address,
    required this.phone,
    required this.isActive,
  });

  @override
  List<Object?> get props => [id, name, address, phone, isActive];
}

class DeleteBranchRequested extends BranchesEvent {
  final String id;
  const DeleteBranchRequested(this.id);

  @override
  List<Object?> get props => [id];
}
