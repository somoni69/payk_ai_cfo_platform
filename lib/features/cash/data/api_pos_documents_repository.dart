import 'package:dio/dio.dart';

// The explicit null checks read more clearly than null-aware map entries here.
// ignore_for_file: use_null_aware_elements

import '../../../core/error/app_failure.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_error_detail.dart';
import '../../../core/network/user_facing_error.dart';
import '../domain/pos_documents.dart';
import '../domain/pos_pricing.dart';

class ApiPosDocumentsRepository implements PosDocumentsRepository {
  ApiPosDocumentsRepository({Dio? dio}) : _dio = dio ?? ApiClient().dio;

  final Dio _dio;

  Future<T> _call<T>(
    Future<T> Function() action, {
    required String fallback,
  }) async {
    try {
      return await action();
    } catch (error) {
      if (error is RepositoryFailure) rethrow;
      throw repositoryFailure(error, fallback: fallback);
    }
  }

  Map<String, dynamic> _asMap(dynamic data) =>
      data is Map ? Map<String, dynamic>.from(data) : <String, dynamic>{};

  Map<String, dynamic> _pay({
    required String paymentMethod,
    double? cashAmount,
    int? bankId,
    String? pin,
    required String requestId,
  }) => {
    'payment_method': paymentMethod,
    if (cashAmount != null) 'cash_amount': moneyApi(cashAmount),
    if (bankId != null) 'bank_id': bankId,
    if (pin != null && pin.isNotEmpty) 'pin': pin,
    'request_id': requestId,
  };

  @override
  Future<PosReceipt> sell({
    required int registerId,
    required List<PosSaleLine> lines,
    required String paymentMethod,
    required double expectedTotal,
    double? cashAmount,
    int? bankId,
    double? receiptDiscountPercent,
    int? heldId,
    String? pin,
    required String requestId,
  }) {
    return _call(() async {
      final response = await _dio.post<dynamic>(
        '/cash/pos/sale',
        data: {
          'register_id': registerId,
          'lines': [for (final line in lines) line.toJson()],
          if (receiptDiscountPercent != null && receiptDiscountPercent > 0)
            'receipt_discount': {'percent': moneyApi(receiptDiscountPercent)},
          if (heldId != null) 'held_id': heldId,
          'expected_total': moneyApi(expectedTotal),
          ..._pay(
            paymentMethod: paymentMethod,
            cashAmount: cashAmount,
            bankId: bankId,
            pin: pin,
            requestId: requestId,
          ),
        },
      );
      return PosReceipt.fromJson(_asMap(response.data));
    }, fallback: ErrorKeys.saveFailed);
  }

  @override
  Future<PosReceiptPage> receipts({
    String? kind,
    int? number,
    String? barcode,
    int page = 1,
  }) {
    return _call(() async {
      final response = await _dio.get<dynamic>(
        '/cash/receipts',
        queryParameters: {
          'page': page,
          'size': 30,
          if (kind != null && kind.isNotEmpty) 'kind': kind,
          if (number != null) 'number': number,
          if (barcode != null && barcode.isNotEmpty) 'barcode': barcode,
        },
      );
      return PosReceiptPage.fromJson(_asMap(response.data));
    }, fallback: ErrorKeys.loadFailed);
  }

  @override
  Future<PosReceipt> receipt(int id) {
    return _call(() async {
      final response = await _dio.get<dynamic>('/cash/receipts/$id');
      return PosReceipt.fromJson(_asMap(response.data));
    }, fallback: ErrorKeys.loadFailed);
  }

  @override
  Future<PosReceipt> returnReceipt({
    required int receiptId,
    required int registerId,
    required List<ReturnLineInput> lines,
    required String paymentMethod,
    String? writeoffReason,
    String? comment,
    String? pin,
    required String requestId,
  }) {
    return _call(() async {
      final response = await _dio.post<dynamic>(
        '/cash/receipts/$receiptId/return',
        data: {
          'register_id': registerId,
          'lines': [for (final line in lines) line.toJson()],
          if (writeoffReason != null) 'writeoff_reason': writeoffReason,
          if (comment != null && comment.trim().isNotEmpty)
            'comment': comment.trim(),
          ..._pay(paymentMethod: paymentMethod, pin: pin, requestId: requestId),
        },
      );
      return PosReceipt.fromJson(_asMap(response.data));
    }, fallback: ErrorKeys.saveFailed);
  }

