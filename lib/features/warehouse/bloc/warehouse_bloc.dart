import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/network/user_facing_error.dart';
import '../domain/warehouse_models.dart';
import '../domain/warehouse_repository.dart';
import 'warehouse_event.dart';
import 'warehouse_state.dart';

class WarehouseBloc extends Bloc<WarehouseEvent, WarehouseState> {
  final WarehouseRepository _repository;

  List<WarehouseProduct> _cachedProducts = [];
  List<WarehouseMovement> _cachedMovements = [];
  Future<List<Object>>? _loadRequest;
  Completer<void>? _reloadCompleter;
  WarehouseSummaryData _cachedSummary = const WarehouseSummaryData(
    productsCount: 0,
    totalStockValue: 0.0,
  );

  WarehouseBloc(this._repository) : super(WarehouseLoading()) {
    on<LoadWarehouseData>(_onLoadWarehouseData);
    on<CreateProductRequested>(_onCreateProductRequested);
    on<CreateMovementRequested>(_onCreateMovementRequested);
    on<UpdateProductRequested>(_onUpdateProductRequested);
    on<DeleteProductRequested>(_onDeleteProductRequested);
    on<ZeroOutProductRequested>(_onZeroOutProductRequested);
  }

  Future<void> reload() {
    final active = _reloadCompleter;
    if (active != null) return active.future;

    final completer = Completer<void>();
    _reloadCompleter = completer;
    add(LoadWarehouseData());
    return completer.future;
  }

  Future<void> _onLoadWarehouseData(
    LoadWarehouseData event,
    Emitter<WarehouseState> emit,
  ) async {
    final previous = state is WarehouseLoaded ? state as WarehouseLoaded : null;
    if (previous != null) {
      _emitLoaded(emit);
    } else {
      emit(WarehouseLoading());
    }

    var request = _loadRequest;
    if (request == null) {
      request = Future.wait<Object>([
        _repository.getProducts(),
        _repository.getMovements(),
        _repository.getSummary(),
      ]);
      _loadRequest = request;
    }

    try {
      final results = await request;
      if (emit.isDone) return;
      _cachedProducts = (results[0] as List).cast<WarehouseProduct>();
      _cachedMovements = (results[1] as List).cast<WarehouseMovement>();
      _cachedSummary = results[2] as WarehouseSummaryData;
      _emitLoaded(emit);
    } catch (error) {
      if (emit.isDone) return;
      final message = userFacingError(
        error,
        fallback: 'Не удалось обновить склад. Проверьте соединение.',
      );
      if (previous != null) {
        _emitLoaded(emit, errorMessage: message);
      } else {
        emit(WarehouseError(message));
      }
    } finally {
      if (identical(_loadRequest, request)) _loadRequest = null;
      final completer = _reloadCompleter;
      _reloadCompleter = null;
      if (completer != null && !completer.isCompleted) {
        completer.complete();
      }
    }
  }

  void _onCreateProductRequested(
    CreateProductRequested event,
    Emitter<WarehouseState> emit,
  ) async {
    if (state is! WarehouseLoaded) return;
    final currentState = state as WarehouseLoaded;

    try {
      final created = await _repository.createProduct(event.product);
      _cachedProducts = List<WarehouseProduct>.from(_cachedProducts)
        ..add(created);

      // Пересчитываем суммарные показатели
      _cachedSummary = WarehouseSummaryData(
        productsCount: _cachedProducts.length,
        totalStockValue:
            _cachedSummary.totalStockValue + (created.price * created.stockQty),
      );

      _emitLoaded(
        emit,
        successMessage: 'Товар "${created.name}" успешно добавлен.',
      );
    } catch (e) {
      emit(
        currentState.copyWith(
          errorMessage:
              'Не удалось добавить товар. Проверьте данные и соединение.',
        ),
      );
    }
  }

