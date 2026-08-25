import 'package:flutter_test/flutter_test.dart';
import 'package:payk_ai_cfo_platform/features/hr/bloc/hr_bloc.dart';
import 'package:payk_ai_cfo_platform/features/hr/bloc/hr_event.dart';
import 'package:payk_ai_cfo_platform/features/hr/bloc/hr_state.dart';
import 'package:payk_ai_cfo_platform/features/hr/domain/hr_models.dart';
import 'package:payk_ai_cfo_platform/features/hr/domain/hr_repository.dart';

class MockHrRepository implements HrRepository {
  List<Employee> employees = [];
  List<KpiAlert> kpiAlerts = [];
  List<KpiRecord> kpis = [];
  List<SalaryRecord> salaryRecords = [];

  bool shouldFail = false;

  @override
  Future<List<Employee>> getEmployees({
    bool archived = false,
    bool forceRefresh = false,
  }) async {
    if (shouldFail) throw Exception('Get employees error');
    return List.from(employees);
  }

  @override
  Future<List<KpiAlert>> getKpiAlerts(
    String period, {
    bool forceRefresh = false,
  }) async {
    if (shouldFail) throw Exception('Get KPI alerts error');
    return List.from(kpiAlerts);
  }

  @override
  Future<List<KpiRecord>> getKpis({
    String? period,
    String? employeeId,
    bool forceRefresh = false,
  }) async {
    if (shouldFail) throw Exception('Get KPIs error');
    return List.from(kpis);
  }

  @override
  Future<KpiRecord> createKpi({
    required String employeeId,
    required String period,
    required String metric,
    required double planValue,
    double factValue = 0.0,
  }) async {
    final kpi = KpiRecord(
      id: 'kpi-${kpis.length + 1}',
      employeeId: employeeId,
      employeeName: employees
          .firstWhere(
            (e) => e.id == employeeId,
            orElse: () => Employee(
              id: employeeId,
              fullName: 'Emp',
              baseSalary: 0,
              status: 'active',
              createdAt: DateTime.now(),
            ),
          )
          .fullName,
      period: period,
      metric: metric,
      planValue: planValue,
      factValue: factValue,
      completion: planValue > 0 ? (factValue / planValue * 100) : 0,
    );
    kpis.add(kpi);
    return kpi;
  }

  @override
  Future<KpiRecord> updateKpi({
    required String kpiId,
    String? metric,
    double? planValue,
    double? factValue,
  }) async {
    final index = kpis.indexWhere((k) => k.id == kpiId);
    if (index == -1) throw Exception('KPI not found');
    final updated = kpis[index].copyWith(
      metric: metric,
      planValue: planValue,
      factValue: factValue,
      completion: (planValue ?? kpis[index].planValue) > 0
          ? ((factValue ?? kpis[index].factValue) /
                (planValue ?? kpis[index].planValue) *
                100)
          : 0,
    );
    kpis[index] = updated;
    return updated;
  }

  @override
  Future<void> deleteKpi(String id) async {
    kpis.removeWhere((k) => k.id == id);
  }

  @override
  Future<List<SalaryRecord>> getSalaryRecords(
    String period, {
    bool forceRefresh = false,
  }) async {
    if (shouldFail) throw Exception('Get salary records error');
    return List.from(salaryRecords);
  }

  @override
  Future<SalaryRecord> recalcSalary({
    required String employeeId,
    required String period,
    double? baseAmount,
    double? deductions,
    String? bonusFormula,
  }) async {
    if (shouldFail) throw Exception('Recalc salary error');
    return SalaryRecord(
      id: 'recalc-1',
      employeeId: employeeId,
      employeeName: 'Recalced Employee',
      period: period,
      baseAmount: baseAmount ?? 1000.0,
      bonusAmount: 200.0,
      deductions: deductions ?? 50.0,
      totalAmount: (baseAmount ?? 1000.0) + 200.0 - (deductions ?? 50.0),
      bonusFormula: bonusFormula ?? 'default',
    );
  }

  @override
  Future<Employee> createEmployee(Employee employee) async {
    if (shouldFail) throw Exception('Create employee error');
    final newEmp = employee.copyWith(id: (employees.length + 1).toString());
    employees.add(newEmp);
    return newEmp;
  }

  @override
  Future<Employee> blockEmployee(String id) async {
    final index = employees.indexWhere((e) => e.id == id);
    final updated = employees[index].copyWith(status: 'inactive');
    employees[index] = updated;
    return updated;
  }

  @override
  Future<Employee> unblockEmployee(String id) async {
    final index = employees.indexWhere((e) => e.id == id);
    final updated = employees[index].copyWith(status: 'active');
    employees[index] = updated;
    return updated;
  }

