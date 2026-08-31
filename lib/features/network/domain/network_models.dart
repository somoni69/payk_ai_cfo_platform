import 'package:equatable/equatable.dart';

/// Магазин для экрана входа (публичный эндпоинт /auth/stores).
class LoginStore extends Equatable {
  final int id;
  final String name;
  final String? location;

  const LoginStore({required this.id, required this.name, this.location});

  factory LoginStore.fromJson(Map<String, dynamic> json) {
    return LoginStore(
      id: json['id'] is int
          ? json['id'] as int
          : int.tryParse('${json['id']}') ?? 0,
      name: (json['name'] as String?)?.trim() ?? '',
      location: (json['location'] as String?)?.trim(),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'location': location,
  };

  @override
  List<Object?> get props => [id, name, location];
}

/// Магазин сети в панели управления владельца.
class NetworkStore extends Equatable {
  final int id;
  final String name;
  final String? location;
  final bool isActive;
  final int usersCount;

  /// All-time operations (not the period summary count).
  final int operationsCount;

  /// True when the store has operations/products/clients/employees.
  /// Backend deactivates such stores instead of deleting them.
  final bool hasData;

  const NetworkStore({
    required this.id,
    required this.name,
    this.location,
    this.isActive = true,
    this.usersCount = 0,
    this.operationsCount = 0,
    this.hasData = false,
  });

  factory NetworkStore.fromJson(Map<String, dynamic> json) {
    final ops = json['operations_count'] is int
        ? json['operations_count'] as int
        : int.tryParse('${json['operations_count']}') ?? 0;
    return NetworkStore(
      id: json['id'] is int
          ? json['id'] as int
          : int.tryParse('${json['id']}') ?? 0,
      name: (json['name'] as String?)?.trim() ?? '',
      location: (json['location'] as String?)?.trim(),
      isActive: json['is_active'] as bool? ?? true,
      usersCount: json['users_count'] is int
          ? json['users_count'] as int
          : int.tryParse('${json['users_count']}') ?? 0,
      operationsCount: ops,
      hasData: json['has_data'] as bool? ?? ops > 0,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'location': location,
    'is_active': isActive,
    'users_count': usersCount,
    'operations_count': operationsCount,
    'has_data': hasData,
  };

  NetworkStore copyWith({
    int? id,
    String? name,
    String? location,
    bool? isActive,
    int? usersCount,
    int? operationsCount,
    bool? hasData,
  }) {
    return NetworkStore(
      id: id ?? this.id,
      name: name ?? this.name,
      location: location ?? this.location,
      isActive: isActive ?? this.isActive,
      usersCount: usersCount ?? this.usersCount,
      operationsCount: operationsCount ?? this.operationsCount,
      hasData: hasData ?? this.hasData,
    );
  }

  @override
  List<Object?> get props => [
    id,
    name,
    location,
    isActive,
    usersCount,
    operationsCount,
    hasData,
  ];
}

/// Сводная строка финансовых показателей магазина.
class StoreSummaryRow extends Equatable {
  final int storeId;
  final String storeName;
  final bool isActive;
  final double revenue;
  final double expenses;
  final double profit;
  final int operationsCount;

  const StoreSummaryRow({
    required this.storeId,
    required this.storeName,
    this.isActive = true,
    this.revenue = 0.0,
    this.expenses = 0.0,
    this.profit = 0.0,
    this.operationsCount = 0,
  });

  factory StoreSummaryRow.fromJson(Map<String, dynamic> json) {
    final rev = _parseDouble(json['revenue']);
    final exp = _parseDouble(json['expenses']);
    final prof = json['profit'] != null
        ? _parseDouble(json['profit'])
        : (rev - exp);

    return StoreSummaryRow(
      storeId: json['store_id'] is int
          ? json['store_id'] as int
          : int.tryParse('${json['store_id']}') ?? 0,
      storeName: (json['store_name'] as String?)?.trim() ?? '',
      isActive: json['is_active'] as bool? ?? true,
      revenue: rev,
      expenses: exp,
      profit: prof,
      operationsCount: json['operations_count'] is int
          ? json['operations_count'] as int
          : int.tryParse('${json['operations_count']}') ?? 0,
    );
  }

  static double _parseDouble(dynamic val) {
    if (val is num) return val.toDouble();
    if (val is String) return double.tryParse(val) ?? 0.0;
    return 0.0;
  }

  @override
  List<Object?> get props => [
    storeId,
    storeName,
    isActive,
    revenue,
    expenses,
    profit,
    operationsCount,
  ];
}

/// Данные для создания нового магазина сети.
class StoreCreateInput {
  final String name;
  final String? location;
  final String? directorUsername;
  final String? directorPassword;
  final String? directorFullName;

  const StoreCreateInput({
    required this.name,
    this.location,
    this.directorUsername,
    this.directorPassword,
    this.directorFullName,
  });

  Map<String, dynamic> toJson() => {
    'name': name.trim(),
    if (location != null && location!.trim().isNotEmpty)
      'location': location!.trim(),
    if (directorUsername != null && directorUsername!.trim().isNotEmpty)
      'director_username': directorUsername!.trim(),
    if (directorPassword != null && directorPassword!.trim().isNotEmpty)
      'director_password': directorPassword!.trim(),
    if (directorFullName != null && directorFullName!.trim().isNotEmpty)
      'director_full_name': directorFullName!.trim(),
  };
}

/// Выбранный действующий магазин для сессии владельца.
class ActingStore extends Equatable {
  final int id;
  final String name;

  const ActingStore({required this.id, required this.name});

  factory ActingStore.fromJson(Map<String, dynamic> json) {
    return ActingStore(
      id: json['id'] is int
          ? json['id'] as int
          : int.tryParse('${json['id']}') ?? 0,
      name: (json['name'] as String?)?.trim() ?? '',
    );
  }

  Map<String, dynamic> toJson() => {'id': id, 'name': name};

  @override
  List<Object?> get props => [id, name];
}

/// Результат удаления или отключения магазина.
class StoreDeleteResult extends Equatable {
  final bool deleted;
  final bool deactivated;
  final String message;

  const StoreDeleteResult({
    required this.deleted,
    required this.deactivated,
    required this.message,
  });

  factory StoreDeleteResult.fromJson(Map<String, dynamic> json) {
    return StoreDeleteResult(
      deleted: json['deleted'] as bool? ?? false,
      deactivated: json['deactivated'] as bool? ?? false,
      message: (json['message'] as String?)?.trim() ?? '',
    );
  }

  @override
  List<Object?> get props => [deleted, deactivated, message];
}
