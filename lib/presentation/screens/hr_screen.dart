import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_tabler_icons/flutter_tabler_icons.dart';
import 'package:intl/intl.dart';
import '../../core/theme/theme_extensions.dart';
import '../../core/localization/language_cubit.dart';
import '../../features/hr/bloc/hr_bloc.dart';
import '../../features/hr/bloc/hr_event.dart';
import '../../features/hr/bloc/hr_state.dart';
import '../../features/hr/domain/hr_models.dart';
import '../../features/hr/domain/hr_repository.dart';
import '../widgets/ledger_card.dart';
import '../widgets/ledger_pill.dart';

class HrScreen extends StatelessWidget {
  const HrScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider<HrBloc>(
      create: (context) => HrBloc(context.read<HrRepository>())..add(const LoadHrData('2026-06')),
      child: const HrView(),
    );
  }
}

class HrView extends StatefulWidget {
  const HrView({super.key});

  @override
  State<HrView> createState() => _HrViewState();
}

class _HrViewState extends State<HrView> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String _selectedPeriod = '2026-06';

  final List<String> _periods = ['2026-05', '2026-06', '2026-07'];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final textStyles = context.textStyles;
    final localeCubit = context.read<LanguageCubit>();

    return Scaffold(
      appBar: AppBar(
        backgroundColor: colors.surface,
        elevation: 0,
        title: Text(
          localeCubit.translate('hr_title'),
          style: textStyles.h2Sans.copyWith(fontWeight: FontWeight.w500),
        ),
        actions: [
          // Выбор периода
          DropdownButton<String>(
            value: _selectedPeriod,
            dropdownColor: colors.surface,
            underline: const SizedBox(),
            icon: Icon(TablerIcons.calendar, size: 18, color: colors.brand),
            items: _periods.map((p) {
              return DropdownMenuItem(
                value: p,
                child: Text(p, style: textStyles.bodyMono.copyWith(fontWeight: FontWeight.w500)),
              );
            }).toList(),
            onChanged: (val) {
              if (val != null) {
                setState(() {
                  _selectedPeriod = val;
                });
                context.read<HrBloc>().add(LoadHrData(val));
              }
            },
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(TablerIcons.user_plus),
            color: colors.brand,
            onPressed: () => _showAddEmployeeDialog(context),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: colors.brand,
          labelColor: colors.brand,
          unselectedLabelColor: colors.textSecondary,
          labelStyle: textStyles.bodySans.copyWith(fontWeight: FontWeight.w500),
          tabs: [
            Tab(text: localeCubit.translate('hr_tab_staff')),
            Tab(text: localeCubit.translate('hr_tab_kpi')),
            Tab(text: localeCubit.translate('hr_tab_salary')),
          ],
        ),
      ),
      body: BlocListener<HrBloc, HrState>(
        listener: (context, state) {
          if (state is HrLoaded) {
            if (state.errorMessage != null) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(state.errorMessage!),
                  backgroundColor: colors.accentRed,
                ),
              );
            } else if (state.successMessage != null) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(state.successMessage!),
                  backgroundColor: colors.accentGreen,
                ),
              );
            }
          }
        },
        child: BlocBuilder<HrBloc, HrState>(
          builder: (context, state) {
            if (state is HrLoading) {
              return const Center(child: CircularProgressIndicator());
            }

            if (state is HrError) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(TablerIcons.alert_circle, size: 48, color: colors.accentRed),
                      const SizedBox(height: 16),
                      Text(state.message, style: textStyles.bodySans, textAlign: TextAlign.center),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: () => context.read<HrBloc>().add(LoadHrData(_selectedPeriod)),
                        child: const Text('Повторить попытку'),
                      ),
                    ],
                  ),
                ),
              );
            }

            if (state is HrLoaded) {
              return TabBarView(
                controller: _tabController,
                children: [
                  _buildStaffTab(context, state),
                  _buildKpiTab(context, state),
                  _buildSalaryTab(context, state),
                ],
              );
            }

            return const SizedBox();
          },
        ),
      ),
    );
  }

  Widget _buildStaffTab(BuildContext context, HrLoaded state) {
    final colors = context.colors;
    final textStyles = context.textStyles;
    final localeCubit = context.read<LanguageCubit>();
    final oCcy = NumberFormat("#,##0.00", "ru_RU");

    return RefreshIndicator(
      onRefresh: () async {
        context.read<HrBloc>().add(LoadHrData(_selectedPeriod));
      },
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: state.employees.length,
        separatorBuilder: (context, index) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final emp = state.employees[index];

          Color statusBg = colors.brand.withValues(alpha: 0.08);
          Color statusText = colors.brand;
          String statusLabel = localeCubit.translate('status_active');

          if (emp.status == 'vacation') {
            statusBg = colors.accentAmber.withValues(alpha: 0.08);
            statusText = colors.accentAmber;
            statusLabel = localeCubit.translate('status_vacation');
          } else if (emp.status == 'fired') {
            statusBg = colors.accentRed.withValues(alpha: 0.08);
            statusText = colors.accentRed;
            statusLabel = localeCubit.translate('status_fired');
          }

          return LedgerCard(
            padding: const EdgeInsets.all(14),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(emp.fullName, style: textStyles.bodySans.copyWith(fontWeight: FontWeight.w500)),
                      const SizedBox(height: 4),
                      Text(
                        '${emp.position ?? "Сотрудник"} • ${emp.departmentName ?? "Основной офис"}',
                        style: textStyles.captionSans.copyWith(color: colors.textSecondary),
                      ),
                      const SizedBox(height: 4),
                      if (emp.phone != null)
                        Text(
                          emp.phone!,
                          style: textStyles.smallSans.copyWith(color: colors.textTooltip),
                        ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    LedgerPill(
                      text: statusLabel,
                      backgroundColor: statusBg,
                      textColor: statusText,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${oCcy.format(emp.baseSalary)} TJS',
                      style: textStyles.bodyMono.copyWith(fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildKpiTab(BuildContext context, HrLoaded state) {
    final colors = context.colors;
    final textStyles = context.textStyles;
    final localeCubit = context.read<LanguageCubit>();
    final oCcy = NumberFormat("#,##0.00", "ru_RU");

    if (state.kpiAlerts.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Text(
            'Нарушений KPI за этот период нет.',
            style: textStyles.bodySans.copyWith(color: colors.textTooltip),
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () async {
        context.read<HrBloc>().add(LoadHrData(_selectedPeriod));
      },
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: state.kpiAlerts.length,
        separatorBuilder: (context, index) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final alert = state.kpiAlerts[index];
          final percent = (alert.completion * 100).toStringAsFixed(0);

          return LedgerCard(
            padding: const EdgeInsets.all(14),
            borderColor: alert.triggered ? colors.accentAmber : colors.border,
            backgroundColor: alert.triggered ? colors.accentAmber.withValues(alpha: 0.04) : colors.surface,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(alert.employeeName, style: textStyles.bodySans.copyWith(fontWeight: FontWeight.w500)),
                    LedgerPill(
                      text: '$percent%',
                      backgroundColor: alert.triggered ? colors.accentAmber.withValues(alpha: 0.1) : colors.accentGreen.withValues(alpha: 0.1),
                      textColor: alert.triggered ? colors.accentAmber : colors.accentGreen,
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text('${localeCubit.translate('kpi_metric')}: ${alert.metric}', style: textStyles.captionSans),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text(
                      '${localeCubit.translate('kpi_plan')}: ${oCcy.format(alert.planValue)} | ${localeCubit.translate('kpi_fact')}: ${oCcy.format(alert.factValue)}',
                      style: textStyles.smallMono.copyWith(color: colors.textSecondary),
                    ),
                  ],
                ),
                if (alert.comment != null && alert.comment!.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    'AI-анализ: ${alert.comment!}',
                    style: textStyles.smallSans.copyWith(color: colors.accentAmber, fontStyle: FontStyle.italic),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildSalaryTab(BuildContext context, HrLoaded state) {
    final colors = context.colors;
    final textStyles = context.textStyles;
    final oCcy = NumberFormat("#,##0.00", "ru_RU");

    if (state.salaryRecords.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Text(
            'Начислений заработной платы за этот период нет.',
            style: textStyles.bodySans.copyWith(color: colors.textTooltip),
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () async {
        context.read<HrBloc>().add(LoadHrData(_selectedPeriod));
      },
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: state.salaryRecords.length,
        separatorBuilder: (context, index) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final record = state.salaryRecords[index];

          return InkWell(
            onDoubleTap: () => _showRecalcSalaryDialog(context, record),
            child: LedgerCard(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(record.employeeName, style: textStyles.bodySans.copyWith(fontWeight: FontWeight.w500)),
                      Text(
                        '${oCcy.format(record.totalAmount)} TJS',
                        style: textStyles.bodyMono.copyWith(
                          fontWeight: FontWeight.w600,
                          color: colors.brand,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Оклад: ${oCcy.format(record.baseAmount)}',
                        style: textStyles.smallMono.copyWith(color: colors.textSecondary),
                      ),
                      Text(
                        'Бонус: +${oCcy.format(record.bonusAmount)}',
                        style: textStyles.smallMono.copyWith(color: colors.accentGreen),
                      ),
                      Text(
                        'Удержания: -${oCcy.format(record.deductions)}',
                        style: textStyles.smallMono.copyWith(color: colors.accentRed),
                      ),
                    ],
                  ),
                  if (record.bonusFormula != null && record.bonusFormula!.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      'Формула KPI: ${record.bonusFormula!}',
                      style: textStyles.smallSans.copyWith(color: colors.textTooltip, fontStyle: FontStyle.italic),
                    ),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void _showAddEmployeeDialog(BuildContext context) {
    final colors = context.colors;
    final hrBloc = context.read<HrBloc>();
    final nameController = TextEditingController();
    final posController = TextEditingController();
    final salaryController = TextEditingController();
    final phoneController = TextEditingController();
    final emailController = TextEditingController();

    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: colors.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Прием на работу'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(labelText: 'ФИО сотрудника'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: posController,
                  decoration: const InputDecoration(labelText: 'Должность'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: salaryController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: 'Оклад (TJS)'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: phoneController,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(labelText: 'Телефон'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(labelText: 'E-mail'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Отмена'),
            ),
            ElevatedButton(
              onPressed: () {
                final name = nameController.text.trim();
                final salary = double.tryParse(salaryController.text) ?? 0.0;

                if (name.isEmpty) return;

                hrBloc.add(
                  CreateEmployeeRequested(
                    Employee(
                      id: '',
                      fullName: name,
                      position: posController.text.trim(),
                      baseSalary: salary,
                      phone: phoneController.text.trim(),
                      email: emailController.text.trim(),
                      status: 'active',
                      createdAt: DateTime.now(),
                    ),
                  ),
                );
                Navigator.pop(dialogContext);
              },
              child: const Text('Добавить'),
            ),
          ],
        );
      },
    );
  }

  void _showRecalcSalaryDialog(BuildContext context, SalaryRecord record) {
    final colors = context.colors;
    final hrBloc = context.read<HrBloc>();
    final baseController = TextEditingController(text: record.baseAmount.toString());
    final dedController = TextEditingController(text: record.deductions.toString());
    final formulaController = TextEditingController(text: record.bonusFormula ?? '');

    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: colors.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text('Корректировка ЗП: ${record.employeeName}'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: baseController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: 'Базовый оклад'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: dedController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: 'Удержания / Штрафы'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: formulaController,
                  decoration: const InputDecoration(
                    labelText: 'Формула бонуса (KPI)',
                    hintText: 'например: fact_value * 0.1',
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Отмена'),
            ),
            ElevatedButton(
              onPressed: () {
                final base = double.tryParse(baseController.text);
                final ded = double.tryParse(dedController.text);

                hrBloc.add(
                  RecalcSalaryRequested(
                    employeeId: record.employeeId,
                    period: record.period,
                    baseAmount: base,
                    deductions: ded,
                    bonusFormula: formulaController.text.trim(),
                  ),
                );
                Navigator.pop(dialogContext);
              },
              child: const Text('Пересчитать'),
            ),
          ],
        );
      },
    );
  }
}
