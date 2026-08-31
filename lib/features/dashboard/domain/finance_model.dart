/// Модель финансовых показателей компании согласно ТЗ (FIN-01).
class FinanceMetrics {
  final double cashBalance; // Остаток в кассах
  final double revenue; // Выручка
  final double expenses; // Расходы
  final double netProfit; // Чистая прибыль
  final double? breakEvenPoint; // Точка безубыточности
  final double? cashForecast; // Прогноз кассы

  // Процентное изменение (дельты) к предыдущему периоду
  final double? cashBalanceDelta;
  final double? revenueDelta;
  final double? expensesDelta;
  final double? netProfitDelta;
  final double? cashForecastDelta;
  final int operationsCount;
  final double avgCheck;

  const FinanceMetrics({
    required this.cashBalance,
    required this.revenue,
    required this.expenses,
    required this.netProfit,
    required this.breakEvenPoint,
    required this.cashForecast,
    required this.cashBalanceDelta,
    required this.revenueDelta,
    required this.expensesDelta,
    required this.netProfitDelta,
    required this.cashForecastDelta,
    this.operationsCount = 0,
    this.avgCheck = 0,
  });
}

class MetricBreakdownRow {
  final String label;
  final double value;
  final double share;

  const MetricBreakdownRow({
    required this.label,
    required this.value,
    this.share = 0,
  });
}

class MetricBreakdown {
  final String metric;
  final double value;
  final String period;
  final List<MetricBreakdownRow> rows;

  const MetricBreakdown({
    required this.metric,
    required this.value,
    required this.period,
    this.rows = const [],
  });
}

/// Точка графика движения денежных средств за день (FIN-03).
class CashFlowPoint {
  final DateTime date;
  final double amount; // Остаток на конец дня
  final double income; // Приход за день
  final double expense; // Расход за день

  const CashFlowPoint({
    required this.date,
    required this.amount,
    this.income = 0.0,
    this.expense = 0.0,
  });
}

/// Core dashboard payload returned by `/finance/overview`.
///
/// Keeping metrics and cash-flow history together prevents two identical
/// network requests during the initial dashboard load.
class FinanceOverview {
  final FinanceMetrics metrics;
  final List<CashFlowPoint> history;

  const FinanceOverview({required this.metrics, required this.history});
}

class PnlRow {
  final String category;
  final double amount;
  final double share;

  const PnlRow({
    required this.category,
    required this.amount,
    required this.share,
  });
}

class PnlReport {
  final List<PnlRow> income;
  final List<PnlRow> expense;
  final double totalIncome;
  final double totalExpense;
  final double profit;

  const PnlReport({
    required this.income,
    required this.expense,
    required this.totalIncome,
    required this.totalExpense,
    required this.profit,
  });
}

class BreakEvenAnalysis {
  final double revenue;
  final double fixedCosts;
  final double variableCosts;
  final double variableRatio;
  final double breakEvenRevenue;
  final double marginOfSafety;

  const BreakEvenAnalysis({
    required this.revenue,
    required this.fixedCosts,
    required this.variableCosts,
    required this.variableRatio,
    required this.breakEvenRevenue,
    required this.marginOfSafety,
  });
}

class AbcRow {
  final String name;
  final double turnover;
  final double share;
  final double cumulative;
  final String abcClass; // "A", "B", "C"

  const AbcRow({
    required this.name,
    required this.turnover,
    required this.share,
    required this.cumulative,
    required this.abcClass,
  });
}

/// Backend `/finance/abc` accepts only `category` | `counterparty`.
abstract final class AbcDimensions {
  static const category = 'category';
  static const counterparty = 'counterparty';

  static String toApi(String raw) {
    final dimension = raw.trim().toLowerCase();
    if (dimension == 'client' || dimension == counterparty) {
      return counterparty;
    }
    return category;
  }

  static bool isCategory(String raw) => toApi(raw) == category;
}

class AbcAnalysis {
  final String dimension; // "category" or "counterparty" (legacy: "client")
  final List<AbcRow> rows;
  final double total;

