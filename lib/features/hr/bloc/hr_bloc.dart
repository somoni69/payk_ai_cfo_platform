import 'package:flutter_bloc/flutter_bloc.dart';
import '../domain/hr_models.dart';
import '../domain/hr_repository.dart';
import 'hr_event.dart';
import 'hr_state.dart';

class HrBloc extends Bloc<HrEvent, HrState> {
  final HrRepository _repository;

  List<Employee> _cachedEmployees = [];
  List<KpiAlert> _cachedKpiAlerts = [];
  List<SalaryRecord> _cachedSalaries = [];

  HrBloc(this._repository) : super(HrLoading()) {
    on<LoadHrData>(_onLoadHrData);
    on<CreateEmployeeRequested>(_onCreateEmployeeRequested);
    on<RecalcSalaryRequested>(_onRecalcSalaryRequested);
  }

  void _onLoadHrData(LoadHrData event, Emitter<HrState> emit) async {
    if (_cachedEmployees.isNotEmpty) {
      emit(HrLoaded(
        employees: _cachedEmployees,
        kpiAlerts: _cachedKpiAlerts,
        salaryRecords: _cachedSalaries,
        period: event.period,
      ));
    } else {
      emit(HrLoading());
    }
    try {
      final results = await Future.wait([
        _repository.getEmployees(),
        _repository.getKpiAlerts(event.period),
        _repository.getSalaryRecords(event.period),
      ]);
      _cachedEmployees = results[0] as List<Employee>;
      _cachedKpiAlerts = results[1] as List<KpiAlert>;
      _cachedSalaries = results[2] as List<SalaryRecord>;
      
      emit(HrLoaded(
        employees: _cachedEmployees,
        kpiAlerts: _cachedKpiAlerts,
        salaryRecords: _cachedSalaries,
        period: event.period,
      ));
    } catch (e) {
      emit(HrError('Ошибка загрузки данных HR: ${e.toString()}'));
    }
  }

  void _onCreateEmployeeRequested(CreateEmployeeRequested event, Emitter<HrState> emit) async {
    if (state is! HrLoaded) return;
    final currentState = state as HrLoaded;

    try {
      final created = await _repository.createEmployee(event.employee);
      _cachedEmployees = List<Employee>.from(_cachedEmployees)..add(created);
      
      emit(currentState.copyWith(
        employees: _cachedEmployees,
        successMessage: 'Сотрудник "${created.fullName}" успешно принят на работу.',
      ));
    } catch (e) {
      emit(currentState.copyWith(
        errorMessage: 'Не удалось добавить сотрудника: ${e.toString()}',
      ));
    }
  }

  void _onRecalcSalaryRequested(RecalcSalaryRequested event, Emitter<HrState> emit) async {
    if (state is! HrLoaded) return;
    final currentState = state as HrLoaded;

    try {
      final recalculated = await _repository.recalcSalary(
        employeeId: event.employeeId,
        period: event.period,
        baseAmount: event.baseAmount,
        deductions: event.deductions,
        bonusFormula: event.bonusFormula,
      );

      // Ищем и заменяем запись в локальном списке расчетных листков
      final updatedSalaries = _cachedSalaries.map((s) {
        return (s.employeeId == event.employeeId && s.period == event.period) ? recalculated : s;
      }).toList();

      // Если записи не было в списке, добавляем её
      if (!updatedSalaries.any((s) => s.employeeId == event.employeeId && s.period == event.period)) {
        updatedSalaries.add(recalculated);
      }

      _cachedSalaries = updatedSalaries;

      emit(currentState.copyWith(
        salaryRecords: _cachedSalaries,
        successMessage: 'Расчет по сотруднику "${recalculated.employeeName}" успешно обновлен.',
      ));
    } catch (e) {
      emit(currentState.copyWith(
        errorMessage: 'Не удалось выполнить перерасчет: ${e.toString()}',
      ));
    }
  }
}
