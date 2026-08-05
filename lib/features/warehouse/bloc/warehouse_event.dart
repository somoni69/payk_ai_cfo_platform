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
