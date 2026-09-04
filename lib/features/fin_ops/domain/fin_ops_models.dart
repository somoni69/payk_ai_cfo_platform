import 'package:equatable/equatable.dart';

double _money(dynamic value, [double fallback = 0]) {
  if (value == null) return fallback;
  if (value is num) return value.toDouble();
  if (value is String) {
    return double.tryParse(value.replaceAll(' ', '').replaceAll(',', '.')) ??
        fallback;
  }
  return fallback;
}

double? _moneyOrNull(dynamic value) {
  if (value == null) return null;
  if (value is num) return value.toDouble();
  if (value is String) {
    return double.tryParse(value.replaceAll(' ', '').replaceAll(',', '.'));
  }
  return null;
}

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
      balance: _money(json['balance']),
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

class ResponsibleOption extends Equatable {
  final String id;
  final String fullName;
  final String? position;

  const ResponsibleOption({
    required this.id,
    required this.fullName,
    this.position,
  });

  String get label => position == null || position!.isEmpty
      ? fullName
      : '$fullName — $position';

  factory ResponsibleOption.fromJson(Map<String, dynamic> json) {
    return ResponsibleOption(
      id: (json['id'] ?? '').toString(),
      fullName: (json['full_name'] ?? json['name'] ?? '').toString(),
      position: json['position']?.toString(),
    );
  }

  @override
  List<Object?> get props => [id, fullName, position];
}

class Encashment extends Equatable {
  final String id;
  final String bankName;
  final String? registerName;
  final double amount;
  final String responsiblePerson;
  final DateTime date;
  final String? note;

  const Encashment({
    required this.id,
    required this.bankName,
    this.registerName,
    required this.amount,
    required this.responsiblePerson,
    required this.date,
    this.note,
  });

  factory Encashment.fromJson(Map<String, dynamic> json) {
    return Encashment(
      id: (json['id'] ?? '').toString(),
      bankName: (json['bank_name'] ?? '').toString(),
      registerName: json['register_name']?.toString(),
      amount: _money(json['amount']),
      responsiblePerson:
          (json['responsible_name'] ?? json['responsible_person'] ?? '')
              .toString(),
      date:
          DateTime.tryParse(
            (json['occurred_at'] ?? json['date'] ?? '').toString(),
          ) ??
          DateTime.now(),
      note: json['note']?.toString(),
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
  List<Object?> get props => [
    id,
    bankName,
    registerName,
    amount,
    responsiblePerson,
    date,
    note,
  ];
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
      amount: _money(json['amount']),
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

class AidRepayment extends Equatable {
  final String id;
  final String period;
  final double amount;

  const AidRepayment({
    required this.id,
    required this.period,
    required this.amount,
  });

  factory AidRepayment.fromJson(Map<String, dynamic> json) {
    return AidRepayment(
      id: (json['id'] ?? '').toString(),
      period: (json['salary_period'] ?? json['period'] ?? '').toString(),
      amount: _money(json['amount']),
    );
  }

  @override
  List<Object?> get props => [id, period, amount];
}

class FinancialAid extends Equatable {
  final String id;
  final String employeeName;
  final double amount;
  final double repaidAmount;
  final String status;
  final DateTime date;
  final bool deductFromSalary;
  final List<AidRepayment> repayments;

  const FinancialAid({
    required this.id,
    required this.employeeName,
    required this.amount,
    required this.repaidAmount,
    required this.status,
    required this.date,
    this.deductFromSalary = true,
    this.repayments = const [],
  });

  double get remainingAmount {
    final left = amount - repaidAmount;
    return left < 0 ? 0 : left;
  }

  factory FinancialAid.fromJson(Map<String, dynamic> json) {
    final remaining = _moneyOrNull(json['remaining_amount']);
    final repaid = _money(json['repaid_amount']);
    final amount = _money(json['amount']);
    final deduct = json['deduct_from_salary'] != false;
    final rawRepayments = json['repayments'] as List? ?? [];
    final closed =
        json['deducted_in_period'] != null ||
        (remaining != null ? remaining <= 0 : repaid >= amount);
    return FinancialAid(
      id: (json['id'] ?? '').toString(),
      employeeName: (json['employee_name'] ?? '').toString(),
      amount: amount,
      repaidAmount: repaid,
      status: deduct
          ? (closed ? 'repaid' : 'active')
          : (json['status'] ?? 'repaid').toString(),
      date:
          DateTime.tryParse(
            (json['issued_at'] ?? json['date'] ?? json['created_at'] ?? '')
                .toString(),
          ) ??
          DateTime.now(),
      deductFromSalary: deduct,
      repayments: rawRepayments
          .whereType<Map>()
          .map((e) => AidRepayment.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
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
    deductFromSalary,
    repayments,
  ];
}

class BranchBalance extends Equatable {
  final String branchId;
  final String branchName;
  final double balance;
  final double inTransit;

  const BranchBalance({
    required this.branchId,
    required this.branchName,
    this.balance = 0,
    this.inTransit = 0,
  });

  factory BranchBalance.fromJson(Map<String, dynamic> json) {
    return BranchBalance(
      branchId: (json['branch_id'] ?? json['id'] ?? '').toString(),
      branchName: (json['branch_name'] ?? json['name'] ?? '').toString(),
      balance: _money(json['balance']),
      inTransit: _money(json['incoming_in_transit'] ?? json['in_transit']),
    );
  }

  @override
  List<Object?> get props => [branchId, branchName, balance, inTransit];
}
