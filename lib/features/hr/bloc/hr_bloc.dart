import 'package:flutter_bloc/flutter_bloc.dart';
import '../domain/hr_models.dart';
import '../domain/hr_repository.dart';
import 'hr_event.dart';
import 'hr_state.dart';

class HrBloc extends Bloc<HrEvent, HrState> {
  final HrRepository _repository;

  List<Employee> _cachedEmployees = [];
  List<KpiRecord> _cachedKpiRecords = [];
  List<KpiAlert> _cachedKpiAlerts = [];
  List<SalaryRecord> _cachedSalaries = [];
  final Map<String, Future<List<Object>>> _loadRequests = {};
  int _loadGeneration = 0;
  String _period = '';

  HrBloc(this._repository) : super(HrLoading()) {
    on<LoadHrData>(_onLoadHrData);
    on<LoadHrSection>(_onLoadHrSection);
    on<CreateEmployeeRequested>(_onCreateEmployeeRequested);
    on<UpdateEmployeeRequested>(_onUpdateEmployeeRequested);
    on<DeleteEmployeeRequested>(_onDeleteEmployeeRequested);
    on<BlockEmployeeRequested>(_onBlockEmployeeRequested);
    on<UnblockEmployeeRequested>(_onUnblockEmployeeRequested);
    on<ArchiveEmployeeRequested>(_onArchiveEmployeeRequested);
    on<RestoreEmployeeRequested>(_onRestoreEmployeeRequested);
    on<SyncIikoEmployeesRequested>(_onSyncIikoEmployeesRequested);
    on<CreateKpiRequested>(_onCreateKpiRequested);
    on<UpdateKpiRequested>(_onUpdateKpiRequested);
    on<DeleteKpiRequested>(_onDeleteKpiRequested);
    on<RecalcSalaryRequested>(_onRecalcSalaryRequested);
    on<CreateAttendanceRequested>(_onCreateAttendance);
    on<DeleteAttendanceRequested>(_onDeleteAttendance);
    on<CreateCandidateRequested>(_onCreateCandidate);
    on<UpdateCandidateStageRequested>(_onUpdateCandidateStage);
    on<DeleteCandidateRequested>(_onDeleteCandidate);
    on<CreateEvaluationRequested>(_onCreateEvaluation);
    on<CreateContractRequested>(_onCreateContract);
    on<DeleteContractRequested>(_onDeleteContract);
  }

