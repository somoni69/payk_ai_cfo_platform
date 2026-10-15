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

/// One account the server could not tell apart at login (`409 choose_store`).
class LoginChoice extends Equatable {
  final int? id;
  final String name;
  final String? location;
  final bool owner;

  const LoginChoice({
    required this.name,
    this.id,
    this.location,
    this.owner = false,
  });

  factory LoginChoice.fromJson(Map<String, dynamic> json) {
    return LoginChoice(
      id: json['id'] is int ? json['id'] as int : int.tryParse('${json['id']}'),
      name: (json['name'] as String?)?.trim() ?? '',
      location: (json['location'] as String?)?.trim(),
      owner: json['owner'] == true,
    );
  }

  @override
  List<Object?> get props => [id, name, location, owner];
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

  /// Модули, подключённые магазину.
  final List<ModuleBrief> modules;

  /// Подключённые каналы Meta: facebook, instagram, whatsapp.
  final List<String> channels;

  const NetworkStore({
    required this.id,
    required this.name,
    this.location,
    this.isActive = true,
    this.usersCount = 0,
    this.operationsCount = 0,
    this.hasData = false,
    this.modules = const [],
    this.channels = const [],
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
      modules: (json['modules'] as List? ?? const [])
          .whereType<Map>()
          .map((item) => ModuleBrief.fromJson(Map<String, dynamic>.from(item)))
          .toList(growable: false),
      channels: (json['channels'] as List? ?? const [])
          .map((item) => item.toString())
          .toList(growable: false),
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
    'modules': modules.map((item) => item.toJson()).toList(),
    'channels': channels,
  };

  NetworkStore copyWith({
    int? id,
    String? name,
    String? location,
    bool? isActive,
    int? usersCount,
    int? operationsCount,
    bool? hasData,
    List<ModuleBrief>? modules,
    List<String>? channels,
  }) {
    return NetworkStore(
      id: id ?? this.id,
      name: name ?? this.name,
      location: location ?? this.location,
      isActive: isActive ?? this.isActive,
      usersCount: usersCount ?? this.usersCount,
      operationsCount: operationsCount ?? this.operationsCount,
      hasData: hasData ?? this.hasData,
      modules: modules ?? this.modules,
      channels: channels ?? this.channels,
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
    modules,
    channels,
  ];
}

class ModuleBrief extends Equatable {
  final int id;
  final String name;

  const ModuleBrief({required this.id, required this.name});

  factory ModuleBrief.fromJson(Map<String, dynamic> json) {
    return ModuleBrief(
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

/// Набор разделов меню, который владелец подключает клиенту.
class ClientModule extends Equatable {
  final int id;
  final String name;
  final String? description;
  final List<String> sections;
  final List<ModuleBrief> stores;

  const ClientModule({
    required this.id,
    required this.name,
    this.description,
    this.sections = const [],
    this.stores = const [],
  });

  factory ClientModule.fromJson(Map<String, dynamic> json) {
    return ClientModule(
      id: json['id'] is int
          ? json['id'] as int
          : int.tryParse('${json['id']}') ?? 0,
      name: (json['name'] as String?)?.trim() ?? '',
      description: (json['description'] as String?)?.trim(),
      sections: (json['sections'] as List? ?? const [])
          .map((item) => item.toString())
          .toList(growable: false),
      stores: (json['stores'] as List? ?? const [])
          .whereType<Map>()
          .map((item) => ModuleBrief.fromJson(Map<String, dynamic>.from(item)))
          .toList(growable: false),
    );
  }

  @override
  List<Object?> get props => [id, name, description, sections, stores];
}

/// Каталог разделов, из которых собирается модуль.
class ModuleCatalog extends Equatable {
  final List<String> sections;
  final Map<String, String> requires;

  const ModuleCatalog({required this.sections, this.requires = const {}});

  factory ModuleCatalog.fromJson(Map<String, dynamic> json) {
    final rawRequires = json['requires'];
    final requires = <String, String>{};
    if (rawRequires is Map) {
      rawRequires.forEach((key, value) {
        if (value != null) requires[key.toString()] = value.toString();
      });
    }
    return ModuleCatalog(
      sections: (json['sections'] as List? ?? const [])
          .map((item) => item.toString())
          .toList(growable: false),
      requires: requires,
    );
  }

  static const fallback = ModuleCatalog(
    sections: [
      'dashboard',
      'cash',
      'reports',
      'finance-ops',
      'finance',
      'warehouse',
      'playroom',
      'crm',
      'meta',
      'hr',
      'tasks',
      'my-tasks',
      'checklists',
      'audit',
      'legal',
      'marketing',
      'strategy',
      'integrations',
      'branches',
    ],
    requires: {'meta': 'crm', 'playroom': 'cash'},
  );

  @override
  List<Object?> get props => [sections, requires];
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
  final List<int> moduleIds;

  const StoreCreateInput({
    required this.name,
    this.location,
    this.directorUsername,
    this.directorPassword,
    this.directorFullName,
    this.moduleIds = const [],
  });

  Map<String, dynamic> toJson() => {
    'name': name.trim(),
    'module_ids': moduleIds,
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

class StoreChannel extends Equatable {
  final String kind;
  final bool connected;
  final String? via;
  final String? name;
  final String? accountId;
  final String? businessId;
  final String? pageName;
  final bool? subscribed;
  final DateTime? lastInboundAt;
  final DateTime? tokenExpiresAt;
  final String? error;

  const StoreChannel({
    required this.kind,
    this.connected = false,
    this.via,
    this.name,
    this.accountId,
    this.businessId,
    this.pageName,
    this.subscribed,
    this.lastInboundAt,
    this.tokenExpiresAt,
    this.error,
  });

  factory StoreChannel.fromJson(Map<String, dynamic> json) {
    DateTime? time(Object? raw) =>
        raw is String ? DateTime.tryParse(raw) : null;
    final subscribed = json['subscribed'];
    return StoreChannel(
      kind: (json['kind'] ?? '').toString(),
      connected: json['connected'] == true,
      via: json['via']?.toString(),
      name: json['name']?.toString(),
      accountId: json['account_id']?.toString(),
      businessId: json['business_id']?.toString(),
      pageName: json['page_name']?.toString(),
      subscribed: subscribed is bool ? subscribed : null,
      lastInboundAt: time(json['last_inbound_at']),
      tokenExpiresAt: time(json['token_expires_at']),
      error: json['error']?.toString(),
    );
  }

  @override
  List<Object?> get props => [
    kind,
    connected,
    via,
    name,
    accountId,
    businessId,
    pageName,
    subscribed,
    lastInboundAt,
    tokenExpiresAt,
    error,
  ];
}

class StoreChannels extends Equatable {
  final int storeId;
  final String storeName;
  final bool hasChats;
  final List<StoreChannel> channels;
  final String webhookUrl;
  final bool appSecretSet;
  final bool verifyTokenSet;

  const StoreChannels({
    required this.storeId,
    required this.storeName,
    required this.hasChats,
    required this.channels,
    required this.webhookUrl,
    required this.appSecretSet,
    required this.verifyTokenSet,
  });

  bool get serverReady => appSecretSet && verifyTokenSet;

  factory StoreChannels.fromJson(Map<String, dynamic> json) {
    final setup = json['setup'] is Map
        ? Map<String, dynamic>.from(json['setup'] as Map)
        : <String, dynamic>{};
    return StoreChannels(
      storeId: json['store_id'] is int
          ? json['store_id'] as int
          : int.tryParse('${json['store_id']}') ?? 0,
      storeName: (json['store_name'] as String?)?.trim() ?? '',
      hasChats: json['has_chats'] == true,
      channels: (json['channels'] as List? ?? const [])
          .whereType<Map>()
          .map((item) => StoreChannel.fromJson(Map<String, dynamic>.from(item)))
          .toList(growable: false),
      webhookUrl: (setup['webhook_url'] ?? '').toString(),
      appSecretSet: setup['app_secret_set'] == true,
      verifyTokenSet: setup['verify_token_set'] == true,
    );
  }

  @override
  List<Object?> get props => [
    storeId,
    storeName,
    hasChats,
    channels,
    webhookUrl,
    appSecretSet,
    verifyTokenSet,
  ];
}

class UmnicoIntegration extends Equatable {
  final String id;
  final String kind;
  final String type;
  final String login;
  final String status;
  final int? storeId;
  final String? storeName;

  const UmnicoIntegration({
    required this.id,
    required this.kind,
    this.type = '',
    this.login = '',
    this.status = '',
    this.storeId,
    this.storeName,
  });

  factory UmnicoIntegration.fromJson(Map<String, dynamic> json) {
    final storeRaw = json['store_id'];
    return UmnicoIntegration(
      id: (json['id'] ?? '').toString(),
      kind: (json['kind'] ?? '').toString(),
      type: (json['type'] ?? '').toString(),
      login: (json['login'] ?? '').toString(),
      status: (json['status'] ?? '').toString(),
      storeId: switch (storeRaw) {
        int value => value,
        num value => value.toInt(),
        String value => int.tryParse(value),
        _ => null,
      },
      storeName: json['store_name']?.toString(),
    );
  }

  @override
  List<Object?> get props => [
    id,
    kind,
    type,
    login,
    status,
    storeId,
    storeName,
  ];
}

class UmnicoState extends Equatable {
  final bool connected;
  final String? login;
  final bool webhookOk;
  final String? error;
  final String? integrationsError;
  final List<UmnicoIntegration> integrations;
  final DateTime? polledAt;
  final int pollEverySeconds;

  const UmnicoState({
    this.connected = false,
    this.login,
    this.webhookOk = false,
    this.error,
    this.integrationsError,
    this.integrations = const [],
    this.polledAt,
    this.pollEverySeconds = 30,
  });

  factory UmnicoState.fromJson(Map<String, dynamic> json) {
    final polledRaw = json['polled_at'];
    final everyRaw = json['poll_every_s'];
    return UmnicoState(
      connected: json['connected'] == true,
      login: json['login']?.toString(),
      webhookOk: json['webhook_ok'] == true,
      error: json['error']?.toString(),
      integrationsError: json['integrations_error']?.toString(),
      polledAt: polledRaw is String ? DateTime.tryParse(polledRaw) : null,
      pollEverySeconds: switch (everyRaw) {
        int value when value > 0 => value,
        num value when value > 0 => value.toInt(),
        _ => 30,
      },
      integrations: (json['integrations'] as List? ?? const [])
          .whereType<Map>()
          .map(
            (item) =>
                UmnicoIntegration.fromJson(Map<String, dynamic>.from(item)),
          )
          .toList(growable: false),
    );
  }

  @override
  List<Object?> get props => [
    connected,
    login,
    webhookOk,
    error,
    integrationsError,
    integrations,
    polledAt,
    pollEverySeconds,
  ];
}
