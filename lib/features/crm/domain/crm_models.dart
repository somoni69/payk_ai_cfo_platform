/// Модель клиента в CRM системе.
class CrmClient {
  final String id;
  final String fullName;
  final String? phone;
  final String? email;
  final String loyaltyLevel; // 'bronze', 'silver', 'gold', 'platinum'
  final double bonusPoints;
  final double totalSpent;
  final double acquisitionCost;
  final int purchasesCount;
  final String? note;
  final DateTime createdAt;
  final double? roi;
  final bool churnRisk;

  const CrmClient({
    required this.id,
    required this.fullName,
    this.phone,
    this.email,
    required this.loyaltyLevel,
    required this.bonusPoints,
    required this.totalSpent,
    required this.acquisitionCost,
    required this.purchasesCount,
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
    String? loyaltyLevel,
    double? bonusPoints,
    double? totalSpent,
    double? acquisitionCost,
    int? purchasesCount,
    String? note,
    DateTime? createdAt,
    double? roi,
    bool? churnRisk,
  }) {
    return CrmClient(
      id: id ?? this.id,
      fullName: fullName ?? this.fullName,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      loyaltyLevel: loyaltyLevel ?? this.loyaltyLevel,
      bonusPoints: bonusPoints ?? this.bonusPoints,
      totalSpent: totalSpent ?? this.totalSpent,
      acquisitionCost: acquisitionCost ?? this.acquisitionCost,
      purchasesCount: purchasesCount ?? this.purchasesCount,
      note: note ?? this.note,
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
  final String stage; // 'lead', 'contact', 'proposal', 'negotiation', 'won', 'lost'
  final DateTime createdAt;
  final String? clientName;

  const CrmDeal({
    required this.id,
    required this.clientId,
    required this.title,
    required this.amount,
    required this.stage,
    required this.createdAt,
    this.clientName,
  });
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
