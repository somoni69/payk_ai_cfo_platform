import 'package:flutter_bloc/flutter_bloc.dart';
import '../domain/crm_models.dart';
import '../domain/crm_repository.dart';
import 'crm_event.dart';
import 'crm_state.dart';

class CrmBloc extends Bloc<CrmEvent, CrmState> {
  final CrmRepository _repository;

  ClientListFilters _filters = const ClientListFilters(size: 50);
  static const _pickFilters = ClientListFilters(page: 1, size: 200);
  String? _loyaltyFilterClientId;
  int _loadGeneration = 0;

  CrmBloc(this._repository) : super(CrmLoading()) {
    on<LoadCrmData>(_onLoadCrmData);
    on<ClientFiltersChanged>(_onClientFiltersChanged);
    on<CreateClientRequested>(_onCreateClient);
    on<UpdateClientRequested>(_onUpdateClient);
    on<DeleteClientRequested>(_onDeleteClient);
    on<RegisterPurchaseRequested>(_onRegisterPurchase);
    on<CreateDealRequested>(_onCreateDeal);
    on<UpdateDealRequested>(_onUpdateDeal);
    on<DeleteDealRequested>(_onDeleteDeal);
    on<AddLoyaltyPointsRequested>(_onAddLoyalty);
    on<SendReactivationRequested>(_onSendReactivation);
    on<AnalyzeChurnRequested>(_onAnalyzeChurn);
    on<LoadClientDetailRequested>(_onLoadClientDetail);
    on<ClearClientDetail>(_onClearClientDetail);
    on<ClearCrmFeedback>(_onClearFeedback);
    on<LoyaltyHistoryFilterChanged>(_onLoyaltyHistoryFilter);
    on<MoveDealStageRequested>(_onMoveDealStage);
  }

  Future<void> _onLoadCrmData(LoadCrmData event, Emitter<CrmState> emit) async {
    final generation = ++_loadGeneration;
    final previous = state is CrmLoaded ? state as CrmLoaded : null;

    if (previous != null) {
      emit(
        previous.copyWith(
          isRefreshing: true,
          clearError: true,
          clearSuccess: true,
        ),
      );
    } else {
      emit(CrmLoading());
    }

    try {
      final results = await Future.wait<Object>([
        _repository.getClients(
          filters: _filters,
          forceRefresh: event.forceRefresh,
        ),
        _repository.getDeals(forceRefresh: event.forceRefresh),
        _repository.getCrmStats(forceRefresh: event.forceRefresh),
        _repository.getLoyaltySummary(forceRefresh: event.forceRefresh),
        _repository.getReactivation(forceRefresh: event.forceRefresh),
        _repository.getChurn(forceRefresh: event.forceRefresh),
        _repository.getBirthdays(forceRefresh: event.forceRefresh),
        _repository.getClients(
          filters: _pickFilters,
          forceRefresh: event.forceRefresh,
        ),
        _repository.getLoyaltyTxns(
          clientId: _loyaltyFilterClientId,
          size: 50,
        ),
      ]);

      if (generation != _loadGeneration) return;

      final page = results[0] as ClientsPage;
      final pickPage = results[7] as ClientsPage;
      emit(
        CrmLoaded(
          clients: page.items,
          clientsTotal: page.total,
          clientsPage: page.page,
          clientsSize: page.size,
          clientFilters: _filters,
          deals: results[1] as List<CrmDeal>,
          stats: results[2] as CrmStatsData,
          loyaltySummary: results[3] as List<LoyaltySummaryRow>,
          reactivation: results[4] as List<CrmClient>,
          churn: results[5] as List<CrmClient>,
          birthdays: results[6] as List<BirthdayRow>,
          pickClients: pickPage.items,
          loyaltyTxns: results[8] as List<LoyaltyTxn>,
          loyaltyFilterClientId: _loyaltyFilterClientId,
          detailClient: previous?.detailClient,
          detailDeals: previous?.detailDeals ?? const [],
          detailLoyalty: previous?.detailLoyalty ?? const [],
        ),
      );
    } catch (e) {
      if (generation != _loadGeneration) return;
      final key = e.toString().replaceAll('Exception: ', '');
      if (previous != null) {
        emit(
          previous.copyWith(
            isRefreshing: false,
            errorMessage: key.startsWith('error_') ? key : 'crm_error_refresh',
          ),
        );
      } else {
        emit(
          CrmError(key.startsWith('error_') ? key : 'crm_error_load'),
        );
      }
    } finally {
      if (event.completion?.isCompleted == false) {
        event.completion!.complete();
      }
    }
  }

