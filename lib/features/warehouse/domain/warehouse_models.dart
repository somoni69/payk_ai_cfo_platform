/// Модель товара на складе.
class WarehouseProduct {
  final String id;
  final String name;
  final String? sku;
  final String? barcode;
  final String unit;
  final double price;
  final double? costPrice;
  final double stockQty;
  final String? externalId;

  const WarehouseProduct({
    required this.id,
    required this.name,
    this.sku,
    this.barcode,
    required this.unit,
    required this.price,
    this.costPrice,
    required this.stockQty,
    this.externalId,
  });

  WarehouseProduct copyWith({
    String? id,
    String? name,
    String? sku,
    String? barcode,
    String? unit,
    double? price,
    double? costPrice,
    double? stockQty,
    String? externalId,
  }) {
    return WarehouseProduct(
      id: id ?? this.id,
      name: name ?? this.name,
      sku: sku ?? this.sku,
      barcode: barcode ?? this.barcode,
      unit: unit ?? this.unit,
      price: price ?? this.price,
      costPrice: costPrice ?? this.costPrice,
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

  WarehouseSummaryData copyWith({int? productsCount, double? totalStockValue}) {
    return WarehouseSummaryData(
      productsCount: productsCount ?? this.productsCount,
      totalStockValue: totalStockValue ?? this.totalStockValue,
    );
  }
}

/// Партия завоза со сроком годности (`/warehouse/batches`).
class WarehouseBatch {
  final String id;
  final String productId;
  final String productName;
  final String? unit;
  final String? code;
  final double qty;
  final DateTime? expiryDate;
  final DateTime? receivedAt;
  final String? note;
  final int? daysLeft;
  final int? suggestedDiscount;

  const WarehouseBatch({
    required this.id,
    required this.productId,
    required this.productName,
    this.unit,
    this.code,
    required this.qty,
    this.expiryDate,
    this.receivedAt,
    this.note,
    this.daysLeft,
    this.suggestedDiscount,
  });

  bool get isExpired => daysLeft != null && daysLeft! < 0;
  bool get isUrgent => daysLeft != null && daysLeft! >= 0 && daysLeft! < 7;
}

/// AI stock analysis (`GET /warehouse/analysis`) — opt-in, long-running.
class WarehouseStockAnalysis {
  final int totalItems;
  final int zeroItems;
  final double stockValue;
  final int expiringCount;
  final int expiredCount;
  final double atRiskAmount;
  final List<WarehouseLowStockRow> lowStock;
  final List<WarehouseExpiringRow> expiring;
  final String summary;

  const WarehouseStockAnalysis({
    required this.totalItems,
    required this.zeroItems,
    required this.stockValue,
    required this.expiringCount,
    required this.expiredCount,
    required this.atRiskAmount,
    this.lowStock = const [],
    this.expiring = const [],
    this.summary = '',
  });
}

class WarehouseLowStockRow {
  final String name;
  final double qty;
  final String unit;

  const WarehouseLowStockRow({
    required this.name,
    required this.qty,
    required this.unit,
  });
}

class WarehouseExpiringRow {
  final String batchId;
  final String productId;
  final String productName;
  final String? code;
  final String unit;
  final double qty;
  final DateTime? expiryDate;
  final int daysLeft;
  final bool expired;
  final double price;
  final int suggestedDiscount;
  final double? discountedPrice;
  final double atRiskAmount;

  const WarehouseExpiringRow({
    required this.batchId,
    required this.productId,
    required this.productName,
    this.code,
    required this.unit,
    required this.qty,
    this.expiryDate,
    required this.daysLeft,
    required this.expired,
    required this.price,
    required this.suggestedDiscount,
    this.discountedPrice,
    required this.atRiskAmount,
  });
}
