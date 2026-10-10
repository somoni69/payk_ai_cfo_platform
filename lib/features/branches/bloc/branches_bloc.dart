import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/network/user_facing_error.dart';
import '../domain/branches_repository.dart';
import 'branches_event.dart';
import 'branches_state.dart';

class BranchesBloc extends Bloc<BranchesEvent, BranchesState> {
  final BranchesRepository _repository;

  BranchesBloc(this._repository) : super(BranchesInitial()) {
    on<LoadBranches>(_onLoadBranches);
    on<CreateBranchRequested>(_onCreateBranchRequested);
    on<UpdateBranchRequested>(_onUpdateBranchRequested);
    on<DeleteBranchRequested>(_onDeleteBranchRequested);
  }

  Future<void> _onLoadBranches(
    LoadBranches event,
    Emitter<BranchesState> emit,
  ) async {
    if (state is! BranchesLoaded || event.forceRefresh) {
      emit(BranchesLoading());
    }
    try {
      final branches = await _repository.getBranches();
      emit(BranchesLoaded(branches: branches));
    } catch (e) {
      emit(BranchesError(userFacingError(e)));
    }
  }

  Future<void> _onCreateBranchRequested(
    CreateBranchRequested event,
    Emitter<BranchesState> emit,
  ) async {
    try {
      await _repository.createBranch(
        name: event.name,
        code: event.code,
        address: event.address,
        phone: event.phone,
      );
      final branches = await _repository.getBranches();
      emit(BranchesLoaded(branches: branches, message: 'branches_created'));
    } catch (e) {
      emit(BranchesError(userFacingError(e)));
    }
  }

  Future<void> _onUpdateBranchRequested(
    UpdateBranchRequested event,
    Emitter<BranchesState> emit,
  ) async {
    try {
      await _repository.updateBranch(
        id: event.id,
        name: event.name,
        code: event.code,
        address: event.address,
        phone: event.phone,
        isActive: event.isActive,
      );
      final branches = await _repository.getBranches();
      emit(BranchesLoaded(branches: branches, message: 'branches_updated'));
    } catch (e) {
      emit(BranchesError(userFacingError(e)));
    }
  }

  Future<void> _onDeleteBranchRequested(
    DeleteBranchRequested event,
    Emitter<BranchesState> emit,
  ) async {
    try {
      await _repository.deleteBranch(event.id);
      final branches = await _repository.getBranches();
      emit(BranchesLoaded(branches: branches, message: 'branches_deleted'));
    } catch (e) {
      emit(BranchesError(userFacingError(e)));
    }
  }
}