  Future<void> _onClientFiltersChanged(
    ClientFiltersChanged event,
    Emitter<CrmState> emit,
  ) async {
    if (state is! CrmLoaded) return;
    final current = state as CrmLoaded;

    final nextQuery = event.query != null
        ? (event.query!.trim().isEmpty ? null : event.query!.trim())
        : _filters.query;
    final nextLevel = event.level != null
        ? (event.level!.isEmpty ? null : event.level)
        : _filters.level;
    final nextPage = event.page ??
        ((event.query != null || event.level != null) ? 1 : _filters.page);

    _filters = ClientListFilters(
      query: nextQuery,
      level: nextLevel,
      page: nextPage,
      size: _filters.size,
    );

    emit(
      current.copyWith(
        isRefreshing: true,
        clearError: true,
        clientFilters: _filters,
      ),
    );
    try {
      final page = await _repository.getClients(
        filters: _filters,
        forceRefresh: true,
      );
      emit(
        current.copyWith(
          clients: page.items,
          clientsTotal: page.total,
          clientsPage: page.page,
          clientsSize: page.size,
          clientFilters: _filters,
          isRefreshing: false,
        ),
      );
    } catch (e) {
      final key = e.toString().replaceAll('Exception: ', '');
      emit(
        current.copyWith(
          isRefreshing: false,
          errorMessage: key.startsWith('error_') ? key : 'crm_error_refresh',
          clientFilters: _filters,
        ),
      );
    }
  }

  Future<void> _reloadCore(
    Emitter<CrmState> emit,
    CrmLoaded current, {
    String? successMessage,
    CrmClient? detailClient,
    bool clearDetail = false,
  }) async {
    try {
      final results = await Future.wait<Object>([
        _repository.getClients(filters: _filters, forceRefresh: true),
        _repository.getDeals(forceRefresh: true),
        _repository.getCrmStats(forceRefresh: true),
        _repository.getLoyaltySummary(forceRefresh: true),
        _repository.getReactivation(forceRefresh: true),
        _repository.getChurn(forceRefresh: true),
        _repository.getBirthdays(forceRefresh: true),
        _repository.getClients(filters: _pickFilters, forceRefresh: true),
        _repository.getLoyaltyTxns(
          clientId: _loyaltyFilterClientId,
          size: 50,
        ),
      ]);
      final page = results[0] as ClientsPage;
      final pickPage = results[7] as ClientsPage;
      emit(
        current.copyWith(
          clients: page.items,
          clientsTotal: page.total,
          clientsPage: page.page,
          clientsSize: page.size,
          clientFilters: _filters,
          deals: results[1] as List<CrmDeal>,
          stats: results[2] as CrmStatsData,
          loyaltySummary: results[3] as List<LoyaltySummaryRow>,
          reactivation: results[4] as List<CrmClient>,
          churn: results[5] as List<CrmClient>,
          birthdays: results[6] as List<BirthdayRow>,
          pickClients: pickPage.items,
          loyaltyTxns: results[8] as List<LoyaltyTxn>,
          loyaltyFilterClientId: _loyaltyFilterClientId,
          detailClient: detailClient,
          clearDetail: clearDetail,
          isRefreshing: false,
          successMessage: successMessage,
          clearError: true,
          clearSuccess: successMessage == null,
        ),
      );
    } catch (e) {
      final key = e.toString().replaceAll('Exception: ', '');
      emit(
        current.copyWith(
          isRefreshing: false,
          errorMessage: key.startsWith('error_') ? key : 'crm_error_refresh',
        ),
      );
    }
  }

