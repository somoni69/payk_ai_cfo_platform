import 'dart:collection';

import '../../../core/network/api_client.dart';
import '../../../core/network/user_facing_error.dart';
import '../../../core/network/expiring_request_cache.dart';
import '../domain/hr_models.dart';
import '../domain/hr_repository.dart';

/// Конкретная реализация репозитория кадров и KPI для бэкенда PAYK.
class ApiHrRepository implements HrRepository {
  final ApiClient _apiClient = ApiClient();
  final _employeesCache = ExpiringRequestCache<List<Employee>>();
  final _kpiCaches = BoundedPeriodRequestCache<List<KpiAlert>>(capacity: 8);
  final _salaryCaches = BoundedPeriodRequestCache<List<SalaryRecord>>(
    capacity: 8,
  );

  int _requirePositiveId(String value, String fieldName) {
    final id = int.tryParse(value);
    if (id == null || id <= 0) {
      throw ArgumentError.value(value, fieldName, ErrorKeys.invalidId);
    }
    return id;
  }

  double _toDouble(dynamic val) {
    if (val == null) return 0.0;
    if (val is num) return val.toDouble();
    return double.tryParse(val.toString()) ?? 0.0;
  }

  @override
  Future<List<Employee>> getEmployees({bool forceRefresh = false}) =>
      _employeesCache.get(_fetchEmployees, forceRefresh: forceRefresh);

  Future<List<Employee>> _fetchEmployees() async {
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
          createdAt: DateTime.parse(
            map['created_at'] ?? DateTime.now().toIso8601String(),
          ),
        );
      }).toList();
    } catch (e) {
      throw Exception(userFacingError(e, fallback: ErrorKeys.loadFailed));
    }
  }

  @override
  Future<List<KpiAlert>> getKpiAlerts(
    String period, {
    bool forceRefresh = false,
  }) => _kpiCaches.get(
    period,
    () => _fetchKpiAlerts(period),
    forceRefresh: forceRefresh,
  );

  Future<List<KpiAlert>> _fetchKpiAlerts(String period) async {
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
      throw Exception(userFacingError(e, fallback: ErrorKeys.loadFailed));
    }
  }

  @override
  Future<List<SalaryRecord>> getSalaryRecords(
    String period, {
    bool forceRefresh = false,
  }) => _salaryCaches.get(
    period,
    () => _fetchSalaryRecords(period),
    forceRefresh: forceRefresh,
  );

  Future<List<SalaryRecord>> _fetchSalaryRecords(String period) async {
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
      throw Exception(userFacingError(e, fallback: ErrorKeys.loadFailed));
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
        'employee_id': _requirePositiveId(employeeId, 'employeeId'),
        'period': period,
      };
      if (baseAmount != null) payload['base_amount'] = baseAmount;
      if (deductions != null) payload['deductions'] = deductions;
      if (bonusFormula != null) payload['bonus_formula'] = bonusFormula;

      final response = await _apiClient.dio.post(
        '/hr/salary/recalc',
        data: payload,
      );
      final map = response.data as Map<String, dynamic>;
      _salaryCaches.invalidate(period);

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
      throw Exception(userFacingError(e, fallback: ErrorKeys.loadFailed));
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

      final response = await _apiClient.dio.post(
        '/hr/employees',
        data: payload,
      );
      final map = response.data as Map<String, dynamic>;
      _employeesCache.invalidate();

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
        createdAt: DateTime.parse(
          map['created_at'] ?? DateTime.now().toIso8601String(),
        ),
      );
    } catch (e) {
      throw Exception(userFacingError(e, fallback: ErrorKeys.loadFailed));
    }
  }
}

class BoundedPeriodRequestCache<T> {
  final int capacity;
  final LinkedHashMap<String, ExpiringRequestCache<T>> _caches =
      LinkedHashMap();

  BoundedPeriodRequestCache({required this.capacity})
    : assert(capacity > 0, 'capacity must be positive');

  int get length => _caches.length;

  Iterable<String> get keys => _caches.keys;

  Future<T> get(
    String period,
    Future<T> Function() loader, {
    bool forceRefresh = false,
  }) {
    final existing = _caches.remove(period);
    final cache = existing ?? ExpiringRequestCache<T>();
    _caches[period] = cache;

    while (_caches.length > capacity) {
      _caches.remove(_caches.keys.first);
    }

    return cache.get(loader, forceRefresh: forceRefresh);
  }

  void invalidate(String period) => _caches[period]?.invalidate();
}
