import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../domain/network_models.dart';
import '../domain/network_repository.dart';
import 'network_event.dart';
import 'network_state.dart';

class NetworkBloc extends Bloc<NetworkEvent, NetworkState> {
  final NetworkRepository _repository;
  final Map<NetworkPeriod, List<StoreSummaryRow>> _summaryCache = {};

  NetworkBloc(this._repository) : super(const NetworkLoading()) {
    on<LoadNetworkData>(_onLoadNetworkData);
    on<CreateStoreRequested>(_onCreateStoreRequested);
    on<EnterStoreRequested>(_onEnterStoreRequested);
    on<LeaveStoreRequested>(_onLeaveStoreRequested);
  }

  (DateTime?, DateTime?) _dateRangeFor(NetworkPeriod period) {
    final now = DateTime.now();
    switch (period) {
      case NetworkPeriod.today:
        final today = DateTime(now.year, now.month, now.day);
        return (today, today);
      case NetworkPeriod.month:
        final startOfMonth = DateTime(now.year, now.month, 1);
        final today = DateTime(now.year, now.month, now.day);
        return (startOfMonth, today);
      case NetworkPeriod.all:
        return (null, null);
    }
  }

  Future<void> _onLoadNetworkData(
    LoadNetworkData event,
    Emitter<NetworkState> emit,
  ) async {
    final previous = state is NetworkLoaded ? state as NetworkLoaded : null;

    if (event.forceRefresh) {
      _summaryCache.clear();
    }

    // Оптимизация переключения периода: если данные сети уже в памяти, переключаем мгновенно (0 ms)
    if (previous != null && !event.forceRefresh) {
      final cachedSummary = _summaryCache[event.period];
      if (cachedSummary != null) {
        emit(previous.copyWith(period: event.period, summary: cachedSummary));
        event.completion?.complete();
        return;
      }

      // Мгновенно обновляем выбранный таб в UI без ожидания сети
      emit(previous.copyWith(period: event.period));

      try {
        final (from, to) = _dateRangeFor(event.period);
        final summary = await _repository.fetchSummary(
          dateFrom: from,
          dateTo: to,
        );
        _summaryCache[event.period] = summary;

        final current = state is NetworkLoaded
            ? state as NetworkLoaded
            : previous;
        if (current.period == event.period) {
          emit(current.copyWith(summary: summary));
        }
        event.completion?.complete();
      } catch (e) {
        emit(
          previous.copyWith(
            actionMessage: () => e.toString().replaceAll('Exception: ', ''),
          ),
        );
        event.completion?.complete();
      }
      return;
    }

    if (previous == null) {
      emit(const NetworkLoading());
    }

    try {
      final (from, to) = _dateRangeFor(event.period);
      final results = await Future.wait([
        _repository.fetchStores(),
        _repository.fetchSummary(dateFrom: from, dateTo: to),
        _repository.getActingStore(),
      ]);

      final stores = results[0] as List<NetworkStore>;
      final summary = results[1] as List<StoreSummaryRow>;
      final acting = results[2] as ActingStore?;

      _summaryCache[event.period] = summary;

      emit(
        NetworkLoaded(
          stores: stores,
          summary: summary,
          period: event.period,
          actingStore: acting,
        ),
      );
      event.completion?.complete();
    } catch (e) {
      if (previous != null) {
        emit(
          previous.copyWith(
            actionMessage: () => e.toString().replaceAll('Exception: ', ''),
          ),
        );
      } else {
        emit(NetworkError(e.toString().replaceAll('Exception: ', '')));
      }
      event.completion?.complete();
    }
  }

  Future<void> _onCreateStoreRequested(
    CreateStoreRequested event,
    Emitter<NetworkState> emit,
  ) async {
    final current = state is NetworkLoaded ? state as NetworkLoaded : null;
    if (current != null) {
      emit(current.copyWith(isSubmitting: true));
    }

    try {
      final newStore = await _repository.createStore(event.input);
      if (current != null) {
        final updatedStores = [...current.stores, newStore];
        emit(
          current.copyWith(
            stores: updatedStores,
            isSubmitting: false,
            actionMessage: () => 'network_store_created',
          ),
        );
      }
      event.completion?.complete(true);
    } catch (e) {
      if (current != null) {
        emit(
          current.copyWith(
            isSubmitting: false,
            actionMessage: () => e.toString().replaceAll('Exception: ', ''),
          ),
        );
      }
      event.completion?.complete(false);
    }
  }

  Future<void> _onEnterStoreRequested(
    EnterStoreRequested event,
    Emitter<NetworkState> emit,
  ) async {
    final current = state is NetworkLoaded ? state as NetworkLoaded : null;
    if (current != null) {
      emit(current.copyWith(isSubmitting: true));
    }

    try {
      final acting = await _repository.enterStore(event.storeId);
      if (current != null) {
        emit(
          current.copyWith(
            actingStore: () => acting,
            isSubmitting: false,
            actionMessage: () => 'network_entered',
          ),
        );
      }
      event.completion?.complete(acting);
    } catch (e) {
      if (current != null) {
        emit(
          current.copyWith(
            isSubmitting: false,
            actionMessage: () => e.toString().replaceAll('Exception: ', ''),
          ),
        );
      }
    }
  }

  Future<void> _onLeaveStoreRequested(
    LeaveStoreRequested event,
    Emitter<NetworkState> emit,
  ) async {
    final current = state is NetworkLoaded ? state as NetworkLoaded : null;
    if (current != null) {
      emit(current.copyWith(isSubmitting: true));
    }

    try {
      await _repository.leaveStore();
      if (current != null) {
        emit(
          current.copyWith(
            actingStore: () => null,
            isSubmitting: false,
            actionMessage: () => 'network_left',
          ),
        );
      }
      event.completion?.complete();
    } catch (e) {
      if (current != null) {
        emit(
          current.copyWith(
            isSubmitting: false,
            actionMessage: () => e.toString().replaceAll('Exception: ', ''),
          ),
        );
      }
      event.completion?.complete();
    }
  }
}
