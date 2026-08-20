/// Модель клиента в CRM системе.
class CrmClient {
  final String id;
  final String fullName;
  final String? phone;
  final String? email;
  final DateTime? birthDate;
  final String loyaltyLevel; // bronze | silver | gold | platinum
  final double bonusPoints;
  final double totalSpent;
  final double acquisitionCost;
  final int purchasesCount;
  final DateTime? lastPurchaseAt;
  final String? note;
  final DateTime createdAt;
  final double? roi;
  final bool churnRisk;

  const CrmClient({
    required this.id,
    required this.fullName,
    this.phone,
    this.email,
    this.birthDate,
    required this.loyaltyLevel,
    required this.bonusPoints,
    required this.totalSpent,
    required this.acquisitionCost,
    required this.purchasesCount,
    this.lastPurchaseAt,
    this.note,
    required this.createdAt,
    this.roi,
    required this.churnRisk,
  });

  CrmClient copyWith({
    String? id,
    String? fullName,
    String? phone,
    String? email,
    DateTime? birthDate,
    String? loyaltyLevel,
    double? bonusPoints,
    double? totalSpent,
    double? acquisitionCost,
    int? purchasesCount,
    DateTime? lastPurchaseAt,
    String? note,
    DateTime? createdAt,
    double? roi,
    bool? churnRisk,
    bool clearBirthDate = false,
    bool clearLastPurchase = false,
    bool clearPhone = false,
    bool clearEmail = false,
    bool clearNote = false,
  }) {
    return CrmClient(
      id: id ?? this.id,
      fullName: fullName ?? this.fullName,
      phone: clearPhone ? null : (phone ?? this.phone),
      email: clearEmail ? null : (email ?? this.email),
      birthDate: clearBirthDate ? null : (birthDate ?? this.birthDate),
      loyaltyLevel: loyaltyLevel ?? this.loyaltyLevel,
      bonusPoints: bonusPoints ?? this.bonusPoints,
      totalSpent: totalSpent ?? this.totalSpent,
      acquisitionCost: acquisitionCost ?? this.acquisitionCost,
      purchasesCount: purchasesCount ?? this.purchasesCount,
      lastPurchaseAt: clearLastPurchase
          ? null
          : (lastPurchaseAt ?? this.lastPurchaseAt),
      note: clearNote ? null : (note ?? this.note),
      createdAt: createdAt ?? this.createdAt,
      roi: roi ?? this.roi,
      churnRisk: churnRisk ?? this.churnRisk,
    );
  }
}

/// Модель сделки с клиентом.
class CrmDeal {
  final String id;
  final String clientId;
  final String title;
  final double amount;

  /// lead | contact | proposal | negotiation | won | lost
  final String stage;
  final DateTime createdAt;
  final String? clientName;
  final DateTime? expectedClose;

  const CrmDeal({
    required this.id,
    required this.clientId,
    required this.title,
    required this.amount,
    required this.stage,
    required this.createdAt,
    this.clientName,
    this.expectedClose,
  });

  CrmDeal copyWith({
    String? id,
    String? clientId,
    String? title,
    double? amount,
    String? stage,
    DateTime? createdAt,
    String? clientName,
    DateTime? expectedClose,
    bool clearExpectedClose = false,
  }) {
    return CrmDeal(
      id: id ?? this.id,
      clientId: clientId ?? this.clientId,
      title: title ?? this.title,
      amount: amount ?? this.amount,
      stage: stage ?? this.stage,
      createdAt: createdAt ?? this.createdAt,
      clientName: clientName ?? this.clientName,
      expectedClose: clearExpectedClose
          ? null
          : (expectedClose ?? this.expectedClose),
    );
  }
}

/// Статистические KPI отдела продаж CRM.
class CrmStatsData {
  final int clientsTotal;
  final int activeClients;
  final double ltvTotal;
  final double cacTotal;
  final double? roi;
  final int churnCount;
  final int reactivationCount;

  const CrmStatsData({
    required this.clientsTotal,
    required this.activeClients,
    required this.ltvTotal,
    required this.cacTotal,
    this.roi,
    required this.churnCount,
    required this.reactivationCount,
  });
}

/// Сводка по уровню лояльности.
class LoyaltySummaryRow {
  final String level;
  final int clients;
  final double totalSpent;
  final double bonusPoints;

  const LoyaltySummaryRow({
    required this.level,
    required this.clients,
    required this.totalSpent,
    required this.bonusPoints,
  });
}

/// Транзакция бонусных баллов.
class LoyaltyTxn {
  final String id;
  final String clientId;
  final double points;
  final String? reason;
  final DateTime createdAt;

  const LoyaltyTxn({
    required this.id,
    required this.clientId,
    required this.points,
    this.reason,
    required this.createdAt,
  });
}

/// Ближайший день рождения клиента.
class BirthdayRow {
  final String id;
  final String fullName;
  final String? phone;
  final DateTime birthDate;
  final int daysUntil;
  final int? turning;

  const BirthdayRow({
    required this.id,
    required this.fullName,
    this.phone,
    required this.birthDate,
    required this.daysUntil,
    this.turning,
  });
}

/// Пагинированный список клиентов.
class ClientsPage {
  final List<CrmClient> items;
  final int total;
  final int page;
  final int size;

  const ClientsPage({
    required this.items,
    required this.total,
    required this.page,
    required this.size,
  });
}

/// Пагинированный журнал бонусов.
class LoyaltyTxnsPage {
  final List<LoyaltyTxn> items;
  final int total;
  final int page;
  final int size;

  const LoyaltyTxnsPage({
    required this.items,
    required this.total,
    required this.page,
    required this.size,
  });

  bool get hasMore => page * size < total;
}

/// Результат AI-анализа оттока.
class ChurnAdvice {
  final String clientId;
  final bool risk;
  final String advice;

  const ChurnAdvice({
    required this.clientId,
    required this.risk,
    required this.advice,
  });
}

/// Фильтры списка клиентов.
class ClientListFilters {
  final String? query;
  final String? level;
  final int page;
  final int size;

  const ClientListFilters({
    this.query,
    this.level,
    this.page = 1,
    this.size = 20,
  });

  ClientListFilters copyWith({
    String? query,
    String? level,
    int? page,
    int? size,
    bool clearQuery = false,
    bool clearLevel = false,
  }) {
    return ClientListFilters(
      query: clearQuery ? null : (query ?? this.query),
      level: clearLevel ? null : (level ?? this.level),
      page: page ?? this.page,
      size: size ?? this.size,
    );
  }
}

/// Этапы воронки (OpenAPI DealStage).
const kDealStages = <String>[
  'lead',
  'contact',
  'proposal',
  'negotiation',
  'won',
  'lost',
];

const kLoyaltyLevels = <String>['bronze', 'silver', 'gold', 'platinum'];
