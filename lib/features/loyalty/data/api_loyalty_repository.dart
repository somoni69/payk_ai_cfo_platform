import 'package:dio/dio.dart';

// ignore_for_file: use_null_aware_elements

import '../../../core/error/app_failure.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_error_detail.dart';
import '../../../core/network/user_facing_error.dart';
import '../domain/loyalty_models.dart';
import '../domain/loyalty_repository.dart';

class ApiLoyaltyRepository implements LoyaltyRepository {
  ApiLoyaltyRepository({Dio? dio}) : _dio = dio ?? ApiClient().dio;

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

  Map<String, dynamic> _map(dynamic data) =>
      data is Map ? Map<String, dynamic>.from(data) : <String, dynamic>{};

  @override
  Future<LoyaltyProgramState> program() => _call(() async {
    final response = await _dio.get<dynamic>('/loyalty/program');
    return LoyaltyProgramState.fromJson(_map(response.data));
  }, fallback: ErrorKeys.loadFailed);

  @override
  Future<LoyaltyProgram> createProgram({
    required String title,
    required String slug,
  }) => _call(() async {
    final response = await _dio.post<dynamic>(
      '/loyalty/program',
      data: {'title': title.trim(), 'slug': slug.trim()},
    );
    return LoyaltyProgram.fromJson(_map(response.data));
  }, fallback: ErrorKeys.saveFailed);

  @override
  Future<LoyaltyProgram> updateProgram({String? title, bool? enabled}) =>
      _call(() async {
        final response = await _dio.patch<dynamic>(
          '/loyalty/program',
          data: {
            if (title != null) 'title': title.trim(),
            if (enabled != null) 'enabled': enabled,
          },
        );
        return LoyaltyProgram.fromJson(_map(response.data));
      }, fallback: ErrorKeys.saveFailed);

  @override
  Future<LoyaltyTerminal> createTerminal({
    required String name,
    required String formatCode,
  }) => _call(() async {
    final response = await _dio.post<dynamic>(
      '/loyalty/terminals',
      data: {'name': name.trim(), 'format_code': formatCode},
    );
    return LoyaltyTerminal.fromJson(_map(response.data));
  }, fallback: ErrorKeys.saveFailed);

  @override
  Future<LoyaltyTerminal> updateTerminal(
    int id, {
    String? name,
    String? formatCode,
    bool? isActive,
    bool? coinEnabled,
  }) => _call(() async {
    final response = await _dio.patch<dynamic>(
      '/loyalty/terminals/$id',
      data: {
        if (name != null) 'name': name.trim(),
        if (formatCode != null) 'format_code': formatCode,
        if (isActive != null) 'is_active': isActive,
        if (coinEnabled != null) 'coin_enabled': coinEnabled,
      },
    );
    return LoyaltyTerminal.fromJson(_map(response.data));
  }, fallback: ErrorKeys.saveFailed);

  @override
  Future<LoyaltyPosState> identify({
    required int terminalId,
    required String code,
  }) => _call(() async {
    final response = await _dio.post<dynamic>(
      '/loyalty/pos/identify',
      data: {'terminal_id': terminalId, 'code': code.trim()},
    );
    return LoyaltyPosState.fromJson(_map(response.data));
  }, fallback: ErrorKeys.saveFailed);

  @override
  Future<LoyaltyPosState> price(
    int previewId, {
    required String amount,
    required String billExtId,
    String? excludedAmount,
    String? cardAmount,
    bool wholesale = false,
  }) => _call(() async {
    final response = await _dio.put<dynamic>(
      '/loyalty/pos/previews/$previewId',
      data: {
        'amount': amount,
        'bill_ext_id': billExtId.trim(),
        if (excludedAmount != null && excludedAmount.isNotEmpty)
          'excluded_amount': excludedAmount,
        if (cardAmount != null && cardAmount.isNotEmpty)
          'card_amount': cardAmount,
        'wholesale': wholesale,
      },
    );
    return LoyaltyPosState.fromJson(_map(response.data));
  }, fallback: ErrorKeys.saveFailed);

