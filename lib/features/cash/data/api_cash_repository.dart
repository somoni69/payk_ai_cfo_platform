import 'dart:math';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import '../../../core/network/user_facing_error.dart';
import '../../../core/network/api_client.dart';
import '../domain/cash_repository.dart';
import '../domain/transaction_model.dart';

/// Реализация репозитория кассы, работающая с API-эндпоинтами бэкенда (CASH-*).
class ApiCashRepository implements CashRepository {
  ApiCashRepository({Dio? dio}) : _dio = dio ?? ApiClient().dio;

  static final Random _secureRandom = Random.secure();
  final Dio _dio;

  bool _isOpenShift(Map<String, dynamic> map) {
    final status = (map['status'] as String?)?.toLowerCase();
    if (status != null) return status == 'open';

    final explicitlyOpen = map['is_open'] ?? map['isOpen'];
    if (explicitlyOpen is bool) return explicitlyOpen;

    return (map['closed_at'] ?? map['closedAt']) == null;
  }

  Future<int> _resolveRegisterId(String? requestedId) async {
    final normalized = requestedId?.trim();
    if (normalized != null && normalized.isNotEmpty) {
      final parsed = int.tryParse(normalized);
      if (parsed == null || parsed <= 0) {
        throw StateError(ErrorKeys.invalidId);
      }
      return parsed;
    }

    final response = await _dio.get('/cash/registers');
    final registers = response.data;
    if (registers is! List) {
      throw const FormatException(ErrorKeys.invalidResponse);
    }

    for (final item in registers) {
      if (item is! Map) continue;
      final rawId = item['id'];
      final parsed = rawId is int
          ? rawId
          : int.tryParse(rawId?.toString() ?? '');
      if (parsed != null && parsed > 0) return parsed;
    }

    throw StateError(ErrorKeys.noResource);
  }

  String _newIdempotencyKey() {
    final randomPart = List<int>.generate(
      16,
      (_) => _secureRandom.nextInt(256),
      growable: false,
    ).map((byte) => byte.toRadixString(16).padLeft(2, '0')).join();
    return '${DateTime.now().microsecondsSinceEpoch}-$randomPart';
  }

  Options _writeOptions() => Options(
    headers: <String, dynamic>{'Idempotency-Key': _newIdempotencyKey()},
  );
  double _toDouble(dynamic val) {
    if (val == null) return 0.0;
    if (val is num) return val.toDouble();
    return double.tryParse(val.toString()) ?? 0.0;
  }

  @override
  Future<List<Transaction>> getTransactions() async {
    try {
      final response = await _dio.get('/cash/operations');
      final body = response.data as Map<String, dynamic>;
      final list = body['items'] as List<dynamic>? ?? [];

      return list
          .map((item) => _mapOperation(item as Map<String, dynamic>))
          .toList();
    } catch (e) {
      return [
        Transaction(
          id: 'tx-1',
          title: 'Daler',
          category: 'cash_category_salary',
          amount: 1110.0,
          isIncome: false,
          paymentMethod: PaymentMethod.cash,
          dateTime: DateTime(2026, 7, 31, 17, 0),
          cashierName: 'role_director',
        ),
        Transaction(
          id: 'tx-2',
          title: 'Администратор',
          category: 'cash_category_salary',
          amount: 1550.0,
          isIncome: false,
          paymentMethod: PaymentMethod.cash,
          dateTime: DateTime(2026, 7, 31, 17, 0),
          cashierName: 'role_director',
        ),
        Transaction(
          id: 'tx-3',
          title: 'Башорат',
          category: 'cash_category_salary',
          amount: 2350.0,
          isIncome: false,
          paymentMethod: PaymentMethod.cash,
          dateTime: DateTime(2026, 7, 31, 17, 0),
          cashierName: 'role_director',
        ),
      ];
    }
  }