  Future<void> _onCreateClient(
    CreateClientRequested event,
    Emitter<CrmState> emit,
  ) async {
    if (state is! CrmLoaded) return;
    final current = state as CrmLoaded;
    try {
      await _repository.createClient(event.client);
      await _reloadCore(
        emit,
        current,
        successMessage: 'crm_success_client_created',
      );
    } catch (e) {
      final key = e.toString().replaceAll('Exception: ', '');
      emit(
        current.copyWith(
          errorMessage: key.startsWith('error_') ? key : 'crm_error_save',
        ),
      );
    }
  }

  Future<void> _onUpdateClient(
    UpdateClientRequested event,
    Emitter<CrmState> emit,
  ) async {
    if (state is! CrmLoaded) return;
    final current = state as CrmLoaded;
    try {
      final updated = await _repository.updateClient(
        event.id,
        fullName: event.fullName,
        phone: event.phone,
        email: event.email,
        birthDate: event.birthDate,
        acquisitionCost: event.acquisitionCost,
        note: event.note,
      );
      await _reloadCore(
        emit,
        current,
        successMessage: 'crm_success_client_updated',
        detailClient: current.detailClient?.id == updated.id
            ? updated
            : current.detailClient,
      );
    } catch (e) {
      final key = e.toString().replaceAll('Exception: ', '');
      emit(
        current.copyWith(
          errorMessage: key.startsWith('error_') ? key : 'crm_error_save',
        ),
      );
    }
  }

  Future<void> _onDeleteClient(
    DeleteClientRequested event,
    Emitter<CrmState> emit,
  ) async {
    if (state is! CrmLoaded) return;
    final current = state as CrmLoaded;
    try {
      await _repository.deleteClient(event.id);
      await _reloadCore(
        emit,
        current,
        successMessage: 'crm_success_client_deleted',
        clearDetail: current.detailClient?.id == event.id,
      );
    } catch (e) {
      final key = e.toString().replaceAll('Exception: ', '');
      emit(
        current.copyWith(
          errorMessage: key.startsWith('error_') ? key : 'crm_error_save',
        ),
      );
    }
  }

  Future<void> _onRegisterPurchase(
    RegisterPurchaseRequested event,
    Emitter<CrmState> emit,
  ) async {
    if (state is! CrmLoaded) return;
    final current = state as CrmLoaded;
    try {
      final updated = await _repository.registerPurchase(
        event.clientId,
        event.amount,
      );
      await _reloadCore(
        emit,
        current,
        successMessage: 'crm_success_purchase',
        detailClient: current.detailClient?.id == updated.id
            ? updated
            : current.detailClient,
      );
      if (state is CrmLoaded &&
          (state as CrmLoaded).detailClient?.id == event.clientId) {
        add(LoadClientDetailRequested(event.clientId));
      }
    } catch (e) {
      final key = e.toString().replaceAll('Exception: ', '');
      emit(
        current.copyWith(
          errorMessage: key.startsWith('error_') ? key : 'crm_error_save',
        ),
      );
    }
  }

  Future<void> _onCreateDeal(
    CreateDealRequested event,
    Emitter<CrmState> emit,
  ) async {
    if (state is! CrmLoaded) return;
    final current = state as CrmLoaded;
    try {
      await _repository.createDeal(
        clientId: event.clientId,
        title: event.title,
        amount: event.amount,
        stage: event.stage,
        expectedClose: event.expectedClose,
      );
      await _reloadCore(
        emit,
        current,
        successMessage: 'crm_success_deal_created',
      );
    } catch (e) {
      final key = e.toString().replaceAll('Exception: ', '');
      emit(
        current.copyWith(
          errorMessage: key.startsWith('error_') ? key : 'crm_error_save',
        ),
      );
    }
  }

