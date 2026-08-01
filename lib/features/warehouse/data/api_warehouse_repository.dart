import '../../../core/network/api_client.dart';
import '../../../core/network/user_facing_error.dart';
import '../domain/warehouse_models.dart';
import '../domain/warehouse_repository.dart';

/// Конкретная реализация репозитория склада, работающая с бэкендом PAYK.
class ApiWarehouseRepository implements WarehouseRepository {
  final ApiClient _apiClient = ApiClient();

  int _requirePositiveId(String value, String fieldName) {
    final id = int.tryParse(value);
    if (id == null || id <= 0) {
      throw ArgumentError.value(value, fieldName, ErrorKeys.invalidId);
    }
    return id;
  }

  double _toDouble(dynamic val) {
    if (val == null) return 0.0;
    if (val is num) return val.toDouble();
    return double.tryParse(val.toString()) ?? 0.0;
  }

  @override
  Future<List<WarehouseProduct>> getProducts() async {
    try {
      final response = await _apiClient.dio.get('/warehouse/products');
      final list = response.data as List<dynamic>;

      return list.map((item) {
        final map = item as Map<String, dynamic>;
        return WarehouseProduct(
          id: (map['id'] ?? '').toString(),
          name: map['name'] ?? '',
          sku: map['sku']?.toString(),
          unit: map['unit'] ?? 'шт',
          price: _toDouble(map['price']),
          stockQty: _toDouble(map['stock_qty'] ?? map['stockQty']),
          externalId: map['external_id']?.toString(),
        );
      }).toList();
    } catch (e) {
      throw Exception(userFacingError(e, fallback: ErrorKeys.loadFailed));
    }
  }

  @override
  Future<List<WarehouseMovement>> getMovements() async {
    try {
      final response = await _apiClient.dio.get('/warehouse/movements');
      final list = response.data as List<dynamic>;

      return list.map((item) {
        final map = item as Map<String, dynamic>;
        return WarehouseMovement(
          id: (map['id'] ?? '').toString(),
          productId: (map['product_id'] ?? map['productId'] ?? '').toString(),
          productName: map['product_name'] ?? map['productName'] ?? 'Товар',
          direction: map['direction'] ?? 'income',
          qty: _toDouble(map['qty']),
          amount: _toDouble(map['amount']),
          note: map['note']?.toString(),
          occurredAt: DateTime.parse(
            map['occurred_at'] ??
                map['occurredAt'] ??
                DateTime.now().toIso8601String(),
          ),
          cashOperationId: map['cash_operation_id']?.toString(),
        );
      }).toList();
    } catch (e) {
      throw Exception(userFacingError(e, fallback: ErrorKeys.loadFailed));
    }
  }

  @override
  Future<WarehouseSummaryData> getSummary() async {
    try {
      final response = await _apiClient.dio.get('/warehouse/summary');
      final map = response.data as Map<String, dynamic>;

      return WarehouseSummaryData(
        productsCount: map['products_count'] ?? map['productsCount'] ?? 0,
        totalStockValue: _toDouble(
          map['total_stock_value'] ?? map['totalStockValue'],
        ),
      );
    } catch (e) {
      throw Exception(userFacingError(e, fallback: ErrorKeys.loadFailed));
    }
  }

  @override
  Future<WarehouseProduct> createProduct(WarehouseProduct product) async {
    try {
      final payload = {
        'name': product.name,
        'sku': product.sku,
        'unit': product.unit,
        'price': product.price,
        'stock_qty': product.stockQty,
      };

      final response = await _apiClient.dio.post(
        '/warehouse/products',
        data: payload,
      );
      final map = response.data as Map<String, dynamic>;

      return WarehouseProduct(
        id: (map['id'] ?? '').toString(),
        name: map['name'] ?? '',
        sku: map['sku']?.toString(),
        unit: map['unit'] ?? 'шт',
        price: _toDouble(map['price']),
        stockQty: _toDouble(map['stock_qty'] ?? map['stockQty']),
        externalId: map['external_id']?.toString(),
      );
    } catch (e) {
      throw Exception(userFacingError(e, fallback: ErrorKeys.loadFailed));
    }
  }

  @override
  Future<WarehouseMovement> createMovement(
    String productId,
    String direction,
    double qty,
    double amount,
    String? note,
  ) async {
    try {
      final payload = {
        'product_id': _requirePositiveId(productId, 'productId'),
        'direction': direction, // 'income' или 'expense'
        'qty': qty,
        'amount': amount,
        'note': note,
      };

      final response = await _apiClient.dio.post(
        '/warehouse/movements',
        data: payload,
      );
      final map = response.data as Map<String, dynamic>;

      return WarehouseMovement(
        id: (map['id'] ?? '').toString(),
        productId: (map['product_id'] ?? map['productId'] ?? '').toString(),
        productName: map['product_name'] ?? map['productName'] ?? 'Товар',
        direction: map['direction'] ?? 'income',
        qty: _toDouble(map['qty']),
        amount: _toDouble(map['amount']),
        note: map['note']?.toString(),
        occurredAt: DateTime.parse(
          map['occurred_at'] ??
              map['occurredAt'] ??
              DateTime.now().toIso8601String(),
        ),
        cashOperationId: map['cash_operation_id']?.toString(),
      );
    } catch (e) {
      throw Exception(userFacingError(e, fallback: ErrorKeys.loadFailed));
    }
  }
}
