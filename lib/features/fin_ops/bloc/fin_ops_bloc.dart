import 'package:flutter_bloc/flutter_bloc.dart';
import '../domain/fin_ops_repository.dart';
import 'fin_ops_event.dart';
import 'fin_ops_state.dart';

class FinOpsBloc extends Bloc<FinOpsEvent, FinOpsState> {
  final FinOpsRepository _repository;

  FinOpsBloc(this._repository) : super(FinOpsInitial()) {
    on<LoadFinOpsData>(_onLoadFinOpsData);
    on<CreateEncashmentRequested>(_onCreateEncashmentRequested);
    on<CreateStoreTransferRequested>(_onCreateStoreTransferRequested);
    on<UpdateTransferStatusRequested>(_onUpdateTransferStatusRequested);
    on<CreateFinancialAidRequested>(_onCreateFinancialAidRequested);
    on<RepayFinancialAidRequested>(_onRepayFinancialAidRequested);
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
      emit(
        FinOpsLoaded(
          bankAccounts: banks,
          encashments: encashments,
          storeTransfers: transfers,
          financialAids: aids,
        ),
      );
    } catch (e) {
      emit(FinOpsError(e.toString()));
    }
  }

  Future<void> _onCreateEncashmentRequested(
    CreateEncashmentRequested event,
    Emitter<FinOpsState> emit,
  ) async {
    try {
      await _repository.createEncashment(
        bankName: event.bankName,
        amount: event.amount,
        responsiblePerson: event.responsiblePerson,
      );
      add(const LoadFinOpsData(forceRefresh: true));
    } catch (e) {
      emit(FinOpsError(e.toString()));
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
      emit(FinOpsError(e.toString()));
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
      emit(FinOpsError(e.toString()));
    }
  }

  Future<void> _onCreateFinancialAidRequested(
    CreateFinancialAidRequested event,
    Emitter<FinOpsState> emit,
  ) async {
    try {
      await _repository.createFinancialAid(
        employeeName: event.employeeName,
        amount: event.amount,
      );
      add(const LoadFinOpsData(forceRefresh: true));
    } catch (e) {
      emit(FinOpsError(e.toString()));
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
      emit(FinOpsError(e.toString()));
    }
  }
}
