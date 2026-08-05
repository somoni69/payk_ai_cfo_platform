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
  });
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
