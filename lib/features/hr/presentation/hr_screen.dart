import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_tabler_icons/flutter_tabler_icons.dart';
import '../../../core/localization/locale_date_time_format.dart';
import '../../../core/localization/locale_number_format.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/theme/theme_extensions.dart';
import '../../../core/localization/language_cubit.dart';
import '../../../features/auth/bloc/auth_bloc.dart';
import '../../../features/auth/bloc/auth_state.dart';
import '../../../features/auth/domain/app_access.dart';
import '../../../features/hr/bloc/hr_bloc.dart';
import '../../../features/hr/bloc/hr_event.dart';
import '../../../features/hr/bloc/hr_state.dart';
import '../../../features/hr/domain/hr_models.dart';
import '../../../features/hr/domain/hr_repository.dart';
import '../../../presentation/widgets/expansible_widget.dart';
import '../../../presentation/widgets/ledger_card.dart';
import '../../../presentation/widgets/ledger_pill.dart';
import '../../../presentation/widgets/ledger_bottom_sheet.dart';
import '../../../presentation/widgets/ledger_collapsing_header.dart';
import '../../../presentation/widgets/ledger_shimmer.dart';

part 'hr_extra_tabs.dart';

String _currentHrPeriod() {
  final now = DateTime.now();
  final year = now.year;
  final month = now.month.toString().padLeft(2, '0');
  return '$year-$month';
}

class HrScreen extends StatelessWidget {
  const HrScreen({super.key});

