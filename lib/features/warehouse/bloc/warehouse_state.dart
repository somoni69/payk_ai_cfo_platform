import 'package:equatable/equatable.dart';
import '../domain/warehouse_models.dart';

abstract class WarehouseState extends Equatable {
  const WarehouseState();

  @override
  List<Object?> get props => [];
}

class WarehouseLoading extends WarehouseState {}

class WarehouseLoaded extends WarehouseState {
  final List<WarehouseProduct> products;
  final List<WarehouseMovement> movements;
  final WarehouseSummaryData summary;
  final String? errorMessage;
  final String? successMessage;

  const WarehouseLoaded({
    required this.products,
    required this.movements,
    required this.summary,
    this.errorMessage,
    this.successMessage,
  });

  WarehouseLoaded copyWith({
    List<WarehouseProduct>? products,
    List<WarehouseMovement>? movements,
    WarehouseSummaryData? summary,
    String? errorMessage,
    String? successMessage,
    bool clearError = false,
    bool clearSuccess = false,
  }) {
    return WarehouseLoaded(
      products: products ?? this.products,
      movements: movements ?? this.movements,
      summary: summary ?? this.summary,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      successMessage: clearSuccess ? null : (successMessage ?? this.successMessage),
    );
  }

  @override
  List<Object?> get props => [products, movements, summary, errorMessage, successMessage];
}

class WarehouseError extends WarehouseState {
  final String message;

  const WarehouseError(this.message);

  @override
  List<Object?> get props => [message];
}
