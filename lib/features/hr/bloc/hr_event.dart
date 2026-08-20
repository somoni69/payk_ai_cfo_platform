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
