import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/models/ui_feedback.dart';
import '../../../core/network/user_facing_error.dart';
import '../domain/warehouse_models.dart';
import '../domain/warehouse_repository.dart';
import 'warehouse_event.dart';
import 'warehouse_state.dart';

class WarehouseBloc extends Bloc<WarehouseEvent, WarehouseState> {
  final WarehouseRepository _repository;

  WarehouseBloc(this._repository) : super(WarehouseLoading()) {
    on<LoadWarehouseData>(_onLoadWarehouseData);
    on<CreateProductRequested>(_onCreateProductRequested);
    on<CreateMovementRequested>(_onCreateMovementRequested);
    on<UpdateProductRequested>(_onUpdateProductRequested);
    on<DeleteProductRequested>(_onDeleteProductRequested);
    on<ZeroOutProductRequested>(_onZeroOutProductRequested);
    on<LoadBatchesRequested>(_onLoadBatchesRequested);
    on<CreateBatchRequested>(_onCreateBatchRequested);
    on<UpdateBatchRequested>(_onUpdateBatchRequested);
    on<DeleteBatchRequested>(_onDeleteBatchRequested);
    on<ApplyBatchDiscountRequested>(_onApplyBatchDiscountRequested);
    on<RunStockAnalysisRequested>(_onRunStockAnalysisRequested);
    on<RunExpiryCheckRequested>(_onRunExpiryCheckRequested);
    on<AssignProductBarcodeRequested>(_onAssignProductBarcodeRequested);
    on<AssignMissingBarcodesRequested>(_onAssignMissingBarcodesRequested);
    on<DownloadBarcodeLabelsPdfRequested>(_onDownloadBarcodeLabelsPdfRequested);
  }

  Future<void> _onLoadWarehouseData(
    LoadWarehouseData event,
    Emitter<WarehouseState> emit,
  ) async {
    final currentLoaded = state is WarehouseLoaded
        ? state as WarehouseLoaded
        : null;

    emit(WarehouseLoading());

    try {
      final expiringOnly = currentLoaded?.batchesExpiringOnly ?? false;
      final results = await Future.wait<Object>([
        _repository.getProducts(),
        _repository.getMovements(),
        _repository.getSummary(),
        _repository.getBatches(expiringOnly: expiringOnly),
      ]);

      final products = (results[0] as List).cast<WarehouseProduct>();
      final movements = (results[1] as List).cast<WarehouseMovement>();
      final summary = results[2] as WarehouseSummaryData;
      final batches = (results[3] as List).cast<WarehouseBatch>();

      emit(
        WarehouseLoaded(
          products: products,
          movements: movements,
          summary: summary,
          batches: batches,
          batchesExpiringOnly: expiringOnly,
          stockAnalysis: currentLoaded?.stockAnalysis,
        ),
      );
    } catch (e) {
      final message = userFacingError(e, fallback: ErrorKeys.loadFailed);
      if (currentLoaded != null) {
        emit(currentLoaded.copyWith(errorMessage: message));
      } else {
        emit(WarehouseError(message));
      }
    }
  }

  Future<void> _onCreateProductRequested(
    CreateProductRequested event,
    Emitter<WarehouseState> emit,
  ) async {
    if (state is! WarehouseLoaded) return;
    final current = state as WarehouseLoaded;
    try {
      final newProduct = await _repository.createProduct(event.product);
      final products = [...current.products, newProduct];
      WarehouseSummaryData summary;
      try {
        summary = await _repository.getSummary();
        if (summary.productsCount < products.length) {
          summary = summary.copyWith(
            productsCount: products.length,
            totalStockValue: products.fold<double>(
              0.0,
              (sum, p) => sum + (p.stockQty * p.price),
            ),
          );
        }
      } catch (_) {
        summary = current.summary.copyWith(
          productsCount: products.length,
          totalStockValue: products.fold<double>(
            0.0,
            (sum, p) => sum + (p.stockQty * p.price),
          ),
        );
      }
      emit(
        current.copyWith(
          products: products,
          summary: summary,
          successMessage: 'warehouse_product_created',
          feedback: const LocalizedFeedback('warehouse_product_created'),
          clearError: true,
        ),
      );
    } catch (e) {
      emit(
        current.copyWith(
          errorMessage: userFacingError(e, fallback: ErrorKeys.saveFailed),
          clearSuccess: true,
          clearFeedback: true,
        ),
      );
    }
  }

