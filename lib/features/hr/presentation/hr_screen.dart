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
import '../../../presentation/widgets/ledger_bottom_sheet.dart';
import '../../../presentation/widgets/ledger_shimmer.dart';

part 'hr_extra_tabs.dart';

String _currentHrPeriod() {
  final now = DateTime.now();
  final year = now.year;
  final month = now.month.toString().padLeft(2, '0');
  return '$year-$month';
}

enum HrNavSection {
  staff,
  org,
  attendance,
  kpi,
  salary,
  recruitment,
  nineBox,
  contracts,
  movement,
}

String _hrSectionTitle(LanguageCubit language, HrNavSection section) {
  return language.translate(switch (section) {
    HrNavSection.staff => 'hr_tab_staff',
    HrNavSection.org => 'hr_tab_org',
    HrNavSection.attendance => 'hr_tab_attendance',
    HrNavSection.kpi => 'hr_tab_kpi',
    HrNavSection.salary => 'hr_tab_salary',
    HrNavSection.recruitment => 'hr_tab_recruitment',
    HrNavSection.nineBox => 'hr_tab_ninebox',
    HrNavSection.contracts => 'hr_tab_contracts',
    HrNavSection.movement => 'hr_tab_movement',
  });
}

void _openHrSection(
  BuildContext context,
  HrNavSection section, {
  required String period,
}) {
  final bloc = context.read<HrBloc>();
  final lazySection = switch (section) {
    HrNavSection.org => HrSection.org,
    HrNavSection.attendance => HrSection.attendance,
    HrNavSection.recruitment => HrSection.recruitment,
    HrNavSection.nineBox => HrSection.nineBox,
    HrNavSection.contracts => HrSection.contracts,
    HrNavSection.movement => HrSection.movement,
    _ => null,
  };
  if (lazySection != null) {
    bloc.add(LoadHrSection(lazySection));
  }
  Navigator.of(context, rootNavigator: true).push(
    MaterialPageRoute(
      builder: (_) => BlocProvider.value(
        value: bloc,
        child: HrSectionScreen(section: section, period: period),
      ),
    ),
  );
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

class _HrViewState extends State<HrView> with HrExtraTabsMixin {
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
    _pickerYear = int.parse(_selectedPeriod.split('-')[0]);
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
    final canWrite = _canManageHr(context);

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        backgroundColor: colors.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        title: Text(
          localeCubit.translate('hr_title'),
          style: textStyles.h2Sans.copyWith(
            fontSize: 19,
            fontWeight: FontWeight.w600,
            color: colors.textPrimary,
          ),
        ),
        actions: [
          InkWell(
            onTap: () {
              setState(() {
                _isMonthPickerExpanded = !_isMonthPickerExpanded;
                if (_isMonthPickerExpanded) {
                  _pickerYear = int.parse(_selectedPeriod.split('-')[0]);
                }
              });
            },
            borderRadius: BorderRadius.circular(8),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: colors.surfaceNested,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: colors.border),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _formatPeriod(_selectedPeriod, localeCubit),
                    style: textStyles.captionSans.copyWith(
                      fontWeight: FontWeight.w600,
                      color: colors.brand,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    _isMonthPickerExpanded
                        ? TablerIcons.chevron_up
                        : TablerIcons.chevron_down,
                    size: 16,
                    color: colors.brand,
                  ),
                ],
              ),
            ),
          ),
          if (canWrite)
            IconButton(
              icon: const Icon(TablerIcons.user_plus, size: 20),
              tooltip: localeCubit.translate('hr_hire_title'),
              color: colors.brand,
              onPressed: () => _showAddEmployeeBottomSheet(context),
            ),
          const SizedBox(width: 4),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: colors.border),
        ),
      ),
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
        child: Column(
          children: [
            ClipRect(
              child: AnimatedAlign(
                duration: const Duration(milliseconds: 250),
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
                    return _buildHrOverviewHub(context, state);
                  }

                  return const SizedBox();
                },
              ),
            ),
          ],
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
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: colors.border)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                language.translate('hr_select_month'),
                style: textStyles.h2Sans.copyWith(
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
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
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
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
          const SizedBox(height: 10),
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
                    color: isSelected ? colors.brand : colors.surfaceNested,
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
                          ? FontWeight.w600
                          : FontWeight.w500,
                      fontSize: 13,
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildHrOverviewHub(BuildContext context, HrLoaded state) {
    final colors = context.colors;
    final textStyles = context.textStyles;
    final locale = context.watch<LanguageCubit>();
    final oCcy = localizedDecimalFormat(context);
    final canWrite = _canManageHr(context);

    final totalPayroll = state.salaryRecords.isNotEmpty
        ? state.salaryRecords.fold<double>(0.0, (s, r) => s + r.totalAmount)
        : state.employees.fold<double>(0.0, (s, e) => s + e.baseSalary);
    final totalEmployees = state.employees.length;
    final activeEmployees =
        state.employees.where((e) => e.status == 'active').length;
    final avgKpi = state.kpiAlerts.isNotEmpty
        ? state.kpiAlerts.fold<double>(0.0, (s, a) => s + a.completion) /
            state.kpiAlerts.length
        : 1.0;
    final atRiskCount = state.kpiAlerts.where((a) => a.triggered).length;
    final turnoverRate =
        state.employees.isNotEmpty && (state.movement?.fired.isNotEmpty ?? false)
            ? (state.movement!.fired.length / state.employees.length)
            : 0.0;
    final hasRisk = atRiskCount > 0 || turnoverRate > 0;

    return RefreshIndicator(
      onRefresh: () => _refreshHr(context),
      child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        children: [
          // 1. Hero Card: Total Payroll & Staff Metrics
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: colors.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: colors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        locale.translate('hr_hero_payroll'),
                        style: textStyles.captionSans.copyWith(
                          color: colors.textSecondary,
                          fontWeight: FontWeight.w500,
                          fontSize: 13.5,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: colors.brand.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            TablerIcons.chart_pie,
                            size: 13,
                            color: colors.brand,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'KPI: ${(avgKpi * 100).toStringAsFixed(0)}%',
                            style: textStyles.captionSans.copyWith(
                              color: colors.brand,
                              fontWeight: FontWeight.w600,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  '${oCcy.format(totalPayroll)} TJS',
                  style: textStyles.h2Sans.copyWith(
                    fontWeight: FontWeight.w700,
                    fontSize: 24,
                    color: colors.textPrimary,
                  ),
                ),
                const SizedBox(height: 12),
                Container(height: 1, color: colors.border),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Icon(TablerIcons.users, size: 16, color: colors.brand),
                    const SizedBox(width: 6),
                    Text(
                      locale.translate(
                        'hr_employees_count',
                        params: {'count': '$totalEmployees'},
                      ),
                      style: textStyles.captionSans.copyWith(
                        color: colors.textPrimary,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '• $activeEmployees ${locale.translate('hr_status_active').toLowerCase()}',
                      style: textStyles.captionSans.copyWith(
                        color: colors.textSecondary,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // 2. Actionable Attention & Risks Card
          InkWell(
            onTap: () => _openHrSection(
              context,
              hasRisk ? HrNavSection.movement : HrNavSection.staff,
              period: _selectedPeriod,
            ),
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: colors.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: hasRisk
                      ? colors.accentAmber.withValues(alpha: 0.6)
                      : colors.accentGreen.withValues(alpha: 0.4),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: hasRisk
                          ? colors.accentAmber.withValues(alpha: 0.1)
                          : colors.accentGreen.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      hasRisk
                          ? TablerIcons.alert_triangle
                          : TablerIcons.circle_check,
                      color: hasRisk ? colors.accentAmber : colors.accentGreen,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          locale.translate('hr_attention_title'),
                          style: textStyles.bodySans.copyWith(
                            fontWeight: FontWeight.w600,
                            fontSize: 14.5,
                            color: colors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          hasRisk
                              ? locale.translate(
                                  'hr_attention_risk',
                                  params: {
                                    'rate':
                                        '${(turnoverRate * 100).toStringAsFixed(1)}%',
                                    'risk': '$atRiskCount',
                                  },
                                )
                              : locale.translate('hr_attention_ok'),
                          style: textStyles.captionSans.copyWith(
                            color: colors.textSecondary,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    TablerIcons.chevron_right,
                    size: 18,
                    color: colors.textSecondary,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),

          // 3. Quick Action Button (if canWrite)
          if (canWrite) ...[
            SizedBox(
              width: double.infinity,
              height: 44,
              child: ElevatedButton.icon(
                onPressed: () => _showAddEmployeeBottomSheet(context),
                icon: const Icon(TablerIcons.user_plus, size: 18),
                label: Text(locale.translate('hr_hire_title')),
                style: ElevatedButton.styleFrom(
                  backgroundColor: colors.brand,
                  foregroundColor: colors.surface,
                  elevation: 0,
                  textStyle: textStyles.bodySans.copyWith(
                    fontWeight: FontWeight.w600,
                    fontSize: 14.5,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 14),
          ],

          // 4. Main 2x2 Navigation Grid
          Row(
            children: [
              Expanded(
                child: _buildHubCard(
                  context,
                  title: locale.translate('hr_tab_staff'),
                  subtitle: locale.translate(
                    'hr_employees_count',
                    params: {'count': '$totalEmployees'},
                  ),
                  icon: TablerIcons.users,
                  onTap: () => _openHrSection(
                    context,
                    HrNavSection.staff,
                    period: _selectedPeriod,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildHubCard(
                  context,
                  title: locale.translate('hr_tab_org'),
                  subtitle: locale.translate('hr_default_main_office'),
                  icon: TablerIcons.sitemap,
                  onTap: () => _openHrSection(
                    context,
                    HrNavSection.org,
                    period: _selectedPeriod,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildHubCard(
                  context,
                  title: locale.translate('hr_tab_attendance'),
                  subtitle: locale.translate('hr_attendance_hours'),
                  icon: TablerIcons.calendar_time,
                  onTap: () => _openHrSection(
                    context,
                    HrNavSection.attendance,
                    period: _selectedPeriod,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildHubCard(
                  context,
                  title: locale.translate('hr_tab_kpi'),
                  subtitle: '${(avgKpi * 100).toStringAsFixed(0)}% ср.',
                  icon: TablerIcons.target_arrow,
                  onTap: () => _openHrSection(
                    context,
                    HrNavSection.kpi,
                    period: _selectedPeriod,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // 5. Secondary 2x2 Navigation Grid
          Row(
            children: [
              Expanded(
                child: _buildHubCard(
                  context,
                  title: locale.translate('hr_tab_salary'),
                  subtitle: '${oCcy.format(totalPayroll)} TJS',
                  icon: TablerIcons.receipt_2,
                  onTap: () => _openHrSection(
                    context,
                    HrNavSection.salary,
                    period: _selectedPeriod,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildHubCard(
                  context,
                  title: locale.translate('hr_tab_recruitment'),
                  subtitle: locale.translate('hr_candidate_vacancy'),
                  icon: TablerIcons.briefcase,
                  onTap: () => _openHrSection(
                    context,
                    HrNavSection.recruitment,
                    period: _selectedPeriod,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildHubCard(
                  context,
                  title: locale.translate('hr_tab_ninebox'),
                  subtitle: locale.translate('hr_eval_potential'),
                  icon: TablerIcons.layout_grid,
                  onTap: () => _openHrSection(
                    context,
                    HrNavSection.nineBox,
                    period: _selectedPeriod,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildHubCard(
                  context,
                  title: locale.translate('hr_tab_contracts'),
                  subtitle: locale.translate('hr_tab_movement'),
                  icon: TablerIcons.file_certificate,
                  onTap: () => _openHrSection(
                    context,
                    HrNavSection.contracts,
                    period: _selectedPeriod,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // 6. Recent Staff Feed
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                locale.translate('hr_recent_staff'),
                style: textStyles.h2Sans.copyWith(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: colors.textPrimary,
                ),
              ),
              TextButton(
                onPressed: () => _openHrSection(
                  context,
                  HrNavSection.staff,
                  period: _selectedPeriod,
                ),
                style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Row(
                  children: [
                    Text(
                      locale.translate('hr_all_staff'),
                      style: textStyles.captionSans.copyWith(
                        color: colors.brand,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      TablerIcons.chevron_right,
                      size: 14,
                      color: colors.brand,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          if (state.employees.isEmpty)
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: colors.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: colors.border),
              ),
              alignment: Alignment.center,
              child: Text(
                locale.translate('hr_org_empty'),
                style: textStyles.captionSans.copyWith(
                  color: colors.textSecondary,
                  fontSize: 13.5,
                ),
              ),
            )
          else
            ...state.employees.take(5).map((emp) {
              Color statusBg = colors.brand.withValues(alpha: 0.08);
              Color statusText = colors.brand;
              String statusLabel = locale.translate('hr_status_active');

              if (emp.status == 'vacation') {
                statusBg = colors.accentAmber.withValues(alpha: 0.1);
                statusText = colors.accentAmber;
                statusLabel = locale.translate('hr_status_vacation');
              } else if (emp.status == 'fired') {
                statusBg = colors.accentRed.withValues(alpha: 0.1);
                statusText = colors.accentRed;
                statusLabel = locale.translate('hr_status_fired');
              }

              final initial = emp.fullName.isNotEmpty
                  ? emp.fullName[0].toUpperCase()
                  : '?';

              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: colors.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: colors.border),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: colors.surfaceNested,
                          shape: BoxShape.circle,
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          initial,
                          style: textStyles.bodySans.copyWith(
                            fontWeight: FontWeight.w700,
                            color: colors.brand,
                            fontSize: 15,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              emp.fullName,
                              style: textStyles.bodySans.copyWith(
                                fontWeight: FontWeight.w600,
                                fontSize: 14.5,
                                color: colors.textPrimary,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              locale.translate(
                                'hr_employee_details',
                                params: {
                                  'position':
                                      emp.position ??
                                      locale.translate('hr_default_employee'),
                                  'department':
                                      emp.departmentName ??
                                      locale.translate(
                                        'hr_default_main_office',
                                      ),
                                },
                              ),
                              style: textStyles.captionSans.copyWith(
                                color: colors.textSecondary,
                                fontSize: 12.5,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: statusBg,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              statusLabel,
                              style: textStyles.captionSans.copyWith(
                                color: statusText,
                                fontWeight: FontWeight.w600,
                                fontSize: 11.5,
                              ),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            locale.translate(
                              'hr_amount_tjs',
                              params: {'amount': oCcy.format(emp.baseSalary)},
                            ),
                            style: textStyles.bodySans.copyWith(
                              fontWeight: FontWeight.w700,
                              fontSize: 13.5,
                              color: colors.textPrimary,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            }),
        ],
      ),
    );
  }

  Widget _buildHubCard(
    BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    final colors = context.colors;
    final textStyles = context.textStyles;

    return Material(
      color: colors.surface,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: colors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: colors.brand.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(icon, size: 20, color: colors.brand),
                  ),
                  Icon(
                    TablerIcons.chevron_right,
                    size: 16,
                    color: colors.textSecondary,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                title,
                style: textStyles.bodySans.copyWith(
                  fontWeight: FontWeight.w600,
                  fontSize: 14.5,
                  color: colors.textPrimary,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: textStyles.captionSans.copyWith(
                  color: colors.textSecondary,
                  fontSize: 12.5,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class HrSectionScreen extends StatefulWidget {
  final HrNavSection section;
  final String period;

  const HrSectionScreen({
    super.key,
    required this.section,
    required this.period,
  });

  @override
  State<HrSectionScreen> createState() => _HrSectionScreenState();
}

class _HrSectionScreenState extends State<HrSectionScreen>
    with HrExtraTabsMixin {
  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final textStyles = context.textStyles;
    final locale = context.watch<LanguageCubit>();
    final canWrite = _canManageHr(context);

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        backgroundColor: colors.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: const BackButton(),
        title: Text(
          _hrSectionTitle(locale, widget.section),
          style: textStyles.h2Sans.copyWith(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: colors.textPrimary,
          ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: colors.border),
        ),
      ),
      floatingActionButton: canWrite
          ? _buildSectionFab(context, locale)
          : null,
      body: BlocBuilder<HrBloc, HrState>(
        builder: (context, state) {
          if (state is HrLoading) {
            return const HrOverviewShimmer();
          }

          if (state is HrLoaded) {
            return switch (widget.section) {
              HrNavSection.staff => _buildStaffTab(
                context,
                state,
                period: widget.period,
              ),
              HrNavSection.org => _buildOrgTab(context, state),
              HrNavSection.attendance => _buildAttendanceTab(context, state),
              HrNavSection.kpi => _buildKpiTab(
                context,
                state,
                period: widget.period,
              ),
              HrNavSection.salary => _buildSalaryTab(
                context,
                state,
                period: widget.period,
              ),
              HrNavSection.recruitment => _buildRecruitmentTab(context, state),
              HrNavSection.nineBox => _buildNineBoxTab(context, state),
              HrNavSection.contracts => _buildContractsTab(context, state),
              HrNavSection.movement => _buildMovementTab(context, state),
            };
          }

          return const SizedBox();
        },
      ),
    );
  }

  Widget? _buildSectionFab(BuildContext context, LanguageCubit locale) {
    final colors = context.colors;
    final textStyles = context.textStyles;
    final state = context.read<HrBloc>().state;
    if (state is! HrLoaded) return null;

    final (icon, label, action) = switch (widget.section) {
      HrNavSection.staff => (
        TablerIcons.user_plus,
        locale.translate('hr_hire_title'),
        () => _showAddEmployeeBottomSheet(context),
      ),
      HrNavSection.attendance => (
        TablerIcons.plus,
        locale.translate('hr_attendance_add'),
        () => _showAttendanceSheet(context, state),
      ),
      HrNavSection.recruitment => (
        TablerIcons.plus,
        locale.translate('hr_candidate_add'),
        () => _showCandidateSheet(context),
      ),
      HrNavSection.nineBox => (
        TablerIcons.plus,
        locale.translate('hr_evaluation_add'),
        () => _showEvaluationSheet(context, state),
      ),
      HrNavSection.contracts => (
        TablerIcons.plus,
        locale.translate('hr_contract_add'),
        () => _showContractSheet(context, state),
      ),
      _ => (null, null, null),
    };

    if (icon == null || label == null || action == null) return null;

    return FloatingActionButton.extended(
      heroTag: null,
      onPressed: action,
      backgroundColor: colors.brand,
      foregroundColor: colors.surface,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      icon: Icon(icon),
      label: Text(
        label,
        style: textStyles.bodySans.copyWith(
          color: colors.surface,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
