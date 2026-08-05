/// Модель сотрудника компании.
class Employee {
  final String id;
  final String fullName;
  final String? position;
  final String? phone;
  final String? email;
  final double baseSalary;
  final String status; // 'active', 'vacation', 'fired', 'inactive'
  final String? departmentName;
  final String? managerName;
  final DateTime createdAt;
  final DateTime? hireDate;

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
    this.hireDate,
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
    DateTime? hireDate,
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
      hireDate: hireDate ?? this.hireDate,
    );
  }
}

/// Узел оргсхемы.
class OrgNode {
  final String id;
  final String fullName;
  final String? position;
  final String status;
  final List<OrgNode> children;

  const OrgNode({
    required this.id,
    required this.fullName,
    this.position,
    required this.status,
    this.children = const [],
  });
}

/// Запись табеля.
class AttendanceRecord {
  final String id;
  final String employeeId;
  final String? employeeName;
  final DateTime workDate;
  final double hours;

  const AttendanceRecord({
    required this.id,
    required this.employeeId,
    this.employeeName,
    required this.workDate,
    required this.hours,
  });
}

/// Кандидат (рекрутинг).
class Candidate {
  final String id;
  final String fullName;
  final String vacancy;
  final String? phone;
  final String? email;
  final String stage;
  final String? note;
  final DateTime createdAt;

  const Candidate({
    required this.id,
    required this.fullName,
    required this.vacancy,
    this.phone,
    this.email,
    required this.stage,
    this.note,
    required this.createdAt,
  });
}

/// Оценка 9-box (performance × potential).
class HrEvaluation {
  final String id;
  final String employeeId;
  final String? employeeName;
  final String? position;
  final String period;
  final int performance;
  final int potential;
  final String? note;

  const HrEvaluation({
    required this.id,
    required this.employeeId,
    this.employeeName,
    this.position,
    required this.period,
    required this.performance,
    required this.potential,
    this.note,
  });
}

/// Трудовой договор.
class LaborContract {
  final String id;
  final String employeeId;
  final String? employeeName;
  final String number;
  final DateTime startDate;
  final DateTime? endDate;
  final String status;
  final int? daysLeft;
  final bool isExpiring;

  const LaborContract({
    required this.id,
    required this.employeeId,
    this.employeeName,
    required this.number,
    required this.startDate,
    this.endDate,
    required this.status,
    this.daysLeft,
    this.isExpiring = false,
  });
}

/// Строка кадрового движения (приём / увольнение).
class MovementRow {
  final String id;
  final String fullName;
  final String? position;
  final DateTime? date;
  final bool isHire;

  const MovementRow({
    required this.id,
    required this.fullName,
    this.position,
    this.date,
    required this.isHire,
  });
}

class MovementReport {
  final List<MovementRow> hired;
  final List<MovementRow> fired;

  const MovementReport({this.hired = const [], this.fired = const []});
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
