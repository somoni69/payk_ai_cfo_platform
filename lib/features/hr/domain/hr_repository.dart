import 'hr_models.dart';

/// Абстрактный контракт для репозитория управления кадрами и KPI.
abstract class HrRepository {
  Future<List<Employee>> getEmployees({bool forceRefresh = false});

  Future<List<KpiAlert>> getKpiAlerts(
    String period, {
    bool forceRefresh = false,
  });

  Future<List<SalaryRecord>> getSalaryRecords(
    String period, {
    bool forceRefresh = false,
  });

  Future<SalaryRecord> recalcSalary({
    required String employeeId,
    required String period,
    double? baseAmount,
    double? deductions,
    String? bonusFormula,
  });

  Future<Employee> createEmployee(Employee employee);

  // --- Web-parity sections ---

  Future<List<OrgNode>> getOrgChart({bool forceRefresh = false});

  Future<List<AttendanceRecord>> getAttendance({
    String? employeeId,
    String? dateFrom,
    String? dateTo,
    bool forceRefresh = false,
  });

  Future<AttendanceRecord> createAttendance({
    required String employeeId,
    required DateTime workDate,
    required double hours,
  });

  Future<void> deleteAttendance(String id);

  Future<List<Candidate>> getCandidates({bool forceRefresh = false});

  Future<Candidate> createCandidate({
    required String fullName,
    required String vacancy,
    String? phone,
    String? email,
    String stage = 'new',
    String? note,
  });

  Future<Candidate> updateCandidateStage(String id, String stage);

  Future<void> deleteCandidate(String id);

  Future<List<HrEvaluation>> getEvaluations({
    String? period,
    bool forceRefresh = false,
  });

  Future<HrEvaluation> createEvaluation({
    required String employeeId,
    required String period,
    required int performance,
    required int potential,
    String? note,
  });

  Future<List<LaborContract>> getContracts({bool forceRefresh = false});

  Future<LaborContract> createContract({
    required String employeeId,
    required String number,
    required DateTime startDate,
    DateTime? endDate,
  });

  Future<void> deleteContract(String id);

  Future<MovementReport> getMovementReport({
    required String dateFrom,
    required String dateTo,
    bool forceRefresh = false,
  });
}
