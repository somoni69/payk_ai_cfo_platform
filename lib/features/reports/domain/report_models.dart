import 'package:equatable/equatable.dart';

class DailyReport extends Equatable {
  final String id;
  final String branchName;
  final DateTime date;
  final double revenue;
  final double expenses;
  final double netProfit;
  final double cashEndBalance;
  final double bankEndBalance;
  final String status; // 'submitted', 'verified'
  final String comments;

  const DailyReport({
    required this.id,
    required this.branchName,
    required this.date,
    required this.revenue,
    required this.expenses,
    required this.netProfit,
    required this.cashEndBalance,
    required this.bankEndBalance,
    this.status = 'submitted',
    this.comments = '',
  });

  factory DailyReport.fromJson(Map<String, dynamic> json) {
    return DailyReport(
      id: json['id'] as String? ?? '',
      branchName: json['branch_name'] as String? ?? '',
      date: json['date'] != null
          ? DateTime.parse(json['date'] as String)
          : DateTime.now(),
      revenue: (json['revenue'] as num?)?.toDouble() ?? 0.0,
      expenses: (json['expenses'] as num?)?.toDouble() ?? 0.0,
      netProfit: (json['net_profit'] as num?)?.toDouble() ?? 0.0,
      cashEndBalance: (json['cash_end_balance'] as num?)?.toDouble() ?? 0.0,
      bankEndBalance: (json['bank_end_balance'] as num?)?.toDouble() ?? 0.0,
      status: json['status'] as String? ?? 'submitted',
      comments: json['comments'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'branch_name': branchName,
      'date': date.toIso8601String(),
      'revenue': revenue,
      'expenses': expenses,
      'net_profit': netProfit,
      'cash_end_balance': cashEndBalance,
      'bank_end_balance': bankEndBalance,
      'status': status,
      'comments': comments,
    };
  }

  @override
  List<Object?> get props => [
        id,
        branchName,
        date,
        revenue,
        expenses,
        netProfit,
        cashEndBalance,
        bankEndBalance,
        status,
        comments,
      ];
}