  const AbcAnalysis({
    required this.dimension,
    required this.rows,
    required this.total,
  });
}

class BankAccountInfo {
  final String id;
  final String name;
  final String? bank;
  final String? number;
  final String currency;
  final double balance;

  const BankAccountInfo({
    required this.id,
    required this.name,
    this.bank,
    this.number,
    required this.currency,
    required this.balance,
  });
}

class BankAccountsReport {
  final List<BankAccountInfo> accounts;
  final double totalTjs;

  const BankAccountsReport({required this.accounts, required this.totalTjs});
}

class RateRow {
  final String code;
  final double rate;
  final DateTime rateDate;

  const RateRow({
    required this.code,
    required this.rate,
    required this.rateDate,
  });
}

class ExchangeRatesReport {
  final List<RateRow> rates;

  const ExchangeRatesReport({required this.rates});
}

/// Commercial bank buy/sell quote (`GET /finance/currency-board`).
class BankRateQuote {
  final String bank;
  final String bankName;
  final String currency;
  final double? buy;
  final double? sell;
  final DateTime? fetchedAt;

  const BankRateQuote({
    required this.bank,
    required this.bankName,
    required this.currency,
    this.buy,
    this.sell,
    this.fetchedAt,
  });
}

class CurrencyBoard {
  final List<RateRow> official;
  final List<BankRateQuote> banks;

  const CurrencyBoard({this.official = const [], this.banks = const []});
}

class CashGapForecast {
  final bool atRisk;
  final double avgDailyNet;
  final double balance;
  final int? daysToZero;
  final String message;

  const CashGapForecast({
    required this.atRisk,
    required this.avgDailyNet,
    required this.balance,
    this.daysToZero,
    required this.message,
  });
}

class AiInsightsReport {
  final CashGapForecast forecast;
  final String recommendations;

  const AiInsightsReport({
    required this.forecast,
    required this.recommendations,
  });
}

class PlanFactRow {
  final String category;
  final String type; // 'INFLOW' / 'OUTFLOW' or 'income' / 'expense'
  final double planned;
  final double fact;
  final double deviation;
  final double completion;

  const PlanFactRow({
    required this.category,
    required this.type,
    required this.planned,
    required this.fact,
    required this.deviation,
    required this.completion,
  });
}

class PlanFactReport {
  final String period;
  final List<PlanFactRow> rows;
  final double totalPlanned;
  final double totalFact;

  const PlanFactReport({
    required this.period,
    required this.rows,
    required this.totalPlanned,
    required this.totalFact,
  });
}

class PlanItem {
  final int id;
  final String period;
  final String category;
  final String type; // income | expense
  final double plannedAmount;

  const PlanItem({
    required this.id,
    required this.period,
    required this.category,
    required this.type,
    required this.plannedAmount,
  });
}

class ClientAnalysisRow {
  final String name;
  final int purchases;
  final double total;
  final DateTime? lastPurchase;
  final int? daysSince;

  const ClientAnalysisRow({
    required this.name,
    required this.purchases,
    required this.total,
    this.lastPurchase,
    this.daysSince,
  });
}

class ClientAnalysisReport {
  final List<ClientAnalysisRow> frequent;
  final List<ClientAnalysisRow> dormant;

  const ClientAnalysisReport({
    this.frequent = const [],
    this.dormant = const [],
  });
}

class ConvertResult {
  final String base;
  final double amount;
  final Map<String, double> values;

  const ConvertResult({
    required this.base,
    required this.amount,
    required this.values,
  });
}

/// Строка сопоставления 1С и PAYK для экрана сверки
class OneCRow {
  final String onecName;
  final double onecAmount;
  final String? paykKind; // 'register' | 'account'
  final int? paykId;
  final String? paykName;
  final double? paykAmount;
  final double? difference;
  final String? matchedBy; // 'manual' | 'auto' | null

  const OneCRow({
    required this.onecName,
    required this.onecAmount,
    this.paykKind,
    this.paykId,
    this.paykName,
    this.paykAmount,
    this.difference,
    this.matchedBy,
  });

