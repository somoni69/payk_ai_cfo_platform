import 'package:flutter_bloc/flutter_bloc.dart';
import '../domain/crm_models.dart';
import '../domain/crm_repository.dart';
import 'crm_event.dart';
import 'crm_state.dart';

class CrmBloc extends Bloc<CrmEvent, CrmState> {
  final CrmRepository _repository;

  List<CrmClient> _cachedClients = [];
  List<CrmDeal> _cachedDeals = [];
  Future<List<Object>>? _loadRequest;
  int _loadGeneration = 0;

  CrmStatsData _cachedStats = const CrmStatsData(
    clientsTotal: 0,
    activeClients: 0,
    ltvTotal: 0,
    cacTotal: 0,
    churnCount: 0,
    reactivationCount: 0,
  );

  CrmBloc(this._repository) : super(CrmLoading()) {
    on<LoadCrmData>(_onLoadCrmData);
    on<CreateClientRequested>(_onCreateClientRequested);
    on<CreateDealRequested>(_onCreateDealRequested);
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

    var request = _loadRequest;
    if (request == null) {
      request = Future.wait<Object>([
        _repository.getClients(forceRefresh: event.forceRefresh),
        _repository.getDeals(forceRefresh: event.forceRefresh),
        _repository.getCrmStats(forceRefresh: event.forceRefresh),
      ]);
      _loadRequest = request;
    }

    try {
      final results = await request;
      if (generation != _loadGeneration) return;

      _cachedClients = (results[0] as List).cast<CrmClient>();
      _cachedDeals = (results[1] as List).cast<CrmDeal>();
      _cachedStats = results[2] as CrmStatsData;

      emit(
        CrmLoaded(
          clients: _cachedClients,
          deals: _cachedDeals,
          stats: _cachedStats,
        ),
      );
    } catch (_) {
      if (generation != _loadGeneration) return;
      if (previous != null) {
        emit(
          previous.copyWith(
            isRefreshing: false,
            errorMessage:
                'Не удалось обновить CRM. Проверьте соединение и повторите.',
          ),
        );
      } else {
        emit(
          const CrmError(
            'Не удалось загрузить CRM. Проверьте соединение и повторите.',
          ),
        );
      }
    } finally {
      if (identical(_loadRequest, request)) _loadRequest = null;
      if (event.completion?.isCompleted == false) {
        event.completion!.complete();
      }
    }
  }

  void _onCreateClientRequested(
    CreateClientRequested event,
    Emitter<CrmState> emit,
  ) async {
    if (state is! CrmLoaded) return;
    final currentState = state as CrmLoaded;

    try {
      final created = await _repository.createClient(event.client);
      _cachedClients = List<CrmClient>.from(_cachedClients)..add(created);

      // Корректируем базовую статистику локально
      _cachedStats = CrmStatsData(
        clientsTotal: _cachedStats.clientsTotal + 1,
        activeClients: _cachedStats.activeClients + 1,
        ltvTotal: _cachedStats.ltvTotal,
        cacTotal: _cachedStats.cacTotal + created.acquisitionCost,
        roi: _cachedStats.roi,
        churnCount: _cachedStats.churnCount,
        reactivationCount: _cachedStats.reactivationCount,
      );

      emit(
        currentState.copyWith(
          clients: _cachedClients,
          stats: _cachedStats,
          successMessage:
              'Клиент "${created.fullName}" успешно зарегистрирован.',
        ),
      );
    } catch (_) {
      emit(
        currentState.copyWith(
          errorMessage:
              'Не удалось добавить клиента. Проверьте данные и соединение.',
        ),
      );
    }
  }

  void _onCreateDealRequested(
    CreateDealRequested event,
    Emitter<CrmState> emit,
  ) async {
    if (state is! CrmLoaded) return;
    final currentState = state as CrmLoaded;

    // Ищем имя клиента для отображения
    final client = _cachedClients.firstWhere(
      (c) => c.id == event.clientId,
      orElse: () => CrmClient(
        id: '',
        fullName: 'Новый клиент',
        loyaltyLevel: 'bronze',
        bonusPoints: 0,
        totalSpent: 0,
        acquisitionCost: 0,
        purchasesCount: 0,
        createdAt: DateTime(1970),
        churnRisk: false,
      ),
    );

    // Оптимистично добавляем сделку в локальный список
    final tempDeal = CrmDeal(
      id: 'temp-${DateTime.now().millisecondsSinceEpoch}',
      clientId: event.clientId,
      title: event.title,
      amount: event.amount,
      stage: event.stage,
      createdAt: DateTime.now(),
      clientName: client.fullName,
    );

    final optimisticDeals = List<CrmDeal>.from(_cachedDeals)
      ..insert(0, tempDeal);

    emit(
      currentState.copyWith(
        deals: optimisticDeals,
        clearSuccess: true,
        clearError: true,
      ),
    );

    try {
      final createdDeal = await _repository.createDeal(
        event.clientId,
        event.title,
        event.amount,
        event.stage,
      );

      // Заменяем временную сделку реальным объектом с сервера
      _cachedDeals = List<CrmDeal>.from(_cachedDeals)..insert(0, createdDeal);

      // Обновляем статистику
      _cachedStats = await _repository.getCrmStats(forceRefresh: true);

      emit(
        currentState.copyWith(
          deals: _cachedDeals,
          stats: _cachedStats,
          successMessage: 'Сделка "${createdDeal.title}" успешно открыта.',
        ),
      );
    } catch (_) {
      // Откат оптимистичных сделок в случае ошибки
      emit(
        currentState.copyWith(
          deals: _cachedDeals,
          errorMessage:
              'Не удалось открыть сделку. Проверьте данные и соединение.',
        ),
      );
    }
  }
}
