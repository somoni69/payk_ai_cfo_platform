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

  /// Партии завоза (сроки годности). [expiringOnly] — только «горящие».
  Future<List<WarehouseBatch>> getBatches({bool expiringOnly = false});

  Future<WarehouseBatch> createBatch({
    required String productId,
    required double qty,
    DateTime? expiryDate,
    String? code,
    String? note,
  });

  Future<WarehouseBatch> updateBatch({
    required String id,
    double? qty,
    DateTime? expiryDate,
    DateTime? receivedAt,
    String? code,
    String? note,
  });

  Future<void> deleteBatch(String id);

  /// Уценка товара по партии (меняет цену продукта).
  Future<void> applyBatchDiscount(String batchId, int percent);

  /// AI-разбор остатков и сроков (5–10 с, long timeout).
  Future<WarehouseStockAnalysis> getStockAnalysis();

  /// Присвоить товару валидный EAN-13 штрих-код (`POST /warehouse/products/{id}/barcode`)
  Future<WarehouseProduct> assignBarcode(String productId);

  /// Выдать недостающие EAN-13 коды всем товарам магазина (`POST /warehouse/barcodes/generate-missing`)
  Future<int> assignMissingBarcodes();

  /// Скачать PDF с этикетками товаров (`GET /warehouse/barcodes/labels`)
  /// [sheet]: 'a4' (сетка 3x8) или 'label' (термолента 58 мм)
  Future<List<int>> downloadBarcodeLabelsPdf({
    required List<String> productIds,
    String sheet = 'a4',
    int copies = 1,
  });

  /// Run expiry detectors now (`POST /warehouse/run-expiry-check`).
  /// Returns number of new alerts created.
  Future<int> runExpiryCheck();
}
