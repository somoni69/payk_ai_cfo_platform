import 'package:equatable/equatable.dart';
import '../domain/hr_models.dart';

abstract class HrEvent extends Equatable {
  const HrEvent();

  @override
  List<Object?> get props => [];
}

/// Загрузка кадров, KPI и ведомостей за указанный период (ГГГГ-ММ)
class LoadHrData extends HrEvent {
  final String period;

  const LoadHrData(this.period);

  @override
  List<Object?> get props => [period];
}

/// Принять на работу сотрудника
class CreateEmployeeRequested extends HrEvent {
  final Employee employee;

  const CreateEmployeeRequested(this.employee);

  @override
  List<Object?> get props => [employee];
}

/// Пересчитать заработную плату
class RecalcSalaryRequested extends HrEvent {
  final String employeeId;
  final String period;
  final double? baseAmount;
  final double? deductions;
  final String? bonusFormula;

  const RecalcSalaryRequested({
    required this.employeeId,
    required this.period,
    this.baseAmount,
    this.deductions,
    this.bonusFormula,
  });

  @override
  List<Object?> get props => [employeeId, period, baseAmount, deductions, bonusFormula];
}
