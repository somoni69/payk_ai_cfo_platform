import 'package:equatable/equatable.dart';
import '../domain/hr_models.dart';

abstract class HrState extends Equatable {
  const HrState();

  @override
  List<Object?> get props => [];
}

class HrLoading extends HrState {}

class HrLoaded extends HrState {
  final List<Employee> employees;
  final List<KpiAlert> kpiAlerts;
  final List<SalaryRecord> salaryRecords;
  final String period;
  final String? errorMessage;
  final String? successMessage;

  const HrLoaded({
    required this.employees,
    required this.kpiAlerts,
    required this.salaryRecords,
    required this.period,
    this.errorMessage,
    this.successMessage,
  });

  HrLoaded copyWith({
    List<Employee>? employees,
    List<KpiAlert>? kpiAlerts,
    List<SalaryRecord>? salaryRecords,
    String? period,
    String? errorMessage,
    String? successMessage,
    bool clearError = false,
    bool clearSuccess = false,
  }) {
    return HrLoaded(
      employees: employees ?? this.employees,
      kpiAlerts: kpiAlerts ?? this.kpiAlerts,
      salaryRecords: salaryRecords ?? this.salaryRecords,
      period: period ?? this.period,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      successMessage: clearSuccess ? null : (successMessage ?? this.successMessage),
    );
  }

  @override
  List<Object?> get props => [
        employees,
        kpiAlerts,
        salaryRecords,
        period,
        errorMessage,
        successMessage,
      ];
}

class HrError extends HrState {
  final String message;

  const HrError(this.message);

  @override
  List<Object?> get props => [message];
}
