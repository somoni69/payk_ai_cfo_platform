import 'package:dio/dio.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/user_facing_error.dart';
import '../../fin_ops/domain/fin_ops_models.dart';
import '../domain/playroom_models.dart';
import '../domain/playroom_repository.dart';
import '../../../core/error/app_failure.dart';

class ApiPlayroomRepository implements PlayroomRepository {
  ApiPlayroomRepository({Dio? dio}) : _dio = dio ?? ApiClient().dio;

  final Dio _dio;

  @override
  Future<PlayroomTariff> getTariff() async {
    try {
      final response = await _dio.get<Map<String, dynamic>>('/playroom/tariff');
      return PlayroomTariff.fromJson(response.data ?? const {});
    } catch (error) {
      throw RepositoryFailure(
        userFacingError(error, fallback: ErrorKeys.loadFailed),
      );
    }
  }

  @override
  Future<PlayroomStats> getStats() async {
    try {
      final response = await _dio.get<Map<String, dynamic>>('/playroom/stats');
      return PlayroomStats.fromJson(response.data ?? const {});
    } catch (error) {
      throw RepositoryFailure(
        userFacingError(error, fallback: ErrorKeys.loadFailed),
      );
    }
  }

  @override
  Future<List<PlayroomOrder>> listOrders({
    String? day,
    bool active = false,
    String? query,
  }) async {
    try {
      final q = query?.trim();
      final response = await _dio.get<List<dynamic>>(
        '/playroom/orders',
        queryParameters: {
          if (day != null && day.isNotEmpty && (q == null || q.isEmpty))
            'day': day,
          if (active) 'active': true,
          if (q != null && q.isNotEmpty) 'q': q,
        },
      );
      return [
        for (final item in response.data ?? const <dynamic>[])
          if (item is Map)
            PlayroomOrder.fromJson(Map<String, dynamic>.from(item)),
      ];
    } catch (error) {
      throw RepositoryFailure(
        userFacingError(error, fallback: ErrorKeys.loadFailed),
      );
    }
  }

  @override
  Future<PlayroomOrder> createOrder(PlayroomOrderInput input) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '/playroom/orders',
        data: input.toJson(),
      );
      return PlayroomOrder.fromJson(response.data ?? const {});
    } catch (error) {
      throw RepositoryFailure(
        userFacingError(error, fallback: ErrorKeys.saveFailed),
      );
    }
  }

  @override
  Future<PlayroomOrder> extendOrder(int id, PlayroomExtendInput input) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '/playroom/orders/$id/extend',
        data: input.toJson(),
      );
      return PlayroomOrder.fromJson(response.data ?? const {});
    } catch (error) {
      throw RepositoryFailure(
        userFacingError(error, fallback: ErrorKeys.saveFailed),
      );
    }
  }

  @override
  Future<PlayroomOrder> closeOrder(int id) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '/playroom/orders/$id/close',
      );
      return PlayroomOrder.fromJson(response.data ?? const {});
    } catch (error) {
      throw RepositoryFailure(
        userFacingError(error, fallback: ErrorKeys.saveFailed),
      );
    }
  }

  @override
  Future<PlayroomOrder> cancelOrder(int id) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '/playroom/orders/$id/cancel',
      );
      return PlayroomOrder.fromJson(response.data ?? const {});
    } catch (error) {
      throw RepositoryFailure(
        userFacingError(error, fallback: ErrorKeys.saveFailed),
      );
    }
  }

  @override
  Future<List<int>> downloadTicketPdf(int id, {required String format}) async {
    try {
      final response = await _dio.get<List<int>>(
        '/playroom/orders/$id/ticket.pdf',
        queryParameters: {'format': format},
        options: Options(responseType: ResponseType.bytes),
      );
      return response.data ?? const <int>[];
    } catch (error) {
      throw RepositoryFailure(
        userFacingError(error, fallback: ErrorKeys.loadFailed),
      );
    }
  }

  @override
  Future<List<PlayroomRegister>> getRegisters() async {
    try {
      final response = await _dio.get<List<dynamic>>('/cash/registers');
      return [
        for (final item in response.data ?? const <dynamic>[])
          if (item is Map)
            PlayroomRegister.fromJson(Map<String, dynamic>.from(item)),
      ];
    } catch (error) {
      throw RepositoryFailure(
        userFacingError(error, fallback: ErrorKeys.loadFailed),
      );
    }
  }

  @override
  Future<List<PlayroomOpenShift>> getOpenShifts() async {
    try {
      final response = await _dio.get<List<dynamic>>(
        '/cash/shifts',
        queryParameters: {'only_open': true},
      );
      return [
        for (final item in response.data ?? const <dynamic>[])
          if (item is Map)
            PlayroomOpenShift.fromJson(Map<String, dynamic>.from(item)),
      ];
    } catch (error) {
      throw RepositoryFailure(
        userFacingError(error, fallback: ErrorKeys.loadFailed),
      );
    }
  }

  @override
  Future<List<BankAccount>> getBanks() async {
    try {
      final response = await _dio.get<List<dynamic>>('/finance-ops/banks');
      return [
        for (final item in response.data ?? const <dynamic>[])
          if (item is Map)
            BankAccount.fromJson(Map<String, dynamic>.from(item)),
      ].where((bank) => bank.isActive).toList();
    } catch (error) {
      throw RepositoryFailure(
        userFacingError(error, fallback: ErrorKeys.loadFailed),
      );
    }
  }
}
