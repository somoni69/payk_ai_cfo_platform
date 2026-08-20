import 'package:equatable/equatable.dart';

/// Справочник банков (web `/finance-ops/banks`).
class BankAccount extends Equatable {
  final String id;
  final String bankName;
  final bool isActive;

  /// Legacy display fields (optional).
  final String accountNumber;
  final double balance;
  final String currency;

  const BankAccount({
    required this.id,
    required this.bankName,
    this.isActive = true,
    this.accountNumber = '',
    this.balance = 0,
    this.currency = 'TJS',
  });

  factory BankAccount.fromJson(Map<String, dynamic> json) {
    return BankAccount(
      id: (json['id'] ?? '').toString(),
      bankName: (json['name'] ?? json['bank_name'] ?? '').toString(),
      isActive: json['is_active'] as bool? ?? true,
      accountNumber: json['account_number']?.toString() ?? '',
      balance: (json['balance'] as num?)?.toDouble() ?? 0.0,
      currency: json['currency']?.toString() ?? 'TJS',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': bankName,
      if (accountNumber.isNotEmpty) 'account_number': accountNumber,
      if (balance != 0) 'balance': balance,
      'currency': currency,
    };
  }

  @override
  List<Object?> get props => [
    id,
    bankName,
    isActive,
    accountNumber,
    balance,
    currency,
  ];
}

class Encashment extends Equatable {
  final String id;
  final String bankName;
  final double amount;
  final String responsiblePerson;
  final DateTime date;

  const Encashment({
    required this.id,
    required this.bankName,
    required this.amount,
    required this.responsiblePerson,
    required this.date,
  });

  factory Encashment.fromJson(Map<String, dynamic> json) {
    return Encashment(
      id: (json['id'] ?? '').toString(),
      bankName: (json['bank_name'] ?? '').toString(),
      amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
      responsiblePerson:
          (json['responsible_name'] ?? json['responsible_person'] ?? '')
              .toString(),
      date:
          DateTime.tryParse(
            (json['occurred_at'] ?? json['date'] ?? '').toString(),
          ) ??
          DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'bank_name': bankName,
      'amount': amount,
      'responsible_person': responsiblePerson,
      'date': date.toIso8601String(),
    };
  }

  @override
  List<Object?> get props => [id, bankName, amount, responsiblePerson, date];
}

class StoreTransfer extends Equatable {
  final String id;
  final String fromBranch;
  final String toBranch;
  final double amount;
  final String status; // pending | received | cancelled
  final DateTime date;

  const StoreTransfer({
    required this.id,
    required this.fromBranch,
    required this.toBranch,
    required this.amount,
    required this.status,
    required this.date,
  });

  factory StoreTransfer.fromJson(Map<String, dynamic> json) {
    return StoreTransfer(
      id: (json['id'] ?? '').toString(),
      fromBranch: (json['from_branch_name'] ?? json['from_branch'] ?? '')
          .toString(),
      toBranch: (json['to_branch_name'] ?? json['to_branch'] ?? '').toString(),
      amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
      status: (json['status'] ?? 'pending').toString(),
      date:
          DateTime.tryParse(
            (json['created_at'] ?? json['date'] ?? '').toString(),
          ) ??
          DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'from_branch': fromBranch,
      'to_branch': toBranch,
      'amount': amount,
      'status': status,
      'date': date.toIso8601String(),
    };
  }

  @override
  List<Object?> get props => [id, fromBranch, toBranch, amount, status, date];
}

class FinancialAid extends Equatable {
  final String id;
  final String employeeName;
  final double amount;
  final double repaidAmount;
  final String status;
  final DateTime date;

  const FinancialAid({
    required this.id,
    required this.employeeName,
    required this.amount,
    required this.repaidAmount,
    required this.status,
    required this.date,
  });

  double get remainingAmount {
    final left = amount - repaidAmount;
    return left < 0 ? 0 : left;
  }

  factory FinancialAid.fromJson(Map<String, dynamic> json) {
    return FinancialAid(
      id: (json['id'] ?? '').toString(),
      employeeName: (json['employee_name'] ?? '').toString(),
      amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
      repaidAmount: (json['repaid_amount'] as num?)?.toDouble() ?? 0.0,
      status:
          (json['status'] ??
                  (json['deducted_in_period'] != null ? 'repaid' : 'active'))
              .toString(),
      date:
          DateTime.tryParse(
            (json['issued_at'] ?? json['date'] ?? json['created_at'] ?? '')
                .toString(),
          ) ??
          DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'employee_name': employeeName,
      'amount': amount,
      'repaid_amount': repaidAmount,
      'status': status,
      'date': date.toIso8601String(),
    };
  }

  @override
  List<Object?> get props => [
    id,
    employeeName,
    amount,
    repaidAmount,
    status,
    date,
  ];
}
