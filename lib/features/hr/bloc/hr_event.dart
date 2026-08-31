import 'dart:async';

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
  final bool forceRefresh;
  final Completer<void>? completion;

  const LoadHrData(this.period, {this.forceRefresh = false, this.completion});

  @override
  List<Object?> get props => [period, forceRefresh];
}

/// Lazy-load for optional HR sections (web-parity tabs).
enum HrSection { org, attendance, recruitment, nineBox, contracts, movement }

class LoadHrSection extends HrEvent {
  final HrSection section;
  final bool forceRefresh;
  final Completer<void>? completion;

  const LoadHrSection(
    this.section, {
    this.forceRefresh = false,
    this.completion,
  });

  @override
  List<Object?> get props => [section, forceRefresh];
}

class CreateEmployeeRequested extends HrEvent {
  final Employee employee;

  const CreateEmployeeRequested(this.employee);

  @override
  List<Object?> get props => [employee];
}

class UpdateEmployeeRequested extends HrEvent {
  final Employee employee;

  const UpdateEmployeeRequested(this.employee);

  @override
  List<Object?> get props => [employee];
}

class DeleteEmployeeRequested extends HrEvent {
  final String employeeId;

  const DeleteEmployeeRequested(this.employeeId);

  @override
  List<Object?> get props => [employeeId];
}

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
  List<Object?> get props => [
    employeeId,
    period,
    baseAmount,
    deductions,
    bonusFormula,
  ];
}

class CreateAttendanceRequested extends HrEvent {
  final String employeeId;
  final DateTime workDate;
  final double hours;

  const CreateAttendanceRequested({
    required this.employeeId,
    required this.workDate,
    required this.hours,
  });

  @override
  List<Object?> get props => [employeeId, workDate, hours];
}

class DeleteAttendanceRequested extends HrEvent {
  final String id;

  const DeleteAttendanceRequested(this.id);

  @override
  List<Object?> get props => [id];
}

class CreateCandidateRequested extends HrEvent {
  final String fullName;
  final String vacancy;
  final String? phone;
  final String? email;

  const CreateCandidateRequested({
    required this.fullName,
    required this.vacancy,
    this.phone,
    this.email,
  });

  @override
  List<Object?> get props => [fullName, vacancy, phone, email];
}

class UpdateCandidateStageRequested extends HrEvent {
  final String id;
  final String stage;

  const UpdateCandidateStageRequested({required this.id, required this.stage});

  @override
  List<Object?> get props => [id, stage];
}

class DeleteCandidateRequested extends HrEvent {
  final String id;

  const DeleteCandidateRequested(this.id);

  @override
  List<Object?> get props => [id];
}

class CreateEvaluationRequested extends HrEvent {
  final String employeeId;
  final String period;
  final int performance;
  final int potential;
  final String? note;

  const CreateEvaluationRequested({
    required this.employeeId,
    required this.period,
    required this.performance,
    required this.potential,
    this.note,
  });

  @override
  List<Object?> get props => [employeeId, period, performance, potential, note];
}

class CreateContractRequested extends HrEvent {
  final String employeeId;
  final String number;
  final DateTime startDate;
  final DateTime? endDate;

  const CreateContractRequested({
    required this.employeeId,
    required this.number,
    required this.startDate,
    this.endDate,
  });

  @override
  List<Object?> get props => [employeeId, number, startDate, endDate];
}

class DeleteContractRequested extends HrEvent {
  final String id;

  const DeleteContractRequested(this.id);

  @override
  List<Object?> get props => [id];
}

// --- KPI Events ---

class CreateKpiRequested extends HrEvent {
  final String employeeId;
  final String period;
  final String metric;
  final double planValue;
  final double factValue;

  const CreateKpiRequested({
    required this.employeeId,
    required this.period,
    required this.metric,
    required this.planValue,
    required this.factValue,
  });

  @override
  List<Object?> get props => [employeeId, period, metric, planValue, factValue];
}

class UpdateKpiRequested extends HrEvent {
  final String kpiId;
  final String? metric;
  final double? planValue;
  final double? factValue;

  const UpdateKpiRequested({
    required this.kpiId,
    this.metric,
    this.planValue,
    this.factValue,
  });

  @override
  List<Object?> get props => [kpiId, metric, planValue, factValue];
}

class DeleteKpiRequested extends HrEvent {
  final String kpiId;

  const DeleteKpiRequested(this.kpiId);

  @override
  List<Object?> get props => [kpiId];
}

// --- Employee Lifecycle & iiko Events ---

class BlockEmployeeRequested extends HrEvent {
  final String employeeId;

  const BlockEmployeeRequested(this.employeeId);

  @override
  List<Object?> get props => [employeeId];
}

class UnblockEmployeeRequested extends HrEvent {
  final String employeeId;

  const UnblockEmployeeRequested(this.employeeId);

  @override
  List<Object?> get props => [employeeId];
}

class ArchiveEmployeeRequested extends HrEvent {
  final String employeeId;

  const ArchiveEmployeeRequested(this.employeeId);

  @override
  List<Object?> get props => [employeeId];
}

class RestoreEmployeeRequested extends HrEvent {
  final String employeeId;

  const RestoreEmployeeRequested(this.employeeId);

  @override
  List<Object?> get props => [employeeId];
}

class SyncIikoEmployeesRequested extends HrEvent {
  const SyncIikoEmployeesRequested();
}
