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
          costPrice: map['cost_price'] == null && map['costPrice'] == null
              ? null
              : _toDouble(map['cost_price'] ?? map['costPrice']),
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
        if (product.costPrice != null) 'cost_price': product.costPrice,
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
        costPrice: map['cost_price'] == null && map['costPrice'] == null
            ? null
            : _toDouble(map['cost_price'] ?? map['costPrice']),
        stockQty: _toDouble(map['stock_qty'] ?? map['stockQty']),
        externalId: map['external_id']?.toString(),
      );
    } catch (e) {
      throw Exception(userFacingError(e, fallback: ErrorKeys.loadFailed));
    }
  }

  @override
  Future<WarehouseProduct> updateProduct(WarehouseProduct product) async {
    try {
      final response = await _apiClient.dio.patch(
        '/warehouse/products/${_requirePositiveId(product.id, 'id')}',
        data: {
          'name': product.name,
          'sku': product.sku,
          'unit': product.unit,
          'price': product.price,
          if (product.costPrice != null) 'cost_price': product.costPrice,
          'stock_qty': product.stockQty,
        },
      );
      final map = response.data as Map<String, dynamic>;
      return WarehouseProduct(
        id: (map['id'] ?? product.id).toString(),
        name: map['name'] ?? product.name,
        sku: map['sku']?.toString(),
        unit: map['unit'] ?? product.unit,
        price: _toDouble(map['price']),
        costPrice: map['cost_price'] == null && map['costPrice'] == null
            ? product.costPrice
            : _toDouble(map['cost_price'] ?? map['costPrice']),
        stockQty: _toDouble(map['stock_qty'] ?? map['stockQty']),
        externalId: map['external_id']?.toString(),
      );
    } catch (e) {
      throw Exception(userFacingError(e, fallback: ErrorKeys.saveFailed));
    }
  }

  @override
  Future<void> deleteProduct(String id) async {
    try {
      await _apiClient.dio.delete(
        '/warehouse/products/${_requirePositiveId(id, 'id')}',
      );
    } catch (e) {
      throw Exception(userFacingError(e, fallback: ErrorKeys.saveFailed));
    }
  }

  @override
  Future<void> zeroOutProduct(String id) async {
    try {
      await _apiClient.dio.post(
        '/finance-ops/zero-out',
        data: {'target': 'product', 'id': _requirePositiveId(id, 'id')},
      );
    } catch (e) {
      throw Exception(userFacingError(e, fallback: ErrorKeys.saveFailed));
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

  WarehouseBatch _batchFromJson(Map<String, dynamic> map) {
    DateTime? parseDate(dynamic v) {
      if (v is! String || v.isEmpty) return null;
      return DateTime.tryParse(v);
    }

    final daysRaw = map['days_left'] ?? map['daysLeft'];
    final daysLeft = switch (daysRaw) {
      int v => v,
      num v => v.toInt(),
      String v => int.tryParse(v),
      _ => null,
    };
    final discRaw = map['suggested_discount'] ?? map['suggestedDiscount'];
    final suggested = switch (discRaw) {
      int v => v,
      num v => v.toInt(),
      String v => int.tryParse(v),
      _ => null,
    };

    return WarehouseBatch(
      id: (map['id'] ?? '').toString(),
      productId: (map['product_id'] ?? map['productId'] ?? '').toString(),
      productName: (map['product_name'] ?? map['productName'] ?? 'Товар')
          .toString(),
      unit: map['unit']?.toString(),
      code: map['code']?.toString(),
      qty: _toDouble(map['qty']),
      expiryDate: parseDate(map['expiry_date'] ?? map['expiryDate']),
      receivedAt: parseDate(map['received_at'] ?? map['receivedAt']),
      note: map['note']?.toString(),
      daysLeft: daysLeft,
      suggestedDiscount: suggested,
    );
  }

  @override
  Future<List<WarehouseBatch>> getBatches({bool expiringOnly = false}) async {
    try {
      final response = await _apiClient.dio.get(
        '/warehouse/batches',
        queryParameters: {if (expiringOnly) 'expiring': true},
      );
      final list = response.data as List<dynamic>;
      return list
          .map((e) => _batchFromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
    } catch (e) {
      throw Exception(userFacingError(e, fallback: ErrorKeys.loadFailed));
    }
  }

  @override
  Future<WarehouseBatch> createBatch({
    required String productId,
    required double qty,
    DateTime? expiryDate,
    String? code,
    String? note,
  }) async {
    try {
      final payload = <String, dynamic>{
        'product_id': _requirePositiveId(productId, 'productId'),
        'qty': qty,
        if (expiryDate != null)
          'expiry_date':
              '${expiryDate.year.toString().padLeft(4, '0')}-'
              '${expiryDate.month.toString().padLeft(2, '0')}-'
              '${expiryDate.day.toString().padLeft(2, '0')}',
        if (code != null && code.isNotEmpty) 'code': code,
        if (note != null && note.isNotEmpty) 'note': note,
      };
      final response = await _apiClient.dio.post(
        '/warehouse/batches',
        data: payload,
      );
      return _batchFromJson(Map<String, dynamic>.from(response.data as Map));
    } catch (e) {
      throw Exception(userFacingError(e, fallback: ErrorKeys.saveFailed));
    }
  }

  String _ymd(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';

  @override
  Future<WarehouseBatch> updateBatch({
    required String id,
    double? qty,
    DateTime? expiryDate,
    DateTime? receivedAt,
    String? code,
    String? note,
  }) async {
    try {
      final payload = <String, dynamic>{
        'qty': ?qty,
        if (expiryDate != null) 'expiry_date': _ymd(expiryDate),
        if (receivedAt != null) 'received_at': _ymd(receivedAt),
        'code': ?code,
        'note': ?note,
      };
      final response = await _apiClient.dio.patch(
        '/warehouse/batches/${_requirePositiveId(id, 'id')}',
        data: payload,
      );
      return _batchFromJson(Map<String, dynamic>.from(response.data as Map));
    } catch (e) {
      throw Exception(userFacingError(e, fallback: ErrorKeys.saveFailed));
    }
  }

  @override
  Future<void> deleteBatch(String id) async {
    try {
      await _apiClient.dio.delete(
        '/warehouse/batches/${_requirePositiveId(id, 'id')}',
      );
    } catch (e) {
      throw Exception(userFacingError(e, fallback: ErrorKeys.saveFailed));
    }
  }

  @override
  Future<void> applyBatchDiscount(String batchId, int percent) async {
    try {
      await _apiClient.dio.post(
        '/warehouse/batches/${_requirePositiveId(batchId, 'batchId')}/apply-discount',
        data: {'percent': percent},
      );
    } catch (e) {
      throw Exception(userFacingError(e, fallback: ErrorKeys.saveFailed));
    }
  }

  @override
  Future<WarehouseStockAnalysis> getStockAnalysis() async {
    try {
      final response = await _apiClient.dio.get(
        '/warehouse/analysis',
        options: ApiClient.longRunningOptions(
          receiveTimeout: const Duration(seconds: 90),
        ),
      );
      final map = response.data is Map
          ? Map<String, dynamic>.from(response.data as Map)
          : <String, dynamic>{};

      int asInt(dynamic v) => switch (v) {
        int i => i,
        num n => n.toInt(),
        String s => int.tryParse(s) ?? 0,
        _ => 0,
      };

      final lowRaw = map['low_stock'] ?? map['lowStock'];
      final lowStock = lowRaw is List
          ? lowRaw.map((e) {
              final m = Map<String, dynamic>.from(e as Map);
              return WarehouseLowStockRow(
                name: (m['name'] ?? '').toString(),
                qty: _toDouble(m['qty']),
                unit: (m['unit'] ?? '').toString(),
              );
            }).toList()
          : const <WarehouseLowStockRow>[];

      final expRaw = map['expiring'];
      final expiring = expRaw is List
          ? expRaw.map((e) {
              final m = Map<String, dynamic>.from(e as Map);
              final expiryRaw = m['expiry_date'] ?? m['expiryDate'];
              return WarehouseExpiringRow(
                batchId: (m['batch_id'] ?? m['batchId'] ?? '').toString(),
                productId: (m['product_id'] ?? m['productId'] ?? '').toString(),
                productName: (m['product_name'] ?? m['productName'] ?? '')
                    .toString(),
                code: m['code']?.toString(),
                unit: (m['unit'] ?? '').toString(),
                qty: _toDouble(m['qty']),
                expiryDate: expiryRaw is String
                    ? DateTime.tryParse(expiryRaw)
                    : null,
                daysLeft: asInt(m['days_left'] ?? m['daysLeft']),
                expired: m['expired'] == true,
                price: _toDouble(m['price']),
                suggestedDiscount: asInt(
                  m['suggested_discount'] ?? m['suggestedDiscount'],
                ),
                discountedPrice: m['discounted_price'] != null
                    ? _toDouble(m['discounted_price'] ?? m['discountedPrice'])
                    : null,
                atRiskAmount: _toDouble(
                  m['at_risk_amount'] ?? m['atRiskAmount'],
                ),
              );
            }).toList()
          : const <WarehouseExpiringRow>[];

      return WarehouseStockAnalysis(
        totalItems: asInt(map['total_items'] ?? map['totalItems']),
        zeroItems: asInt(map['zero_items'] ?? map['zeroItems']),
        stockValue: _toDouble(map['stock_value'] ?? map['stockValue']),
        expiringCount: asInt(map['expiring_count'] ?? map['expiringCount']),
        expiredCount: asInt(map['expired_count'] ?? map['expiredCount']),
        atRiskAmount: _toDouble(map['at_risk_amount'] ?? map['atRiskAmount']),
        lowStock: lowStock,
        expiring: expiring,
        summary: (map['summary'] ?? '').toString(),
      );
    } catch (e) {
      throw Exception(userFacingError(e, fallback: ErrorKeys.loadFailed));
    }
  }

  @override
  Future<int> runExpiryCheck() async {
    try {
      final response = await _apiClient.dio.post('/warehouse/run-expiry-check');
      final map = response.data is Map
          ? Map<String, dynamic>.from(response.data as Map)
          : <String, dynamic>{};
      final created = map['created'];
      return switch (created) {
        int v => v,
        num v => v.toInt(),
        String v => int.tryParse(v) ?? 0,
        _ => 0,
      };
    } catch (e) {
      throw Exception(userFacingError(e, fallback: ErrorKeys.saveFailed));
    }
  }
}
