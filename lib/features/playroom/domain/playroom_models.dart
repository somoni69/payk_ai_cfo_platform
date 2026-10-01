import '../../cash/domain/transaction_model.dart';

enum PlayroomStatus { active, closed, cancelled }

class PlayroomExtension {
  final int id;
  final int minutes;
  final double rate;
  final double amount;
  final DateTime startAt;
  final DateTime endAt;
  final PaymentMethod paymentMethod;
  final String? bankName;
  final DateTime createdAt;

  const PlayroomExtension({
    required this.id,
    required this.minutes,
    required this.rate,
    required this.amount,
    required this.startAt,
    required this.endAt,
    required this.paymentMethod,
    this.bankName,
    required this.createdAt,
  });

  factory PlayroomExtension.fromJson(Map<String, dynamic> json) {
    return PlayroomExtension(
      id: _asInt(json['id']) ?? 0,
      minutes: _asInt(json['minutes']) ?? 0,
      rate: _asDouble(json['rate']),
      amount: _asDouble(json['amount']),
      startAt: _asDate(json['start_at']) ?? DateTime.now(),
      endAt: _asDate(json['end_at']) ?? DateTime.now(),
      paymentMethod: PaymentMethod.fromLabel(
        (json['payment_method'] ?? 'cash').toString(),
      ),
      bankName: _asString(json['bank_name']),
      createdAt: _asDate(json['created_at']) ?? DateTime.now(),
    );
  }
}

class PlayroomOrder {
  final int id;
  final int number;
  final String code;
  final String? storeName;
  final String? customerName;
  final String? customerPhone;
  final int people;
  final DateTime startAt;
  final DateTime endAt;
  final int minutes;
  final double rate;
  final double amount;
  final PaymentMethod paymentMethod;
  final String? bankName;
  final int? registerId;
  final String? registerName;
  final PlayroomStatus status;
  final DateTime? closedAt;
  final String? createdByName;
  final DateTime createdAt;
  final List<PlayroomExtension> extensions;

  const PlayroomOrder({
    required this.id,
    required this.number,
    required this.code,
    this.storeName,
    this.customerName,
    this.customerPhone,
    required this.people,
    required this.startAt,
    required this.endAt,
    required this.minutes,
    required this.rate,
    required this.amount,
    required this.paymentMethod,
    this.bankName,
    this.registerId,
    this.registerName,
    required this.status,
    this.closedAt,
    this.createdByName,
    required this.createdAt,
    this.extensions = const [],
  });

  int get baseMinutes {
    final extra = extensions.fold<int>(0, (sum, item) => sum + item.minutes);
    final base = minutes - extra;
    return base < 0 ? 0 : base;
  }

  factory PlayroomOrder.fromJson(Map<String, dynamic> json) {
    return PlayroomOrder(
      id: _asInt(json['id']) ?? 0,
      number: _asInt(json['number']) ?? 0,
      code: (json['code'] ?? '').toString(),
      storeName: _asString(json['store_name']),
      customerName: _asString(json['customer_name']),
      customerPhone: _asString(json['customer_phone']),
      people: _asInt(json['people']) ?? 0,
      startAt: _asDate(json['start_at']) ?? DateTime.now(),
      endAt: _asDate(json['end_at']) ?? DateTime.now(),
      minutes: _asInt(json['minutes']) ?? 0,
      rate: _asDouble(json['rate']),
      amount: _asDouble(json['amount']),
      paymentMethod: PaymentMethod.fromLabel(
        (json['payment_method'] ?? 'cash').toString(),
      ),
      bankName: _asString(json['bank_name']),
      registerId: _asInt(json['register_id']),
      registerName: _asString(json['register_name']),
      status: _status(json['status']?.toString()),
      closedAt: _asDate(json['closed_at']),
      createdByName: _asString(json['created_by_name']),
      createdAt: _asDate(json['created_at']) ?? DateTime.now(),
      extensions: _maps(
        json['extensions'],
      ).map(PlayroomExtension.fromJson).toList(),
    );
  }
}

class PlayroomTariff {
  final String openFrom;
  final String dayUntil;
  final String closeAt;
  final double dayRate;
  final double eveningRate;
  final int stepMinutes;
  final double? currentRate;

