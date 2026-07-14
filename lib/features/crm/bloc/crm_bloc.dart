import 'package:flutter_bloc/flutter_bloc.dart';
import '../domain/crm_models.dart';
import '../domain/crm_repository.dart';
import 'crm_event.dart';
import 'crm_state.dart';

class CrmBloc extends Bloc<CrmEvent, CrmState> {
  final CrmRepository _repository;

  List<CrmClient> _cachedClients = [];
  List<CrmDeal> _cachedDeals = [];
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

  void _onLoadCrmData(LoadCrmData event, Emitter<CrmState> emit) async {
    if (_cachedClients.isNotEmpty) {
      emit(CrmLoaded(
        clients: _cachedClients,
        deals: _cachedDeals,
        stats: _cachedStats,
      ));
    } else {
      emit(CrmLoading());
    }
    try {
      final results = await Future.wait([
        _repository.getClients(),
        _repository.getDeals(),
        _repository.getCrmStats(),
      ]);
      _cachedClients = results[0] as List<CrmClient>;
      _cachedDeals = results[1] as List<CrmDeal>;
      _cachedStats = results[2] as CrmStatsData;

      emit(CrmLoaded(
        clients: _cachedClients,
        deals: _cachedDeals,
        stats: _cachedStats,
      ));
    } catch (e) {
      emit(CrmError('Ошибка загрузки CRM: ${e.toString()}'));
    }
  }

  void _onCreateClientRequested(CreateClientRequested event, Emitter<CrmState> emit) async {
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

      emit(currentState.copyWith(
        clients: _cachedClients,
        stats: _cachedStats,
        successMessage: 'Клиент "${created.fullName}" успешно зарегистрирован.',
      ));
    } catch (e) {
      emit(currentState.copyWith(
        errorMessage: 'Не удалось добавить клиента: ${e.toString()}',
      ));
    }
  }

  void _onCreateDealRequested(CreateDealRequested event, Emitter<CrmState> emit) async {
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

    final optimisticDeals = List<CrmDeal>.from(_cachedDeals)..insert(0, tempDeal);

    emit(currentState.copyWith(
      deals: optimisticDeals,
      clearSuccess: true,
      clearError: true,
    ));

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
      _cachedStats = await _repository.getCrmStats();

      emit(currentState.copyWith(
        deals: _cachedDeals,
        stats: _cachedStats,
        successMessage: 'Сделка "${createdDeal.title}" успешно открыта.',
      ));
    } catch (e) {
      // Откат оптимистичных сделок в случае ошибки
      emit(currentState.copyWith(
        deals: _cachedDeals,
        errorMessage: 'Не удалось открыть сделку: ${e.toString()}',
      ));
    }
  }
}
