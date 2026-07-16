/// Способы оплаты согласно ТЗ (CASH-04).
enum PaymentMethod {
  cash, // Наличные
  card, // Карта
  alif, // Алиф
  dushanbeCity, // Душанбе Сити
  ocms; // ОСМС (ОСМС Сити)

  String get label {
    switch (this) {
      case PaymentMethod.cash:
        return 'Наличные';
      case PaymentMethod.card:
        return 'Карта';
      case PaymentMethod.alif:
        return 'Алиф';
      case PaymentMethod.dushanbeCity:
        return 'Душанбе Сити';
      case PaymentMethod.ocms:
        return 'ОСМС';
    }
  }

  static PaymentMethod fromLabel(String label) {
    switch (label.toLowerCase()) {
      case 'карта':
        return PaymentMethod.card;
      case 'алиф':
        return PaymentMethod.alif;
      case 'душанбе сити':
        return PaymentMethod.dushanbeCity;
      case 'осмс':
        return PaymentMethod.ocms;
      case 'наличные':
      default:
        return PaymentMethod.cash;
    }
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

  // Дополнительные поля для истории смен
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

  const CashRegister({
    required this.id,
    required this.name,
    this.location,
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