  factory OneCRow.fromJson(Map<String, dynamic> json) {
    return OneCRow(
      onecName: (json['onec_name'] ?? '').toString(),
      onecAmount: (json['onec_amount'] as num?)?.toDouble() ?? 0.0,
      paykKind: json['payk_kind']?.toString(),
      paykId: (json['payk_id'] as num?)?.toInt(),
      paykName: json['payk_name']?.toString(),
      paykAmount: (json['payk_amount'] as num?)?.toDouble(),
      difference: (json['difference'] as num?)?.toDouble(),
      matchedBy: json['matched_by']?.toString(),
    );
  }

  Map<String, dynamic> toJson() => {
    'onec_name': onecName,
    'onec_amount': onecAmount,
    'payk_kind': paykKind,
    'payk_id': paykId,
    'payk_name': paykName,
    'payk_amount': paykAmount,
    'difference': difference,
    'matched_by': matchedBy,
  };
}

/// Целевая касса или счет для привязки строки 1С
class OneCTarget {
  final String kind; // 'register' | 'account'
  final int id;
  final String name;
  final double amount;

  const OneCTarget({
    required this.kind,
    required this.id,
    required this.name,
    this.amount = 0.0,
  });

  factory OneCTarget.fromJson(Map<String, dynamic> json) {
    return OneCTarget(
      kind: (json['kind'] ?? 'register').toString(),
      id: (json['id'] as num?)?.toInt() ?? 0,
      name: (json['name'] ?? '').toString(),
      amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toJson() => {
    'kind': kind,
    'id': id,
    'name': name,
    'amount': amount,
  };
}

/// Позиция PAYK, отсутствующая в выгрузке 1С
class OneCNotInOnecItem {
  final String name;
  final double amount;
  final String kind;
  final int id;

  const OneCNotInOnecItem({
    required this.name,
    required this.amount,
    required this.kind,
    required this.id,
  });

  factory OneCNotInOnecItem.fromJson(Map<String, dynamic> json) {
    return OneCNotInOnecItem(
      name: (json['name'] ?? '').toString(),
      amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
      kind: (json['kind'] ?? 'register').toString(),
      id: (json['id'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
    'name': name,
    'amount': amount,
    'kind': kind,
    'id': id,
  };
}

/// Отчет сверки остатков с 1С
class OneCReconcileReport {
  final String date;
  final List<OneCRow> rows;
  final List<OneCNotInOnecItem> notInOnec;
  final double totalOnec;
  final double totalPayk;

  const OneCReconcileReport({
    required this.date,
    required this.rows,
    required this.notInOnec,
    required this.totalOnec,
    required this.totalPayk,
  });

  factory OneCReconcileReport.fromJson(Map<String, dynamic> json) {
    final rowsList =
        (json['rows'] as List<dynamic>?)
            ?.map((e) => OneCRow.fromJson(e as Map<String, dynamic>))
            .toList() ??
        [];
    final notInList =
        (json['not_in_onec'] as List<dynamic>?)
            ?.map((e) => OneCNotInOnecItem.fromJson(e as Map<String, dynamic>))
            .toList() ??
        [];
    return OneCReconcileReport(
      date: (json['date'] ?? '').toString(),
      rows: rowsList,
      notInOnec: notInList,
      totalOnec: (json['total_onec'] as num?)?.toDouble() ?? 0.0,
      totalPayk: (json['total_payk'] as num?)?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toJson() => {
    'date': date,
    'rows': rows.map((e) => e.toJson()).toList(),
    'not_in_onec': notInOnec.map((e) => e.toJson()).toList(),
    'total_onec': totalOnec,
    'total_payk': totalPayk,
  };
}

/// Запрос на ручную привязку или отвязку строки 1С
class OneCLinkInput {
  final String onecName;
  final String? kind; // 'register' | 'account' | null
  final int? targetId;

  const OneCLinkInput({required this.onecName, this.kind, this.targetId});

  Map<String, dynamic> toJson() => {
    'onec_name': onecName,
    if (kind != null) 'kind': kind,
    if (targetId != null) 'target_id': targetId,
  };
}