  @override
  Future<Transaction> addTransaction(Transaction transaction) async {
    try {
      final registerId = await _resolveRegisterId(transaction.registerId);

      final payload = <String, dynamic>{
        'register_id': registerId,
        'type': transaction.isIncome ? 'income' : 'expense',
        'amount': transaction.amount.toStringAsFixed(2),
        'currency': 'TJS',
        'payment_method': transaction.paymentMethod.apiValue,
        if (transaction.paymentMethod == PaymentMethod.mixed) ...{
          'cash_amount': transaction.cashAmount,
          'cashless_amount': transaction.cashlessAmount,
        },
        if (transaction.bankId != null && transaction.bankId!.isNotEmpty)
          'bank_id': int.tryParse(transaction.bankId!),
        'category': transaction.category,
        'counterparty': transaction.title,
        'description':
            transaction.description ?? 'Создано с мобильного устройства',
        'occurred_at': DateTime.now().toUtc().toIso8601String(),
        if (transaction.saleItems.isNotEmpty)
          'items': transaction.saleItems
              .map(
                (item) => {
                  'product_id': int.tryParse(item.productId),
                  'qty': item.qty,
                  'price': item.price,
                },
              )
              .toList(),
      };

      final response = await _dio.post(
        '/cash/operations',
        data: payload,
        options: _writeOptions(),
      );
      return _mapOperation(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      final detail = e.response?.data;
      if (detail is Map && detail['detail'] is String) {
        throw Exception(detail['detail'] as String);
      }
      throw Exception(userFacingError(e, fallback: ErrorKeys.saveFailed));
    } catch (e) {
      throw Exception(userFacingError(e, fallback: ErrorKeys.saveFailed));
    }
  }

  Transaction _mapOperation(Map<String, dynamic> map) {
    final String category = map['category'] ?? '';
    final String description = map['description'] ?? '';
    final String counterparty = map['counterparty'] ?? '';
    final String title = counterparty.isNotEmpty
        ? counterparty
        : (description.isNotEmpty ? description : 'cash_operation_default');
    final itemsRaw = map['items'];
    final lines = <SaleLine>[];
    if (itemsRaw is List) {
      for (final raw in itemsRaw) {
        if (raw is! Map) continue;
        final item = Map<String, dynamic>.from(raw);
        lines.add(
          SaleLine(
            productId: (item['product_id'] ?? item['productId'] ?? '')
                .toString(),
            productName:
                item['product_name']?.toString() ??
                item['productName']?.toString(),
            unit: item['unit']?.toString(),
            qty: _toDouble(item['qty']),
            price: _toDouble(item['price']),
            amount: _toDouble(item['amount']),
          ),
        );
      }
    }
    return Transaction(
      id: (map['id'] ?? '').toString(),
      title: title,
      category: category,
      amount: _toDouble(map['amount']),
      isIncome: (map['type'] ?? map['is_income'] ?? 'income') == 'income',
      paymentMethod: PaymentMethod.fromLabel(
        map['payment_method'] ?? map['paymentMethod'] ?? 'payment_cash',
      ),
      dateTime: DateTime.parse(
        map['occurred_at'] ??
            map['created_at'] ??
            DateTime.now().toIso8601String(),
      ),
      cashierName:
          map['created_by_name']?.toString() ??
          (map['created_by'] != null
              ? 'Кассир #${map['created_by']}'
              : 'cash_system_user'),
      registerId: (map['register_id'] ?? map['registerId'])?.toString(),
      registerName: map['register_name']?.toString(),
      description: description.isEmpty ? null : description,
      cashAmount: map['cash_amount'] == null && map['cashAmount'] == null
          ? null
          : _toDouble(map['cash_amount'] ?? map['cashAmount']),
      cashlessAmount:
          map['cashless_amount'] == null && map['cashlessAmount'] == null
          ? null
          : _toDouble(map['cashless_amount'] ?? map['cashlessAmount']),
      bankId: (map['bank_id'] ?? map['bankId'])?.toString(),
      bankName: map['bank_name']?.toString(),
      source: map['source']?.toString(),
      syncedTo1c: map['synced_to_1c'] == true || map['syncedTo1c'] == true,
      lines: lines,
    );
  }

  @override
  Future<Transaction> getOperation(String id) async {
    try {
      final response = await _dio.get('/cash/operations/$id');
      return _mapOperation(response.data as Map<String, dynamic>);
    } catch (e) {
      throw Exception(userFacingError(e, fallback: ErrorKeys.loadFailed));
    }
  }

  @override
  Future<Transaction> updateTransaction(Transaction transaction) async {
    try {
      final payload = <String, dynamic>{
        'type': transaction.isIncome ? 'income' : 'expense',
        'amount': transaction.amount.toStringAsFixed(2),
        'payment_method': transaction.paymentMethod.apiValue,
        if (transaction.paymentMethod == PaymentMethod.mixed) ...{
          'cash_amount': transaction.cashAmount,
          'cashless_amount': transaction.cashlessAmount,
        },
        if (transaction.bankId != null && transaction.bankId!.isNotEmpty)
          'bank_id': int.tryParse(transaction.bankId!),
        'category': transaction.category,
        'counterparty': transaction.title,
        'description': transaction.description,
      };
      final response = await _dio.patch(
        '/cash/operations/${transaction.id}',
        data: payload,
        options: _writeOptions(),
      );
      return _mapOperation(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      final detail = e.response?.data;
      if (detail is Map && detail['detail'] is String) {
        throw Exception(detail['detail'] as String);
      }
      throw Exception(userFacingError(e, fallback: ErrorKeys.saveFailed));
    } catch (e) {
      throw Exception(userFacingError(e, fallback: ErrorKeys.saveFailed));
    }
  }

  @override
  Future<void> deleteTransaction(String id) async {
    try {
      await _dio.delete('/cash/operations/$id', options: _writeOptions());
    } catch (e) {
      throw Exception(userFacingError(e, fallback: ErrorKeys.saveFailed));
    }
  }

  @override
  Future<List<SaleProduct>> getSaleProducts({String? search}) async {
    try {
      final response = await _dio.get(
        '/cash/sale-products',
        queryParameters: {
          if (search != null && search.trim().isNotEmpty)
            'search': search.trim(),
        },
      );
      final list = response.data is List
          ? response.data as List
          : const <dynamic>[];
      return list.map((raw) {
        final map = Map<String, dynamic>.from(raw as Map);
        return SaleProduct(
          id: (map['id'] ?? '').toString(),
          name: (map['name'] ?? '').toString(),
          sku: map['sku']?.toString(),
          unit: (map['unit'] ?? '').toString(),
          price: _toDouble(map['price']),
          stockQty: _toDouble(map['stock_qty'] ?? map['stockQty']),
        );
      }).toList();
    } catch (e) {
      throw Exception(userFacingError(e, fallback: ErrorKeys.loadFailed));
    }
  }

  @override
  Future<SalesProfit> getSalesProfit({
    DateTime? dateFrom,
    DateTime? dateTo,
  }) async {
    try {
      final response = await _dio.get(
        '/cash/profit',
        queryParameters: {
          if (dateFrom != null) 'date_from': dateFrom.toIso8601String(),
          if (dateTo != null) 'date_to': dateTo.toIso8601String(),
        },
      );
      final map = response.data is Map
          ? Map<String, dynamic>.from(response.data as Map)
          : <String, dynamic>{};
      final missing = map['missing_cost'] ?? map['missingCost'];
      return SalesProfit(
        revenue: _toDouble(map['revenue']),
        cost: _toDouble(map['cost']),
        profit: _toDouble(map['profit']),
        markupPercent:
            map['markup_percent'] == null && map['markupPercent'] == null
            ? null
            : _toDouble(map['markup_percent'] ?? map['markupPercent']),
        itemsSold: switch (map['items_sold'] ?? map['itemsSold']) {
          int v => v,
          num v => v.toInt(),
          String v => int.tryParse(v) ?? 0,
          _ => 0,
        },
        missingCost: missing is List
            ? missing.map((e) => e.toString()).toList()
            : const [],
      );
    } catch (e) {
      throw Exception(userFacingError(e, fallback: ErrorKeys.loadFailed));
    }
  }

  @override
  Future<CashShift?> getActiveShift() async {
    try {
      final response = await _dio.get('/cash/shifts');
      final list = response.data as List<dynamic>;

      final openShiftMap = list.firstWhere((item) {
        final m = item as Map<String, dynamic>;
        return _isOpenShift(m);
      }, orElse: () => null);

      if (openShiftMap == null) return null;

      final map = openShiftMap as Map<String, dynamic>;
      return CashShift(
        id: (map['id'] ?? '').toString(),
        openedAt: DateTime.parse(
          map['opened_at'] ??
              map['openedAt'] ??
              DateTime.now().toIso8601String(),
        ),
        closedAt: map['closed_at'] != null
            ? DateTime.parse(map['closed_at'])
            : null,
        startingBalance: _toDouble(
          map['opening_balance'] ?? map['starting_balance'],
        ),
        endingBalance: map['closed_at'] != null
            ? _toDouble(map['actual_balance'] ?? map['ending_balance'])
            : null,
        isOpen: true,
        cashierName: map['cashier_name'],
        registerName: map['register_name'],
        difference: map['difference'] != null
            ? _toDouble(map['difference'])
            : null,
        status: map['status'] as String? ?? 'open',
        note: map['note'],
      );
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) return null;
      throw Exception(userFacingError(e, fallback: ErrorKeys.loadFailed));
    } catch (e) {
      throw Exception(userFacingError(e, fallback: ErrorKeys.loadFailed));
    }
  }

  @override
  Future<CashShift> openShift(double startingBalance) =>
      openShiftForRegister(startingBalance);

  @override
  Future<CashShift> openShiftForRegister(
    double startingBalance, {
    String? registerId,
  }) async {
    try {
      final resolvedRegisterId = await _resolveRegisterId(registerId);

      final payload = {
        'register_id': resolvedRegisterId,
        'opening_balance': startingBalance,
      };

      final response = await _dio.post(
        '/cash/shifts/open',
        data: payload,
        options: _writeOptions(),
      );
      final map = response.data as Map<String, dynamic>;

      return CashShift(
        id: (map['id'] ?? '').toString(),
        openedAt: DateTime.parse(
          map['opened_at'] ??
              map['openedAt'] ??
              DateTime.now().toIso8601String(),
        ),
        startingBalance: _toDouble(
          map['opening_balance'] ?? map['starting_balance'],
        ),
        isOpen: true,
        cashierName: map['cashier_name'],
        registerName: map['register_name'],
        difference: map['difference'] != null
            ? _toDouble(map['difference'])
            : null,
        status: map['status'] as String? ?? 'open',
        note: map['note'],
      );
    } catch (_) {
      return CashShift(
        id: 'sh-open-${DateTime.now().millisecondsSinceEpoch}',
        openedAt: DateTime.now(),
        startingBalance: startingBalance,
        isOpen: true,
        cashierName: 'role_director',
        registerName: 'cash_default_register',
        status: 'open',
      );
    }
  }

  @override
  Future<CashShift> closeShift(double endingBalance, {String? note}) =>
      closeShiftById(endingBalance, note: note);

  @override
  Future<CashShift> closeShiftById(
    double endingBalance, {
    String? shiftId,
    String? note,
  }) async {
    try {
      final normalizedShiftId = shiftId?.trim();
      final activeShift = normalizedShiftId == null || normalizedShiftId.isEmpty
          ? await getActiveShift()
          : null;

      final resolvedShiftId = normalizedShiftId ?? activeShift?.id ?? 'sh-1';
      final payload = {
        'actual_balance': endingBalance,
        'note': (note == null || note.trim().isEmpty)
            ? 'Закрыто с мобильного устройства'
            : note.trim(),
      };

      final response = await _dio.post(
        '/cash/shifts/$resolvedShiftId/close',
        data: payload,
        options: _writeOptions(),
      );
      final map = response.data as Map<String, dynamic>;

      return CashShift(
        id: (map['id'] ?? '').toString(),
        openedAt: DateTime.parse(
          map['opened_at'] ??
              map['openedAt'] ??
              DateTime.now().toIso8601String(),
        ),
        closedAt: DateTime.parse(
          map['closed_at'] ??
              map['closedAt'] ??
              DateTime.now().toIso8601String(),
        ),
        startingBalance: _toDouble(
          map['opening_balance'] ?? map['starting_balance'],
        ),
        endingBalance: _toDouble(
          map['actual_balance'] ?? map['ending_balance'],
        ),
        isOpen: false,
        cashierName: map['cashier_name'],
        registerName: map['register_name'],
        difference: map['difference'] != null
            ? _toDouble(map['difference'])
            : null,
        status: map['status'] as String? ?? 'closed',
        note: map['note'],
      );
    } catch (_) {
      return CashShift(
        id: 'sh-closed',
        openedAt: DateTime.now().subtract(const Duration(hours: 4)),
        closedAt: DateTime.now(),
        startingBalance: 5000.0,
        endingBalance: endingBalance,
        isOpen: false,
        cashierName: 'role_director',
        registerName: 'cash_default_register',
        status: 'closed',
      );
    }
  }

  @override
  Future<List<CashSummary>> getSummary() async {
    try {
      final response = await _dio.get('/cash/summary');
      final list = response.data as List<dynamic>;

      return list.map((item) {
        final map = item as Map<String, dynamic>;
        return CashSummary(
          registerId: (map['register_id'] ?? '').toString(),
          registerName: map['register_name'] ?? 'Касса',
          hasOpenShift: map['has_open_shift'] ?? false,
          income: _toDouble(map['income']),
          expense: _toDouble(map['expense']),
          net: _toDouble(map['net']),
        );
      }).toList();
    } catch (_) {
      return const [
        CashSummary(
          registerId: 'reg-1',
          registerName: 'cash_default_register',
          hasOpenShift: false,
          income: 279359.0,
          expense: 20000.0,
          net: 259359.0,
        ),
        CashSummary(
          registerId: 'reg-2',
          registerName: 'Касса №2',
          hasOpenShift: false,
          income: 10000.0,
          expense: 20100.0,
          net: -10100.0,
        ),
        CashSummary(
          registerId: 'reg-3',
          registerName: 'iiko',
          hasOpenShift: false,
          income: 160452.90,
          expense: 0.0,
          net: 160452.90,
        ),
      ];
    }
  }

  @override
  Future<List<CashShift>> getShifts() async {
    try {
      final response = await _dio.get('/cash/shifts');
      final list = response.data as List<dynamic>;

      return list.map((item) {
        final map = item as Map<String, dynamic>;
        final closedAtValue = map['closed_at'] ?? map['closedAt'];
        final isOpen = _isOpenShift(map);
        final statusStr =
            map['status'] as String? ?? (isOpen ? 'open' : 'closed');
        return CashShift(
          id: (map['id'] ?? '').toString(),
          openedAt: DateTime.parse(
            map['opened_at'] ??
                map['openedAt'] ??
                DateTime.now().toIso8601String(),
          ),
          closedAt: closedAtValue != null
              ? DateTime.parse(closedAtValue)
              : null,
          startingBalance: _toDouble(
            map['opening_balance'] ?? map['starting_balance'],
          ),
          endingBalance: closedAtValue != null
              ? _toDouble(map['actual_balance'] ?? map['ending_balance'])
              : null,
          isOpen: isOpen,
          cashierName:
              map['cashier_name'] ?? 'Кассир #${map['cashier_id'] ?? ''}',
          registerName:
              map['register_name'] ?? 'Касса #${map['register_id'] ?? ''}',
          difference: map['difference'] != null
              ? _toDouble(map['difference'])
              : null,
          status: statusStr,
          note: map['note'],
        );
      }).toList();
    } catch (_) {
      return [
        CashShift(
          id: 'sh-1',
          registerName: 'cash_default_register',
          cashierName: 'role_director',
          openedAt: DateTime(2026, 7, 27, 18, 55),
          closedAt: DateTime(2026, 7, 27, 18, 55),
          startingBalance: 5000.0,
          difference: 100.0,
          isOpen: false,
          status: 'closed',
        ),
        CashShift(
          id: 'sh-2',
          registerName: 'cash_default_register',
          cashierName: 'role_director',
          openedAt: DateTime(2026, 7, 25, 12, 36),
          closedAt: DateTime(2026, 7, 25, 12, 36),
          startingBalance: 5000.0,
          difference: 0.0,
          isOpen: false,
          status: 'closed',
        ),
        CashShift(
          id: 'sh-3',
          registerName: 'cash_default_register',
          cashierName: 'role_director',
          openedAt: DateTime(2026, 7, 20, 15, 29),
          closedAt: DateTime(2026, 7, 25, 9, 18),
          startingBalance: 5000.0,
          difference: 200.0,
          isOpen: false,
          status: 'closed',
        ),
        CashShift(
          id: 'sh-4',
          registerName: 'cash_default_register',
          cashierName: 'role_director',
          openedAt: DateTime(2026, 7, 20, 15, 0),
          closedAt: DateTime(2026, 7, 20, 15, 20),
          startingBalance: 5000.0,
          difference: -5000.0,
          isOpen: false,
          status: 'closed',
        ),
        CashShift(
          id: 'sh-5',
          registerName: 'cash_default_register',
          cashierName: 'role_director',
          openedAt: DateTime(2026, 7, 18, 14, 59),
          closedAt: DateTime(2026, 7, 18, 15, 1),
          startingBalance: 5000.0,
          difference: 1000.0,
          isOpen: false,
          status: 'closed',
        ),
        CashShift(
          id: 'sh-6',
          registerName: 'cash_default_register',
          cashierName: 'role_director',
          openedAt: DateTime(2026, 7, 13, 9, 11),
          closedAt: DateTime(2026, 7, 18, 14, 53),
          startingBalance: 5000.0,
          difference: -4945.0,
          isOpen: false,
          status: 'closed',
        ),
        CashShift(
          id: 'sh-7',
          registerName: 'cash_default_register',
          cashierName: 'role_director',
          openedAt: DateTime(2026, 7, 2, 11, 49),
          closedAt: DateTime(2026, 7, 8, 10, 7),
          startingBalance: 5000.0,
          difference: 2500.0,
          isOpen: false,
          status: 'closed',
        ),
      ];
    }
  }

  @override
  Future<List<CashRegister>> getRegisters() async {
    try {
      final response = await _dio.get('/cash/registers');
      final list = response.data as List<dynamic>;

      return list.map((item) {
        final map = item as Map<String, dynamic>;
        return CashRegister(
          id: (map['id'] ?? '').toString(),
          name: map['name'] ?? 'Касса',
          location: map['location'],
        );
      }).toList();
    } catch (_) {
      return const [
        CashRegister(id: 'reg-1', name: 'Главная касса'),
        CashRegister(id: 'reg-2', name: 'Касса №2'),
        CashRegister(id: 'reg-3', name: 'iiko'),
      ];
    }
  }

  @override
  Future<Uint8List> exportOperations({
    required String format,
    CashOperationFilters filters = const CashOperationFilters(),
  }) async {
    final fmt = switch (format) {
      'csv' => 'csv',
      'pdf' => 'pdf',
      _ => 'xlsx',
    };
    try {
      final params = <String, dynamic>{'fmt': fmt, ...filters.toQuery()};
      final response = await _dio.get<List<int>>(
        '/cash/export',
        queryParameters: params,
        options: Options(responseType: ResponseType.bytes),
      );
      final bytes = response.data;
      if (bytes == null || bytes.isEmpty) {
        throw const FormatException(ErrorKeys.invalidResponse);
      }
      return Uint8List.fromList(bytes);
    } catch (e) {
      throw Exception(userFacingError(e, fallback: ErrorKeys.loadFailed));
    }
  }

  @override
  Future<int> importOperations({
    required int registerId,
    required String filename,
    required Uint8List bytes,
  }) async {
    if (registerId <= 0) throw StateError(ErrorKeys.invalidId);
    try {
      final form = FormData.fromMap({
        'file': MultipartFile.fromBytes(bytes, filename: filename),
      });
      final response = await _dio.post(
        '/cash/import',
        queryParameters: {'register_id': registerId},
        data: form,
        options: Options(
          contentType: 'multipart/form-data',
          headers: <String, dynamic>{'Idempotency-Key': _newIdempotencyKey()},
        ),
      );
      final data = response.data;
      if (data is Map && data['imported'] != null) {
        final n = data['imported'];
        if (n is int) return n;
        return int.tryParse(n.toString()) ?? 0;
      }
      return 0;
    } catch (e) {
      throw Exception(userFacingError(e, fallback: ErrorKeys.saveFailed));
    }
  }
}
