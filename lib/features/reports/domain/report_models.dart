import 'package:equatable/equatable.dart';

/// Daily branch sales report — aligned with backend `DailyReportRead`
/// and web Payk-Ecosystem reports module.
class DailyReport extends Equatable {
  final int id;
  final int branchId;
  final String? branchName;
  final DateTime reportDate;
  final double totalSales;
  final double cashAmount;
  final double cashlessAmount;
  final int returnsCount;
  final double returnsAmount;
  final bool hasInvoices;
  final String? productsSold;
  final String? note;
  final int? createdBy;
  final DateTime? createdAt;

  const DailyReport({
    required this.id,
    required this.branchId,
    this.branchName,
    required this.reportDate,
    required this.totalSales,
    required this.cashAmount,
    required this.cashlessAmount,
    this.returnsCount = 0,
    this.returnsAmount = 0,
    this.hasInvoices = false,
    this.productsSold,
    this.note,
    this.createdBy,
    this.createdAt,
  });

  static double _num(dynamic v) {
    if (v == null) return 0;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString()) ?? 0;
  }

  static int _int(dynamic v) {
    if (v == null) return 0;
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse(v.toString()) ?? 0;
  }

  static DateTime _date(dynamic v) {
    if (v is DateTime) return v;
    if (v is String && v.isNotEmpty) {
      final parsed = DateTime.tryParse(v);
      if (parsed != null) return parsed;
    }
    return DateTime.now();
  }

  factory DailyReport.fromJson(Map<String, dynamic> json) {
    return DailyReport(
      id: _int(json['id']),
      branchId: _int(json['branch_id']),
      branchName: json['branch_name']?.toString(),
      reportDate: _date(json['report_date']),
      totalSales: _num(json['total_sales']),
      cashAmount: _num(json['cash_amount']),
      cashlessAmount: _num(json['cashless_amount']),
      returnsCount: _int(json['returns_count']),
      returnsAmount: _num(json['returns_amount']),
      hasInvoices: json['has_invoices'] == true,
      productsSold: json['products_sold']?.toString(),
      note: json['note']?.toString(),
      createdBy: json['created_by'] == null ? null : _int(json['created_by']),
      createdAt: json['created_at'] != null ? _date(json['created_at']) : null,
    );
  }

  Map<String, dynamic> toCreateJson({int? branchIdOverride}) {
    final map = <String, dynamic>{
      'report_date': _dateOnly(reportDate),
      'total_sales': totalSales,
      'cash_amount': cashAmount,
      'cashless_amount': cashlessAmount,
      'returns_count': returnsCount,
      'returns_amount': returnsAmount,
      'has_invoices': hasInvoices,
      'products_sold': productsSold,
      'note': note,
    };
    final bid = branchIdOverride ?? (branchId > 0 ? branchId : null);
    if (bid != null) map['branch_id'] = bid;
    return map;
  }

  Map<String, dynamic> toUpdateJson() {
    return {
      'report_date': _dateOnly(reportDate),
      'total_sales': totalSales,
      'cash_amount': cashAmount,
      'cashless_amount': cashlessAmount,
      'returns_count': returnsCount,
      'returns_amount': returnsAmount,
      'has_invoices': hasInvoices,
      'products_sold': productsSold,
      'note': note,
    };
  }

  static String _dateOnly(DateTime d) {
    final local = d.toLocal();
    final y = local.year.toString().padLeft(4, '0');
    final m = local.month.toString().padLeft(2, '0');
    final day = local.day.toString().padLeft(2, '0');
    return '$y-$m-$day';
  }

  @override
  List<Object?> get props => [
    id,
    branchId,
    branchName,
    reportDate,
    totalSales,
    cashAmount,
    cashlessAmount,
    returnsCount,
    returnsAmount,
    hasInvoices,
    productsSold,
    note,
    createdBy,
    createdAt,
  ];
}

/// Filters for listing daily reports (management).
class DailyReportFilters extends Equatable {
  final int? branchId;
  final String? dateFrom;
  final String? dateTo;

  const DailyReportFilters({this.branchId, this.dateFrom, this.dateTo});

  Map<String, dynamic> toQuery() {
    final q = <String, dynamic>{};
    if (branchId != null) q['branch_id'] = branchId;
    if (dateFrom != null && dateFrom!.isNotEmpty) q['date_from'] = dateFrom;
    if (dateTo != null && dateTo!.isNotEmpty) q['date_to'] = dateTo;
    return q;
  }

  @override
  List<Object?> get props => [branchId, dateFrom, dateTo];
}

/// Payload for create/update forms.
class DailyReportInput extends Equatable {
  final int? branchId;
  final DateTime reportDate;
  final double totalSales;
  final double cashAmount;
  final double cashlessAmount;
  final int returnsCount;
  final double returnsAmount;
  final bool hasInvoices;
  final String? productsSold;
  final String? note;

  const DailyReportInput({
    this.branchId,
    required this.reportDate,
    required this.totalSales,
    required this.cashAmount,
    required this.cashlessAmount,
    this.returnsCount = 0,
    this.returnsAmount = 0,
    this.hasInvoices = false,
    this.productsSold,
    this.note,
  });

  Map<String, dynamic> toCreateJson() {
    final map = <String, dynamic>{
      'report_date': DailyReport._dateOnly(reportDate),
      'total_sales': totalSales,
      'cash_amount': cashAmount,
      'cashless_amount': cashlessAmount,
      'returns_count': returnsCount,
      'returns_amount': returnsAmount,
      'has_invoices': hasInvoices,
      'products_sold': productsSold,
      'note': note,
    };
    if (branchId != null) map['branch_id'] = branchId;
    return map;
  }

  Map<String, dynamic> toUpdateJson() {
    return {
      'report_date': DailyReport._dateOnly(reportDate),
      'total_sales': totalSales,
      'cash_amount': cashAmount,
      'cashless_amount': cashlessAmount,
      'returns_count': returnsCount,
      'returns_amount': returnsAmount,
      'has_invoices': hasInvoices,
      'products_sold': productsSold,
      'note': note,
    };
  }

  @override
  List<Object?> get props => [
    branchId,
    reportDate,
    totalSales,
    cashAmount,
    cashlessAmount,
    returnsCount,
    returnsAmount,
    hasInvoices,
    productsSold,
    note,
  ];
}