  @override
  Future<LoyaltyPosState> preview(int id) => _call(() async {
    final response = await _dio.get<dynamic>('/loyalty/pos/previews/$id');
    return LoyaltyPosState.fromJson(_map(response.data));
  }, fallback: ErrorKeys.loadFailed);

  @override
  Future<LoyaltyPosState> suggestCoin(int id) => _call(() async {
    final response = await _dio.post<dynamic>(
      '/loyalty/pos/previews/$id/suggest-coin10',
    );
    return LoyaltyPosState.fromJson(_map(response.data));
  }, fallback: ErrorKeys.saveFailed);

  @override
  Future<void> cancelPreview(int id) => _call(() async {
    await _dio.post<dynamic>('/loyalty/pos/previews/$id/cancel');
  }, fallback: ErrorKeys.saveFailed);

  @override
  Future<Map<String, dynamic>> commit(
    int id, {
    required String key,
    required double expectedCash,
    required double expectedCoupon,
  }) => _call(() async {
    final response = await _dio.post<dynamic>(
      '/loyalty/pos/previews/$id/commit',
      data: {
        'expected_cash_to_pay': expectedCash.toStringAsFixed(2),
        'expected_coupon': expectedCoupon.toStringAsFixed(2),
      },
      options: Options(headers: {'Idempotency-Key': key}),
    );
    return _map(response.data);
  }, fallback: ErrorKeys.saveFailed);

  @override
  Future<Map<String, dynamic>> returnBill({
    required int terminalId,
    required String billExtId,
    String? amount,
    String? note,
  }) => _call(() async {
    final response = await _dio.post<dynamic>(
      '/loyalty/pos/returns',
      data: {
        'terminal_id': terminalId,
        'bill_ext_id': billExtId.trim(),
        if (amount != null && amount.isNotEmpty) 'amount': amount,
        if (note != null && note.trim().isNotEmpty) 'note': note.trim(),
      },
    );
    return _map(response.data);
  }, fallback: ErrorKeys.saveFailed);

  @override
  Future<Map<String, dynamic>> startSms({
    required int terminalId,
    required String phone,
  }) => _call(() async {
    final response = await _dio.post<dynamic>(
      '/loyalty/pos/sms/start',
      data: {'terminal_id': terminalId, 'phone': phone.trim()},
    );
    return _map(response.data);
  }, fallback: ErrorKeys.saveFailed);

  @override
  Future<LoyaltyPosState> confirmSms({
    required int terminalId,
    required String phone,
    required String code,
  }) => _call(() async {
    final response = await _dio.post<dynamic>(
      '/loyalty/pos/sms/confirm',
      data: {
        'terminal_id': terminalId,
        'phone': phone.trim(),
        'code': code.trim(),
      },
    );
    return LoyaltyPosState.fromJson(_map(response.data));
  }, fallback: ErrorKeys.saveFailed);

  @override
  Future<void> lateAccrual({
    required int terminalId,
    required String phone,
    required String billExtId,
    required String amount,
    required String day,
  }) => _call(() async {
    await _dio.post<dynamic>(
      '/loyalty/pos/late',
      data: {
        'terminal_id': terminalId,
        'phone': phone.trim(),
        'bill_ext_id': billExtId.trim(),
        'amount': amount,
        'day': day,
      },
    );
  }, fallback: ErrorKeys.saveFailed);

  @override
  Future<List<LoyaltyBillRow>> bills({int? terminalId}) => _call(() async {
    final response = await _dio.get<dynamic>(
      '/loyalty/pos/bills',
      queryParameters: {
        'limit': 20,
        if (terminalId != null) 'terminal_id': terminalId,
      },
    );
    final data = response.data;
    if (data is! List) return const [];
    return [
      for (final item in data)
        if (item is Map)
          LoyaltyBillRow.fromJson(Map<String, dynamic>.from(item)),
    ];
  }, fallback: ErrorKeys.loadFailed);

  @override
  Future<LoyaltyMembersPage> members(MemberQuery query) => _call(() async {
    final response = await _dio.get<dynamic>(
      '/loyalty/members',
      queryParameters: {...query.filters(), 'page': query.page, 'size': 30},
    );
    return LoyaltyMembersPage.fromJson(_map(response.data));
  }, fallback: ErrorKeys.loadFailed);

