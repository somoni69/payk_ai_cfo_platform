/// Модель товара на складе.
class WarehouseProduct {
  final String id;
  final String name;
  final String? sku;
  final String unit;
  final double price;
  final double stockQty;
  final String? externalId;

  const WarehouseProduct({
    required this.id,
    required this.name,
    this.sku,
    required this.unit,
    required this.price,
    required this.stockQty,
    this.externalId,
  });

  WarehouseProduct copyWith({
    String? id,
    String? name,
    String? sku,
    String? unit,
    double? price,
    double? stockQty,
    String? externalId,
  }) {
    return WarehouseProduct(
      id: id ?? this.id,
      name: name ?? this.name,
      sku: sku ?? this.sku,
      unit: unit ?? this.unit,
      price: price ?? this.price,
      stockQty: stockQty ?? this.stockQty,
      externalId: externalId ?? this.externalId,
    );
  }
}

/// Модель складской операции перемещения товара (приход/расход).
class WarehouseMovement {
  final String id;
  final String productId;
  final String productName;
  final String direction; // 'income' (приход) или 'expense' (расход)
  final double qty;
  final double amount;
  final String? note;
  final DateTime occurredAt;
  final String? cashOperationId;

  const WarehouseMovement({
    required this.id,
    required this.productId,
    required this.productName,
    required this.direction,
    required this.qty,
    required this.amount,
    this.note,
    required this.occurredAt,
    this.cashOperationId,
  });
}

/// Сводные метрики склада.
class WarehouseSummaryData {
  final int productsCount;
  final double totalStockValue;

  const WarehouseSummaryData({
    required this.productsCount,
    required this.totalStockValue,
  });
}
