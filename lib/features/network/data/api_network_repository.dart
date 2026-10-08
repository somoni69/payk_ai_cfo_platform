import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/user_facing_error.dart';
import '../../../core/security/secure_storage_provider.dart';
import '../domain/network_models.dart';
import '../domain/network_repository.dart';

class ApiNetworkRepository implements NetworkRepository {
  final ApiClient _apiClient;
  final FlutterSecureStorage _storage;

  static const String _actingStoreKey = 'payk.acting_store';

  ApiNetworkRepository({ApiClient? apiClient, FlutterSecureStorage? storage})
    : _apiClient = apiClient ?? ApiClient(),
      _storage = storage ?? AppSecureStorage.instance;

  @override
  Future<List<LoginStore>> fetchLoginStores() async {
    try {
      final response = await _apiClient.dio.get<dynamic>('/auth/stores');
      final list = response.data is List ? response.data as List : const [];
      return list
          .whereType<Map>()
          .map((m) => LoginStore.fromJson(Map<String, dynamic>.from(m)))
          .toList(growable: false);
    } catch (_) {
      return const [];
    }
  }

  @override
  Future<List<NetworkStore>> fetchStores() async {
    try {
      final response = await _apiClient.dio.get<dynamic>('/network/stores');
      final list = response.data is List ? response.data as List : const [];
      return list
          .whereType<Map>()
          .map((m) => NetworkStore.fromJson(Map<String, dynamic>.from(m)))
          .toList(growable: false);
    } on DioException catch (e) {
      throw Exception(userFacingError(e, fallback: ErrorKeys.loadFailed));
    } catch (_) {
      throw Exception(ErrorKeys.loadFailed);
    }
  }

  @override
  Future<List<StoreSummaryRow>> fetchSummary({
    DateTime? dateFrom,
    DateTime? dateTo,
  }) async {
    try {
      final queryParams = <String, dynamic>{};
      if (dateFrom != null) {
        queryParams['date_from'] =
            '${dateFrom.year}-${dateFrom.month.toString().padLeft(2, '0')}-${dateFrom.day.toString().padLeft(2, '0')}';
      }
      if (dateTo != null) {
        queryParams['date_to'] =
            '${dateTo.year}-${dateTo.month.toString().padLeft(2, '0')}-${dateTo.day.toString().padLeft(2, '0')}';
      }

      final response = await _apiClient.dio.get<dynamic>(
        '/network/summary',
        queryParameters: queryParams,
      );
      final list = response.data is List ? response.data as List : const [];
      return list
          .whereType<Map>()
          .map((m) => StoreSummaryRow.fromJson(Map<String, dynamic>.from(m)))
          .toList(growable: false);
    } on DioException catch (e) {
      throw Exception(userFacingError(e, fallback: ErrorKeys.loadFailed));
    } catch (_) {
      throw Exception(ErrorKeys.loadFailed);
    }
  }

  @override
  Future<NetworkStore> createStore(StoreCreateInput input) async {
    try {
      final response = await _apiClient.dio.post<dynamic>(
        '/network/stores',
        data: input.toJson(),
      );
      final data = response.data is Map
          ? Map<String, dynamic>.from(response.data as Map)
          : <String, dynamic>{};
      return NetworkStore.fromJson(data);
    } on DioException catch (e) {
      throw Exception(userFacingError(e, fallback: ErrorKeys.saveFailed));
    } catch (_) {
      throw Exception(ErrorKeys.saveFailed);
    }
  }

  @override
  Future<NetworkStore> updateStore(
    int id, {
    String? name,
    String? location,
    bool? isActive,
    List<int>? moduleIds,
  }) async {
    try {
      final response = await _apiClient.dio.patch<dynamic>(
        '/network/stores/$id',
        data: {
          'name': ?name?.trim(),
          'location': ?location?.trim(),
          'is_active': ?isActive,
          'module_ids': ?moduleIds,
        },
      );
      final data = response.data is Map
          ? Map<String, dynamic>.from(response.data as Map)
          : <String, dynamic>{};
      return NetworkStore.fromJson(data);
    } on DioException catch (e) {
      throw Exception(userFacingError(e, fallback: ErrorKeys.saveFailed));
    } catch (_) {
      throw Exception(ErrorKeys.saveFailed);
    }
  }