  Future<void> _onLoadHrData(LoadHrData event, Emitter<HrState> emit) async {
    final generation = ++_loadGeneration;
    final previous = state is HrLoaded ? state as HrLoaded : null;
    final canKeepCurrent = previous?.period == event.period;
    _period = event.period;

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
        _repository.getKpis(
          period: event.period,
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
      _cachedKpiRecords = (results[3] as List).cast<KpiRecord>();

      emit(
        HrLoaded(
          employees: _cachedEmployees,
          kpiRecords: _cachedKpiRecords,
          kpiAlerts: _cachedKpiAlerts,
          salaryRecords: _cachedSalaries,
          period: event.period,
          // Preserve already loaded sections when refreshing same period.
          orgChart: canKeepCurrent ? previous!.orgChart : const [],
          orgLoaded: canKeepCurrent ? previous!.orgLoaded : false,
          attendance: canKeepCurrent ? previous!.attendance : const [],
          attendanceLoaded: canKeepCurrent ? previous!.attendanceLoaded : false,
          candidates: canKeepCurrent ? previous!.candidates : const [],
          candidatesLoaded: canKeepCurrent ? previous!.candidatesLoaded : false,
          evaluations: canKeepCurrent ? previous!.evaluations : const [],
          evaluationsLoaded: canKeepCurrent
              ? previous!.evaluationsLoaded
              : false,
          contracts: canKeepCurrent ? previous!.contracts : const [],
          contractsLoaded: canKeepCurrent ? previous!.contractsLoaded : false,
          movement: canKeepCurrent ? previous!.movement : null,
          movementLoaded: canKeepCurrent ? previous!.movementLoaded : false,
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

  Future<void> _onLoadHrSection(
    LoadHrSection event,
    Emitter<HrState> emit,
  ) async {
    if (state is! HrLoaded) return;
    final current = state as HrLoaded;

    final alreadyLoaded = switch (event.section) {
      HrSection.org => current.orgLoaded,
      HrSection.attendance => current.attendanceLoaded,
      HrSection.recruitment => current.candidatesLoaded,
      HrSection.nineBox => current.evaluationsLoaded,
      HrSection.contracts => current.contractsLoaded,
      HrSection.movement => current.movementLoaded,
    };
    if (alreadyLoaded && !event.forceRefresh) {
      if (event.completion?.isCompleted == false) event.completion!.complete();
      return;
    }

    emit(current.copyWith(sectionLoading: true, clearError: true));

    try {
      switch (event.section) {
        case HrSection.org:
          final org = await _repository.getOrgChart(
            forceRefresh: event.forceRefresh,
          );
          if (state is HrLoaded) {
            emit(
              (state as HrLoaded).copyWith(
                orgChart: org,
                orgLoaded: true,
                sectionLoading: false,
              ),
            );
          }
          break;
        case HrSection.attendance:
          final rows = await _repository.getAttendance(
            forceRefresh: event.forceRefresh,
          );
          if (state is HrLoaded) {
            emit(
              (state as HrLoaded).copyWith(
                attendance: rows,
                attendanceLoaded: true,
                sectionLoading: false,
              ),
            );
          }
          break;
        case HrSection.recruitment:
          final rows = await _repository.getCandidates(
            forceRefresh: event.forceRefresh,
          );
          if (state is HrLoaded) {
            emit(
              (state as HrLoaded).copyWith(
                candidates: rows,
                candidatesLoaded: true,
                sectionLoading: false,
              ),
            );
          }
          break;
        case HrSection.nineBox:
          final period = _period.isNotEmpty ? _period : current.period;
          final rows = await _repository.getEvaluations(
            period: period,
            forceRefresh: event.forceRefresh,
          );
          if (state is HrLoaded) {
            emit(
              (state as HrLoaded).copyWith(
                evaluations: rows,
                evaluationsLoaded: true,
                sectionLoading: false,
              ),
            );
          }
          break;
        case HrSection.contracts:
          final rows = await _repository.getContracts(
            forceRefresh: event.forceRefresh,
          );
          if (state is HrLoaded) {
            emit(
              (state as HrLoaded).copyWith(
                contracts: rows,
                contractsLoaded: true,
                sectionLoading: false,
              ),
            );
          }
          break;
        case HrSection.movement:
          final period = _period.isNotEmpty ? _period : current.period;
          final parts = period.split('-');
          final year = int.tryParse(parts[0]) ?? DateTime.now().year;
          final month = parts.length > 1
              ? (int.tryParse(parts[1]) ?? DateTime.now().month)
              : DateTime.now().month;
          final from = '$year-${month.toString().padLeft(2, '0')}-01';
          final lastDay = DateTime(year, month + 1, 0).day;
          final to =
              '$year-${month.toString().padLeft(2, '0')}-${lastDay.toString().padLeft(2, '0')}';
          final report = await _repository.getMovementReport(
            dateFrom: from,
            dateTo: to,
            forceRefresh: event.forceRefresh,
          );
          if (state is HrLoaded) {
            emit(
              (state as HrLoaded).copyWith(
                movement: report,
                movementLoaded: true,
                sectionLoading: false,
              ),
            );
          }
          break;
      }
    } catch (e) {
      if (state is HrLoaded) {
        emit(
          (state as HrLoaded).copyWith(
            sectionLoading: false,
            errorMessage: e.toString(),
          ),
        );
      }
    } finally {
      if (event.completion?.isCompleted == false) event.completion!.complete();
    }
  }

  Future<void> _onCreateEmployeeRequested(
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
          successMessage: 'hr_toast_employee_created',
        ),
      );
    } catch (e) {
      emit(currentState.copyWith(errorMessage: e.toString()));
    }
  }

  Future<void> _onUpdateEmployeeRequested(
    UpdateEmployeeRequested event,
    Emitter<HrState> emit,
  ) async {
    if (state is! HrLoaded) return;
    final currentState = state as HrLoaded;
    try {
      final updated = await _repository.updateEmployee(event.employee);
      _cachedEmployees = _cachedEmployees
          .map((e) => e.id == updated.id ? updated : e)
          .toList();
      emit(
        currentState.copyWith(
          employees: _cachedEmployees,
          successMessage: 'hr_toast_employee_updated',
        ),
      );
    } catch (e) {
      emit(currentState.copyWith(errorMessage: e.toString()));
    }
  }

  Future<void> _onDeleteEmployeeRequested(
    DeleteEmployeeRequested event,
    Emitter<HrState> emit,
  ) async {
    if (state is! HrLoaded) return;
    final currentState = state as HrLoaded;
    try {
      await _repository.deleteEmployee(event.employeeId);
      _cachedEmployees = _cachedEmployees
          .where((e) => e.id != event.employeeId)
          .toList();
      emit(
        currentState.copyWith(
          employees: _cachedEmployees,
          successMessage: 'hr_toast_employee_deleted',
        ),
      );
    } catch (e) {
      emit(currentState.copyWith(errorMessage: e.toString()));
    }
  }

  Future<void> _onRecalcSalaryRequested(
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

      final updatedSalaries = _cachedSalaries.map((s) {
        return (s.employeeId == event.employeeId && s.period == event.period)
            ? recalculated
            : s;
      }).toList();

      if (!updatedSalaries.any(
        (s) => s.employeeId == event.employeeId && s.period == event.period,
      )) {
        updatedSalaries.add(recalculated);
      }

      _cachedSalaries = updatedSalaries;

      emit(
        currentState.copyWith(
          salaryRecords: _cachedSalaries,
          successMessage: 'hr_toast_salary_recalc',
        ),
      );
    } catch (e) {
      emit(currentState.copyWith(errorMessage: e.toString()));
    }
  }