  @override
  Future<LoyaltyMemberCard> member(int id) => _call(() async {
    final response = await _dio.get<dynamic>('/loyalty/members/$id');
    return LoyaltyMemberCard.fromJson(_map(response.data));
  }, fallback: ErrorKeys.loadFailed);

  @override
  Future<double> adjustMember(
    int id, {
    required String amount,
    required String reason,
  }) => _call(() async {
    final response = await _dio.post<dynamic>(
      '/loyalty/members/$id/adjust',
      data: {'amount': amount, 'reason': reason.trim()},
    );
    return jsonNum(_map(response.data)['balance_after']);
  }, fallback: ErrorKeys.saveFailed);

  @override
  Future<void> setWholesale(
    int id, {
    required String action,
    required String reason,
  }) => _call(() async {
    await _dio.post<dynamic>(
      '/loyalty/members/$id/wholesale',
      data: {'action': action, 'reason': reason.trim()},
    );
  }, fallback: ErrorKeys.saveFailed);

  @override
  Future<List<LoyaltyBirthday>> birthdays({int days = 30, int? status}) =>
      _call(() async {
        final response = await _dio.get<dynamic>(
          '/loyalty/birthdays',
          queryParameters: {'days': days, if (status != null) 'status': status},
        );
        final data = response.data;
        final raw = data is Map ? data['items'] : data;
        if (raw is! List) return const [];
        return [
          for (final item in raw)
            if (item is Map)
              LoyaltyBirthday.fromJson(Map<String, dynamic>.from(item)),
        ];
      }, fallback: ErrorKeys.loadFailed);

  @override
  Future<List<LoyaltyMessageRow>> messages({int page = 1}) => _call(() async {
    final response = await _dio.get<dynamic>(
      '/loyalty/messages',
      queryParameters: {'page': page, 'size': 40},
    );
    final raw = _map(response.data)['items'];
    if (raw is! List) return const [];
    return [
      for (final item in raw)
        if (item is Map)
          LoyaltyMessageRow.fromJson(Map<String, dynamic>.from(item)),
    ];
  }, fallback: ErrorKeys.loadFailed);

  @override
  Future<LoyaltyMessageSummary> messageSummary() => _call(() async {
    final response = await _dio.get<dynamic>('/loyalty/messages/summary');
    return LoyaltyMessageSummary.fromJson(_map(response.data));
  }, fallback: ErrorKeys.loadFailed);

  @override
  Future<LoyaltyDashboard> dashboard() => _call(() async {
    final response = await _dio.get<dynamic>('/loyalty/reports/dashboard');
    return LoyaltyDashboard.fromJson(_map(response.data));
  }, fallback: ErrorKeys.loadFailed);

  @override
  Future<List<IdentifiedSlice>> identified() => _call(() async {
    final response = await _dio.get<dynamic>('/loyalty/reports/identified');
    final byFormat = jsonMap(_map(response.data)['by_format']);
    return [
      for (final entry in byFormat.entries)
        IdentifiedSlice.fromJson(jsonMap(entry.value), entry.key),
    ];
  }, fallback: ErrorKeys.loadFailed);

  @override
  Future<BroadcastPreview> previewBroadcast({
    required Map<String, String> filters,
    required String textTj,
    required String textRu,
  }) => _call(() async {
    final response = await _dio.post<dynamic>(
      '/loyalty/broadcasts/preview',
      data: {
        'filters': filters,
        'text_tj': textTj.trim(),
        'text_ru': textRu.trim(),
      },
    );
    return BroadcastPreview.fromJson(_map(response.data));
  }, fallback: ErrorKeys.saveFailed);

  @override
  Future<void> sendBroadcast({
    required Map<String, String> filters,
    required String textTj,
    required String textRu,
    required String clientKey,
  }) => _call(() async {
    await _dio.post<dynamic>(
      '/loyalty/broadcasts',
      data: {
        'filters': filters,
        'text_tj': textTj.trim(),
        'text_ru': textRu.trim(),
        'client_key': clientKey,
      },
    );
  }, fallback: ErrorKeys.saveFailed);
}