  @override
  Future<StoreDeleteResult> deleteStore(int id) async {
    try {
      final response = await _apiClient.dio.delete<dynamic>(
        '/network/stores/$id',
      );
      final data = response.data is Map
          ? Map<String, dynamic>.from(response.data as Map)
          : <String, dynamic>{};
      return StoreDeleteResult.fromJson(data);
    } on DioException catch (e) {
      throw Exception(userFacingError(e, fallback: ErrorKeys.saveFailed));
    } catch (_) {
      throw Exception(ErrorKeys.saveFailed);
    }
  }

  @override
  Future<ModuleCatalog> fetchModuleCatalog() async {
    try {
      final response = await _apiClient.dio.get<dynamic>(
        '/network/modules/catalog',
      );
      final data = response.data is Map
          ? Map<String, dynamic>.from(response.data as Map)
          : <String, dynamic>{};
      final catalog = ModuleCatalog.fromJson(data);
      return catalog.sections.isEmpty ? ModuleCatalog.fallback : catalog;
    } on DioException catch (e) {
      throw Exception(userFacingError(e, fallback: ErrorKeys.loadFailed));
    } catch (_) {
      throw Exception(ErrorKeys.loadFailed);
    }
  }

  @override
  Future<List<ClientModule>> fetchModules() async {
    try {
      final response = await _apiClient.dio.get<dynamic>('/network/modules');
      final list = response.data is List ? response.data as List : const [];
      return list
          .whereType<Map>()
          .map((item) => ClientModule.fromJson(Map<String, dynamic>.from(item)))
          .toList(growable: false);
    } on DioException catch (e) {
      throw Exception(userFacingError(e, fallback: ErrorKeys.loadFailed));
    } catch (_) {
      throw Exception(ErrorKeys.loadFailed);
    }
  }

  @override
  Future<ClientModule> saveModule({
    int? id,
    required String name,
    String? description,
    required List<String> sections,
  }) async {
    try {
      final payload = {
        'name': name.trim(),
        'description': description?.trim(),
        'sections': sections,
      };
      final response = id == null
          ? await _apiClient.dio.post<dynamic>(
              '/network/modules',
              data: payload,
            )
          : await _apiClient.dio.patch<dynamic>(
              '/network/modules/$id',
              data: payload,
            );
      final data = response.data is Map
          ? Map<String, dynamic>.from(response.data as Map)
          : <String, dynamic>{};
      return ClientModule.fromJson(data);
    } on DioException catch (e) {
      throw Exception(userFacingError(e, fallback: ErrorKeys.saveFailed));
    } catch (_) {
      throw Exception(ErrorKeys.saveFailed);
    }
  }

  StoreChannels _channelsFrom(dynamic raw) {
    final data = raw is Map
        ? Map<String, dynamic>.from(raw)
        : <String, dynamic>{};
    return StoreChannels.fromJson(data);
  }

  @override
  Future<StoreChannels> fetchStoreChannels(int storeId) async {
    try {
      final response = await _apiClient.dio.get<dynamic>(
        '/network/stores/$storeId/channels',
      );
      return _channelsFrom(response.data);
    } on DioException catch (e) {
      throw Exception(userFacingError(e, fallback: ErrorKeys.loadFailed));
    } catch (_) {
      throw Exception(ErrorKeys.loadFailed);
    }
  }

  @override
  Future<StoreChannels> connectFacebookChannel(
    int storeId,
    String token,
  ) async {
    return _putChannel(storeId, 'facebook', {'token': token.trim()});
  }