  Future<void> _onCreateMovementRequested(
    CreateMovementRequested event,
    Emitter<WarehouseState> emit,
  ) async {
    if (state is! WarehouseLoaded) return;
    final current = state as WarehouseLoaded;

    // Оптимистичное обновление локальных остатков
    final delta = event.direction == 'income' ? event.qty : -event.qty;
    final optimisticProducts = current.products.map((p) {
      if (p.id == event.productId) {
        return p.copyWith(
          stockQty: (p.stockQty + delta).clamp(0.0, double.infinity),
        );
      }
      return p;
    }).toList();
    emit(
      current.copyWith(
        products: optimisticProducts,
        clearError: true,
        clearFeedback: true,
      ),
    );

    try {
      final newMovement = await _repository.createMovement(
        event.productId,
        event.direction,
        event.qty,
        event.amount,
        event.note,
      );

      final results = await Future.wait<Object>([
        _repository.getProducts(),
        _repository.getSummary(),
        _repository.getBatches(expiringOnly: current.batchesExpiringOnly),
      ]);

      final products = (results[0] as List).cast<WarehouseProduct>();
      final summary = results[1] as WarehouseSummaryData;
      final batches = (results[2] as List).cast<WarehouseBatch>();
      final movements = [newMovement, ...current.movements];

      emit(
        current.copyWith(
          movements: movements,
          products: products,
          summary: summary,
          batches: batches,
          successMessage: 'warehouse_movement_created',
          feedback: const LocalizedFeedback('warehouse_movement_created'),
          clearError: true,
        ),
      );
    } catch (e) {
      // Откат к исходным товарам при ошибке
      emit(
        current.copyWith(
          products: current.products,
          errorMessage: userFacingError(e, fallback: ErrorKeys.saveFailed),
          clearSuccess: true,
          clearFeedback: true,
        ),
      );
    }
  }

  Future<void> _onUpdateProductRequested(
    UpdateProductRequested event,
    Emitter<WarehouseState> emit,
  ) async {
    if (state is! WarehouseLoaded) return;
    final current = state as WarehouseLoaded;
    try {
      final updated = await _repository.updateProduct(event.product);
      final products = [
        for (final p in current.products) p.id == updated.id ? updated : p,
      ];
      final summary = await _repository.getSummary();
      emit(
        current.copyWith(
          products: products,
          summary: summary,
          successMessage: 'warehouse_product_updated',
          feedback: const LocalizedFeedback('warehouse_product_updated'),
          clearError: true,
        ),
      );
    } catch (e) {
      emit(
        current.copyWith(
          errorMessage: userFacingError(e, fallback: ErrorKeys.saveFailed),
          clearSuccess: true,
          clearFeedback: true,
        ),
      );
    }
  }

  Future<void> _onDeleteProductRequested(
    DeleteProductRequested event,
    Emitter<WarehouseState> emit,
  ) async {
    if (state is! WarehouseLoaded) return;
    final current = state as WarehouseLoaded;
    try {
      await _repository.deleteProduct(event.id);
      final products = current.products
          .where((p) => p.id != event.id)
          .toList(growable: false);
      final summary = await _repository.getSummary();
      emit(
        current.copyWith(
          products: products,
          summary: summary,
          successMessage: 'warehouse_product_deleted',
          feedback: const LocalizedFeedback('warehouse_product_deleted'),
          clearError: true,
        ),
      );
    } catch (e) {
      emit(
        current.copyWith(
          errorMessage: userFacingError(e, fallback: ErrorKeys.saveFailed),
          clearSuccess: true,
          clearFeedback: true,
        ),
      );
    }
  }

  Future<void> _onZeroOutProductRequested(
    ZeroOutProductRequested event,
    Emitter<WarehouseState> emit,
  ) async {
    if (state is! WarehouseLoaded) return;
    final current = state as WarehouseLoaded;
    try {
      await _repository.zeroOutProduct(event.id);
      final products = await _repository.getProducts();
      final summary = await _repository.getSummary();
      emit(
        current.copyWith(
          products: products,
          summary: summary,
          successMessage: 'warehouse_stock_zeroed',
          feedback: const LocalizedFeedback('warehouse_stock_zeroed'),
          clearError: true,
        ),
      );
    } catch (e) {
      emit(
        current.copyWith(
          errorMessage: userFacingError(e, fallback: ErrorKeys.saveFailed),
          clearSuccess: true,
          clearFeedback: true,
        ),
      );
    }
  }

