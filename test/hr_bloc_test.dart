import 'package:flutter_test/flutter_test.dart';
import 'package:payk_ai_cfo_platform/features/hr/bloc/hr_bloc.dart';
import 'package:payk_ai_cfo_platform/features/hr/bloc/hr_event.dart';
import 'package:payk_ai_cfo_platform/features/hr/bloc/hr_state.dart';
import 'package:payk_ai_cfo_platform/features/hr/domain/hr_models.dart';
import 'package:payk_ai_cfo_platform/features/hr/domain/hr_repository.dart';

class MockHrRepository implements HrRepository {
  List<Employee> employees = [];
  List<KpiAlert> kpiAlerts = [];
  List<SalaryRecord> salaryRecords = [];

  bool shouldFail = false;

  @override
  Future<List<Employee>> getEmployees({bool forceRefresh = false}) async {
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