  Future<void> _onUpdateDeal(
    UpdateDealRequested event,
    Emitter<CrmState> emit,
  ) async {
    if (state is! CrmLoaded) return;
    final current = state as CrmLoaded;
    try {
      await _repository.updateDeal(
        event.id,
        title: event.title,
        amount: event.amount,
        stage: event.stage,
        expectedClose: event.expectedClose,
      );
      await _reloadCore(
        emit,
        current,
        successMessage: 'crm_success_deal_updated',
      );
    } catch (e) {
      final key = e.toString().replaceAll('Exception: ', '');
      emit(
        current.copyWith(
          errorMessage: key.startsWith('error_') ? key : 'crm_error_save',
        ),
      );
    }
  }

  Future<void> _onDeleteDeal(
    DeleteDealRequested event,
    Emitter<CrmState> emit,
  ) async {
    if (state is! CrmLoaded) return;
    final current = state as CrmLoaded;
    try {
      await _repository.deleteDeal(event.id);
      await _reloadCore(
        emit,
        current,
        successMessage: 'crm_success_deal_deleted',
      );
    } catch (e) {
      final key = e.toString().replaceAll('Exception: ', '');
      emit(
        current.copyWith(
          errorMessage: key.startsWith('error_') ? key : 'crm_error_save',
        ),
      );
    }
  }

  Future<void> _onAddLoyalty(
    AddLoyaltyPointsRequested event,
    Emitter<CrmState> emit,
  ) async {
    if (state is! CrmLoaded) return;
    final current = state as CrmLoaded;
    try {
      await _repository.createLoyaltyTxn(
        clientId: event.clientId,
        points: event.points,
        reason: event.reason,
      );
      await _reloadCore(
        emit,
        current,
        successMessage: 'crm_success_bonus',
      );
      if (current.detailClient?.id == event.clientId) {
        add(LoadClientDetailRequested(event.clientId));
      }
    } catch (e) {
      final key = e.toString().replaceAll('Exception: ', '');
      emit(
        current.copyWith(
          errorMessage: key.startsWith('error_') ? key : 'crm_error_save',
        ),
      );
    }
  }

  Future<void> _onSendReactivation(
    SendReactivationRequested event,
    Emitter<CrmState> emit,
  ) async {
    if (state is! CrmLoaded) return;
    final current = state as CrmLoaded;
    try {
      final ok = await _repository.sendReactivation(event.clientId, event.text);
      emit(
        current.copyWith(
          successMessage: ok ? 'crm_success_sms_sent' : 'crm_error_sms',
          errorMessage: ok ? null : 'crm_error_sms',
          clearError: ok,
          clearSuccess: !ok,
        ),
      );
    } catch (e) {
      final key = e.toString().replaceAll('Exception: ', '');
      emit(
        current.copyWith(
          errorMessage: key.startsWith('error_') ? key : 'crm_error_sms',
        ),
      );
    }
  }

  Future<void> _onAnalyzeChurn(
    AnalyzeChurnRequested event,
    Emitter<CrmState> emit,
  ) async {
    if (state is! CrmLoaded) return;
    final current = state as CrmLoaded;
    emit(current.copyWith(churnAnalyzing: true, clearChurnAdvice: true, clearError: true));
    try {
      final advice = await _repository.analyzeChurn(event.clientId);
      emit(
        (state is CrmLoaded ? state as CrmLoaded : current).copyWith(
          churnAdvice: advice,
          churnAnalyzing: false,
        ),
      );
    } catch (e) {
      final key = e.toString().replaceAll('Exception: ', '');
      emit(
        current.copyWith(
          churnAnalyzing: false,
          errorMessage: key.startsWith('error_') ? key : 'crm_error_ai',
        ),
      );
    }
  }

