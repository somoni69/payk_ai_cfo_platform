import 'package:equatable/equatable.dart';

class BankAccount extends Equatable {
  final String id;
  final String bankName;
  final String accountNumber;
  final double balance;
  final String currency;

  const BankAccount({
    required this.id,
    required this.bankName,
    required this.accountNumber,
    required this.balance,
    this.currency = 'TJS',
  });

  factory BankAccount.fromJson(Map<String, dynamic> json) {
    return BankAccount(
      id: json['id'] as String? ?? '',
      bankName: json['bank_name'] as String? ?? '',
      accountNumber: json['account_number'] as String? ?? '',
      balance: (json['balance'] as num?)?.toDouble() ?? 0.0,
      currency: json['currency'] as String? ?? 'TJS',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'bank_name': bankName,
      'account_number': accountNumber,
      'balance': balance,
      'currency': currency,
    };
  }

  @override
  List<Object?> get props => [id, bankName, accountNumber, balance, currency];
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
      id: json['id'] as String? ?? '',
      bankName: json['bank_name'] as String? ?? '',
      amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
      responsiblePerson: json['responsible_person'] as String? ?? '',
      date: json['date'] != null
          ? DateTime.parse(json['date'] as String)
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
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
  final String status; // 'pending', 'received', 'cancelled'
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
      id: json['id'] as String? ?? '',
      fromBranch: json['from_branch'] as String? ?? '',
      toBranch: json['to_branch'] as String? ?? '',
      amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
      status: json['status'] as String? ?? 'pending',
      date: json['date'] != null
          ? DateTime.parse(json['date'] as String)
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'from_branch': fromBranch,
      'to_branch': toBranch,
      'amount': amount,
      'status': status,
      'date': date.toIso8601String(),
    };
  }

  @override
  List<Object?> get props => [
        id,
        fromBranch,
        toBranch,
        amount,
        status,
        date,
      ];
}

class FinancialAid extends Equatable {
  final String id;
  final String employeeName;
  final double amount;
  final double repaidAmount;
  final String status; // 'active', 'repaid'
  final DateTime date;

  const FinancialAid({
    required this.id,
    required this.employeeName,
    required this.amount,
    required this.repaidAmount,
    required this.status,
    required this.date,
  });

  double get remainingAmount => amount - repaidAmount;

  factory FinancialAid.fromJson(Map<String, dynamic> json) {
    return FinancialAid(
      id: json['id'] as String? ?? '',
      employeeName: json['employee_name'] as String? ?? '',
      amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
      repaidAmount: (json['repaid_amount'] as num?)?.toDouble() ?? 0.0,
      status: json['status'] as String? ?? 'active',
      date: json['date'] != null
          ? DateTime.parse(json['date'] as String)
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
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