  @override
  Future<StoreChannels> connectInstagramChannel(
    int storeId, {
    String? token,
  }) async {
    final trimmed = token?.trim();
    return _putChannel(storeId, 'instagram', {
      'token': trimmed == null || trimmed.isEmpty ? null : trimmed,
    });
  }

  @override
  Future<StoreChannels> connectWhatsAppChannel(
    int storeId, {
    required String phoneId,
    required String token,
    String? businessId,
  }) async {
    final business = businessId?.trim();
    return _putChannel(storeId, 'whatsapp', {
      'phone_id': phoneId.trim(),
      'token': token.trim(),
      'business_id': business == null || business.isEmpty ? null : business,
    });
  }

  Future<StoreChannels> _putChannel(
    int storeId,
    String kind,
    Map<String, dynamic> data,
  ) async {
    try {
      final response = await _apiClient.dio.put<dynamic>(
        '/network/stores/$storeId/channels/$kind',
        data: data,
      );
      return _channelsFrom(response.data);
    } on DioException catch (e) {
      throw Exception(userFacingError(e, fallback: ErrorKeys.saveFailed));
    } catch (_) {
      throw Exception(ErrorKeys.saveFailed);
    }
  }

  @override
  Future<StoreChannels> checkStoreChannel(int storeId, String kind) async {
    try {
      final response = await _apiClient.dio.post<dynamic>(
        '/network/stores/$storeId/channels/$kind/check',
      );
      return _channelsFrom(response.data);
    } on DioException catch (e) {
      throw Exception(userFacingError(e, fallback: ErrorKeys.loadFailed));
    } catch (_) {
      throw Exception(ErrorKeys.loadFailed);
    }
  }

  UmnicoState _umnicoFrom(dynamic raw) {
    final data = raw is Map
        ? Map<String, dynamic>.from(raw)
        : <String, dynamic>{};
    return UmnicoState.fromJson(data);
  }

  @override
  Future<UmnicoState> fetchUmnico() async {
    try {
      final response = await _apiClient.dio.get<dynamic>('/network/umnico');
      return _umnicoFrom(response.data);
    } on DioException catch (e) {
      throw Exception(userFacingError(e, fallback: ErrorKeys.loadFailed));
    } catch (_) {
      throw Exception(ErrorKeys.loadFailed);
    }
  }

  @override
  Future<UmnicoState> connectUmnico({
    required String login,
    required String password,
  }) async {
    try {
      final response = await _apiClient.dio.put<dynamic>(
        '/network/umnico',
        data: {'login': login.trim(), 'password': password},
      );
      return _umnicoFrom(response.data);
    } on DioException catch (e) {
      throw Exception(userFacingError(e, fallback: ErrorKeys.saveFailed));
    } catch (_) {
      throw Exception(ErrorKeys.saveFailed);
    }
  }

  @override
  Future<UmnicoState> disconnectUmnico() async {
    try {
      final response = await _apiClient.dio.delete<dynamic>('/network/umnico');
      return _umnicoFrom(response.data);
    } on DioException catch (e) {
      throw Exception(userFacingError(e, fallback: ErrorKeys.saveFailed));
    } catch (_) {
      throw Exception(ErrorKeys.saveFailed);
    }
  }

  @override
  Future<StoreChannels> connectChannelViaUmnico(
    int storeId,
    String kind,
    String integrationId,
  ) async {
    try {
      final response = await _apiClient.dio.put<dynamic>(
        '/network/stores/$storeId/channels/$kind/umnico',
        data: {'integration_id': integrationId},
      );
      return _channelsFrom(response.data);
    } on DioException catch (e) {
      throw Exception(userFacingError(e, fallback: ErrorKeys.saveFailed));
    } catch (_) {
      throw Exception(ErrorKeys.saveFailed);
    }
  }