  Future<void> _onLoadBatchesRequested(
    LoadBatchesRequested event,
    Emitter<WarehouseState> emit,
  ) async {
    if (state is! WarehouseLoaded) return;
    final current = state as WarehouseLoaded;
    try {
      final batches = await _repository.getBatches(
        expiringOnly: event.expiringOnly,
      );
      emit(
        current.copyWith(
          batches: batches,
          batchesExpiringOnly: event.expiringOnly,
        ),
      );
    } catch (e) {
      emit(
        current.copyWith(
          errorMessage: userFacingError(e, fallback: ErrorKeys.loadFailed),
        ),
      );
    }
  }

  Future<void> _onCreateBatchRequested(
    CreateBatchRequested event,
    Emitter<WarehouseState> emit,
  ) async {
    if (state is! WarehouseLoaded) return;
    final current = state as WarehouseLoaded;
    try {
      final batch = await _repository.createBatch(
        productId: event.productId,
        qty: event.qty,
        expiryDate: event.expiryDate,
        code: event.code,
        note: event.note,
      );
      final batches = [batch, ...current.batches];
      final products = await _repository.getProducts();
      final summary = await _repository.getSummary();
      emit(
        current.copyWith(
          batches: batches,
          products: products,
          summary: summary,
          successMessage: 'warehouse_batch_created',
          feedback: const LocalizedFeedback('warehouse_batch_created'),
          clearError: true,
        ),
      );
    } catch (e) {
      emit(
        current.copyWith(
          errorMessage: userFacingError(e, fallback: ErrorKeys.saveFailed),
          clearSuccess: true,
          clearFeedback: true,
        ),
      );
    }
  }

  Future<void> _onUpdateBatchRequested(
    UpdateBatchRequested event,
    Emitter<WarehouseState> emit,
  ) async {
    if (state is! WarehouseLoaded) return;
    final current = state as WarehouseLoaded;
    try {
      final updated = await _repository.updateBatch(
        id: event.id,
        qty: event.qty,
        expiryDate: event.expiryDate,
        receivedAt: event.receivedAt,
        code: event.code,
        note: event.note,
      );
      final batches = [
        for (final b in current.batches) b.id == updated.id ? updated : b,
      ];
      final products = await _repository.getProducts();
      final summary = await _repository.getSummary();
      emit(
        current.copyWith(
          batches: batches,
          products: products,
          summary: summary,
          successMessage: 'warehouse_batch_saved',
          feedback: const LocalizedFeedback('warehouse_batch_saved'),
          clearError: true,
        ),
      );
    } catch (e) {
      emit(
        current.copyWith(
          errorMessage: userFacingError(e, fallback: ErrorKeys.saveFailed),
          clearSuccess: true,
          clearFeedback: true,
        ),
      );
    }
  }

  Future<void> _onDeleteBatchRequested(
    DeleteBatchRequested event,
    Emitter<WarehouseState> emit,
  ) async {
    if (state is! WarehouseLoaded) return;
    final current = state as WarehouseLoaded;
    try {
      await _repository.deleteBatch(event.id);
      final batches = current.batches
          .where((b) => b.id != event.id)
          .toList(growable: false);
      final products = await _repository.getProducts();
      final summary = await _repository.getSummary();
      emit(
        current.copyWith(
          batches: batches,
          products: products,
          summary: summary,
          successMessage: 'warehouse_batch_deleted',
          feedback: const LocalizedFeedback('warehouse_batch_deleted'),
          clearError: true,
        ),
      );
    } catch (e) {
      emit(
        current.copyWith(
          errorMessage: userFacingError(e, fallback: ErrorKeys.saveFailed),
          clearSuccess: true,
          clearFeedback: true,
        ),
      );
    }
  }

  Future<void> _onApplyBatchDiscountRequested(
    ApplyBatchDiscountRequested event,
    Emitter<WarehouseState> emit,
  ) async {
    if (state is! WarehouseLoaded) return;
    final current = state as WarehouseLoaded;
    try {
      await _repository.applyBatchDiscount(event.batchId, event.percent);
      final batches = await _repository.getBatches(
        expiringOnly: current.batchesExpiringOnly,
      );
      emit(
        current.copyWith(
          batches: batches,
          successMessage: 'warehouse_discount_applied',
          feedback: const LocalizedFeedback('warehouse_discount_applied'),
          clearError: true,
        ),
      );
    } catch (e) {
      emit(
        current.copyWith(
          errorMessage: userFacingError(e, fallback: ErrorKeys.saveFailed),
          clearSuccess: true,
          clearFeedback: true,
        ),
      );
    }
  }