  void _onCreateMovementRequested(
    CreateMovementRequested event,
    Emitter<WarehouseState> emit,
  ) async {
    if (state is! WarehouseLoaded) return;
    final currentState = state as WarehouseLoaded;

    // Ищем оригинальный товар для проведения транзакции
    final index = _cachedProducts.indexWhere((p) => p.id == event.productId);
    if (index == -1) {
      emit(currentState.copyWith(errorMessage: 'Товар не найден.'));
      return;
    }
    final originalProduct = _cachedProducts[index];

    // Оптимистично пересчитываем количество товара в локальной памяти
    final change = event.direction == 'income' ? event.qty : -event.qty;
    final double targetQty = originalProduct.stockQty + change;

    if (targetQty < 0 && event.direction == 'expense') {
      emit(
        currentState.copyWith(
          errorMessage: 'Ошибка: недостаточно товара на складе для списания.',
        ),
      );
      return;
    }

    final optimisticProducts = _cachedProducts.map((p) {
      return p.id == event.productId ? p.copyWith(stockQty: targetQty) : p;
    }).toList();

    emit(
      currentState.copyWith(
        products: optimisticProducts,
        clearSuccess: true,
        clearError: true,
      ),
    );

    try {
      final createdMovement = await _repository.createMovement(
        event.productId,
        event.direction,
        event.qty,
        event.amount,
        event.note,
      );

      // Обновляем список движений
      _cachedMovements = List<WarehouseMovement>.from(_cachedMovements)
        ..insert(0, createdMovement);

      // Синхронизируем каталог и показатели параллельно.
      final synchronized = await Future.wait([
        _repository.getProducts(),
        _repository.getSummary(),
      ]);
      _cachedProducts = synchronized[0] as List<WarehouseProduct>;
      _cachedSummary = synchronized[1] as WarehouseSummaryData;

      _emitLoaded(
        emit,
        successMessage: 'Движение по товару успешно зафиксировано.',
      );
    } catch (e) {
      // Локальный кэш всё ещё содержит подтверждённое состояние до оптимистичного изменения.
      emit(
        currentState.copyWith(
          products: _cachedProducts,
          errorMessage: 'Не удалось провести операцию. Повторите попытку.',
        ),
      );
    }
  }

  Future<void> _onUpdateProductRequested(
    UpdateProductRequested event,
    Emitter<WarehouseState> emit,
  ) async {
    if (state is! WarehouseLoaded) return;
    try {
      final updated = await _repository.updateProduct(event.product);
      _cachedProducts = _cachedProducts
          .map((p) => p.id == updated.id ? updated : p)
          .toList();
      _cachedSummary = await _repository.getSummary();
      _emitLoaded(emit, successMessage: 'warehouse_toast_product_updated');
    } catch (e) {
      if (state is WarehouseLoaded) {
        emit(
          (state as WarehouseLoaded).copyWith(errorMessage: e.toString()),
        );
      }
    }
  }

  Future<void> _onDeleteProductRequested(
    DeleteProductRequested event,
    Emitter<WarehouseState> emit,
  ) async {
    if (state is! WarehouseLoaded) return;
    try {
      await _repository.deleteProduct(event.id);
      _cachedProducts = _cachedProducts.where((p) => p.id != event.id).toList();
      _cachedSummary = await _repository.getSummary();
      _emitLoaded(emit, successMessage: 'warehouse_toast_product_deleted');
    } catch (e) {
      if (state is WarehouseLoaded) {
        emit(
          (state as WarehouseLoaded).copyWith(errorMessage: e.toString()),
        );
      }
    }
  }

  Future<void> _onZeroOutProductRequested(
    ZeroOutProductRequested event,
    Emitter<WarehouseState> emit,
  ) async {
    if (state is! WarehouseLoaded) return;
    try {
      await _repository.zeroOutProduct(event.id);
      _cachedProducts = _cachedProducts
          .map((p) => p.id == event.id ? p.copyWith(stockQty: 0) : p)
          .toList();
      _cachedSummary = await _repository.getSummary();
      _emitLoaded(emit, successMessage: 'warehouse_toast_product_zeroed');
    } catch (e) {
      if (state is WarehouseLoaded) {
        emit(
          (state as WarehouseLoaded).copyWith(errorMessage: e.toString()),
        );
      }
    }
  }

  void _emitLoaded(
    Emitter<WarehouseState> emit, {
    String? errorMessage,
    String? successMessage,
  }) {
    emit(
      WarehouseLoaded(
        products: _cachedProducts,
        movements: _cachedMovements,
        summary: _cachedSummary,
        errorMessage: errorMessage,
        successMessage: successMessage,
      ),
    );
  }
}
