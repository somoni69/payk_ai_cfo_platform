import 'warehouse_models.dart';

/// Абстрактный контракт для репозитория склада.
abstract class WarehouseRepository {
  /// Получить каталог товаров с остатками
  Future<List<WarehouseProduct>> getProducts();

  /// Получить историю движений товаров (приход/расход)
  Future<List<WarehouseMovement>> getMovements();

  /// Получить сводные метрики склада
  Future<WarehouseSummaryData> getSummary();

  /// Добавить новый товар
  Future<WarehouseProduct> createProduct(WarehouseProduct product);

  Future<WarehouseProduct> updateProduct(WarehouseProduct product);

  Future<void> deleteProduct(String id);

  /// Director-only: zero stock via `/finance-ops/zero-out`.
  Future<void> zeroOutProduct(String id);

  /// Добавить операцию перемещения товара (приход/расход)
  Future<WarehouseMovement> createMovement(
    String productId,
    String direction,
    double qty,
    double amount,
    String? note,
  );
}