  @override
  Future<Employee> archiveEmployee(String id) async {
    final index = employees.indexWhere((e) => e.id == id);
    final updated = employees[index].copyWith(isArchived: true);
    employees[index] = updated;
    return updated;
  }

  @override
  Future<Employee> restoreEmployee(String id) async {
    final index = employees.indexWhere((e) => e.id == id);
    final updated = employees[index].copyWith(isArchived: false);
    employees[index] = updated;
    return updated;
  }

  @override
  Future<int> syncIikoEmployees() async {
    return employees.length;
  }

  @override
  Future<List<EmployeeDocument>> getEmployeeDocuments(String employeeId) async {
    return [
      EmployeeDocument(
        id: 'doc-1',
        employeeId: employeeId,
        name: 'Passport.pdf',
        url: 'https://example.com/passport.pdf',
        createdAt: DateTime.now(),
      ),
    ];
  }

  @override
  Future<List<int>> downloadSalaryCertificatePdf(String employeeId) async {
    return [37, 80, 68, 70]; // %PDF
  }

  @override
  Future<List<int>> downloadMovementReportPdf({
    required String dateFrom,
    required String dateTo,
  }) async {
    return [37, 80, 68, 70]; // %PDF
  }

  @override
  Future<List<OrgNode>> getOrgChart({bool forceRefresh = false}) async =>
      const [];

  @override
  Future<List<AttendanceRecord>> getAttendance({
    String? employeeId,
    String? dateFrom,
    String? dateTo,
    bool forceRefresh = false,
  }) async => const [];

  @override
  Future<AttendanceRecord> createAttendance({
    required String employeeId,
    required DateTime workDate,
    required double hours,
  }) async {
    return AttendanceRecord(
      id: '1',
      employeeId: employeeId,
      workDate: workDate,
      hours: hours,
    );
  }

  @override
  Future<void> deleteAttendance(String id) async {}

  @override
  Future<List<Candidate>> getCandidates({bool forceRefresh = false}) async =>
      const [];

  @override
  Future<Candidate> createCandidate({
    required String fullName,
    required String vacancy,
    String? phone,
    String? email,
    String stage = 'new',
    String? note,
  }) async {
    return Candidate(
      id: '1',
      fullName: fullName,
      vacancy: vacancy,
      phone: phone,
      email: email,
      stage: stage,
      note: note,
      createdAt: DateTime.now(),
    );
  }

  @override
  Future<Candidate> updateCandidateStage(String id, String stage) async {
    return Candidate(
      id: id,
      fullName: 'Test',
      vacancy: 'V',
      stage: stage,
      createdAt: DateTime.now(),
    );
  }

  @override
  Future<void> deleteCandidate(String id) async {}

  @override
  Future<List<HrEvaluation>> getEvaluations({
    String? period,
    bool forceRefresh = false,
  }) async => const [];

  @override
  Future<HrEvaluation> createEvaluation({
    required String employeeId,
    required String period,
    required int performance,
    required int potential,
    String? note,
  }) async {
    return HrEvaluation(
      id: '1',
      employeeId: employeeId,
      period: period,
      performance: performance,
      potential: potential,
      note: note,
    );
  }

  @override
  Future<List<LaborContract>> getContracts({
    bool expiring = false,
    bool forceRefresh = false,
  }) async => const [];

  @override
  Future<LaborContract> createContract({
    required String employeeId,
    required String number,
    required DateTime startDate,
    DateTime? endDate,
  }) async {
    return LaborContract(
      id: '1',
      employeeId: employeeId,
      number: number,
      startDate: startDate,
      endDate: endDate,
      status: 'active',
    );
  }

  @override
  Future<void> deleteContract(String id) async {}

  @override
  Future<MovementReport> getMovementReport({
    required String dateFrom,
    required String dateTo,
    bool forceRefresh = false,
  }) async => const MovementReport();
}