  const PlayroomTariff({
    required this.openFrom,
    required this.dayUntil,
    required this.closeAt,
    required this.dayRate,
    required this.eveningRate,
    required this.stepMinutes,
    this.currentRate,
  });

  factory PlayroomTariff.fromJson(Map<String, dynamic> json) {
    return PlayroomTariff(
      openFrom: (json['open_from'] ?? '08:00').toString(),
      dayUntil: (json['day_until'] ?? '15:00').toString(),
      closeAt: (json['close_at'] ?? '24:00').toString(),
      dayRate: _asDouble(json['day_rate']),
      eveningRate: _asDouble(json['evening_rate']),
      stepMinutes: _asInt(json['step_minutes']) ?? 30,
      currentRate: json['current_rate'] == null
          ? null
          : _asDouble(json['current_rate']),
    );
  }
}

class PlayroomStats {
  final int orders;
  final int people;
  final double revenue;
  final int active;
  final int expired;

  const PlayroomStats({
    required this.orders,
    required this.people,
    required this.revenue,
    required this.active,
    required this.expired,
  });

  static const empty = PlayroomStats(
    orders: 0,
    people: 0,
    revenue: 0,
    active: 0,
    expired: 0,
  );

  factory PlayroomStats.fromJson(Map<String, dynamic> json) {
    return PlayroomStats(
      orders: _asInt(json['orders']) ?? 0,
      people: _asInt(json['people']) ?? 0,
      revenue: _asDouble(json['revenue']),
      active: _asInt(json['active']) ?? 0,
      expired: _asInt(json['expired']) ?? 0,
    );
  }
}

class PlayroomRegister {
  final int id;
  final String name;

  const PlayroomRegister({required this.id, required this.name});

  factory PlayroomRegister.fromJson(Map<String, dynamic> json) {
    return PlayroomRegister(
      id: _asInt(json['id']) ?? 0,
      name: (json['name'] ?? '').toString(),
    );
  }
}

class PlayroomOpenShift {
  final int cashierId;
  final int? registerId;

  const PlayroomOpenShift({required this.cashierId, this.registerId});

  factory PlayroomOpenShift.fromJson(Map<String, dynamic> json) {
    return PlayroomOpenShift(
      cashierId: _asInt(json['cashier_id']) ?? 0,
      registerId: _asInt(json['register_id']),
    );
  }
}

class PlayroomOrderInput {
  final int registerId;
  final int people;
  final int minutes;
  final String? startAt;
  final String? customerName;
  final String? customerPhone;
  final String paymentMethod;
  final int? bankId;

  const PlayroomOrderInput({
    required this.registerId,
    required this.people,
    required this.minutes,
    this.startAt,
    this.customerName,
    this.customerPhone,
    required this.paymentMethod,
    this.bankId,
  });

  Map<String, dynamic> toJson() => {
    'register_id': registerId,
    'people': people,
    'minutes': minutes,
    'start_at': startAt,
    'customer_name': customerName,
    'customer_phone': customerPhone,
    'payment_method': paymentMethod,
    'bank_id': bankId,
  };
}

class PlayroomExtendInput {
  final int minutes;
  final String paymentMethod;
  final int? bankId;

  const PlayroomExtendInput({
    required this.minutes,
    required this.paymentMethod,
    this.bankId,
  });

  Map<String, dynamic> toJson() => {
    'minutes': minutes,
    'payment_method': paymentMethod,
    'bank_id': bankId,
  };
}

PlayroomStatus _status(String? raw) => switch (raw) {
  'closed' => PlayroomStatus.closed,
  'cancelled' => PlayroomStatus.cancelled,
  _ => PlayroomStatus.active,
};

int? _asInt(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value);
  return null;
}

double _asDouble(dynamic value) {
  if (value is num) return value.toDouble();
  if (value is String) {
    return double.tryParse(value.replaceAll(' ', '').replaceAll(',', '.')) ?? 0;
  }
  return 0;
}

String? _asString(dynamic value) {
  if (value == null) return null;
  final text = value.toString().trim();
  return text.isEmpty ? null : text;
}

DateTime? _asDate(dynamic value) {
  if (value is! String || value.isEmpty) return null;
  return DateTime.tryParse(value);
}

List<Map<String, dynamic>> _maps(dynamic raw) {
  if (raw is! List) return const [];
  return [
    for (final item in raw)
      if (item is Map) Map<String, dynamic>.from(item),
  ];
}