  @override
  Future<StoreChannels> disconnectStoreChannel(int storeId, String kind) async {
    try {
      final response = await _apiClient.dio.delete<dynamic>(
        '/network/stores/$storeId/channels/$kind',
      );
      return _channelsFrom(response.data);
    } on DioException catch (e) {
      throw Exception(userFacingError(e, fallback: ErrorKeys.saveFailed));
    } catch (_) {
      throw Exception(ErrorKeys.saveFailed);
    }
  }

  @override
  Future<void> deleteModule(int id) async {
    try {
      await _apiClient.dio.delete<dynamic>('/network/modules/$id');
    } on DioException catch (e) {
      throw Exception(userFacingError(e, fallback: ErrorKeys.saveFailed));
    } catch (_) {
      throw Exception(ErrorKeys.saveFailed);
    }
  }

  @override
  Future<void> resetDirectorPassword(
    int id, {
    String? username,
    required String password,
  }) async {
    try {
      await _apiClient.dio.post<dynamic>(
        '/network/stores/$id/director-password',
        data: {
          if (username != null && username.trim().isNotEmpty)
            'username': username.trim(),
          'password': password.trim(),
        },
      );
    } on DioException catch (e) {
      throw Exception(userFacingError(e, fallback: ErrorKeys.saveFailed));
    } catch (_) {
      throw Exception(ErrorKeys.saveFailed);
    }
  }

  @override
  Future<ActingStore> enterStore(int storeId) async {
    try {
      final response = await _apiClient.dio.post<dynamic>(
        '/network/enter/$storeId',
      );
      final data = response.data is Map
          ? Map<String, dynamic>.from(response.data as Map)
          : <String, dynamic>{};

      final accessToken = data['access_token'] as String?;
      final refreshToken = data['refresh_token'] as String?;
      if (accessToken != null && accessToken.isNotEmpty) {
        await _apiClient.saveAccessToken(accessToken);
      }
      if (refreshToken != null && refreshToken.isNotEmpty) {
        await _apiClient.saveRefreshToken(refreshToken);
      }

      final storeMap = data['store'] is Map
          ? Map<String, dynamic>.from(data['store'] as Map)
          : <String, dynamic>{'id': storeId, 'name': 'Store #$storeId'};
      final acting = ActingStore.fromJson(storeMap);

      await _storage.write(
        key: _actingStoreKey,
        value: jsonEncode(acting.toJson()),
      );
      return acting;
    } on DioException catch (e) {
      throw Exception(userFacingError(e, fallback: ErrorKeys.saveFailed));
    } catch (_) {
      throw Exception(ErrorKeys.saveFailed);
    }
  }

  @override
  Future<void> leaveStore() async {
    try {
      final response = await _apiClient.dio.post<dynamic>('/network/leave');
      final data = response.data is Map
          ? Map<String, dynamic>.from(response.data as Map)
          : <String, dynamic>{};

      final accessToken = data['access_token'] as String?;
      final refreshToken = data['refresh_token'] as String?;
      if (accessToken != null && accessToken.isNotEmpty) {
        await _apiClient.saveAccessToken(accessToken);
      }
      if (refreshToken != null && refreshToken.isNotEmpty) {
        await _apiClient.saveRefreshToken(refreshToken);
      }

      await _storage.delete(key: _actingStoreKey);
    } on DioException catch (e) {
      throw Exception(userFacingError(e, fallback: ErrorKeys.saveFailed));
    } catch (_) {
      throw Exception(ErrorKeys.saveFailed);
    }
  }

  @override
  Future<ActingStore?> getActingStore() async {
    try {
      final raw = await _storage.read(key: _actingStoreKey);
      if (raw == null || raw.isEmpty) return null;
      final map = jsonDecode(raw);
      if (map is Map) {
        return ActingStore.fromJson(Map<String, dynamic>.from(map));
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> clearActingStore() async {
    try {
      await _storage.delete(key: _actingStoreKey);
    } catch (_) {}
  }
}