  Future<void> _onCreateAttendance(
    CreateAttendanceRequested event,
    Emitter<HrState> emit,
  ) async {
    if (state is! HrLoaded) return;
    try {
      final row = await _repository.createAttendance(
        employeeId: event.employeeId,
        workDate: event.workDate,
        hours: event.hours,
      );
      if (state is! HrLoaded) return;
      final current = state as HrLoaded;
      emit(
        current.copyWith(
          attendance: [row, ...current.attendance],
          attendanceLoaded: true,
          successMessage: 'hr_toast_attendance_created',
        ),
      );
    } catch (e) {
      if (state is HrLoaded) {
        emit((state as HrLoaded).copyWith(errorMessage: e.toString()));
      }
    }
  }

  Future<void> _onDeleteAttendance(
    DeleteAttendanceRequested event,
    Emitter<HrState> emit,
  ) async {
    if (state is! HrLoaded) return;
    try {
      await _repository.deleteAttendance(event.id);
      if (state is! HrLoaded) return;
      final current = state as HrLoaded;
      emit(
        current.copyWith(
          attendance: current.attendance
              .where((a) => a.id != event.id)
              .toList(),
          successMessage: 'hr_toast_attendance_deleted',
        ),
      );
    } catch (e) {
      if (state is HrLoaded) {
        emit((state as HrLoaded).copyWith(errorMessage: e.toString()));
      }
    }
  }

  Future<void> _onCreateCandidate(
    CreateCandidateRequested event,
    Emitter<HrState> emit,
  ) async {
    if (state is! HrLoaded) return;
    try {
      final row = await _repository.createCandidate(
        fullName: event.fullName,
        vacancy: event.vacancy,
        phone: event.phone,
        email: event.email,
      );
      if (state is! HrLoaded) return;
      final current = state as HrLoaded;
      emit(
        current.copyWith(
          candidates: [row, ...current.candidates],
          candidatesLoaded: true,
          successMessage: 'hr_toast_candidate_created',
        ),
      );
    } catch (e) {
      if (state is HrLoaded) {
        emit((state as HrLoaded).copyWith(errorMessage: e.toString()));
      }
    }
  }

  Future<void> _onUpdateCandidateStage(
    UpdateCandidateStageRequested event,
    Emitter<HrState> emit,
  ) async {
    if (state is! HrLoaded) return;
    try {
      final row = await _repository.updateCandidateStage(event.id, event.stage);
      if (state is! HrLoaded) return;
      final current = state as HrLoaded;
      emit(
        current.copyWith(
          candidates: current.candidates
              .map((c) => c.id == event.id ? row : c)
              .toList(),
          successMessage: 'hr_toast_candidate_updated',
        ),
      );
    } catch (e) {
      if (state is HrLoaded) {
        emit((state as HrLoaded).copyWith(errorMessage: e.toString()));
      }
    }
  }