  @override
  Future<PosReceipt> exchangeReceipt({
    required int receiptId,
    required int registerId,
    required List<ReturnLineInput> lines,
    required List<PosSaleLine> newLines,
    required String paymentMethod,
    String? writeoffReason,
    String? comment,
    String? pin,
    required String requestId,
  }) {
    return _call(() async {
      final response = await _dio.post<dynamic>(
        '/cash/receipts/$receiptId/exchange',
        data: {
          'register_id': registerId,
          'lines': [for (final line in lines) line.toJson()],
          'new_lines': [for (final line in newLines) line.toJson()],
          if (writeoffReason != null) 'writeoff_reason': writeoffReason,
          if (comment != null && comment.trim().isNotEmpty)
            'comment': comment.trim(),
          ..._pay(paymentMethod: paymentMethod, pin: pin, requestId: requestId),
        },
      );
      return PosReceipt.fromJson(_asMap(response.data));
    }, fallback: ErrorKeys.saveFailed);
  }

  @override
  Future<WriteoffPage> writeoffs({String? reason, int page = 1}) {
    return _call(() async {
      final response = await _dio.get<dynamic>(
        '/cash/writeoffs',
        queryParameters: {
          'page': page,
          'size': 30,
          if (reason != null && reason.isNotEmpty) 'reason': reason,
        },
      );
      return WriteoffPage.fromJson(_asMap(response.data));
    }, fallback: ErrorKeys.loadFailed);
  }

  @override
  Future<WriteoffDoc> createWriteoff({
    int? registerId,
    required String reason,
    String? comment,
    required List<PosSaleLine> lines,
    String? pin,
  }) {
    return _call(() async {
      final response = await _dio.post<dynamic>(
        '/cash/writeoffs',
        data: {
          if (registerId != null) 'register_id': registerId,
          'reason': reason,
          if (comment != null && comment.trim().isNotEmpty)
            'comment': comment.trim(),
          'lines': [
            for (final line in lines)
              {'product_id': line.productId, 'qty': qtyApi(line.qty)},
          ],
          if (pin != null && pin.isNotEmpty) 'pin': pin,
        },
      );
      return WriteoffDoc.fromJson(_asMap(response.data));
    }, fallback: ErrorKeys.saveFailed);
  }

  @override
  Future<List<HeldCart>> heldCarts({int? registerId}) {
    return _call(() async {
      final response = await _dio.get<dynamic>(
        '/cash/pos/held',
        queryParameters: {if (registerId != null) 'register_id': registerId},
      );
      final data = response.data;
      if (data is! List) return const <HeldCart>[];
      return [
        for (final item in data)
          if (item is Map) HeldCart.fromJson(Map<String, dynamic>.from(item)),
      ];
    }, fallback: ErrorKeys.loadFailed);
  }

  @override
  Future<HeldCart> holdCart({
    required int registerId,
    String? label,
    required List<PosSaleLine> lines,
    double? receiptDiscountPercent,
  }) {
    return _call(() async {
      final response = await _dio.post<dynamic>(
        '/cash/pos/held',
        data: {
          'register_id': registerId,
          if (label != null && label.trim().isNotEmpty) 'label': label.trim(),
          'lines': [for (final line in lines) line.toJson()],
          if (receiptDiscountPercent != null && receiptDiscountPercent > 0)
            'receipt_discount': {'percent': moneyApi(receiptDiscountPercent)},
        },
      );
      return HeldCart.fromJson(_asMap(response.data));
    }, fallback: ErrorKeys.saveFailed);
  }

  @override
  Future<HeldCart> restoreHeld(int id) {
    return _call(() async {
      final response = await _dio.post<dynamic>('/cash/pos/held/$id/restore');
      return HeldCart.fromJson(_asMap(response.data));
    }, fallback: ErrorKeys.saveFailed);
  }

  @override
  Future<void> archiveHeld(int id, {String? pin}) {
    return _call(() async {
      await _dio.post<dynamic>(
        '/cash/pos/held/$id/archive',
        data: {if (pin != null && pin.isNotEmpty) 'pin': pin},
      );
    }, fallback: ErrorKeys.saveFailed);
  }

  @override
  Future<void> cashMove({
    required int registerId,
    required String direction,
    required double amount,
    required String comment,
    String? pin,
    required String requestId,
  }) {
    return _call(() async {
      await _dio.post<dynamic>(
        '/cash/pos/cash-move',
        data: {
          'register_id': registerId,
          'direction': direction,
          'amount': moneyApi(amount),
          'comment': comment.trim(),
          if (pin != null && pin.isNotEmpty) 'pin': pin,
          'request_id': requestId,
        },
      );
    }, fallback: ErrorKeys.saveFailed);
  }
}
