/// Модель сотрудника компании.
class Employee {
  final String id;
  final String fullName;
  final String? position;
  final String? phone;
  final String? email;
  final double baseSalary;
  final String status; // 'active', 'vacation', 'fired'
  final String? departmentName;
  final String? managerName;
  final DateTime createdAt;

  const Employee({
    required this.id,
    required this.fullName,
    this.position,
    this.phone,
    this.email,
    required this.baseSalary,
    required this.status,
    this.departmentName,
    this.managerName,
    required this.createdAt,
  });

  Employee copyWith({
    String? id,
    String? fullName,
    String? position,
    String? phone,
    String? email,
    double? baseSalary,
    String? status,
    String? departmentName,
    String? managerName,
    DateTime? createdAt,
  }) {
    return Employee(
      id: id ?? this.id,
      fullName: fullName ?? this.fullName,
      position: position ?? this.position,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      baseSalary: baseSalary ?? this.baseSalary,
      status: status ?? this.status,
      departmentName: departmentName ?? this.departmentName,
      managerName: managerName ?? this.managerName,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

/// Модель нарушения или предупреждения по KPI сотрудника.
class KpiAlert {
  final String employeeId;
  final String employeeName;
  final String metric;
  final String period;
  final double planValue;
  final double factValue;
  final double completion;
  final double threshold;
  final bool triggered;
  final String? comment;

  const KpiAlert({
    required this.employeeId,
    required this.employeeName,
    required this.metric,
    required this.period,
    required this.planValue,
    required this.factValue,
    required this.completion,
    required this.threshold,
    required this.triggered,
    this.comment,
  });
}

/// Расчетная запись заработной платы за период.
class SalaryRecord {
  final String id;
  final String employeeId;
  final String employeeName;
  final String period; // ГГГГ-ММ
  final double baseAmount;
  final double bonusAmount;
  final double deductions;
  final double totalAmount;
  final String? bonusFormula;

  const SalaryRecord({
    required this.id,
    required this.employeeId,
    required this.employeeName,
    required this.period,
    required this.baseAmount,
    required this.bonusAmount,
    required this.deductions,
    required this.totalAmount,
    this.bonusFormula,
  });
}
