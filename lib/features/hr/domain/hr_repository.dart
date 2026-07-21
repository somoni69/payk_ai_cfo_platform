import 'hr_models.dart';

/// Абстрактный контракт для репозитория управления кадрами и KPI.
abstract class HrRepository {
  /// Получить полный список сотрудников
  Future<List<Employee>> getEmployees({bool forceRefresh = false});

  /// Получить предупреждения по невыполнению KPI за указанный период (ГГГГ-ММ)
  Future<List<KpiAlert>> getKpiAlerts(
    String period, {
    bool forceRefresh = false,
  });

  /// Получить расчетную ведомость по зарплатам за период (ГГГГ-ММ)
  Future<List<SalaryRecord>> getSalaryRecords(
    String period, {
    bool forceRefresh = false,
  });

  /// Пересчитать заработную плату конкретного сотрудника
  Future<SalaryRecord> recalcSalary({
    required String employeeId,
    required String period,
    double? baseAmount,
    double? deductions,
    String? bonusFormula,
  });

  /// Принять нового сотрудника на работу
  Future<Employee> createEmployee(Employee employee);
}
