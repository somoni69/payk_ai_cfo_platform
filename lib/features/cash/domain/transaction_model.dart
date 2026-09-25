/// Способы оплаты согласно ТЗ (CASH-04).
enum PaymentMethod {
  cash,
  card,
  alif,
  dushanbeCity,
  ocms,
  mixed;

  /// Localization key for UI (`payment_cash`, …).
  String get labelKey => switch (this) {
    PaymentMethod.cash => 'payment_cash',
    PaymentMethod.card => 'payment_card',
    PaymentMethod.alif => 'payment_alif',
    PaymentMethod.dushanbeCity => 'payment_dushanbe_city',
    PaymentMethod.ocms => 'payment_ocms',
    PaymentMethod.mixed => 'payment_mixed',
  };

  /// Stable storage / API token (also a localization key).
  String get label => labelKey;

  /// Backend enum value (`dushanbe_city`, `osms`, …).
  String get apiValue => switch (this) {
    PaymentMethod.cash => 'cash',
    PaymentMethod.card => 'card',
    PaymentMethod.alif => 'alif',
    PaymentMethod.dushanbeCity => 'dushanbe_city',
    PaymentMethod.ocms => 'osms',
    PaymentMethod.mixed => 'mixed',
  };

  static PaymentMethod fromLabel(String label) {
    final normalized = label.trim().toLowerCase();
    return switch (normalized) {
      'payment_card' || 'карта' || 'card' || 'кор' => PaymentMethod.card,
      'payment_alif' || 'алиф' || 'alif' => PaymentMethod.alif,
      'payment_dushanbe_city' ||
      'душанбе сити' ||
      'dushanbe city' ||
      'dushanbe_city' ||
      'dushanbecity' => PaymentMethod.dushanbeCity,
      'payment_ocms' || 'осмс' || 'ocms' || 'osms' => PaymentMethod.ocms,
      'payment_mixed' ||
      'mixed' ||
      'смешанная' ||
      'смешанный' => PaymentMethod.mixed,
      'payment_cash' || 'наличные' || 'cash' || 'пул' => PaymentMethod.cash,
      _ => PaymentMethod.cash,
    };
  }

  /// Новая продажа / операция. ОСМС из ввода убран — остаётся в истории и фильтре.
  static const List<PaymentMethod> inputValues = [
    PaymentMethod.cash,
    PaymentMethod.card,
    PaymentMethod.alif,
    PaymentMethod.dushanbeCity,
    PaymentMethod.mixed,
  ];
}

/// Товар для продажи без штрих-кода (`GET /cash/sale-products`).
class SaleProduct {
  final String id;
  final String name;
  final String? sku;
  final String? barcode;
  final String unit;
  final double price;
  final double stockQty;
  final String? imageUrl;

  const SaleProduct({
    required this.id,
    required this.name,
    this.sku,
    this.barcode,
    required this.unit,
    required this.price,
    required this.stockQty,
    this.imageUrl,
  });
}

/// Строка продажи в приходе (склад спишется вместе с операцией).
class SaleItemInput {
  final String productId;
  final double qty;
  final double price;

  const SaleItemInput({
    required this.productId,
    required this.qty,
    required this.price,
  });

  double get amount => qty * price;
}

/// Состав продажи в карточке операции (`GET /cash/operations/{id}`).
class SaleLine {
  final String productId;
  final String? productName;
  final String? unit;
  final double qty;
  final double price;
  final double amount;

  const SaleLine({
    required this.productId,
    this.productName,
    this.unit,
    required this.qty,
    required this.price,
    required this.amount,
  });
}

/// Чистая прибыль с продаж (`GET /cash/profit`).
class SalesProfit {
  final double revenue;
  final double revenueCosted;
  final double cost;
  final double profit;
  final double? markupPercent;
  final int itemsSold;
  final int itemsCosted;
  final List<String> missingCost;

  const SalesProfit({
    required this.revenue,
    required this.cost,
    required this.profit,
    this.revenueCosted = 0,
    this.markupPercent,
    this.itemsSold = 0,
    this.itemsCosted = 0,
    this.missingCost = const [],
  });
}

/// Модель кассовой транзакции в Ledger.
class Transaction {
  final String id;
  final String title;
  final String category;
  final double amount;
  final bool isIncome;
  final PaymentMethod paymentMethod;
  final DateTime dateTime;
  final String cashierName;
  final String? registerId;
  final String? registerName;
  final String? description;
  final double? cashAmount;
  final double? cashlessAmount;
  final String? bankId;
  final String? bankName;
  final String? source;
  final bool syncedTo1c;

  /// Продажа без штрих-кода; пусто = обычная операция.
  final List<SaleItemInput> saleItems;

  /// Состав из карточки операции.
  final List<SaleLine> lines;

  const Transaction({
    required this.id,
    required this.title,
    required this.category,
    required this.amount,
    required this.isIncome,
    required this.paymentMethod,
    required this.dateTime,
    required this.cashierName,
    this.registerId,
    this.registerName,
    this.description,
    this.cashAmount,
    this.cashlessAmount,
    this.bankId,
    this.bankName,
    this.source,
    this.syncedTo1c = false,
    this.saleItems = const [],
    this.lines = const [],
  });