  Future<void> _onDeleteCandidate(
    DeleteCandidateRequested event,
    Emitter<HrState> emit,
  ) async {
    if (state is! HrLoaded) return;
    try {
      await _repository.deleteCandidate(event.id);
      if (state is! HrLoaded) return;
      final current = state as HrLoaded;
      emit(
        current.copyWith(
          candidates: current.candidates
              .where((c) => c.id != event.id)
              .toList(),
          successMessage: 'hr_toast_candidate_deleted',
        ),
      );
    } catch (e) {
      if (state is HrLoaded) {
        emit((state as HrLoaded).copyWith(errorMessage: e.toString()));
      }
    }
  }

  Future<void> _onCreateEvaluation(
    CreateEvaluationRequested event,
    Emitter<HrState> emit,
  ) async {
    if (state is! HrLoaded) return;
    try {
      final row = await _repository.createEvaluation(
        employeeId: event.employeeId,
        period: event.period,
        performance: event.performance,
        potential: event.potential,
        note: event.note,
      );
      if (state is! HrLoaded) return;
      final current = state as HrLoaded;
      emit(
        current.copyWith(
          evaluations: [row, ...current.evaluations],
          evaluationsLoaded: true,
          successMessage: 'hr_toast_evaluation_created',
        ),
      );
    } catch (e) {
      if (state is HrLoaded) {
        emit((state as HrLoaded).copyWith(errorMessage: e.toString()));
      }
    }
  }

  Future<void> _onCreateContract(
    CreateContractRequested event,
    Emitter<HrState> emit,
  ) async {
    if (state is! HrLoaded) return;
    try {
      final row = await _repository.createContract(
        employeeId: event.employeeId,
        number: event.number,
        startDate: event.startDate,
        endDate: event.endDate,
      );
      if (state is! HrLoaded) return;
      final current = state as HrLoaded;
      emit(
        current.copyWith(
          contracts: [row, ...current.contracts],
          contractsLoaded: true,
          successMessage: 'hr_toast_contract_created',
        ),
      );
    } catch (e) {
      if (state is HrLoaded) {
        emit((state as HrLoaded).copyWith(errorMessage: e.toString()));
      }
    }
  }

  Future<void> _onDeleteContract(
    DeleteContractRequested event,
    Emitter<HrState> emit,
  ) async {
    if (state is! HrLoaded) return;
    try {
      await _repository.deleteContract(event.id);
      if (state is! HrLoaded) return;
      final current = state as HrLoaded;
      emit(
        current.copyWith(
          contracts: current.contracts.where((c) => c.id != event.id).toList(),
          successMessage: 'hr_toast_contract_deleted',
        ),
      );
    } catch (e) {
      if (state is HrLoaded) {
        emit((state as HrLoaded).copyWith(errorMessage: e.toString()));
      }
    }
  }

  Future<void> _onCreateKpiRequested(
    CreateKpiRequested event,
    Emitter<HrState> emit,
  ) async {
    if (state is! HrLoaded) return;
    final current = state as HrLoaded;
    try {
      final created = await _repository.createKpi(
        employeeId: event.employeeId,
        period: event.period,
        metric: event.metric,
        planValue: event.planValue,
        factValue: event.factValue,
      );
      _cachedKpiRecords = [created, ..._cachedKpiRecords];
      emit(
        current.copyWith(
          kpiRecords: _cachedKpiRecords,
          successMessage: 'hr_toast_kpi_created',
        ),
      );
    } catch (e) {
      emit(current.copyWith(errorMessage: e.toString()));
    }
  }

  Future<void> _onUpdateKpiRequested(
    UpdateKpiRequested event,
    Emitter<HrState> emit,
  ) async {
    if (state is! HrLoaded) return;
    final current = state as HrLoaded;
    try {
      final updated = await _repository.updateKpi(
        kpiId: event.kpiId,
        metric: event.metric,
        planValue: event.planValue,
        factValue: event.factValue,
      );
      _cachedKpiRecords = _cachedKpiRecords
          .map((k) => k.id == event.kpiId ? updated : k)
          .toList();
      emit(
        current.copyWith(
          kpiRecords: _cachedKpiRecords,
          successMessage: 'hr_toast_kpi_updated',
        ),
      );
    } catch (e) {
      emit(current.copyWith(errorMessage: e.toString()));
    }
  }

