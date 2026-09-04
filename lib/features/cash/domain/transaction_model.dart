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

  const SaleProduct({
    required this.id,
    required this.name,
    this.sku,
    this.barcode,
    required this.unit,
    required this.price,
    required this.stockQty,
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
