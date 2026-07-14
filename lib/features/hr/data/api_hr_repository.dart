import '../../../core/network/api_client.dart';
import '../domain/hr_models.dart';
import '../domain/hr_repository.dart';

/// Конкретная реализация репозитория кадров и KPI для бэкенда PAYK.
class ApiHrRepository implements HrRepository {
  final ApiClient _apiClient = ApiClient();

  double _toDouble(dynamic val) {
    if (val == null) return 0.0;
    if (val is num) return val.toDouble();
    return double.tryParse(val.toString()) ?? 0.0;
  }

  @override
  Future<List<Employee>> getEmployees() async {
    try {
      // Запрашиваем первую страницу с большим размером для мобильного списка
      final response = await _apiClient.dio.get(
        '/hr/employees',
        queryParameters: {'page': 1, 'size': 100},
      );
      final dataMap = response.data as Map<String, dynamic>;
      final list = (dataMap['items'] ?? []) as List<dynamic>;

      return list.map((item) {
        final map = item as Map<String, dynamic>;
        return Employee(
          id: (map['id'] ?? '').toString(),
          fullName: map['full_name'] ?? '',
          position: map['position']?.toString(),
          phone: map['phone']?.toString(),
          email: map['email']?.toString(),
          baseSalary: _toDouble(map['base_salary']),
          status: map['status'] ?? 'active',
          departmentName: map['department_name']?.toString(),
          managerName: map['manager_name']?.toString(),
          createdAt: DateTime.parse(map['created_at'] ?? DateTime.now().toIso8601String()),
        );
      }).toList();
    } catch (e) {
      throw Exception('Не удалось загрузить сотрудников: ${e.toString()}');
    }
  }

  @override
  Future<List<KpiAlert>> getKpiAlerts(String period) async {
    try {
      final response = await _apiClient.dio.get(
        '/hr/kpi/alerts',
        queryParameters: {'period': period},
      );
      final list = response.data as List<dynamic>;

      return list.map((item) {
        final map = item as Map<String, dynamic>;
        return KpiAlert(
          employeeId: (map['employee_id'] ?? '').toString(),
          employeeName: map['employee_name'] ?? '',
          metric: map['metric'] ?? '',
          period: map['period'] ?? '',
          planValue: _toDouble(map['plan_value']),
          factValue: _toDouble(map['fact_value']),
          completion: _toDouble(map['completion']),
          threshold: _toDouble(map['threshold']),
          triggered: map['triggered'] ?? false,
          comment: map['comment']?.toString(),
        );
      }).toList();
    } catch (e) {
      throw Exception('Не удалось загрузить предупреждения по KPI: ${e.toString()}');
    }
  }

  @override
  Future<List<SalaryRecord>> getSalaryRecords(String period) async {
    try {
      final response = await _apiClient.dio.get(
        '/hr/salary',
        queryParameters: {'period': period},
      );
      final list = response.data as List<dynamic>;

      return list.map((item) {
        final map = item as Map<String, dynamic>;
        return SalaryRecord(
          id: (map['id'] ?? '').toString(),
          employeeId: (map['employee_id'] ?? '').toString(),
          employeeName: map['employee_name'] ?? 'Сотрудник',
          period: map['period'] ?? '',
          baseAmount: _toDouble(map['base_amount']),
          bonusAmount: _toDouble(map['bonus_amount']),
          deductions: _toDouble(map['deductions']),
          totalAmount: _toDouble(map['total_amount']),
          bonusFormula: map['bonus_formula']?.toString(),
        );
      }).toList();
    } catch (e) {
      throw Exception('Не удалось загрузить расчетную ведомость: ${e.toString()}');
    }
  }

  @override
  Future<SalaryRecord> recalcSalary({
    required String employeeId,
    required String period,
    double? baseAmount,
    double? deductions,
    String? bonusFormula,
  }) async {
    try {
      final payload = <String, dynamic>{
        'employee_id': int.tryParse(employeeId) ?? 0,
        'period': period,
      };
      if (baseAmount != null) payload['base_amount'] = baseAmount;
      if (deductions != null) payload['deductions'] = deductions;
      if (bonusFormula != null) payload['bonus_formula'] = bonusFormula;

      final response = await _apiClient.dio.post('/hr/salary/recalc', data: payload);
      final map = response.data as Map<String, dynamic>;

      return SalaryRecord(
        id: (map['id'] ?? '').toString(),
        employeeId: (map['employee_id'] ?? '').toString(),
        employeeName: map['employee_name'] ?? 'Сотрудник',
        period: map['period'] ?? '',
        baseAmount: _toDouble(map['base_amount']),
        bonusAmount: _toDouble(map['bonus_amount']),
        deductions: _toDouble(map['deductions']),
        totalAmount: _toDouble(map['total_amount']),
        bonusFormula: map['bonus_formula']?.toString(),
      );
    } catch (e) {
      throw Exception('Не удалось пересчитать зарплату: ${e.toString()}');
    }
  }

  @override
  Future<Employee> createEmployee(Employee employee) async {
    try {
      final payload = {
        'full_name': employee.fullName,
        'position': employee.position,
        'phone': employee.phone,
        'email': employee.email,
        'base_salary': employee.baseSalary,
        'status': employee.status,
        'hire_date': DateTime.now().toIso8601String().substring(0, 10),
      };

      final response = await _apiClient.dio.post('/hr/employees', data: payload);
      final map = response.data as Map<String, dynamic>;

      return Employee(
        id: (map['id'] ?? '').toString(),
        fullName: map['full_name'] ?? '',
        position: map['position']?.toString(),
        phone: map['phone']?.toString(),
        email: map['email']?.toString(),
        baseSalary: _toDouble(map['base_salary']),
        status: map['status'] ?? 'active',
        departmentName: map['department_name']?.toString(),
        managerName: map['manager_name']?.toString(),
        createdAt: DateTime.parse(map['created_at'] ?? DateTime.now().toIso8601String()),
      );
    } catch (e) {
      throw Exception('Не удалось зарегистрировать сотрудника: ${e.toString()}');
    }
  }
}
