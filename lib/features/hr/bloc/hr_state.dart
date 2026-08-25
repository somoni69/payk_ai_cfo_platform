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
  final List<KpiRecord> kpiRecords;
  final List<KpiAlert> kpiAlerts;
  final List<SalaryRecord> salaryRecords;
  final String period;

  final List<OrgNode> orgChart;
  final bool orgLoaded;
  final List<AttendanceRecord> attendance;
  final bool attendanceLoaded;
  final List<Candidate> candidates;
  final bool candidatesLoaded;
  final List<HrEvaluation> evaluations;
  final bool evaluationsLoaded;
  final List<LaborContract> contracts;
  final bool contractsLoaded;
  final MovementReport? movement;
  final bool movementLoaded;
  final bool sectionLoading;

  final String? errorMessage;
  final String? successMessage;
  final bool isRefreshing;

  const HrLoaded({
    required this.employees,
    this.kpiRecords = const [],
    required this.kpiAlerts,
    required this.salaryRecords,
    required this.period,
    this.orgChart = const [],
    this.orgLoaded = false,
    this.attendance = const [],
    this.attendanceLoaded = false,
    this.candidates = const [],
    this.candidatesLoaded = false,
    this.evaluations = const [],
    this.evaluationsLoaded = false,
    this.contracts = const [],
    this.contractsLoaded = false,
    this.movement,
    this.movementLoaded = false,
    this.sectionLoading = false,
    this.errorMessage,
    this.successMessage,
    this.isRefreshing = false,
  });

  HrLoaded copyWith({
    List<Employee>? employees,
    List<KpiRecord>? kpiRecords,
    List<KpiAlert>? kpiAlerts,
    List<SalaryRecord>? salaryRecords,
    String? period,
    List<OrgNode>? orgChart,
    bool? orgLoaded,
    List<AttendanceRecord>? attendance,
    bool? attendanceLoaded,
    List<Candidate>? candidates,
    bool? candidatesLoaded,
    List<HrEvaluation>? evaluations,
    bool? evaluationsLoaded,
    List<LaborContract>? contracts,
    bool? contractsLoaded,
    MovementReport? movement,
    bool? movementLoaded,
    bool? sectionLoading,
    String? errorMessage,
    String? successMessage,
    bool clearError = false,
    bool clearSuccess = false,
    bool? isRefreshing,
  }) {
    return HrLoaded(
      employees: employees ?? this.employees,
      kpiRecords: kpiRecords ?? this.kpiRecords,
      kpiAlerts: kpiAlerts ?? this.kpiAlerts,
      salaryRecords: salaryRecords ?? this.salaryRecords,
      period: period ?? this.period,
      orgChart: orgChart ?? this.orgChart,
      orgLoaded: orgLoaded ?? this.orgLoaded,
      attendance: attendance ?? this.attendance,
      attendanceLoaded: attendanceLoaded ?? this.attendanceLoaded,
      candidates: candidates ?? this.candidates,
      candidatesLoaded: candidatesLoaded ?? this.candidatesLoaded,
      evaluations: evaluations ?? this.evaluations,
      evaluationsLoaded: evaluationsLoaded ?? this.evaluationsLoaded,
      contracts: contracts ?? this.contracts,
      contractsLoaded: contractsLoaded ?? this.contractsLoaded,
      movement: movement ?? this.movement,
      movementLoaded: movementLoaded ?? this.movementLoaded,
      sectionLoading: sectionLoading ?? this.sectionLoading,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      successMessage: clearSuccess
          ? null
          : (successMessage ?? this.successMessage),
      isRefreshing: isRefreshing ?? this.isRefreshing,
    );
  }

  @override
  List<Object?> get props => [
    employees,
    kpiRecords,
    kpiAlerts,
    salaryRecords,
    period,
    orgChart,
    orgLoaded,
    attendance,
    attendanceLoaded,
    candidates,
    candidatesLoaded,
    evaluations,
    evaluationsLoaded,
    contracts,
    contractsLoaded,
    movement,
    movementLoaded,
    sectionLoading,
    errorMessage,
    successMessage,
    isRefreshing,
  ];
}

class HrError extends HrState {
  final String message;

  const HrError(this.message);

  @override
  List<Object?> get props => [message];
}