  bool get isManual =>
      (source == null || source == 'manual' || source!.isEmpty) && !syncedTo1c;

  Transaction copyWith({
    String? id,
    String? title,
    String? category,
    double? amount,
    bool? isIncome,
    PaymentMethod? paymentMethod,
    DateTime? dateTime,
    String? cashierName,
    String? registerId,
    String? registerName,
    String? description,
    double? cashAmount,
    double? cashlessAmount,
    String? bankId,
    String? bankName,
    String? source,
    bool? syncedTo1c,
    List<SaleItemInput>? saleItems,
    List<SaleLine>? lines,
  }) {
    return Transaction(
      id: id ?? this.id,
      title: title ?? this.title,
      category: category ?? this.category,
      amount: amount ?? this.amount,
      isIncome: isIncome ?? this.isIncome,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      dateTime: dateTime ?? this.dateTime,
      cashierName: cashierName ?? this.cashierName,
      registerId: registerId ?? this.registerId,
      registerName: registerName ?? this.registerName,
      description: description ?? this.description,
      cashAmount: cashAmount ?? this.cashAmount,
      cashlessAmount: cashlessAmount ?? this.cashlessAmount,
      bankId: bankId ?? this.bankId,
      bankName: bankName ?? this.bankName,
      source: source ?? this.source,
      syncedTo1c: syncedTo1c ?? this.syncedTo1c,
      saleItems: saleItems ?? this.saleItems,
      lines: lines ?? this.lines,
    );
  }
}

/// Модель кассовой смены согласно ТЗ (CASH-05 / CASH-06).
class CashShift {
  final String? id;
  final DateTime openedAt;
  final DateTime? closedAt;
  final double startingBalance;
  final double? endingBalance;
  final bool isOpen;

  final String? cashierName;
  final String? registerName;
  final double? difference;
  final String? status;
  final String? note;

  const CashShift({
    this.id,
    required this.openedAt,
    this.closedAt,
    required this.startingBalance,
    this.endingBalance,
    required this.isOpen,
    this.cashierName,
    this.registerName,
    this.difference,
    this.status,
    this.note,
  });
}

/// Модель кассового аппарата (RegisterRead).
class CashRegister {
  final String id;
  final String name;
  final String? location;

  const CashRegister({required this.id, required this.name, this.location});
}

/// Строка терминала в форме закрытия смены (без сумм системы).
class ShiftClosingLine {
  final String key;
  final String label;

  const ShiftClosingLine({required this.key, required this.label});
}

class ShiftTerminalFact {
  final String key;
  final double amount;

  const ShiftTerminalFact({required this.key, required this.amount});

  Map<String, dynamic> toJson() => {'key': key, 'amount': amount};
}

class ShiftPersonOption {
  final String id;
  final String fullName;
  final String? position;

  const ShiftPersonOption({
    required this.id,
    required this.fullName,
    this.position,
  });

  String get label {
    final role = position?.trim();
    if (role == null || role.isEmpty) return fullName;
    return '$fullName — $role';
  }
}

class ShiftReportLine {
  final String key;
  final String label;
  final bool cashless;
  final double? fact;
  final double system;
  final double? diff;

  const ShiftReportLine({
    required this.key,
    required this.label,
    this.cashless = true,
    this.fact,
    this.system = 0,
    this.diff,
  });
}

class ShiftReportExpense {
  final String name;
  final String? direction;
  final double amount;

  const ShiftReportExpense({
    required this.name,
    this.direction,
    this.amount = 0,
  });
}

/// Бланк приёма от кассира.
class CashShiftReport {
  final String shiftId;
  final String? storeName;
  final String? registerName;
  final String? cashierName;
  final String? collectorName;
  final String? chiefCashierName;
  final String? auditorName;
  final DateTime? openedAt;
  final DateTime? closedAt;
  final double openingBalance;
  final double? actualBalance;
  final double? expectedBalance;
  final List<ShiftReportLine> lines;
  final List<ShiftReportExpense> expenses;
  final double expensesTotal;
  final String? note;
  final bool isClosed;
  final String? branchName;
  final double cashShare;
  final double cardShare;

  const CashShiftReport({
    required this.shiftId,
    this.storeName,
    this.branchName,
    this.registerName,
    this.cashierName,
    this.collectorName,
    this.chiefCashierName,
    this.auditorName,
    this.openedAt,
    this.closedAt,
    this.openingBalance = 0,
    this.actualBalance,
    this.expectedBalance,
    this.lines = const [],
    this.expenses = const [],
    this.expensesTotal = 0,
    this.note,
    this.isClosed = true,
    this.cashShare = 0,
    this.cardShare = 0,
  });
}

/// Сводные показатели кассы / кассового аппарата (SummaryRow).
class CashSummary {
  final String registerId;
  final String registerName;
  final bool hasOpenShift;
  final double income;
  final double expense;
  final double net;

  const CashSummary({
    required this.registerId,
    required this.registerName,
    required this.hasOpenShift,
    required this.income,
    required this.expense,
    required this.net,
  });
}
