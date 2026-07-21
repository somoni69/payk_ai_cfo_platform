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
  final Map<String, Future<List<Object>>> _loadRequests = {};
  int _loadGeneration = 0;

  HrBloc(this._repository) : super(HrLoading()) {
    on<LoadHrData>(_onLoadHrData);
    on<CreateEmployeeRequested>(_onCreateEmployeeRequested);
    on<RecalcSalaryRequested>(_onRecalcSalaryRequested);
  }

  Future<void> _onLoadHrData(LoadHrData event, Emitter<HrState> emit) async {
    final generation = ++_loadGeneration;
    final previous = state is HrLoaded ? state as HrLoaded : null;
    final canKeepCurrent = previous?.period == event.period;

    if (canKeepCurrent) {
      emit(
        previous!.copyWith(
          isRefreshing: true,
          clearError: true,
          clearSuccess: true,
        ),
      );
    } else {
      emit(HrLoading());
    }

    var request = _loadRequests[event.period];
    if (request == null) {
      request = Future.wait<Object>([
        _repository.getEmployees(forceRefresh: event.forceRefresh),
        _repository.getKpiAlerts(
          event.period,
          forceRefresh: event.forceRefresh,
        ),
        _repository.getSalaryRecords(
          event.period,
          forceRefresh: event.forceRefresh,
        ),
      ]);
      _loadRequests[event.period] = request;
    }

    try {
      final results = await request;
      if (generation != _loadGeneration) return;

      _cachedEmployees = (results[0] as List).cast<Employee>();
      _cachedKpiAlerts = (results[1] as List).cast<KpiAlert>();
      _cachedSalaries = (results[2] as List).cast<SalaryRecord>();

      emit(
        HrLoaded(
          employees: _cachedEmployees,
          kpiAlerts: _cachedKpiAlerts,
          salaryRecords: _cachedSalaries,
          period: event.period,
        ),
      );
    } catch (error) {
      if (generation != _loadGeneration) return;
      if (canKeepCurrent) {
        emit(
          previous!.copyWith(
            isRefreshing: false,
            errorMessage:
                'Не удалось обновить данные HR. Проверьте соединение.',
          ),
        );
      } else {
        emit(
          const HrError(
            'Не удалось загрузить данные HR. Проверьте соединение.',
          ),
        );
      }
    } finally {
      if (identical(_loadRequests[event.period], request)) {
        _loadRequests.remove(event.period);
      }
      if (event.completion?.isCompleted == false) event.completion!.complete();
    }
  }

  void _onCreateEmployeeRequested(
    CreateEmployeeRequested event,
    Emitter<HrState> emit,
  ) async {
    if (state is! HrLoaded) return;
    final currentState = state as HrLoaded;

    try {
      final created = await _repository.createEmployee(event.employee);
      _cachedEmployees = List<Employee>.from(_cachedEmployees)..add(created);

      emit(
        currentState.copyWith(
          employees: _cachedEmployees,
          successMessage:
              'Сотрудник "${created.fullName}" успешно принят на работу.',
        ),
      );
    } catch (e) {
      emit(
        currentState.copyWith(
          errorMessage: 'Не удалось добавить сотрудника. Проверьте данные.',
        ),
      );
    }
  }

  void _onRecalcSalaryRequested(
    RecalcSalaryRequested event,
    Emitter<HrState> emit,
  ) async {
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
        return (s.employeeId == event.employeeId && s.period == event.period)
            ? recalculated
            : s;
      }).toList();

      // Если записи не было в списке, добавляем её
      if (!updatedSalaries.any(
        (s) => s.employeeId == event.employeeId && s.period == event.period,
      )) {
        updatedSalaries.add(recalculated);
      }

      _cachedSalaries = updatedSalaries;

      emit(
        currentState.copyWith(
          salaryRecords: _cachedSalaries,
          successMessage:
              'Расчет по сотруднику "${recalculated.employeeName}" успешно обновлен.',
        ),
      );
    } catch (e) {
      emit(
        currentState.copyWith(
          errorMessage: 'Не удалось выполнить перерасчёт. Проверьте данные.',
        ),
      );
    }
  }
}