void main() {
  group('HrBloc Unit Tests', () {
    late MockHrRepository repository;
    late HrBloc bloc;

    setUp(() {
      repository = MockHrRepository();
      repository.employees = [
        Employee(
          id: '1',
          fullName: 'Иван Иванов',
          position: 'Кассир',
          baseSalary: 1500.0,
          status: 'active',
          createdAt: DateTime.now(),
        ),
      ];
      repository.kpiAlerts = [
        const KpiAlert(
          employeeId: '1',
          employeeName: 'Иван Иванов',
          metric: 'Продажи',
          period: '2026-06',
          planValue: 100.0,
          factValue: 80.0,
          completion: 0.8,
          threshold: 0.9,
          triggered: true,
        ),
      ];
      repository.kpis = [
        const KpiRecord(
          id: 'kpi-1',
          employeeId: '1',
          employeeName: 'Иван Иванов',
          period: '2026-06',
          metric: 'Выручка',
          planValue: 50000.0,
          factValue: 52000.0,
          completion: 104.0,
        ),
      ];
      repository.salaryRecords = [
        const SalaryRecord(
          id: '1',
          employeeId: '1',
          employeeName: 'Иван Иванов',
          period: '2026-06',
          baseAmount: 1500.0,
          bonusAmount: 100.0,
          deductions: 50.0,
          totalAmount: 1550.0,
        ),
      ];
      bloc = HrBloc(repository);
    });

    tearDown(() {
      bloc.close();
    });

    test('Initial state is HrLoading', () {
      expect(bloc.state, isA<HrLoading>());
    });

    test('LoadHrData emits HrLoaded with data', () async {
      final expected = [
        isA<HrLoading>(),
        isA<HrLoaded>()
            .having((s) => s.employees.length, 'employees count', 1)
            .having((s) => s.kpiAlerts.length, 'KPI alerts count', 1)
            .having((s) => s.kpiRecords.length, 'KPI records count', 1)
            .having((s) => s.salaryRecords.length, 'salary records count', 1),
      ];

      expectLater(bloc.stream, emitsInOrder(expected));
      bloc.add(const LoadHrData('2026-06'));
    });

    test('CreateEmployeeRequested appends new employee to list', () async {
      bloc.add(const LoadHrData('2026-06'));
      await bloc.stream.firstWhere((s) => s is HrLoaded);

      bloc.add(
        CreateEmployeeRequested(
          Employee(
            id: '',
            fullName: 'Пётр Петров',
            position: 'Бухгалтер',
            baseSalary: 3000.0,
            status: 'active',
            createdAt: DateTime.now(),
          ),
        ),
      );

      final List<HrState> emitted = [];
      final sub = bloc.stream.listen(emitted.add);

      await Future.delayed(const Duration(milliseconds: 50));
      sub.cancel();

      expect(emitted, isNotEmpty);
      final loaded = emitted.first as HrLoaded;
      expect(loaded.employees.length, 2);
      expect(loaded.employees.last.fullName, 'Пётр Петров');
    });

    test('BlockEmployeeRequested updates employee status', () async {
      bloc.add(const LoadHrData('2026-06'));
      await bloc.stream.firstWhere((s) => s is HrLoaded);

      bloc.add(const BlockEmployeeRequested('1'));

      final List<HrState> emitted = [];
      final sub = bloc.stream.listen(emitted.add);

      await Future.delayed(const Duration(milliseconds: 50));
      sub.cancel();

      expect(emitted, isNotEmpty);
      final loaded = emitted.first as HrLoaded;
      expect(loaded.employees.first.status, 'inactive');
    });

    test(
      'CreateKpiRequested and DeleteKpiRequested update kpiRecords',
      () async {
        bloc.add(const LoadHrData('2026-06'));
        await bloc.stream.firstWhere((s) => s is HrLoaded);

        bloc.add(
          const CreateKpiRequested(
            employeeId: '1',
            period: '2026-06',
            metric: 'Средний чек',
            planValue: 200.0,
            factValue: 210.0,
          ),
        );

        await Future.delayed(const Duration(milliseconds: 50));
        var loaded = bloc.state as HrLoaded;
        expect(loaded.kpiRecords.length, 2);
        expect(loaded.kpiRecords.first.metric, 'Средний чек');

        bloc.add(DeleteKpiRequested(loaded.kpiRecords.first.id));
        await Future.delayed(const Duration(milliseconds: 50));
        loaded = bloc.state as HrLoaded;
        expect(loaded.kpiRecords.length, 1);
      },
    );

    test('RecalcSalaryRequested updates employee salary worksheet', () async {
      bloc.add(const LoadHrData('2026-06'));
      await bloc.stream.firstWhere((s) => s is HrLoaded);

      bloc.add(
        const RecalcSalaryRequested(
          employeeId: '1',
          period: '2026-06',
          baseAmount: 1800.0,
          deductions: 100.0,
        ),
      );

      final List<HrState> emitted = [];
      final sub = bloc.stream.listen(emitted.add);

      await Future.delayed(const Duration(milliseconds: 50));
      sub.cancel();

      expect(emitted, isNotEmpty);
      final loaded = emitted.first as HrLoaded;
      final record = loaded.salaryRecords.firstWhere(
        (s) => s.employeeId == '1',
      );
      expect(record.baseAmount, 1800.0);
      expect(record.deductions, 100.0);
      expect(record.totalAmount, 1900.0); // 1800 + 200 (mock bonus) - 100
    });
  });
}