  Future<void> _onDeleteKpiRequested(
    DeleteKpiRequested event,
    Emitter<HrState> emit,
  ) async {
    if (state is! HrLoaded) return;
    final current = state as HrLoaded;
    try {
      await _repository.deleteKpi(event.kpiId);
      _cachedKpiRecords = _cachedKpiRecords
          .where((k) => k.id != event.kpiId)
          .toList();
      emit(
        current.copyWith(
          kpiRecords: _cachedKpiRecords,
          successMessage: 'hr_toast_kpi_deleted',
        ),
      );
    } catch (e) {
      emit(current.copyWith(errorMessage: e.toString()));
    }
  }

  Future<void> _onBlockEmployeeRequested(
    BlockEmployeeRequested event,
    Emitter<HrState> emit,
  ) async {
    if (state is! HrLoaded) return;
    final current = state as HrLoaded;
    try {
      await _repository.blockEmployee(event.employeeId);
      _cachedEmployees = _cachedEmployees
          .map(
            (e) =>
                e.id == event.employeeId ? e.copyWith(status: 'inactive') : e,
          )
          .toList();
      emit(
        current.copyWith(
          employees: _cachedEmployees,
          successMessage: 'hr_toast_employee_blocked',
        ),
      );
    } catch (e) {
      emit(current.copyWith(errorMessage: e.toString()));
    }
  }

  Future<void> _onUnblockEmployeeRequested(
    UnblockEmployeeRequested event,
    Emitter<HrState> emit,
  ) async {
    if (state is! HrLoaded) return;
    final current = state as HrLoaded;
    try {
      await _repository.unblockEmployee(event.employeeId);
      _cachedEmployees = _cachedEmployees
          .map(
            (e) => e.id == event.employeeId ? e.copyWith(status: 'active') : e,
          )
          .toList();
      emit(
        current.copyWith(
          employees: _cachedEmployees,
          successMessage: 'hr_toast_employee_unblocked',
        ),
      );
    } catch (e) {
      emit(current.copyWith(errorMessage: e.toString()));
    }
  }

  Future<void> _onArchiveEmployeeRequested(
    ArchiveEmployeeRequested event,
    Emitter<HrState> emit,
  ) async {
    if (state is! HrLoaded) return;
    final current = state as HrLoaded;
    try {
      await _repository.archiveEmployee(event.employeeId);
      _cachedEmployees = _cachedEmployees
          .map(
            (e) => e.id == event.employeeId ? e.copyWith(isArchived: true) : e,
          )
          .toList();
      emit(
        current.copyWith(
          employees: _cachedEmployees,
          successMessage: 'hr_toast_employee_archived',
        ),
      );
    } catch (e) {
      emit(current.copyWith(errorMessage: e.toString()));
    }
  }

  Future<void> _onRestoreEmployeeRequested(
    RestoreEmployeeRequested event,
    Emitter<HrState> emit,
  ) async {
    if (state is! HrLoaded) return;
    final current = state as HrLoaded;
    try {
      await _repository.restoreEmployee(event.employeeId);
      _cachedEmployees = _cachedEmployees
          .map(
            (e) => e.id == event.employeeId ? e.copyWith(isArchived: false) : e,
          )
          .toList();
      emit(
        current.copyWith(
          employees: _cachedEmployees,
          successMessage: 'hr_toast_employee_restored',
        ),
      );
    } catch (e) {
      emit(current.copyWith(errorMessage: e.toString()));
    }
  }

  Future<void> _onSyncIikoEmployeesRequested(
    SyncIikoEmployeesRequested event,
    Emitter<HrState> emit,
  ) async {
    if (state is! HrLoaded) return;
    final current = state as HrLoaded;
    try {
      await _repository.syncIikoEmployees();
      final fresh = await _repository.getEmployees(forceRefresh: true);
      _cachedEmployees = fresh;
      emit(
        current.copyWith(
          employees: _cachedEmployees,
          successMessage: 'hr_toast_iiko_synced',
        ),
      );
    } catch (e) {
      emit(current.copyWith(errorMessage: e.toString()));
    }
  }
}
