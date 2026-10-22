import 'dart:async';

import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/observability/app_error_reporter.dart';
import '../../../core/network/user_facing_error.dart';
import '../domain/fin_ops_repository.dart';
import '../../branches/domain/branches_repository.dart';
import 'fin_ops_event.dart';
import 'fin_ops_state.dart';

class FinOpsBloc extends Bloc<FinOpsEvent, FinOpsState> {
  final FinOpsRepository _repository;
  final BranchesRepository _branchesRepository;

  FinOpsBloc(this._repository, this._branchesRepository)
    : super(FinOpsInitial()) {
    on<LoadFinOpsData>(_onLoadFinOpsData);
    on<CreateEncashmentRequested>(
      _onCreateEncashmentRequested,
      transformer: droppable(),
    );
    on<CreateStoreTransferRequested>(
      _onCreateStoreTransferRequested,
      transformer: droppable(),
    );
    on<UpdateTransferStatusRequested>(
      _onUpdateTransferStatusRequested,
      transformer: droppable(),
    );
    on<CreateFinancialAidRequested>(
      _onCreateFinancialAidRequested,
      transformer: droppable(),
    );
    on<RepayFinancialAidRequested>(
      _onRepayFinancialAidRequested,
      transformer: droppable(),
    );
    on<CreateBankRequested>(_onCreateBank, transformer: droppable());
    on<DeleteBankRequested>(_onDeleteBank, transformer: droppable());
    on<CancelStoreTransferRequested>(
      _onCancelTransfer,
      transformer: droppable(),
    );
  }

  Future<List<T>> _optional<T>(Future<List<T>> Function() load) async {
    try {
      return await load();
    } catch (e, st) {
      unawaited(AppErrorReporter.capture(e, st, context: 'fin_ops_optional'));
      return const [];
    }
  }

  Future<void> _onLoadFinOpsData(
    LoadFinOpsData event,
    Emitter<FinOpsState> emit,
  ) async {
    if (state is! FinOpsLoaded || event.forceRefresh) {
      emit(FinOpsLoading());
    }
    try {
      final banks = await _repository.getBankAccounts();
      final encashments = await _repository.getEncashments();
      final transfers = await _repository.getStoreTransfers();
      final aids = await _repository.getFinancialAids();
      final branches = await _branchesRepository.getBranches();
      // Balances and the responsible list are helpers for forms; a role without
      // them still sees its operations, so a failure there is reported only.
      final balances = await _optional(_repository.getBranchBalances);
      final responsibles = await _optional(_repository.getResponsibleOptions);
      emit(
        FinOpsLoaded(
          bankAccounts: banks,
          encashments: encashments,
          storeTransfers: transfers,
          financialAids: aids,
          branches: branches,
          branchBalances: balances,
          responsibleOptions: responsibles,
        ),
      );
    } catch (e) {
      emit(FinOpsError(userFacingError(e)));
    }
  }

  Future<void> _onCreateEncashmentRequested(
    CreateEncashmentRequested event,
    Emitter<FinOpsState> emit,
  ) async {
    try {
      await _repository.createEncashment(
        registerId: event.registerId,
        responsibleEmployeeId: event.responsibleEmployeeId,
        amount: event.amount,
        bankId: event.bankId,
        note: event.note,
      );
      add(const LoadFinOpsData(forceRefresh: true));
    } catch (e) {
      emit(FinOpsError(userFacingError(e)));
    }
  }

  Future<void> _onCreateStoreTransferRequested(
    CreateStoreTransferRequested event,
    Emitter<FinOpsState> emit,
  ) async {
    try {
      await _repository.createStoreTransfer(
        fromBranch: event.fromBranch,
        toBranch: event.toBranch,
        amount: event.amount,
      );
      add(const LoadFinOpsData(forceRefresh: true));
    } catch (e) {
      emit(FinOpsError(userFacingError(e)));
    }
  }

  Future<void> _onUpdateTransferStatusRequested(
    UpdateTransferStatusRequested event,
    Emitter<FinOpsState> emit,
  ) async {
    try {
      await _repository.updateTransferStatus(
        transferId: event.transferId,
        status: event.status,
      );
      add(const LoadFinOpsData(forceRefresh: true));
    } catch (e) {
      emit(FinOpsError(userFacingError(e)));
    }
  }

  Future<void> _onCreateFinancialAidRequested(
    CreateFinancialAidRequested event,
    Emitter<FinOpsState> emit,
  ) async {
    try {
      await _repository.createFinancialAid(
        employeeId: event.employeeId,
        amount: event.amount,
        deductFromSalary: event.deductFromSalary,
        registerId: event.registerId,
      );
      add(const LoadFinOpsData(forceRefresh: true));
    } catch (e) {
      emit(FinOpsError(userFacingError(e)));
    }
  }

  Future<void> _onRepayFinancialAidRequested(
    RepayFinancialAidRequested event,
    Emitter<FinOpsState> emit,
  ) async {
    try {
      await _repository.repayFinancialAid(
        aidId: event.aidId,
        amount: event.amount,
      );
      add(const LoadFinOpsData(forceRefresh: true));
    } catch (e) {
      emit(FinOpsError(userFacingError(e)));
    }
  }

  Future<void> _onCreateBank(
    CreateBankRequested event,
    Emitter<FinOpsState> emit,
  ) async {
    try {
      await _repository.createBank(name: event.name);
      add(const LoadFinOpsData(forceRefresh: true));
    } catch (e) {
      emit(FinOpsError(userFacingError(e)));
    }
  }

  Future<void> _onDeleteBank(
    DeleteBankRequested event,
    Emitter<FinOpsState> emit,
  ) async {
    try {
      await _repository.deleteBank(event.id);
      add(const LoadFinOpsData(forceRefresh: true));
    } catch (e) {
      emit(FinOpsError(userFacingError(e)));
    }
  }

  Future<void> _onCancelTransfer(
    CancelStoreTransferRequested event,
    Emitter<FinOpsState> emit,
  ) async {
    try {
      await _repository.cancelStoreTransfer(event.transferId);
      add(const LoadFinOpsData(forceRefresh: true));
    } catch (e) {
      emit(FinOpsError(userFacingError(e)));
    }
  }
}