  Future<void> _onRunExpiryCheckRequested(
    RunExpiryCheckRequested event,
    Emitter<WarehouseState> emit,
  ) async {
    if (state is! WarehouseLoaded) return;
    final current = state as WarehouseLoaded;
    try {
      final created = await _repository.runExpiryCheck();
      final batches = await _repository.getBatches(
        expiringOnly: current.batchesExpiringOnly,
      );
      final feedback = created > 0
          ? WarehouseActionFeedback(action: 'expiry_check', count: created)
          : const LocalizedFeedback('warehouse_expiry_check_none');

      emit(
        current.copyWith(
          batches: batches,
          feedback: feedback,
          successMessage: feedback.translationKey,
          clearError: true,
        ),
      );
    } catch (e) {
      emit(
        current.copyWith(
          errorMessage: userFacingError(e, fallback: ErrorKeys.saveFailed),
          clearSuccess: true,
          clearFeedback: true,
        ),
      );
    }
  }

  Future<void> _onRunStockAnalysisRequested(
    RunStockAnalysisRequested event,
    Emitter<WarehouseState> emit,
  ) async {
    if (state is! WarehouseLoaded) return;
    final current = state as WarehouseLoaded;
    emit(
      current.copyWith(
        isAnalysisLoading: true,
        clearAnalysisError: true,
        clearError: true,
      ),
    );
    try {
      final analysis = await _repository.getStockAnalysis();
      emit(
        current.copyWith(
          stockAnalysis: analysis,
          isAnalysisLoading: false,
          clearAnalysisError: true,
        ),
      );
    } catch (e) {
      emit(
        current.copyWith(
          isAnalysisLoading: false,
          analysisError: userFacingError(e, fallback: ErrorKeys.loadFailed),
        ),
      );
    }
  }

  Future<void> _onAssignProductBarcodeRequested(
    AssignProductBarcodeRequested event,
    Emitter<WarehouseState> emit,
  ) async {
    if (state is! WarehouseLoaded) return;
    final current = state as WarehouseLoaded;
    try {
      final updated = await _repository.assignBarcode(event.productId);
      final products = [
        for (final p in current.products) p.id == updated.id ? updated : p,
      ];
      emit(
        current.copyWith(
          products: products,
          successMessage: 'warehouse_barcode_assigned',
          feedback: const LocalizedFeedback('warehouse_barcode_assigned'),
          clearError: true,
        ),
      );
    } catch (e) {
      emit(
        current.copyWith(
          errorMessage: userFacingError(e, fallback: ErrorKeys.saveFailed),
          clearSuccess: true,
          clearFeedback: true,
        ),
      );
    }
  }

  Future<void> _onAssignMissingBarcodesRequested(
    AssignMissingBarcodesRequested event,
    Emitter<WarehouseState> emit,
  ) async {
    if (state is! WarehouseLoaded) return;
    final current = state as WarehouseLoaded;
    try {
      final count = await _repository.assignMissingBarcodes();
      final products = await _repository.getProducts();
      final feedback = WarehouseActionFeedback(
        action: 'barcodes_generated',
        count: count,
      );
      emit(
        current.copyWith(
          products: products,
          feedback: feedback,
          successMessage: feedback.translationKey,
          clearError: true,
        ),
      );
    } catch (e) {
      emit(
        current.copyWith(
          errorMessage: userFacingError(e, fallback: ErrorKeys.saveFailed),
          clearSuccess: true,
          clearFeedback: true,
        ),
      );
    }
  }

  Future<void> _onDownloadBarcodeLabelsPdfRequested(
    DownloadBarcodeLabelsPdfRequested event,
    Emitter<WarehouseState> emit,
  ) async {
    if (state is! WarehouseLoaded) return;
    final current = state as WarehouseLoaded;
    emit(current.copyWith(isPdfDownloading: true, clearError: true));
    try {
      final bytes = await _repository.downloadBarcodeLabelsPdf(
        productIds: event.productIds,
        sheet: event.sheet,
        copies: event.copies,
      );
      emit(
        current.copyWith(
          isPdfDownloading: false,
          pdfBytes: bytes,
          feedback: const LocalizedFeedback('warehouse_pdf_ready'),
        ),
      );
    } catch (e) {
      emit(
        current.copyWith(
          isPdfDownloading: false,
          errorMessage: userFacingError(e, fallback: ErrorKeys.loadFailed),
        ),
      );
    }
  }
}