  @override
  Widget build(BuildContext context) {
    context.watch<LanguageCubit>();
    return BlocProvider<HrBloc>(
      create: (context) =>
          HrBloc(context.read<HrRepository>())
            ..add(LoadHrData(_currentHrPeriod())),
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
  String _selectedPeriod = _currentHrPeriod();
  bool _isMonthPickerExpanded = false;
  late int _pickerYear;

  static const List<String> _shortMonthKeys = [
    'hr_month_jan_short',
    'hr_month_feb_short',
    'hr_month_mar_short',
    'hr_month_apr_short',
    'hr_month_may_short',
    'hr_month_jun_short',
    'hr_month_jul_short',
    'hr_month_aug_short',
    'hr_month_sep_short',
    'hr_month_oct_short',
    'hr_month_nov_short',
    'hr_month_dec_short',
  ];

  static const List<String> _fullMonthKeys = [
    'hr_month_january',
    'hr_month_february',
    'hr_month_march',
    'hr_month_april',
    'hr_month_may',
    'hr_month_june',
    'hr_month_july',
    'hr_month_august',
    'hr_month_september',
    'hr_month_october',
    'hr_month_november',
    'hr_month_december',
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 9, vsync: this);
    _tabController.addListener(_handleTabChange);
    _pickerYear = int.parse(_selectedPeriod.split('-')[0]);
  }

  void _handleTabChange() {
    if (!mounted || _tabController.indexIsChanging) return;
    final section = switch (_tabController.index) {
      1 => HrSection.org,
      2 => HrSection.attendance,
      5 => HrSection.recruitment,
      6 => HrSection.nineBox,
      7 => HrSection.contracts,
      8 => HrSection.movement,
      _ => null,
    };
    if (section != null) {
      context.read<HrBloc>().add(LoadHrSection(section));
    }
  }

  @override
  void dispose() {
    _tabController.removeListener(_handleTabChange);
    _tabController.dispose();
    super.dispose();
  }

  bool _canManageHr(BuildContext context) {
    final authState = context.read<AuthBloc>().state;
    return authState is AuthAuthenticated &&
        authState.role.canManage(AppCapability.hr);
  }

  Future<void> _refreshHr(BuildContext context) {
    final completion = Completer<void>();
    context.read<HrBloc>().add(
      LoadHrData(_selectedPeriod, forceRefresh: true, completion: completion),
    );
    return completion.future;
  }

  String _formatPeriod(String period, LanguageCubit language) {
    final parts = period.split('-');
    final year = parts[0];
    final month = int.parse(parts[1]);
    return language.translate(
      'hr_period_month_year',
      params: {
        'month': language.translate(_fullMonthKeys[month - 1]),
        'year': year,
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final textStyles = context.textStyles;
    final localeCubit = context.watch<LanguageCubit>();

    return Scaffold(
      backgroundColor: colors.background,
      body: BlocListener<HrBloc, HrState>(
        listener: (context, state) {
          if (state is HrLoaded) {
            if (state.errorMessage != null) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    localeCubit.translateMessage(state.errorMessage!),
                  ),
                  backgroundColor: colors.accentRed,
                ),
              );
            } else if (state.successMessage != null) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    localeCubit.translateMessage(state.successMessage!),
                  ),
                  backgroundColor: colors.accentGreen,
                ),
              );
            }
          }
        },
        child: NestedScrollView(
          headerSliverBuilder: (context, innerBoxIsScrolled) {
            return [
              LedgerCollapsingHeader(
                title: localeCubit.translate('hr_title'),
                pinned: true,
                floating: false,
                snap: false,
                actions: [
                  InkWell(
                    onTap: () {
                      setState(() {
                        _isMonthPickerExpanded = !_isMonthPickerExpanded;
                        if (_isMonthPickerExpanded) {
                          _pickerYear = int.parse(
                            _selectedPeriod.split('-')[0],
                          );
                        }
                      });
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      child: Row(
                        children: [
                          Text(
                            _formatPeriod(_selectedPeriod, localeCubit),
                            style: textStyles.captionSans.copyWith(
                              fontWeight: FontWeight.w500,
                              color: colors.brand,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Icon(
                            _isMonthPickerExpanded
                                ? TablerIcons.chevron_up
                                : TablerIcons.chevron_down,
                            size: 18,
                            color: colors.brand,
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (_canManageHr(context))
                    IconButton(
                      icon: const Icon(TablerIcons.user_plus),
                      tooltip: localeCubit.translate('hr_hire_title'),
                      color: colors.brand,
                      onPressed: () => _showAddEmployeeBottomSheet(context),
                    ),
                ],
                bottom: LedgerTabBar(
                  controller: _tabController,
                  isScrollable: true,
                  tabs: [
                    Tab(text: localeCubit.translate('hr_tab_staff')),
                    Tab(text: localeCubit.translate('hr_tab_org')),
                    Tab(text: localeCubit.translate('hr_tab_attendance')),
                    Tab(text: localeCubit.translate('hr_tab_kpi')),
                    Tab(text: localeCubit.translate('hr_tab_salary')),
                    Tab(text: localeCubit.translate('hr_tab_recruitment')),
                    Tab(text: localeCubit.translate('hr_tab_ninebox')),
                    Tab(text: localeCubit.translate('hr_tab_contracts')),
                    Tab(text: localeCubit.translate('hr_tab_movement')),
                  ],
                ),
              ),
            ];
          },
          body: Column(
            children: [
              ClipRect(
                child: AnimatedAlign(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOut,
                  alignment: Alignment.topCenter,
                  heightFactor: _isMonthPickerExpanded ? 1.0 : 0.0,
                  child: _buildInlineMonthPicker(localeCubit),
                ),
              ),
              Expanded(
                child: BlocBuilder<HrBloc, HrState>(
                  builder: (context, state) {
                    if (state is HrLoading) {
                      return const HrOverviewShimmer();
                    }

                    if (state is HrError) {
                      return Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24.0),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                TablerIcons.alert_circle,
                                size: 48,
                                color: colors.accentRed,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                localeCubit.translateMessage(state.message),
                                style: textStyles.bodySans,
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 16),
                              ElevatedButton(
                                onPressed: () => context.read<HrBloc>().add(
                                  LoadHrData(_selectedPeriod),
                                ),
                                child: Text(
                                  localeCubit.translate('common_retry'),
                                ),
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
                          _buildOrgTab(context, state),
                          _buildAttendanceTab(context, state),
                          _buildKpiTab(context, state),
                          _buildSalaryTab(context, state),
                          _buildRecruitmentTab(context, state),
                          _buildNineBoxTab(context, state),
                          _buildContractsTab(context, state),
                          _buildMovementTab(context, state),
                        ],
                      );
                    }

                    return const SizedBox();
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInlineMonthPicker(LanguageCubit language) {
    final colors = context.colors;
    final textStyles = context.textStyles;
    final currentMonth = int.parse(_selectedPeriod.split('-')[1]);
    final currentYear = int.parse(_selectedPeriod.split('-')[0]);

    return Container(
      color: colors.surface,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                language.translate('hr_select_month'),
                style: textStyles.h2Sans.copyWith(
                  fontWeight: FontWeight.w500,
                  fontSize: 18,
                ),
              ),
              Row(
                children: [
                  IconButton(
                    icon: const Icon(TablerIcons.chevron_left, size: 20),
                    tooltip: language.translate('common_previous'),
                    onPressed: () {
                      setState(() {
                        _pickerYear--;
                      });
                    },
                  ),
                  Text(
                    '$_pickerYear',
                    style: textStyles.bodySans.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(TablerIcons.chevron_right, size: 20),
                    tooltip: language.translate('common_next'),
                    onPressed: () {
                      setState(() {
                        _pickerYear++;
                      });
                    },
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 4,
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              childAspectRatio: 2.2,
            ),
            itemCount: 12,
            itemBuilder: (context, index) {
              final monthIdx = index + 1;
              final isSelected =
                  currentMonth == monthIdx && currentYear == _pickerYear;

              return GestureDetector(
                onTap: () {
                  final newPeriod =
                      '$_pickerYear-${monthIdx.toString().padLeft(2, '0')}';
                  setState(() {
                    _selectedPeriod = newPeriod;
                    _isMonthPickerExpanded = false;
                  });
                  context.read<HrBloc>().add(LoadHrData(newPeriod));
                },
                child: Container(
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: isSelected ? colors.brand : colors.surface,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isSelected ? colors.brand : colors.border,
                    ),
                  ),
                  child: Text(
                    language.translate(_shortMonthKeys[index]),
                    style: textStyles.captionSans.copyWith(
                      color: isSelected ? colors.surface : colors.textPrimary,
                      fontWeight: isSelected
                          ? FontWeight.w500
                          : FontWeight.normal,
                    ),
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 8),
          Container(height: 1, color: colors.border.withValues(alpha: 0.5)),
        ],
      ),
    );
  }

  Widget _buildStaffTab(BuildContext context, HrLoaded state) {
    final colors = context.colors;
    final textStyles = context.textStyles;
    final localeCubit = context.watch<LanguageCubit>();
    final oCcy = localizedDecimalFormat(context);

    return RefreshIndicator(
      onRefresh: () => _refreshHr(context),
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: state.employees.length,
        separatorBuilder: (context, index) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final emp = state.employees[index];

          Color statusBg = colors.brand.withValues(alpha: 0.08);
          Color statusText = colors.brand;
          String statusLabel = localeCubit.translate('hr_status_active');

          if (emp.status == 'vacation') {
            statusBg = colors.accentAmber.withValues(alpha: 0.08);
            statusText = colors.accentAmber;
            statusLabel = localeCubit.translate('hr_status_vacation');
          } else if (emp.status == 'fired') {
            statusBg = colors.accentRed.withValues(alpha: 0.08);
            statusText = colors.accentRed;
            statusLabel = localeCubit.translate('hr_status_fired');
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
                      Text(
                        emp.fullName,
                        style: textStyles.bodySans.copyWith(
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        localeCubit.translate(
                          'hr_employee_details',
                          params: {
                            'position':
                                emp.position ??
                                localeCubit.translate('hr_default_employee'),
                            'department':
                                emp.departmentName ??
                                localeCubit.translate('hr_default_main_office'),
                          },
                        ),
                        style: textStyles.captionSans.copyWith(
                          color: colors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      if (emp.phone != null)
                        Text(
                          emp.phone!,
                          style: textStyles.smallSans.copyWith(
                            color: colors.textTooltip,
                          ),
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
                      localeCubit.translate(
                        'hr_amount_tjs',
                        params: {'amount': oCcy.format(emp.baseSalary)},
                      ),
                      style: textStyles.bodyMono.copyWith(
                        fontWeight: FontWeight.w500,
                      ),
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
    final localeCubit = context.watch<LanguageCubit>();
    final oCcy = localizedDecimalFormat(context);

    if (state.kpiAlerts.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Text(
            localeCubit.translate('hr_kpi_empty'),
            style: textStyles.bodySans.copyWith(color: colors.textTooltip),
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => _refreshHr(context),
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: state.kpiAlerts.length,
        separatorBuilder: (context, index) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final alert = state.kpiAlerts[index];
          final percent = formatLocalizedNumber(
            context,
            alert.completion * 100,
            maximumFractionDigits: 0,
          );

          return LedgerCard(
            padding: const EdgeInsets.all(14),
            borderColor: alert.triggered ? colors.accentAmber : colors.border,
            backgroundColor: alert.triggered
                ? colors.accentAmber.withValues(alpha: 0.04)
                : colors.surface,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      localeCubit.translateMessage(alert.employeeName),
                      style: textStyles.bodySans.copyWith(
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    LedgerPill(
                      text: localeCubit.translate(
                        'hr_percentage',
                        params: {'value': percent},
                      ),
                      backgroundColor: alert.triggered
                          ? colors.accentAmber.withValues(alpha: 0.1)
                          : colors.accentGreen.withValues(alpha: 0.1),
                      textColor: alert.triggered
                          ? colors.accentAmber
                          : colors.accentGreen,
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  localeCubit.translate(
                    'hr_kpi_metric_value',
                    params: {'metric': alert.metric},
                  ),
                  style: textStyles.captionSans,
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text(
                      localeCubit.translate(
                        'hr_kpi_plan_fact',
                        params: {
                          'plan': oCcy.format(alert.planValue),
                          'fact': oCcy.format(alert.factValue),
                        },
                      ),
                      style: textStyles.smallMono.copyWith(
                        color: colors.textSecondary,
                      ),
                    ),
                  ],
                ),
                if (alert.comment != null && alert.comment!.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    localeCubit.translate(
                      'hr_ai_analysis',
                      params: {'comment': alert.comment!},
                    ),
                    style: textStyles.smallSans.copyWith(
                      color: colors.accentAmber,
                      fontStyle: FontStyle.italic,
                    ),
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
    final localeCubit = context.watch<LanguageCubit>();
    final oCcy = localizedDecimalFormat(context);

    if (state.salaryRecords.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Text(
            localeCubit.translate('hr_salary_empty'),
            style: textStyles.bodySans.copyWith(color: colors.textTooltip),
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => _refreshHr(context),
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: state.salaryRecords.length,
        separatorBuilder: (context, index) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final record = state.salaryRecords[index];
          final canManage = _canManageHr(context);
          final recalculateLabel = localeCubit.translate('hr_recalculate');

          return InkWell(
            onTap: canManage
                ? () => _showRecalcSalaryBottomSheet(context, record)
                : null,
            child: LedgerCard(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          localeCubit.translateMessage(record.employeeName),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: textStyles.bodySans.copyWith(
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        localeCubit.translate(
                          'hr_amount_tjs',
                          params: {'amount': oCcy.format(record.totalAmount)},
                        ),
                        style: textStyles.bodyMono.copyWith(
                          fontWeight: FontWeight.w500,
                          color: colors.brand,
                        ),
                      ),
                      if (canManage)
                        IconButton(
                          onPressed: () =>
                              _showRecalcSalaryBottomSheet(context, record),
                          icon: Icon(
                            TablerIcons.refresh,
                            semanticLabel: recalculateLabel,
                          ),
                          tooltip: recalculateLabel,
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 12,
                    runSpacing: 4,
                    alignment: WrapAlignment.spaceBetween,
                    children: [
                      Text(
                        localeCubit.translate(
                          'hr_salary_base',
                          params: {'amount': oCcy.format(record.baseAmount)},
                        ),
                        style: textStyles.smallMono.copyWith(
                          color: colors.textSecondary,
                        ),
                      ),
                      Text(
                        localeCubit.translate(
                          'hr_salary_bonus',
                          params: {'amount': oCcy.format(record.bonusAmount)},
                        ),
                        style: textStyles.smallMono.copyWith(
                          color: colors.accentGreen,
                        ),
                      ),
                      Text(
                        localeCubit.translate(
                          'hr_salary_deductions',
                          params: {'amount': oCcy.format(record.deductions)},
                        ),
                        style: textStyles.smallMono.copyWith(
                          color: colors.accentRed,
                        ),
                      ),
                    ],
                  ),
                  if (record.bonusFormula != null &&
                      record.bonusFormula!.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      localeCubit.translate(
                        'hr_kpi_formula',
                        params: {'formula': record.bonusFormula!},
                      ),
                      style: textStyles.smallSans.copyWith(
                        color: colors.textTooltip,
                        fontStyle: FontStyle.italic,
                      ),
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

  Future<void> _showAddEmployeeBottomSheet(BuildContext context) async {
    final textStyles = context.textStyles;
    final localeCubit = context.read<LanguageCubit>();
    final hrBloc = context.read<HrBloc>();
    final nameController = TextEditingController();
    final posController = TextEditingController();
    final salaryController = TextEditingController();
    final phoneController = TextEditingController();
    final emailController = TextEditingController();

    bool isDirty() {
      return nameController.text.trim().isNotEmpty ||
          posController.text.trim().isNotEmpty ||
          salaryController.text.trim().isNotEmpty ||
          phoneController.text.trim().isNotEmpty ||
          emailController.text.trim().isNotEmpty;
    }

    try {
      await LedgerBottomSheet.show(
        context: context,
        title: localeCubit.translate('hr_hire_title'),
        isDirty: isDirty,
        builder: (context, setSheetState) {
          final language = context.watch<LanguageCubit>();
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                style: textStyles.bodySans,
                decoration: InputDecoration(
                  labelText: language.translate('hr_employee_full_name'),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: posController,
                style: textStyles.bodySans,
                decoration: InputDecoration(
                  labelText: language.translate('hr_position'),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: salaryController,
                style: textStyles.bodySans,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: InputDecoration(
                  labelText: language.translate('hr_salary_tjs'),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: phoneController,
                style: textStyles.bodySans,
                keyboardType: TextInputType.phone,
                decoration: InputDecoration(
                  labelText: language.translate('hr_phone'),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: emailController,
                style: textStyles.bodySans,
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(
                  labelText: language.translate('hr_email'),
                ),
              ),
            ],
          );
        },
        footerBuilder: (context, setSheetState) {
          final language = context.watch<LanguageCubit>();
          return ElevatedButton(
            onPressed: () {
              final name = nameController.text.trim();
              final salary =
                  parseLocalizedNumber(context, salaryController.text) ?? 0.0;

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
              Navigator.pop(context);
            },
            child: Text(language.translate('common_add')),
          );
        },
      );
    } finally {
      nameController.dispose();
      posController.dispose();
      salaryController.dispose();
      phoneController.dispose();
      emailController.dispose();
    }
  }

  Future<void> _showRecalcSalaryBottomSheet(
    BuildContext context,
    SalaryRecord record,
  ) async {
    final textStyles = context.textStyles;
    final localeCubit = context.read<LanguageCubit>();
    final hrBloc = context.read<HrBloc>();
    final initialBase = formatLocalizedNumber(
      context,
      record.baseAmount,
      useGrouping: false,
    );
    final initialDeductions = formatLocalizedNumber(
      context,
      record.deductions,
      useGrouping: false,
    );
    final baseController = TextEditingController(text: initialBase);
    final dedController = TextEditingController(text: initialDeductions);
    final formulaController = TextEditingController(
      text: record.bonusFormula ?? '',
    );

    bool isDirty() {
      return baseController.text.trim() != initialBase ||
          dedController.text.trim() != initialDeductions ||
          formulaController.text.trim() != (record.bonusFormula ?? '');
    }

    try {
      await LedgerBottomSheet.show(
        context: context,
        title: localeCubit.translate(
          'hr_salary_adjustment_title',
          params: {
            'employee': localeCubit.translateMessage(record.employeeName),
          },
        ),
        isDirty: isDirty,
        builder: (context, setSheetState) {
          final language = context.watch<LanguageCubit>();
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: baseController,
                style: textStyles.bodySans,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: InputDecoration(
                  labelText: language.translate('hr_base_salary'),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: dedController,
                style: textStyles.bodySans,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: InputDecoration(
                  labelText: language.translate('hr_deductions_penalties'),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: formulaController,
                style: textStyles.bodySans,
                decoration: InputDecoration(
                  labelText: language.translate('hr_bonus_formula'),
                  hintText: language.translate('hr_bonus_formula_hint'),
                ),
              ),
            ],
          );
        },
        footerBuilder: (context, setSheetState) {
          final language = context.watch<LanguageCubit>();
          return ElevatedButton(
            onPressed: () {
              final base = parseLocalizedNumber(context, baseController.text);
              final ded = parseLocalizedNumber(context, dedController.text);

              hrBloc.add(
                RecalcSalaryRequested(
                  employeeId: record.employeeId,
                  period: record.period,
                  baseAmount: base,
                  deductions: ded,
                  bonusFormula: formulaController.text.trim(),
                ),
              );
              Navigator.pop(context);
            },
            child: Text(language.translate('hr_recalculate')),
          );
        },
      );
    } finally {
      baseController.dispose();
      dedController.dispose();
      formulaController.dispose();
    }
  }
}
