import 'package:equatable/equatable.dart';
import '../domain/warehouse_models.dart';

abstract class WarehouseEvent extends Equatable {
  const WarehouseEvent();

  @override
  List<Object?> get props => [];
}

/// Загрузка всех данных склада
class LoadWarehouseData extends WarehouseEvent {}

/// Запрос на создание нового товара
class CreateProductRequested extends WarehouseEvent {
  final WarehouseProduct product;

  const CreateProductRequested(this.product);

  @override
  List<Object?> get props => [product];
}

/// Запрос на проведение движения товара (приход/расход)
class CreateMovementRequested extends WarehouseEvent {
  final String productId;
  final String direction;
  final double qty;
  final double amount;
  final String? note;

  const CreateMovementRequested({
    required this.productId,
    required this.direction,
    required this.qty,
    required this.amount,
    this.note,
  });

  @override
  List<Object?> get props => [productId, direction, qty, amount, note];
}

class UpdateProductRequested extends WarehouseEvent {
  final WarehouseProduct product;

  const UpdateProductRequested(this.product);

  @override
  List<Object?> get props => [product];
}

class DeleteProductRequested extends WarehouseEvent {
  final String id;

  const DeleteProductRequested(this.id);

  @override
  List<Object?> get props => [id];
}

class ZeroOutProductRequested extends WarehouseEvent {
  final String id;

  const ZeroOutProductRequested(this.id);

  @override
  List<Object?> get props => [id];
}

class LoadBatchesRequested extends WarehouseEvent {
  final bool expiringOnly;

  const LoadBatchesRequested({this.expiringOnly = false});

  @override
  List<Object?> get props => [expiringOnly];
}

class CreateBatchRequested extends WarehouseEvent {
  final String productId;
  final double qty;
  final DateTime? expiryDate;
  final String? code;
  final String? note;

  const CreateBatchRequested({
    required this.productId,
    required this.qty,
    this.expiryDate,
    this.code,
    this.note,
  });

  @override
  List<Object?> get props => [productId, qty, expiryDate, code, note];
}

class UpdateBatchRequested extends WarehouseEvent {
  final String id;
  final double? qty;
  final DateTime? expiryDate;
  final DateTime? receivedAt;
  final String? code;
  final String? note;

  const UpdateBatchRequested({
    required this.id,
    this.qty,
    this.expiryDate,
    this.receivedAt,
    this.code,
    this.note,
  });

  @override
  List<Object?> get props => [id, qty, expiryDate, receivedAt, code, note];
}

class DeleteBatchRequested extends WarehouseEvent {
  final String id;

  const DeleteBatchRequested(this.id);

  @override
  List<Object?> get props => [id];
}

class ApplyBatchDiscountRequested extends WarehouseEvent {
  final String batchId;
  final int percent;

  const ApplyBatchDiscountRequested({
    required this.batchId,
    required this.percent,
  });

  @override
  List<Object?> get props => [batchId, percent];
}

/// Opt-in AI stock analysis (not loaded with main warehouse data).
class RunStockAnalysisRequested extends WarehouseEvent {
  const RunStockAnalysisRequested();
}

/// Fire batch expiry alerts immediately (not wait for nightly job).
class RunExpiryCheckRequested extends WarehouseEvent {
  const RunExpiryCheckRequested();
}
