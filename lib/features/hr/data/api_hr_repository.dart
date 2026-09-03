import 'dart:collection';
import 'package:dio/dio.dart';

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
  final _kpiRecordsCaches = BoundedPeriodRequestCache<List<KpiRecord>>(
    capacity: 8,
  );
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
  Future<List<Employee>> getEmployees({
    bool forceRefresh = false,
    bool archived = false,
  }) => _employeesCache.get(
    () => _fetchEmployees(archived: archived),
    forceRefresh: forceRefresh,
  );

  Future<List<Employee>> _fetchEmployees({bool archived = false}) async {
    try {
      // Запрашиваем первую страницу с большим размером для мобильного списка
      final response = await _apiClient.dio.get(
        '/hr/employees',
        queryParameters: {'page': 1, 'size': 100, 'archived': archived},
      );
      final dataMap = response.data as Map<String, dynamic>;
      final list = (dataMap['items'] ?? []) as List<dynamic>;

      return list.map((item) {
        final map = item as Map<String, dynamic>;
        return _mapEmployee(map);
      }).toList();
    } catch (e) {
      throw Exception(userFacingError(e, fallback: ErrorKeys.loadFailed));
    }
  }

  Employee _mapEmployee(Map<String, dynamic> map) {
    return Employee(
      id: (map['id'] ?? '').toString(),
      fullName: map['full_name'] ?? '',
      position: map['position']?.toString(),
      phone: map['phone']?.toString(),
      email: map['email']?.toString(),
      baseSalary: _toDouble(map['base_salary']),
      status: map['status'] ?? 'active',
      isArchived: map['is_archived'] == true,
      departmentName: map['department_name']?.toString(),
      managerName: map['manager_name']?.toString(),
      createdAt: DateTime.parse(
        map['created_at'] ?? DateTime.now().toIso8601String(),
      ),
      hireDate: map['hire_date'] != null
          ? DateTime.tryParse(map['hire_date'].toString())
          : null,
      departmentId: map['department_id']?.toString(),
      managerId: map['manager_id']?.toString(),
      branchId: map['branch_id']?.toString(),
      photoUrl: map['photo_url']?.toString(),
    );
  }

  DateTime? _parseDate(dynamic v) {
    if (v == null) return null;
    if (v is DateTime) return v;
    if (v is String && v.isNotEmpty) return DateTime.tryParse(v);
    return null;
  }

  String _dateOnly(DateTime d) {
    final y = d.year.toString().padLeft(4, '0');
    final m = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    return '$y-$m-$day';
  }

  OrgNode _mapOrgNode(Map<String, dynamic> map) {
    final childrenRaw = map['children'];
    final children = childrenRaw is List
        ? childrenRaw
              .whereType<Map>()
              .map((e) => _mapOrgNode(Map<String, dynamic>.from(e)))
              .toList()
        : const <OrgNode>[];
    return OrgNode(
      id: (map['id'] ?? '').toString(),
      fullName: map['full_name']?.toString() ?? '',
      position: map['position']?.toString(),
      status: map['status']?.toString() ?? 'active',
      children: children,
    );
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
        queryParameters: {'period': period, 'with_ai': true},
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
  Future<List<KpiRecord>> getKpis({
    String? period,
    String? employeeId,
    bool forceRefresh = false,
  }) {
    final cacheKey = '${period ?? 'all'}_${employeeId ?? 'all'}';
    return _kpiRecordsCaches.get(
      cacheKey,
      () => _fetchKpis(period: period, employeeId: employeeId),
      forceRefresh: forceRefresh,
    );
  }

  Future<List<KpiRecord>> _fetchKpis({
    String? period,
    String? employeeId,
  }) async {
    try {
      final params = <String, dynamic>{};
      if (period != null) params['period'] = period;
      if (employeeId != null) {
        params['employee_id'] = _requirePositiveId(employeeId, 'employeeId');
      }
      final response = await _apiClient.dio.get(
        '/hr/kpi',
        queryParameters: params,
      );
      final list = response.data as List<dynamic>? ?? [];

      return list.map((item) {
        final map = item as Map<String, dynamic>;
        return KpiRecord(
          id: (map['id'] ?? '').toString(),
          employeeId: (map['employee_id'] ?? '').toString(),
          employeeName: map['employee_name']?.toString(),
          period: map['period'] ?? '',
          metric: map['metric'] ?? '',
          planValue: _toDouble(map['plan_value']),
          factValue: _toDouble(map['fact_value']),
          completion: map['completion'] != null
              ? _toDouble(map['completion'])
              : null,
        );
      }).toList();
    } catch (e) {
      throw Exception(userFacingError(e, fallback: ErrorKeys.loadFailed));
    }
  }

  @override
  Future<KpiRecord> createKpi({
    required String employeeId,
    required String period,
    required String metric,
    required double planValue,
    required double factValue,
  }) async {
    try {
      final response = await _apiClient.dio.post(
        '/hr/kpi',
        data: {
          'employee_id': _requirePositiveId(employeeId, 'employeeId'),
          'period': period,
          'metric': metric,
          'plan_value': planValue,
          'fact_value': factValue,
        },
      );
      final map = response.data as Map<String, dynamic>;
      _kpiRecordsCaches.invalidate('${period}_all');
      _kpiCaches.invalidate(period);

      return KpiRecord(
        id: (map['id'] ?? '').toString(),
        employeeId: (map['employee_id'] ?? employeeId).toString(),
        employeeName: map['employee_name']?.toString(),
        period: map['period'] ?? period,
        metric: map['metric'] ?? metric,
        planValue: _toDouble(map['plan_value']),
        factValue: _toDouble(map['fact_value']),
        completion: map['completion'] != null
            ? _toDouble(map['completion'])
            : null,
      );
    } catch (e) {
      throw Exception(userFacingError(e, fallback: ErrorKeys.saveFailed));
    }
  }

  @override
  Future<KpiRecord> updateKpi({
    required String kpiId,
    String? metric,
    double? planValue,
    double? factValue,
  }) async {
    try {
      final payload = <String, dynamic>{};
      if (metric != null) payload['metric'] = metric;
      if (planValue != null) payload['plan_value'] = planValue;
      if (factValue != null) payload['fact_value'] = factValue;

      final response = await _apiClient.dio.patch(
        '/hr/kpi/${_requirePositiveId(kpiId, 'kpiId')}',
        data: payload,
      );
      final map = response.data as Map<String, dynamic>;
      final period = map['period']?.toString() ?? '';
      if (period.isNotEmpty) {
        _kpiRecordsCaches.invalidate('${period}_all');
        _kpiCaches.invalidate(period);
      }

      return KpiRecord(
        id: (map['id'] ?? kpiId).toString(),
        employeeId: (map['employee_id'] ?? '').toString(),
        employeeName: map['employee_name']?.toString(),
        period: period,
        metric: map['metric'] ?? '',
        planValue: _toDouble(map['plan_value']),
        factValue: _toDouble(map['fact_value']),
        completion: map['completion'] != null
            ? _toDouble(map['completion'])
            : null,
      );
    } catch (e) {
      throw Exception(userFacingError(e, fallback: ErrorKeys.saveFailed));
    }
  }

  @override
  Future<void> deleteKpi(String kpiId) async {
    try {
      await _apiClient.dio.delete(
        '/hr/kpi/${_requirePositiveId(kpiId, 'kpiId')}',
      );
    } catch (e) {
      throw Exception(userFacingError(e, fallback: ErrorKeys.saveFailed));
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
          aidDeduction: _toDouble(map['aid_deduction']),
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
        aidDeduction: _toDouble(map['aid_deduction']),
        totalAmount: _toDouble(map['total_amount']),
        bonusFormula: map['bonus_formula']?.toString(),
      );
    } catch (e) {
      throw Exception(userFacingError(e, fallback: ErrorKeys.loadFailed));
    }
  }

  @override
  Future<List<int>> downloadSalaryCertificatePdf(String employeeId) async {
    try {
      final response = await _apiClient.dio.get<List<int>>(
        '/hr/employees/${_requirePositiveId(employeeId, 'employeeId')}/salary-certificate',
        queryParameters: {'fmt': 'pdf'},
        options: Options(responseType: ResponseType.bytes),
      );
      return response.data ?? <int>[];
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
        'hire_date': (employee.hireDate ?? DateTime.now())
            .toIso8601String()
            .substring(0, 10),
        if (employee.departmentId != null && employee.departmentId!.isNotEmpty)
          'department_id': int.tryParse(employee.departmentId!),
        if (employee.managerId != null)
          'manager_id': int.tryParse(employee.managerId!),
        if (employee.branchId != null)
          'branch_id': int.tryParse(employee.branchId!),
        if (employee.photoUrl != null) 'photo_url': employee.photoUrl,
      };

      final response = await _apiClient.dio.post(
        '/hr/employees',
        data: payload,
      );
      final map = response.data as Map<String, dynamic>;
      _employeesCache.invalidate();

      return _mapEmployee(map);
    } catch (e) {
      throw Exception(userFacingError(e, fallback: ErrorKeys.loadFailed));
    }
  }

  @override
  Future<List<HrDepartment>> getDepartments() async {
    try {
      final response = await _apiClient.dio.get('/hr/departments');
      final list = response.data is List ? response.data as List : const [];
      return list.whereType<Map>().map((raw) {
        final m = Map<String, dynamic>.from(raw);
        return HrDepartment(
          id: (m['id'] ?? '').toString(),
          name: (m['name'] ?? '').toString(),
          parentId: m['parent_id']?.toString(),
        );
      }).toList();
    } catch (e) {
      throw Exception(userFacingError(e, fallback: ErrorKeys.loadFailed));
    }
  }

  @override
  Future<Employee> updateEmployee(Employee employee) async {
    try {
      final payload = <String, dynamic>{
        'full_name': employee.fullName,
        'position': employee.position,
        'phone': employee.phone,
        'email': employee.email,
        'base_salary': employee.baseSalary,
        'status': employee.status,
        if (employee.hireDate != null)
          'hire_date': employee.hireDate!.toIso8601String().substring(0, 10),
        if (employee.departmentId != null && employee.departmentId!.isNotEmpty)
          'department_id': int.tryParse(employee.departmentId!),
      };
      final response = await _apiClient.dio.patch(
        '/hr/employees/${_requirePositiveId(employee.id, 'employeeId')}',
        data: payload,
      );
      _employeesCache.invalidate();
      return _mapEmployee(Map<String, dynamic>.from(response.data as Map));
    } catch (e) {
      throw Exception(userFacingError(e, fallback: ErrorKeys.saveFailed));
    }
  }

  @override
  Future<void> deleteEmployee(String employeeId) async {
    try {
      await _apiClient.dio.delete(
        '/hr/employees/${_requirePositiveId(employeeId, 'employeeId')}',
      );
      _employeesCache.invalidate();
    } catch (e) {
      throw Exception(userFacingError(e, fallback: ErrorKeys.saveFailed));
    }
  }

  @override
  Future<void> blockEmployee(String employeeId) async {
    try {
      await _apiClient.dio.post(
        '/hr/employees/${_requirePositiveId(employeeId, 'employeeId')}/block',
      );
      _employeesCache.invalidate();
    } catch (e) {
      throw Exception(userFacingError(e, fallback: ErrorKeys.saveFailed));
    }
  }

  @override
  Future<void> unblockEmployee(String employeeId) async {
    try {
      await _apiClient.dio.post(
        '/hr/employees/${_requirePositiveId(employeeId, 'employeeId')}/unblock',
      );
      _employeesCache.invalidate();
    } catch (e) {
      throw Exception(userFacingError(e, fallback: ErrorKeys.saveFailed));
    }
  }

  @override
  Future<void> archiveEmployee(String employeeId) async {
    try {
      await _apiClient.dio.post(
        '/hr/employees/${_requirePositiveId(employeeId, 'employeeId')}/archive',
      );
      _employeesCache.invalidate();
    } catch (e) {
      throw Exception(userFacingError(e, fallback: ErrorKeys.saveFailed));
    }
  }

  @override
  Future<void> restoreEmployee(String employeeId) async {
    try {
      await _apiClient.dio.post(
        '/hr/employees/${_requirePositiveId(employeeId, 'employeeId')}/restore',
      );
      _employeesCache.invalidate();
    } catch (e) {
      throw Exception(userFacingError(e, fallback: ErrorKeys.saveFailed));
    }
  }

  @override
  Future<int> syncIikoEmployees() async {
    try {
      final response = await _apiClient.dio.post('/hr/employees/sync-iiko');
      _employeesCache.invalidate();
      final data = response.data;
      if (data is Map && data['records'] is num) {
        return (data['records'] as num).toInt();
      }
      return 0;
    } catch (e) {
      throw Exception(userFacingError(e, fallback: ErrorKeys.saveFailed));
    }
  }

  @override
  Future<List<EmployeeDocument>> getEmployeeDocuments(String employeeId) async {
    try {
      final response = await _apiClient.dio.get(
        '/hr/employees/${_requirePositiveId(employeeId, 'employeeId')}/documents',
      );
      final list = response.data as List<dynamic>? ?? [];
      return list.whereType<Map>().map((item) {
        final map = Map<String, dynamic>.from(item);
        return EmployeeDocument(
          id: (map['id'] ?? '').toString(),
          employeeId: (map['employee_id'] ?? employeeId).toString(),
          name: map['name']?.toString() ?? 'Документ',
          url: map['url']?.toString() ?? '',
          createdAt: _parseDate(map['created_at']) ?? DateTime.now(),
        );
      }).toList();
    } catch (e) {
      throw Exception(userFacingError(e, fallback: ErrorKeys.loadFailed));
    }
  }

  @override
  Future<EmployeeDocument> uploadEmployeeDocument({
    required String employeeId,
    required String filename,
    required List<int> bytes,
  }) async {
    try {
      final form = FormData.fromMap({
        'file': MultipartFile.fromBytes(bytes, filename: filename),
      });
      final response = await _apiClient.dio.post(
        '/hr/employees/${_requirePositiveId(employeeId, 'employeeId')}/documents',
        data: form,
      );
      final map = Map<String, dynamic>.from(response.data as Map);
      return EmployeeDocument(
        id: (map['id'] ?? '').toString(),
        employeeId: employeeId,
        name: map['name']?.toString() ?? filename,
        url: map['url']?.toString() ?? '',
        createdAt: _parseDate(map['created_at']) ?? DateTime.now(),
      );
    } catch (e) {
      throw Exception(userFacingError(e, fallback: ErrorKeys.saveFailed));
    }
  }

  @override
  Future<List<int>> downloadEmployeeDocument({
    required String employeeId,
    required String documentId,
  }) async {
    try {
      final response = await _apiClient.dio.get<List<int>>(
        '/hr/employees/${_requirePositiveId(employeeId, 'employeeId')}/documents/${_requirePositiveId(documentId, 'documentId')}/download',
        options: Options(responseType: ResponseType.bytes),
      );
      return response.data ?? <int>[];
    } catch (e) {
      throw Exception(userFacingError(e, fallback: ErrorKeys.loadFailed));
    }
  }

  @override
  Future<void> deleteEmployeeDocument({
    required String employeeId,
    required String documentId,
  }) async {
    try {
      await _apiClient.dio.delete(
        '/hr/employees/${_requirePositiveId(employeeId, 'employeeId')}/documents/${_requirePositiveId(documentId, 'documentId')}',
      );
    } catch (e) {
      throw Exception(userFacingError(e, fallback: ErrorKeys.saveFailed));
    }
  }

  @override
  Future<List<OrgNode>> getOrgChart({bool forceRefresh = false}) async {
    try {
      final response = await _apiClient.dio.get('/hr/org-chart');
      final list = response.data as List<dynamic>? ?? [];
      return list
          .whereType<Map>()
          .map((e) => _mapOrgNode(Map<String, dynamic>.from(e)))
          .toList();
    } catch (e) {
      throw Exception(userFacingError(e, fallback: ErrorKeys.loadFailed));
    }
  }

  @override
  Future<List<AttendanceRecord>> getAttendance({
    String? employeeId,
    String? dateFrom,
    String? dateTo,
    bool forceRefresh = false,
  }) async {
    try {
      final params = <String, dynamic>{};
      if (employeeId != null && employeeId.isNotEmpty) {
        params['employee_id'] = _requirePositiveId(employeeId, 'employeeId');
      }
      if (dateFrom != null) params['date_from'] = dateFrom;
      if (dateTo != null) params['date_to'] = dateTo;
      final response = await _apiClient.dio.get(
        '/hr/attendance',
        queryParameters: params,
      );
      final list = response.data as List<dynamic>? ?? [];
      return list.whereType<Map>().map((item) {
        final map = Map<String, dynamic>.from(item);
        return AttendanceRecord(
          id: (map['id'] ?? '').toString(),
          employeeId: (map['employee_id'] ?? '').toString(),
          employeeName: map['employee_name']?.toString(),
          workDate: _parseDate(map['work_date']) ?? DateTime.now(),
          hours: _toDouble(map['hours']),
        );
      }).toList();
    } catch (e) {
      throw Exception(userFacingError(e, fallback: ErrorKeys.loadFailed));
    }
  }

  @override
  Future<AttendanceRecord> createAttendance({
    required String employeeId,
    required DateTime workDate,
    required double hours,
  }) async {
    try {
      final response = await _apiClient.dio.post(
        '/hr/attendance',
        data: {
          'employee_id': _requirePositiveId(employeeId, 'employeeId'),
          'work_date': _dateOnly(workDate),
          'hours': hours,
        },
      );
      final map = Map<String, dynamic>.from(response.data as Map);
      return AttendanceRecord(
        id: (map['id'] ?? '').toString(),
        employeeId: (map['employee_id'] ?? '').toString(),
        employeeName: map['employee_name']?.toString(),
        workDate: _parseDate(map['work_date']) ?? workDate,
        hours: _toDouble(map['hours']),
      );
    } catch (e) {
      throw Exception(userFacingError(e, fallback: ErrorKeys.saveFailed));
    }
  }

  @override
  Future<void> deleteAttendance(String id) async {
    try {
      await _apiClient.dio.delete(
        '/hr/attendance/${_requirePositiveId(id, 'id')}',
      );
    } catch (e) {
      throw Exception(userFacingError(e, fallback: ErrorKeys.saveFailed));
    }
  }

  @override
  Future<List<Candidate>> getCandidates({bool forceRefresh = false}) async {
    try {
      final response = await _apiClient.dio.get('/hr/candidates');
      final list = response.data as List<dynamic>? ?? [];
      return list.whereType<Map>().map((item) {
        final map = Map<String, dynamic>.from(item);
        return Candidate(
          id: (map['id'] ?? '').toString(),
          fullName: map['full_name']?.toString() ?? '',
          vacancy: map['vacancy']?.toString() ?? '',
          phone: map['phone']?.toString(),
          email: map['email']?.toString(),
          stage: map['stage']?.toString() ?? 'new',
          note: map['note']?.toString(),
          createdAt: _parseDate(map['created_at']) ?? DateTime.now(),
        );
      }).toList();
    } catch (e) {
      throw Exception(userFacingError(e, fallback: ErrorKeys.loadFailed));
    }
  }

  @override
  Future<Candidate> createCandidate({
    required String fullName,
    required String vacancy,
    String? phone,
    String? email,
    String stage = 'new',
    String? note,
  }) async {
    try {
      final response = await _apiClient.dio.post(
        '/hr/candidates',
        data: {
          'full_name': fullName,
          'vacancy': vacancy,
          'phone': phone,
          'email': email,
          'stage': stage,
          'note': note,
        },
      );
      final map = Map<String, dynamic>.from(response.data as Map);
      return Candidate(
        id: (map['id'] ?? '').toString(),
        fullName: map['full_name']?.toString() ?? fullName,
        vacancy: map['vacancy']?.toString() ?? vacancy,
        phone: map['phone']?.toString(),
        email: map['email']?.toString(),
        stage: map['stage']?.toString() ?? stage,
        note: map['note']?.toString(),
        createdAt: _parseDate(map['created_at']) ?? DateTime.now(),
      );
    } catch (e) {
      throw Exception(userFacingError(e, fallback: ErrorKeys.saveFailed));
    }
  }

  @override
  Future<Candidate> updateCandidateStage(String id, String stage) async {
    try {
      final response = await _apiClient.dio.patch(
        '/hr/candidates/${_requirePositiveId(id, 'id')}',
        data: {'stage': stage},
      );
      final map = Map<String, dynamic>.from(response.data as Map);
      return Candidate(
        id: (map['id'] ?? id).toString(),
        fullName: map['full_name']?.toString() ?? '',
        vacancy: map['vacancy']?.toString() ?? '',
        phone: map['phone']?.toString(),
        email: map['email']?.toString(),
        stage: map['stage']?.toString() ?? stage,
        note: map['note']?.toString(),
        createdAt: _parseDate(map['created_at']) ?? DateTime.now(),
      );
    } catch (e) {
      throw Exception(userFacingError(e, fallback: ErrorKeys.saveFailed));
    }
  }

  @override
  Future<void> deleteCandidate(String id) async {
    try {
      await _apiClient.dio.delete(
        '/hr/candidates/${_requirePositiveId(id, 'id')}',
      );
    } catch (e) {
      throw Exception(userFacingError(e, fallback: ErrorKeys.saveFailed));
    }
  }

  @override
  Future<List<HrEvaluation>> getEvaluations({
    String? period,
    bool forceRefresh = false,
  }) async {
    try {
      final response = await _apiClient.dio.get(
        '/hr/evaluations',
        queryParameters: period != null ? {'period': period} : null,
      );
      final list = response.data as List<dynamic>? ?? [];
      return list.whereType<Map>().map((item) {
        final map = Map<String, dynamic>.from(item);
        return HrEvaluation(
          id: (map['id'] ?? '').toString(),
          employeeId: (map['employee_id'] ?? '').toString(),
          employeeName: map['employee_name']?.toString(),
          position: map['position']?.toString(),
          period: map['period']?.toString() ?? '',
          performance: (map['performance'] as num?)?.toInt() ?? 0,
          potential: (map['potential'] as num?)?.toInt() ?? 0,
          note: map['note']?.toString(),
        );
      }).toList();
    } catch (e) {
      throw Exception(userFacingError(e, fallback: ErrorKeys.loadFailed));
    }
  }

  @override
  Future<HrEvaluation> createEvaluation({
    required String employeeId,
    required String period,
    required int performance,
    required int potential,
    String? note,
  }) async {
    try {
      final response = await _apiClient.dio.post(
        '/hr/evaluations',
        data: {
          'employee_id': _requirePositiveId(employeeId, 'employeeId'),
          'period': period,
          'performance': performance,
          'potential': potential,
          'note': note,
        },
      );
      final map = Map<String, dynamic>.from(response.data as Map);
      return HrEvaluation(
        id: (map['id'] ?? '').toString(),
        employeeId: (map['employee_id'] ?? employeeId).toString(),
        employeeName: map['employee_name']?.toString(),
        position: map['position']?.toString(),
        period: map['period']?.toString() ?? period,
        performance: (map['performance'] as num?)?.toInt() ?? performance,
        potential: (map['potential'] as num?)?.toInt() ?? potential,
        note: map['note']?.toString(),
      );
    } catch (e) {
      throw Exception(userFacingError(e, fallback: ErrorKeys.saveFailed));
    }
  }

  @override
  Future<List<LaborContract>> getContracts({
    bool forceRefresh = false,
    bool expiring = false,
  }) async {
    try {
      final response = await _apiClient.dio.get(
        '/hr/contracts',
        queryParameters: expiring ? {'expiring': true} : null,
      );
      final list = response.data as List<dynamic>? ?? [];
      return list.whereType<Map>().map((item) {
        final map = Map<String, dynamic>.from(item);
        return LaborContract(
          id: (map['id'] ?? '').toString(),
          employeeId: (map['employee_id'] ?? '').toString(),
          employeeName: map['employee_name']?.toString(),
          number: map['number']?.toString() ?? '',
          startDate: _parseDate(map['start_date']) ?? DateTime.now(),
          endDate: _parseDate(map['end_date']),
          status: map['status']?.toString() ?? 'active',
          daysLeft: (map['days_left'] as num?)?.toInt(),
          isExpiring: map['is_expiring'] == true,
          fileUrl: map['file_url']?.toString(),
        );
      }).toList();
    } catch (e) {
      throw Exception(userFacingError(e, fallback: ErrorKeys.loadFailed));
    }
  }

  @override
  Future<LaborContract> createContract({
    required String employeeId,
    required String number,
    required DateTime startDate,
    DateTime? endDate,
  }) async {
    try {
      final response = await _apiClient.dio.post(
        '/hr/contracts',
        data: {
          'employee_id': _requirePositiveId(employeeId, 'employeeId'),
          'number': number,
          'start_date': _dateOnly(startDate),
          if (endDate != null) 'end_date': _dateOnly(endDate),
        },
      );
      final map = Map<String, dynamic>.from(response.data as Map);
      return LaborContract(
        id: (map['id'] ?? '').toString(),
        employeeId: (map['employee_id'] ?? employeeId).toString(),
        employeeName: map['employee_name']?.toString(),
        number: map['number']?.toString() ?? number,
        startDate: _parseDate(map['start_date']) ?? startDate,
        endDate: _parseDate(map['end_date']),
        status: map['status']?.toString() ?? 'active',
        daysLeft: (map['days_left'] as num?)?.toInt(),
        isExpiring: map['is_expiring'] == true,
        fileUrl: map['file_url']?.toString(),
      );
    } catch (e) {
      throw Exception(userFacingError(e, fallback: ErrorKeys.saveFailed));
    }
  }

  @override
  Future<LaborContract> updateContract({
    required String id,
    String? number,
    DateTime? startDate,
    DateTime? endDate,
    String? status,
  }) async {
    try {
      final response = await _apiClient.dio.patch(
        '/hr/contracts/${_requirePositiveId(id, 'id')}',
        data: {
          'number': ?number,
          if (startDate != null) 'start_date': _dateOnly(startDate),
          if (endDate != null) 'end_date': _dateOnly(endDate),
          'status': ?status,
        },
      );
      final map = Map<String, dynamic>.from(response.data as Map);
      return LaborContract(
        id: (map['id'] ?? id).toString(),
        employeeId: (map['employee_id'] ?? '').toString(),
        employeeName: map['employee_name']?.toString(),
        number: map['number']?.toString() ?? number ?? '',
        startDate: _parseDate(map['start_date']) ?? startDate ?? DateTime.now(),
        endDate: _parseDate(map['end_date']) ?? endDate,
        status: map['status']?.toString() ?? status ?? 'active',
        daysLeft: (map['days_left'] as num?)?.toInt(),
        isExpiring: map['is_expiring'] == true,
        fileUrl: map['file_url']?.toString(),
      );
    } catch (e) {
      throw Exception(userFacingError(e, fallback: ErrorKeys.saveFailed));
    }
  }

  @override
  Future<void> deleteContract(String id) async {
    try {
      await _apiClient.dio.delete(
        '/hr/contracts/${_requirePositiveId(id, 'id')}',
      );
    } catch (e) {
      throw Exception(userFacingError(e, fallback: ErrorKeys.saveFailed));
    }
  }

  @override
  Future<MovementReport> getMovementReport({
    required String dateFrom,
    required String dateTo,
    bool forceRefresh = false,
  }) async {
    try {
      final response = await _apiClient.dio.get(
        '/hr/reports/movement',
        queryParameters: {
          'date_from': dateFrom,
          'date_to': dateTo,
          'fmt': 'json',
        },
      );
      final data = response.data;
      if (data is! Map) {
        throw const FormatException(ErrorKeys.invalidResponse);
      }
      final map = Map<String, dynamic>.from(data);
      List<MovementRow> parseList(dynamic raw, bool isHire) {
        if (raw is! List) return const [];
        return raw.whereType<Map>().map((item) {
          final m = Map<String, dynamic>.from(item);
          return MovementRow(
            id: (m['id'] ?? '').toString(),
            fullName: m['full_name']?.toString() ?? '',
            position: m['position']?.toString(),
            date:
                _parseDate(isHire ? m['hire_date'] : m['terminated_at']) ??
                _parseDate(m['date']),
            isHire: isHire,
          );
        }).toList();
      }

      return MovementReport(
        hired: parseList(map['hired'], true),
        fired: parseList(map['fired'], false),
      );
    } catch (e) {
      throw Exception(userFacingError(e, fallback: ErrorKeys.loadFailed));
    }
  }

  @override
  Future<List<int>> downloadMovementReportPdf({
    required String dateFrom,
    required String dateTo,
  }) async {
    try {
      final response = await _apiClient.dio.get<List<int>>(
        '/hr/reports/movement',
        queryParameters: {
          'date_from': dateFrom,
          'date_to': dateTo,
          'fmt': 'pdf',
        },
        options: Options(responseType: ResponseType.bytes),
      );
      return response.data ?? <int>[];
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