  Future<void> _onLoadClientDetail(
    LoadClientDetailRequested event,
    Emitter<CrmState> emit,
  ) async {
    if (state is! CrmLoaded) return;
    final current = state as CrmLoaded;
    emit(current.copyWith(detailLoading: true, clearError: true));
    try {
      final results = await Future.wait<Object>([
        _repository.getClient(event.clientId),
        _repository.getDeals(clientId: event.clientId, forceRefresh: true),
        _repository.getLoyaltyTxns(clientId: event.clientId),
      ]);
      emit(
        current.copyWith(
          detailClient: results[0] as CrmClient,
          detailDeals: results[1] as List<CrmDeal>,
          detailLoyalty: results[2] as List<LoyaltyTxn>,
          detailLoading: false,
        ),
      );
    } catch (e) {
      final key = e.toString().replaceAll('Exception: ', '');
      emit(
        current.copyWith(
          detailLoading: false,
          errorMessage: key.startsWith('error_') ? key : 'crm_error_load',
        ),
      );
    }
  }

  void _onClearClientDetail(ClearClientDetail event, Emitter<CrmState> emit) {
    if (state is! CrmLoaded) return;
    emit((state as CrmLoaded).copyWith(clearDetail: true));
  }

  void _onClearFeedback(ClearCrmFeedback event, Emitter<CrmState> emit) {
    if (state is! CrmLoaded) return;
    emit(
      (state as CrmLoaded).copyWith(clearError: true, clearSuccess: true),
    );
  }

  Future<void> _onLoyaltyHistoryFilter(
    LoyaltyHistoryFilterChanged event,
    Emitter<CrmState> emit,
  ) async {
    if (state is! CrmLoaded) return;
    final current = state as CrmLoaded;
    final id = event.clientId?.trim();
    _loyaltyFilterClientId = (id == null || id.isEmpty) ? null : id;
    emit(
      current.copyWith(
        loyaltyTxnsLoading: true,
        loyaltyFilterClientId: _loyaltyFilterClientId,
        clearLoyaltyFilter: _loyaltyFilterClientId == null,
        clearError: true,
      ),
    );
    try {
      final txns = await _repository.getLoyaltyTxns(
        clientId: _loyaltyFilterClientId,
        size: 50,
      );
      emit(
        current.copyWith(
          loyaltyTxns: txns,
          loyaltyTxnsLoading: false,
          loyaltyFilterClientId: _loyaltyFilterClientId,
          clearLoyaltyFilter: _loyaltyFilterClientId == null,
        ),
      );
    } catch (e) {
      final key = e.toString().replaceAll('Exception: ', '');
      emit(
        current.copyWith(
          loyaltyTxnsLoading: false,
          errorMessage: key.startsWith('error_') ? key : 'crm_error_load',
          loyaltyFilterClientId: _loyaltyFilterClientId,
          clearLoyaltyFilter: _loyaltyFilterClientId == null,
        ),
      );
    }
  }

  Future<void> _onMoveDealStage(
    MoveDealStageRequested event,
    Emitter<CrmState> emit,
  ) async {
    if (state is! CrmLoaded) return;
    final current = state as CrmLoaded;
    CrmDeal? deal;
    for (final d in current.deals) {
      if (d.id == event.dealId) {
        deal = d;
        break;
      }
    }
    if (deal == null) return;
    final idx = kDealStages.indexOf(deal.stage);
    if (idx < 0) return;
    final nextIdx = idx + event.delta;
    if (nextIdx < 0 || nextIdx >= kDealStages.length) return;
    final nextStage = kDealStages[nextIdx];
    try {
      await _repository.updateDeal(deal.id, stage: nextStage);
      await _reloadCore(
        emit,
        current,
        successMessage: 'crm_success_deal_updated',
      );
    } catch (e) {
      final key = e.toString().replaceAll('Exception: ', '');
      emit(
        current.copyWith(
          errorMessage: key.startsWith('error_') ? key : 'crm_error_save',
        ),
      );
    }
  }
}
