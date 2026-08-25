part of 'hr_screen.dart';

mixin HrExtraTabsMixin<T extends StatefulWidget> on State<T> {
  bool _canManageHr(BuildContext context) {
    final authState = context.read<AuthBloc>().state;
    return authState is AuthAuthenticated &&
        authState.role.canManage(AppCapability.hr);
  }

  Widget _sectionLoader(HrLoaded state, bool loaded, Widget child) {
    if (!loaded && state.sectionLoading) {
      return const HrOverviewShimmer();
    }
    return child;
  }

  Future<void> _sharePdfBytes(List<int> bytes, String filename) async {
    try {
      final tempDir = await getTemporaryDirectory();
      final file = File('${tempDir.path}/$filename');
      await file.writeAsBytes(bytes);
      await SharePlus.instance.share(
        ShareParams(files: [XFile(file.path, mimeType: 'application/pdf')]),
      );
    } catch (e) {
      debugPrint('Error sharing PDF: $e');
    }
  }

  Future<void> _exportMovementPdf(BuildContext context) async {
    final state = context.read<HrBloc>().state;
    if (state is! HrLoaded) return;
    final locale = context.read<LanguageCubit>();
    final period = state.period;
    final parts = period.split('-');
    final year = int.tryParse(parts[0]) ?? DateTime.now().year;
    final month = parts.length > 1
        ? (int.tryParse(parts[1]) ?? DateTime.now().month)
        : DateTime.now().month;
    final from = '$year-${month.toString().padLeft(2, '0')}-01';
    final lastDay = DateTime(year, month + 1, 0).day;
    final to =
        '$year-${month.toString().padLeft(2, '0')}-${lastDay.toString().padLeft(2, '0')}';

    try {
      final repository = context.read<HrRepository>();
      final bytes = await repository.downloadMovementReportPdf(
        dateFrom: from,
        dateTo: to,
      );
      if (bytes.isNotEmpty) {
        await _sharePdfBytes(bytes, 'movement_report_$period.pdf');
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(locale.translate('hr_toast_export_failed')),
            backgroundColor: context.colors.accentRed,
          ),
        );
      }
    }
  }

  Future<void> _showSyncIikoDialog(BuildContext context) async {
    final locale = context.read<LanguageCubit>();
    final colors = context.colors;
    final textStyles = context.textStyles;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: colors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Text(
          locale.translate('hr_sync_iiko_title'),
          style: textStyles.h2Sans.copyWith(
            fontSize: 17,
            fontWeight: FontWeight.w600,
          ),
        ),
        content: Text(
          locale.translate('hr_sync_iiko_confirm'),
          style: textStyles.bodySans.copyWith(fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(locale.translate('common_cancel')),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: colors.brand,
              foregroundColor: colors.surface,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(locale.translate('hr_sync_button')),
          ),
        ],
      ),
    );

    if (confirm == true && context.mounted) {
      context.read<HrBloc>().add(const SyncIikoEmployeesRequested());
    }
  }

  Widget _buildEmptyState({
    required IconData icon,
    required String title,
    String? subtitle,
    required LedgerColors colors,
    required LedgerTextStyles textStyles,
  }) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        const SizedBox(height: 60),
        Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: colors.surfaceNested,
                    shape: BoxShape.circle,
                    border: Border.all(color: colors.border),
                  ),
                  alignment: Alignment.center,
                  child: Icon(icon, size: 28, color: colors.textSecondary),
                ),
                const SizedBox(height: 16),
                Text(
                  title,
                  style: textStyles.h2Sans.copyWith(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: colors.textPrimary,
                  ),
                  textAlign: TextAlign.center,
                ),
                if (subtitle != null && subtitle.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    subtitle,
                    style: textStyles.captionSans.copyWith(
                      fontSize: 13,
                      color: colors.textSecondary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildOrgTab(BuildContext context, HrLoaded state) {
    final colors = context.colors;
    final textStyles = context.textStyles;
    final locale = context.watch<LanguageCubit>();

    return _sectionLoader(
      state,
      state.orgLoaded,
      RefreshIndicator(
        onRefresh: () async {
          final done = Completer<void>();
          context.read<HrBloc>().add(
            LoadHrSection(HrSection.org, forceRefresh: true, completion: done),
          );
          await done.future;
        },
        child: state.orgChart.isEmpty
            ? _buildEmptyState(
                icon: TablerIcons.sitemap,
                title: locale.translate('hr_org_empty'),
                colors: colors,
                textStyles: textStyles,
              )
            : ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  for (final root in state.orgChart)
                    ..._flattenOrg(root, 0, colors, textStyles, locale),
                ],
              ),
      ),
    );
  }

  List<Widget> _flattenOrg(
    OrgNode node,
    int level,
    LedgerColors colors,
    LedgerTextStyles textStyles,
    LanguageCubit locale,
  ) {
    final widgets = <Widget>[
      Padding(
        padding: EdgeInsets.only(left: level * 16.0, bottom: 8),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: colors.border),
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: colors.brand.withValues(alpha: 0.12),
                child: Text(
                  node.fullName.isNotEmpty
                      ? node.fullName.substring(0, 1).toUpperCase()
                      : '?',
                  style: textStyles.bodySans.copyWith(
                    color: colors.brand,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      node.fullName,
                      style: textStyles.bodySans.copyWith(
                        fontWeight: FontWeight.w600,
                        fontSize: 14.5,
                      ),
                    ),
                    if (node.position != null && node.position!.isNotEmpty)
                      Text(
                        node.position!,
                        style: textStyles.captionSans.copyWith(
                          color: colors.textSecondary,
                          fontSize: 13,
                        ),
                      ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: node.status == 'active'
                      ? colors.accentGreen.withValues(alpha: 0.1)
                      : colors.surfaceNested,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  locale.translate('hr_status_${node.status}'),
                  style: textStyles.captionSans.copyWith(
                    color: node.status == 'active'
                        ? colors.accentGreen
                        : colors.textSecondary,
                    fontWeight: FontWeight.w600,
                    fontSize: 11.5,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ];
    for (final child in node.children) {
      widgets.addAll(_flattenOrg(child, level + 1, colors, textStyles, locale));
    }
    return widgets;
  }

  Widget _buildAttendanceTab(BuildContext context, HrLoaded state) {
    final colors = context.colors;
    final textStyles = context.textStyles;
    final locale = context.watch<LanguageCubit>();
    final canWrite = _canManageHr(context);

    return _sectionLoader(
      state,
      state.attendanceLoaded,
      RefreshIndicator(
        onRefresh: () async {
          final done = Completer<void>();
          context.read<HrBloc>().add(
            LoadHrSection(
              HrSection.attendance,
              forceRefresh: true,
              completion: done,
            ),
          );
          await done.future;
        },
        child: state.attendance.isEmpty
            ? _buildEmptyState(
                icon: TablerIcons.calendar_time,
                title: locale.translate('hr_attendance_empty'),
                colors: colors,
                textStyles: textStyles,
              )
            : ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 88),
                itemCount: state.attendance.length,
                separatorBuilder: (context, index) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final row = state.attendance[index];
                  return Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: colors.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: colors.border),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                row.employeeName ?? '#${row.employeeId}',
                                style: textStyles.bodySans.copyWith(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14.5,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                formatLocalizedDateTime(
                                  context,
                                  row.workDate,
                                  style: LocalizedDateTimeStyle.date,
                                ),
                                style: textStyles.captionSans.copyWith(
                                  color: colors.textSecondary,
                                  fontSize: 12.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Text(
                          '${row.hours} h',
                          style: textStyles.bodyMono.copyWith(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                            color: colors.brand,
                          ),
                        ),
                        if (canWrite)
                          IconButton(
                            onPressed: () => context.read<HrBloc>().add(
                              DeleteAttendanceRequested(row.id),
                            ),
                            icon: Icon(
                              TablerIcons.trash,
                              size: 18,
                              color: colors.accentRed,
                            ),
                          ),
                      ],
                    ),
                  );
                },
              ),
      ),
    );
  }

  Future<void> _showAttendanceSheet(
    BuildContext context,
    HrLoaded state,
  ) async {
    final colors = context.colors;
    final textStyles = context.textStyles;
    final locale = context.read<LanguageCubit>();
    if (state.employees.isEmpty) return;

    String employeeId = state.employees.first.id;
    DateTime workDate = DateTime.now();
    final hoursCtrl = TextEditingController(text: '8');

    try {
      await LedgerBottomSheet.show(
        context: context,
        title: locale.translate('hr_attendance_add'),
        builder: (context, setSheetState) {
          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ExpansibleWidget<String>.selection(
                cardPadding: EdgeInsets.zero,
                tilePadding: const EdgeInsets.symmetric(horizontal: 8),
                title: Text(
                  state.employees
                      .firstWhere(
                        (e) => e.id == employeeId,
                        orElse: () => state.employees.first,
                      )
                      .fullName,
                  style: textStyles.bodySans.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                ),
                items: state.employees.map((e) => e.id).toList(),
                selectedValue: employeeId,
                itemLabelBuilder: (id) => state.employees
                    .firstWhere(
                      (e) => e.id == id,
                      orElse: () => state.employees.first,
                    )
                    .fullName,
                onSelected: (v) => setSheetState(() => employeeId = v),
              ),
              const SizedBox(height: 12),
              InkWell(
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: workDate,
                    firstDate: DateTime(2020),
                    lastDate: DateTime.now().add(const Duration(days: 1)),
                  );
                  if (picked != null) {
                    setSheetState(() => workDate = picked);
                  }
                },
                child: InputDecorator(
                  decoration: InputDecoration(
                    labelText: locale.translate('hr_attendance_date'),
                    suffixIcon: const Icon(TablerIcons.calendar, size: 18),
                  ),
                  child: Text(
                    formatLocalizedDateTime(
                      context,
                      workDate,
                      style: LocalizedDateTimeStyle.date,
                    ),
                    style: textStyles.bodySans,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: hoursCtrl,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                style: textStyles.bodySans,
                decoration: InputDecoration(
                  labelText: locale.translate('hr_attendance_hours'),
                ),
              ),
            ],
          );
        },
        footerBuilder: (context, setSheetState) {
          return SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: () {
                final hours =
                    parseLocalizedNumber(context, hoursCtrl.text.trim()) ?? 0;
                if (hours <= 0 || hours > 24) return;
                this.context.read<HrBloc>().add(
                  CreateAttendanceRequested(
                    employeeId: employeeId,
                    workDate: workDate,
                    hours: hours,
                  ),
                );
                Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: colors.brand,
                foregroundColor: colors.surface,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                locale.translate('common_create'),
                style: textStyles.bodySans.copyWith(
                  color: colors.surface,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          );
        },
      );
    } finally {
      hoursCtrl.dispose();
    }
  }

  Widget _buildRecruitmentTab(BuildContext context, HrLoaded state) {
    final colors = context.colors;
    final textStyles = context.textStyles;
    final locale = context.watch<LanguageCubit>();
    final canWrite = _canManageHr(context);

    return _sectionLoader(
      state,
      state.candidatesLoaded,
      RefreshIndicator(
        onRefresh: () async {
          final done = Completer<void>();
          context.read<HrBloc>().add(
            LoadHrSection(
              HrSection.recruitment,
              forceRefresh: true,
              completion: done,
            ),
          );
          await done.future;
        },
        child: state.candidates.isEmpty
            ? _buildEmptyState(
                icon: TablerIcons.user_search,
                title: locale.translate('hr_candidates_empty'),
                colors: colors,
                textStyles: textStyles,
              )
            : ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 88),
                itemCount: state.candidates.length,
                separatorBuilder: (context, index) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final c = state.candidates[index];
                  return Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: colors.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: colors.border),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                c.fullName,
                                style: textStyles.bodySans.copyWith(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14.5,
                                ),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: colors.brand.withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                locale.translate(
                                  'hr_candidate_stage_${c.stage}',
                                ),
                                style: textStyles.captionSans.copyWith(
                                  color: colors.brand,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 11.5,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          c.vacancy,
                          style: textStyles.captionSans.copyWith(
                            color: colors.textSecondary,
                          ),
                        ),
                        if (canWrite) ...[
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 6,
                            children: [
                              for (final stage in const [
                                'screening',
                                'interview',
                                'offer',
                                'hired',
                                'rejected',
                              ])
                                ActionChip(
                                  label: Text(
                                    locale.translate(
                                      'hr_candidate_stage_$stage',
                                    ),
                                    style: textStyles.smallSans,
                                  ),
                                  onPressed: () => context.read<HrBloc>().add(
                                    UpdateCandidateStageRequested(
                                      id: c.id,
                                      stage: stage,
                                    ),
                                  ),
                                ),
                              IconButton(
                                onPressed: () => context.read<HrBloc>().add(
                                  DeleteCandidateRequested(c.id),
                                ),
                                icon: Icon(
                                  TablerIcons.trash,
                                  size: 18,
                                  color: colors.accentRed,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  );
                },
              ),
      ),
    );
  }

  Future<void> _showCandidateSheet(BuildContext context) async {
    final colors = context.colors;
    final textStyles = context.textStyles;
    final locale = context.read<LanguageCubit>();
    final nameCtrl = TextEditingController();
    final vacancyCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();

    try {
      await LedgerBottomSheet.show(
        context: context,
        title: locale.translate('hr_candidate_add'),
        builder: (context, setSheetState) {
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                style: textStyles.bodySans,
                decoration: InputDecoration(
                  labelText: locale.translate('hr_candidate_name'),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: vacancyCtrl,
                style: textStyles.bodySans,
                decoration: InputDecoration(
                  labelText: locale.translate('hr_candidate_vacancy'),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: phoneCtrl,
                style: textStyles.bodySans,
                decoration: InputDecoration(
                  labelText: locale.translate('hr_candidate_phone'),
                ),
              ),
            ],
          );
        },
        footerBuilder: (context, setSheetState) {
          return SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: () {
                final name = nameCtrl.text.trim();
                final vacancy = vacancyCtrl.text.trim();
                if (name.isEmpty || vacancy.isEmpty) return;
                this.context.read<HrBloc>().add(
                  CreateCandidateRequested(
                    fullName: name,
                    vacancy: vacancy,
                    phone: phoneCtrl.text.trim().isEmpty
                        ? null
                        : phoneCtrl.text.trim(),
                  ),
                );
                Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: colors.brand,
                foregroundColor: colors.surface,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                locale.translate('common_create'),
                style: textStyles.bodySans.copyWith(
                  color: colors.surface,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          );
        },
      );
    } finally {
      nameCtrl.dispose();
      vacancyCtrl.dispose();
      phoneCtrl.dispose();
    }
  }

  Widget _buildNineBoxTab(BuildContext context, HrLoaded state) {
    final colors = context.colors;
    final textStyles = context.textStyles;
    final locale = context.watch<LanguageCubit>();

    return _sectionLoader(
      state,
      state.evaluationsLoaded,
      RefreshIndicator(
        onRefresh: () async {
          final done = Completer<void>();
          context.read<HrBloc>().add(
            LoadHrSection(
              HrSection.nineBox,
              forceRefresh: true,
              completion: done,
            ),
          );
          await done.future;
        },
        child: state.evaluations.isEmpty
            ? _buildEmptyState(
                icon: TablerIcons.grid_dots,
                title: locale.translate('hr_evaluations_empty'),
                colors: colors,
                textStyles: textStyles,
              )
            : ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 88),
                itemCount: state.evaluations.length,
                separatorBuilder: (context, index) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final e = state.evaluations[index];
                  return Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: colors.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: colors.border),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          e.employeeName ?? '#${e.employeeId}',
                          style: textStyles.bodySans.copyWith(
                            fontWeight: FontWeight.w600,
                            fontSize: 14.5,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${locale.translate('hr_eval_performance')}: ${e.performance} · ${locale.translate('hr_eval_potential')}: ${e.potential}',
                          style: textStyles.captionSans.copyWith(
                            color: colors.textSecondary,
                            fontSize: 13,
                          ),
                        ),
                        if (e.note != null && e.note!.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            e.note!,
                            style: textStyles.captionSans.copyWith(
                              color: colors.textTooltip,
                            ),
                          ),
                        ],
                      ],
                    ),
                  );
                },
              ),
      ),
    );
  }

  Future<void> _showEvaluationSheet(
    BuildContext context,
    HrLoaded state,
  ) async {
    final colors = context.colors;
    final textStyles = context.textStyles;
    final locale = context.read<LanguageCubit>();
    String employeeId = state.employees.first.id;
    int performance = 2;
    int potential = 2;
    final noteCtrl = TextEditingController();

    try {
      await LedgerBottomSheet.show(
        context: context,
        title: locale.translate('hr_evaluation_add'),
        builder: (context, setSheetState) {
          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ExpansibleWidget<String>.selection(
                cardPadding: EdgeInsets.zero,
                tilePadding: const EdgeInsets.symmetric(horizontal: 8),
                title: Text(
                  state.employees
                      .firstWhere(
                        (e) => e.id == employeeId,
                        orElse: () => state.employees.first,
                      )
                      .fullName,
                  style: textStyles.bodySans.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                ),
                items: state.employees.map((e) => e.id).toList(),
                selectedValue: employeeId,
                itemLabelBuilder: (id) => state.employees
                    .firstWhere(
                      (e) => e.id == id,
                      orElse: () => state.employees.first,
                    )
                    .fullName,
                onSelected: (v) => setSheetState(() => employeeId = v),
              ),
              const SizedBox(height: 12),
              Text(
                '${locale.translate('hr_eval_performance')}: $performance',
                style: textStyles.captionSans,
              ),
              Slider(
                value: performance.toDouble(),
                min: 1,
                max: 3,
                divisions: 2,
                activeColor: colors.brand,
                onChanged: (v) => setSheetState(() => performance = v.round()),
              ),
              Text(
                '${locale.translate('hr_eval_potential')}: $potential',
                style: textStyles.captionSans,
              ),
              Slider(
                value: potential.toDouble(),
                min: 1,
                max: 3,
                divisions: 2,
                activeColor: colors.brand,
                onChanged: (v) => setSheetState(() => potential = v.round()),
              ),
              TextField(
                controller: noteCtrl,
                style: textStyles.bodySans,
                decoration: InputDecoration(
                  labelText: locale.translate('hr_eval_note'),
                ),
              ),
            ],
          );
        },
        footerBuilder: (context, setSheetState) {
          return SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: () {
                this.context.read<HrBloc>().add(
                  CreateEvaluationRequested(
                    employeeId: employeeId,
                    period: state.period,
                    performance: performance,
                    potential: potential,
                    note: noteCtrl.text.trim().isEmpty
                        ? null
                        : noteCtrl.text.trim(),
                  ),
                );
                Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: colors.brand,
                foregroundColor: colors.surface,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                locale.translate('common_create'),
                style: textStyles.bodySans.copyWith(
                  color: colors.surface,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          );
        },
      );
    } finally {
      noteCtrl.dispose();
    }
  }

  Widget _buildContractsTab(BuildContext context, HrLoaded state) {
    final colors = context.colors;
    final textStyles = context.textStyles;
    final locale = context.watch<LanguageCubit>();
    final canWrite = _canManageHr(context);

    return _sectionLoader(
      state,
      state.contractsLoaded,
      RefreshIndicator(
        onRefresh: () async {
          final done = Completer<void>();
          context.read<HrBloc>().add(
            LoadHrSection(
              HrSection.contracts,
              forceRefresh: true,
              completion: done,
            ),
          );
          await done.future;
        },
        child: state.contracts.isEmpty
            ? _buildEmptyState(
                icon: TablerIcons.file_certificate,
                title: locale.translate('hr_contracts_empty'),
                colors: colors,
                textStyles: textStyles,
              )
            : ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 88),
                itemCount: state.contracts.length,
                separatorBuilder: (context, index) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final c = state.contracts[index];
                  return Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: colors.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: colors.border),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                c.employeeName ?? '#${c.employeeId}',
                                style: textStyles.bodySans.copyWith(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14.5,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '№ ${c.number}',
                                style: textStyles.captionSans.copyWith(
                                  color: colors.textSecondary,
                                  fontSize: 13,
                                ),
                              ),
                              Text(
                                formatLocalizedDateTime(
                                  context,
                                  c.startDate,
                                  style: LocalizedDateTimeStyle.date,
                                ),
                                style: textStyles.captionSans.copyWith(
                                  color: colors.textTooltip,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: c.isExpiring
                                ? colors.accentAmber.withValues(alpha: 0.12)
                                : colors.surfaceNested,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            c.isExpiring
                                ? locale.translate('hr_contract_expiring')
                                : locale.translate(
                                    'hr_contract_status_${c.status}',
                                  ),
                            style: textStyles.captionSans.copyWith(
                              color: c.isExpiring
                                  ? colors.accentAmber
                                  : colors.textSecondary,
                              fontWeight: FontWeight.w600,
                              fontSize: 11.5,
                            ),
                          ),
                        ),
                        if (canWrite)
                          IconButton(
                            onPressed: () => context.read<HrBloc>().add(
                              DeleteContractRequested(c.id),
                            ),
                            icon: Icon(
                              TablerIcons.trash,
                              size: 18,
                              color: colors.accentRed,
                            ),
                          ),
                      ],
                    ),
                  );
                },
              ),
      ),
    );
  }

  Future<void> _showContractSheet(BuildContext context, HrLoaded state) async {
    final colors = context.colors;
    final textStyles = context.textStyles;
    final locale = context.read<LanguageCubit>();
    String employeeId = state.employees.first.id;
    final numberCtrl = TextEditingController();
    DateTime startDate = DateTime.now();

    try {
      await LedgerBottomSheet.show(
        context: context,
        title: locale.translate('hr_contract_add'),
        builder: (context, setSheetState) {
          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ExpansibleWidget<String>.selection(
                cardPadding: EdgeInsets.zero,
                tilePadding: const EdgeInsets.symmetric(horizontal: 8),
                title: Text(
                  state.employees
                      .firstWhere(
                        (e) => e.id == employeeId,
                        orElse: () => state.employees.first,
                      )
                      .fullName,
                  style: textStyles.bodySans.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                ),
                items: state.employees.map((e) => e.id).toList(),
                selectedValue: employeeId,
                itemLabelBuilder: (id) => state.employees
                    .firstWhere(
                      (e) => e.id == id,
                      orElse: () => state.employees.first,
                    )
                    .fullName,
                onSelected: (v) => setSheetState(() => employeeId = v),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: numberCtrl,
                style: textStyles.bodySans,
                decoration: InputDecoration(
                  labelText: locale.translate('hr_contract_number'),
                ),
              ),
              const SizedBox(height: 12),
              InkWell(
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: startDate,
                    firstDate: DateTime(2020),
                    lastDate: DateTime.now().add(const Duration(days: 365)),
                  );
                  if (picked != null) {
                    setSheetState(() => startDate = picked);
                  }
                },
                child: InputDecorator(
                  decoration: InputDecoration(
                    labelText: locale.translate('hr_contract_start'),
                    suffixIcon: const Icon(TablerIcons.calendar, size: 18),
                  ),
                  child: Text(
                    formatLocalizedDateTime(
                      context,
                      startDate,
                      style: LocalizedDateTimeStyle.date,
                    ),
                    style: textStyles.bodySans,
                  ),
                ),
              ),
            ],
          );
        },
        footerBuilder: (context, setSheetState) {
          return SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: () {
                final number = numberCtrl.text.trim();
                if (number.isEmpty) return;
                this.context.read<HrBloc>().add(
                  CreateContractRequested(
                    employeeId: employeeId,
                    number: number,
                    startDate: startDate,
                  ),
                );
                Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: colors.brand,
                foregroundColor: colors.surface,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                locale.translate('common_create'),
                style: textStyles.bodySans.copyWith(
                  color: colors.surface,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          );
        },
      );
    } finally {
      numberCtrl.dispose();
    }
  }

  Widget _buildMovementTab(BuildContext context, HrLoaded state) {
    final colors = context.colors;
    final textStyles = context.textStyles;
    final locale = context.watch<LanguageCubit>();
    final report = state.movement;

    final hiredCount = report?.hired.length ?? 0;
    final firedCount = report?.fired.length ?? 0;
    final totalEmp = state.employees.length;
    final turnoverRate = totalEmp > 0
        ? (firedCount / totalEmp * 100).toStringAsFixed(1)
        : '0.0';

    return _sectionLoader(
      state,
      state.movementLoaded,
      RefreshIndicator(
        onRefresh: () async {
          final done = Completer<void>();
          context.read<HrBloc>().add(
            LoadHrSection(
              HrSection.movement,
              forceRefresh: true,
              completion: done,
            ),
          );
          await done.future;
        },
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Movement Summary KPI Cards
            Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: colors.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: colors.border),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              TablerIcons.user_plus,
                              size: 15,
                              color: colors.accentGreen,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              locale.translate('hr_movement_hired_count'),
                              style: textStyles.captionSans.copyWith(
                                color: colors.textSecondary,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '+$hiredCount',
                          style: textStyles.bodyMono.copyWith(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: colors.accentGreen,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: colors.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: colors.border),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              TablerIcons.user_minus,
                              size: 15,
                              color: colors.accentRed,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              locale.translate('hr_movement_fired_count'),
                              style: textStyles.captionSans.copyWith(
                                color: colors.textSecondary,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '-$firedCount',
                          style: textStyles.bodyMono.copyWith(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: colors.accentRed,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: colors.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: colors.border),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              TablerIcons.arrows_exchange,
                              size: 15,
                              color: colors.brand,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              locale.translate('hr_turnover_rate'),
                              style: textStyles.captionSans.copyWith(
                                color: colors.textSecondary,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '$turnoverRate%',
                          style: textStyles.bodyMono.copyWith(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: colors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Export PDF button
            OutlinedButton.icon(
              onPressed: () => _exportMovementPdf(context),
              icon: const Icon(TablerIcons.file_download, size: 16),
              label: Text(locale.translate('hr_export_pdf_button')),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(40),
                foregroundColor: colors.brand,
                side: BorderSide(color: colors.brand.withValues(alpha: 0.4)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
            const SizedBox(height: 16),

            Text(
              locale.translate('hr_movement_hired'),
              style: textStyles.bodySans.copyWith(
                fontWeight: FontWeight.w600,
                fontSize: 15,
              ),
            ),
            const SizedBox(height: 8),
            if (report == null || report.hired.isEmpty)
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: colors.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: colors.border),
                ),
                child: Text(
                  locale.translate('hr_movement_empty'),
                  style: textStyles.captionSans.copyWith(
                    color: colors.textSecondary,
                    fontSize: 13,
                  ),
                ),
              )
            else
              ...report.hired.map(
                (r) => Padding(
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
                        Icon(
                          TablerIcons.user_plus,
                          color: colors.accentGreen,
                          size: 18,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                r.fullName,
                                style: textStyles.bodySans.copyWith(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14.5,
                                ),
                              ),
                              if (r.position != null)
                                Text(
                                  r.position!,
                                  style: textStyles.captionSans.copyWith(
                                    color: colors.textSecondary,
                                    fontSize: 13,
                                  ),
                                ),
                            ],
                          ),
                        ),
                        if (r.date != null)
                          Text(
                            formatLocalizedDateTime(
                              context,
                              r.date!,
                              style: LocalizedDateTimeStyle.date,
                            ),
                            style: textStyles.captionSans.copyWith(
                              color: colors.textSecondary,
                              fontSize: 12,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            const SizedBox(height: 16),
            Text(
              locale.translate('hr_movement_fired'),
              style: textStyles.bodySans.copyWith(
                fontWeight: FontWeight.w600,
                fontSize: 15,
              ),
            ),
            const SizedBox(height: 8),
            if (report == null || report.fired.isEmpty)
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: colors.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: colors.border),
                ),
                child: Text(
                  locale.translate('hr_movement_empty'),
                  style: textStyles.captionSans.copyWith(
                    color: colors.textSecondary,
                    fontSize: 13,
                  ),
                ),
              )
            else
              ...report.fired.map(
                (r) => Padding(
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
                        Icon(
                          TablerIcons.user_minus,
                          color: colors.accentRed,
                          size: 18,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                r.fullName,
                                style: textStyles.bodySans.copyWith(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14.5,
                                ),
                              ),
                              if (r.position != null)
                                Text(
                                  r.position!,
                                  style: textStyles.captionSans.copyWith(
                                    color: colors.textSecondary,
                                    fontSize: 13,
                                  ),
                                ),
                            ],
                          ),
                        ),
                        if (r.date != null)
                          Text(
                            formatLocalizedDateTime(
                              context,
                              r.date!,
                              style: LocalizedDateTimeStyle.date,
                            ),
                            style: textStyles.captionSans.copyWith(
                              color: colors.textSecondary,
                              fontSize: 12,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildStaffTab(
    BuildContext context,
    HrLoaded state, {
    String? period,
  }) {
    final canManage = _canManageHr(context);
    return _StaffTabWidget(
      state: state,
      period: period,
      canManage: canManage,
      onShowDocuments: _showEmployeeDocumentsBottomSheet,
    );
  }

  Widget _buildKpiTab(BuildContext context, HrLoaded state, {String? period}) {
    final canManage = _canManageHr(context);
    return _KpiTabWidget(
      state: state,
      period: period,
      canManage: canManage,
      onEditKpi: _showEditKpiBottomSheet,
      onAddKpi: (ctx) => _showAddKpiBottomSheet(ctx, state),
    );
  }

  Widget _buildSalaryTab(
    BuildContext context,
    HrLoaded state, {
    String? period,
  }) {
    final colors = context.colors;
    final textStyles = context.textStyles;
    final localeCubit = context.watch<LanguageCubit>();
    final oCcy = localizedDecimalFormat(context);

    if (state.salaryRecords.isEmpty) {
      return RefreshIndicator(
        onRefresh: () async {
          final completion = Completer<void>();
          context.read<HrBloc>().add(
            LoadHrData(
              period ?? state.period,
              forceRefresh: true,
              completion: completion,
            ),
          );
          await completion.future;
        },
        child: _buildEmptyState(
          icon: TablerIcons.cash,
          title: localeCubit.translate('hr_salary_empty'),
          colors: colors,
          textStyles: textStyles,
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () async {
        final completion = Completer<void>();
        context.read<HrBloc>().add(
          LoadHrData(
            period ?? state.period,
            forceRefresh: true,
            completion: completion,
          ),
        );
        await completion.future;
      },
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: state.salaryRecords.length,
        separatorBuilder: (context, index) => const SizedBox(height: 10),
        itemBuilder: (context, index) {
          final record = state.salaryRecords[index];
          final canManage = _canManageHr(context);
          final recalculateLabel = localeCubit.translate('hr_recalculate');

          return InkWell(
            onTap: canManage
                ? () => _showRecalcSalaryBottomSheet(context, record)
                : null,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: colors.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: colors.border),
              ),
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
                            fontWeight: FontWeight.w600,
                            fontSize: 14.5,
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
                          fontWeight: FontWeight.w700,
                          fontSize: 14.5,
                          color: colors.brand,
                        ),
                      ),
                      IconButton(
                        onPressed: () async {
                          try {
                            final bytes = await context
                                .read<HrRepository>()
                                .downloadSalaryCertificatePdf(
                                  record.employeeId,
                                );
                            if (bytes.isNotEmpty) {
                              await _sharePdfBytes(
                                bytes,
                                'salary_cert_${record.employeeId}.pdf',
                              );
                            }
                          } catch (_) {}
                        },
                        icon: const Icon(TablerIcons.file_text, size: 18),
                        tooltip: localeCubit.translate(
                          'hr_download_certificate',
                        ),
                      ),
                      if (canManage)
                        IconButton(
                          onPressed: () =>
                              _showRecalcSalaryBottomSheet(context, record),
                          icon: Icon(
                            TablerIcons.refresh,
                            size: 18,
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
                        style: textStyles.captionSans.copyWith(
                          color: colors.textSecondary,
                          fontSize: 12.5,
                        ),
                      ),
                      Text(
                        localeCubit.translate(
                          'hr_salary_bonus',
                          params: {'amount': oCcy.format(record.bonusAmount)},
                        ),
                        style: textStyles.captionSans.copyWith(
                          color: colors.accentGreen,
                          fontWeight: FontWeight.w600,
                          fontSize: 12.5,
                        ),
                      ),
                      Text(
                        localeCubit.translate(
                          'hr_salary_deductions',
                          params: {'amount': oCcy.format(record.deductions)},
                        ),
                        style: textStyles.captionSans.copyWith(
                          color: colors.accentRed,
                          fontSize: 12.5,
                        ),
                      ),
                      if (record.aidDeduction > 0)
                        Text(
                          localeCubit.translate(
                            'hr_salary_aid_deduction',
                            params: {
                              'amount': oCcy.format(record.aidDeduction),
                            },
                          ),
                          style: textStyles.captionSans.copyWith(
                            color: colors.accentAmber,
                            fontWeight: FontWeight.w600,
                            fontSize: 12.5,
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
                      style: textStyles.captionSans.copyWith(
                        color: colors.textTooltip,
                        fontStyle: FontStyle.italic,
                        fontSize: 12,
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

  Future<void> _showAddKpiBottomSheet(
    BuildContext context,
    HrLoaded state,
  ) async {
    if (state.employees.isEmpty) return;
    final textStyles = context.textStyles;
    final locale = context.read<LanguageCubit>();
    final hrBloc = context.read<HrBloc>();
    String selectedEmpId = state.employees.first.id;
    final metricCtrl = TextEditingController();
    final planCtrl = TextEditingController();
    final factCtrl = TextEditingController(text: '0');

    try {
      await LedgerBottomSheet.show(
        context: context,
        title: locale.translate('hr_kpi_add_title'),
        builder: (context, setSheetState) {
          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ExpansibleWidget<String>.selection(
                cardPadding: EdgeInsets.zero,
                tilePadding: const EdgeInsets.symmetric(horizontal: 8),
                title: Text(
                  state.employees
                      .firstWhere(
                        (e) => e.id == selectedEmpId,
                        orElse: () => state.employees.first,
                      )
                      .fullName,
                  style: textStyles.bodySans.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                ),
                items: state.employees.map((e) => e.id).toList(),
                selectedValue: selectedEmpId,
                itemLabelBuilder: (id) => state.employees
                    .firstWhere(
                      (e) => e.id == id,
                      orElse: () => state.employees.first,
                    )
                    .fullName,
                onSelected: (v) => setSheetState(() => selectedEmpId = v),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: metricCtrl,
                style: textStyles.bodySans,
                decoration: InputDecoration(
                  labelText: locale.translate('hr_kpi_metric_name'),
                  hintText: locale.translate('hr_kpi_metric_hint'),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: planCtrl,
                style: textStyles.bodySans,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: InputDecoration(
                  labelText: locale.translate('hr_kpi_plan_value'),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: factCtrl,
                style: textStyles.bodySans,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: InputDecoration(
                  labelText: locale.translate('hr_kpi_fact_value'),
                ),
              ),
            ],
          );
        },
        footerBuilder: (context, setSheetState) {
          final colors = context.colors;
          return SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: () {
                final metric = metricCtrl.text.trim();
                final plan =
                    parseLocalizedNumber(context, planCtrl.text) ?? 0.0;
                final fact =
                    parseLocalizedNumber(context, factCtrl.text) ?? 0.0;
                if (metric.isEmpty || plan <= 0) return;

                hrBloc.add(
                  CreateKpiRequested(
                    employeeId: selectedEmpId,
                    period: state.period,
                    metric: metric,
                    planValue: plan,
                    factValue: fact,
                  ),
                );
                Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: colors.brand,
                foregroundColor: colors.surface,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                locale.translate('common_save'),
                style: textStyles.bodySans.copyWith(
                  color: colors.surface,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          );
        },
      );
    } finally {
      metricCtrl.dispose();
      planCtrl.dispose();
      factCtrl.dispose();
    }
  }

  Future<void> _showEditKpiBottomSheet(
    BuildContext context,
    KpiRecord kpi,
  ) async {
    final textStyles = context.textStyles;
    final locale = context.read<LanguageCubit>();
    final hrBloc = context.read<HrBloc>();
    final metricCtrl = TextEditingController(text: kpi.metric);
    final planCtrl = TextEditingController(
      text: formatLocalizedNumber(context, kpi.planValue, useGrouping: false),
    );
    final factCtrl = TextEditingController(
      text: formatLocalizedNumber(context, kpi.factValue, useGrouping: false),
    );

    try {
      await LedgerBottomSheet.show(
        context: context,
        title: locale.translate('hr_kpi_edit_title'),
        builder: (context, setSheetState) {
          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                kpi.employeeName ?? '',
                style: textStyles.bodySans.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: metricCtrl,
                style: textStyles.bodySans,
                decoration: InputDecoration(
                  labelText: locale.translate('hr_kpi_metric_name'),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: planCtrl,
                style: textStyles.bodySans,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: InputDecoration(
                  labelText: locale.translate('hr_kpi_plan_value'),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: factCtrl,
                style: textStyles.bodySans,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: InputDecoration(
                  labelText: locale.translate('hr_kpi_fact_value'),
                ),
              ),
            ],
          );
        },
        footerBuilder: (context, setSheetState) {
          final colors = context.colors;
          return SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: () {
                final metric = metricCtrl.text.trim();
                final plan = parseLocalizedNumber(context, planCtrl.text);
                final fact = parseLocalizedNumber(context, factCtrl.text);

                hrBloc.add(
                  UpdateKpiRequested(
                    kpiId: kpi.id,
                    metric: metric.isNotEmpty ? metric : null,
                    planValue: plan,
                    factValue: fact,
                  ),
                );
                Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: colors.brand,
                foregroundColor: colors.surface,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                locale.translate('common_save'),
                style: textStyles.bodySans.copyWith(
                  color: colors.surface,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          );
        },
      );
    } finally {
      metricCtrl.dispose();
      planCtrl.dispose();
      factCtrl.dispose();
    }
  }

  Future<void> _showEmployeeDocumentsBottomSheet(
    BuildContext context,
    Employee emp,
  ) async {
    final textStyles = context.textStyles;
    final colors = context.colors;
    final locale = context.read<LanguageCubit>();
    final repository = context.read<HrRepository>();

    await LedgerBottomSheet.show(
      context: context,
      title: locale.translate(
        'hr_employee_docs_title',
        params: {'name': emp.fullName},
      ),
      builder: (context, setSheetState) {
        return FutureBuilder<List<EmployeeDocument>>(
          future: repository.getEmployeeDocuments(emp.id),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Padding(
                padding: EdgeInsets.all(24.0),
                child: Center(child: CircularProgressIndicator.adaptive()),
              );
            }
            final docs = snapshot.data ?? [];
            if (docs.isEmpty) {
              return Padding(
                padding: const EdgeInsets.all(24.0),
                child: Center(
                  child: Column(
                    children: [
                      Icon(
                        TablerIcons.folder_off,
                        size: 36,
                        color: colors.textSecondary,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        locale.translate('hr_no_documents'),
                        style: textStyles.captionSans.copyWith(
                          color: colors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }

            return Column(
              mainAxisSize: MainAxisSize.min,
              children: docs.map((doc) {
                return ListTile(
                  dense: true,
                  leading: const Icon(TablerIcons.file_text, size: 20),
                  title: Text(
                    doc.name,
                    style: textStyles.bodySans.copyWith(fontSize: 14),
                  ),
                  subtitle: Text(
                    formatLocalizedDateTime(
                      context,
                      doc.createdAt,
                      style: LocalizedDateTimeStyle.date,
                    ),
                    style: textStyles.captionSans.copyWith(fontSize: 12),
                  ),
                );
              }).toList(),
            );
          },
        );
      },
    );
  }
}

class _StaffTabWidget extends StatefulWidget {
  final HrLoaded state;
  final String? period;
  final bool canManage;
  final void Function(BuildContext, Employee) onShowDocuments;

  const _StaffTabWidget({
    required this.state,
    this.period,
    required this.canManage,
    required this.onShowDocuments,
  });

  @override
  State<_StaffTabWidget> createState() => _StaffTabWidgetState();
}

class _StaffTabWidgetState extends State<_StaffTabWidget> {
  int _filterIndex = 0;
  String _searchQuery = '';
  final TextEditingController _searchCtrl = TextEditingController();

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final textStyles = context.textStyles;
    final locale = context.watch<LanguageCubit>();
    final oCcy = localizedDecimalFormat(context);

    final filtered = widget.state.employees.where((e) {
      if (_filterIndex == 0 && (e.isArchived || e.status == 'fired')) {
        return false;
      }
      if (_filterIndex == 1 && e.status != 'vacation') {
        return false;
      }
      if (_filterIndex == 2 && !e.isArchived) {
        return false;
      }
      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        final nameMatches = e.fullName.toLowerCase().contains(q);
        final posMatches = e.position?.toLowerCase().contains(q) ?? false;
        final phoneMatches = e.phone?.toLowerCase().contains(q) ?? false;
        return nameMatches || posMatches || phoneMatches;
      }
      return true;
    }).toList();

    return Column(
      children: [
        Container(
          color: colors.surface,
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: Column(
            children: [
              TextField(
                controller: _searchCtrl,
                style: textStyles.bodySans.copyWith(fontSize: 14),
                decoration: InputDecoration(
                  hintText: locale.translate('hr_search_employee_hint'),
                  prefixIcon: Icon(
                    TablerIcons.search,
                    size: 18,
                    color: colors.textSecondary,
                  ),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(TablerIcons.x, size: 16),
                          onPressed: () {
                            _searchCtrl.clear();
                            setState(() => _searchQuery = '');
                          },
                        )
                      : null,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  filled: true,
                  fillColor: colors.surfaceNested,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: colors.border),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: colors.border),
                  ),
                ),
                onChanged: (v) => setState(() => _searchQuery = v.trim()),
              ),
              const SizedBox(height: 10),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _buildFilterChip(
                      0,
                      locale.translate('hr_filter_all'),
                      colors,
                      textStyles,
                    ),
                    const SizedBox(width: 8),
                    _buildFilterChip(
                      1,
                      locale.translate('hr_filter_vacation'),
                      colors,
                      textStyles,
                    ),
                    const SizedBox(width: 8),
                    _buildFilterChip(
                      2,
                      locale.translate('hr_filter_archive'),
                      colors,
                      textStyles,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        Container(height: 1, color: colors.border),
        Expanded(
          child: RefreshIndicator(
            onRefresh: () async {
              final completion = Completer<void>();
              context.read<HrBloc>().add(
                LoadHrData(
                  widget.period ?? widget.state.period,
                  forceRefresh: true,
                  completion: completion,
                ),
              );
              await completion.future;
            },
            child: filtered.isEmpty
                ? ListView(
                    children: [
                      const SizedBox(height: 80),
                      Center(
                        child: Text(
                          locale.translate('hr_staff_empty'),
                          style: textStyles.bodySans.copyWith(
                            color: colors.textSecondary,
                          ),
                        ),
                      ),
                    ],
                  )
                : ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: filtered.length,
                    separatorBuilder: (context, index) =>
                        const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final emp = filtered[index];
                      return _buildEmployeeCard(
                        context,
                        emp,
                        colors,
                        textStyles,
                        locale,
                        oCcy,
                      );
                    },
                  ),
          ),
        ),
      ],
    );
  }

  Widget _buildFilterChip(
    int index,
    String label,
    LedgerColors colors,
    LedgerTextStyles textStyles,
  ) {
    final isSelected = _filterIndex == index;
    return GestureDetector(
      onTap: () => setState(() => _filterIndex = index),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? colors.brand : colors.surfaceNested,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: isSelected ? colors.brand : colors.border),
        ),
        child: Text(
          label,
          style: textStyles.captionSans.copyWith(
            color: isSelected ? colors.surface : colors.textPrimary,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
            fontSize: 13,
          ),
        ),
      ),
    );
  }

  Widget _buildEmployeeCard(
    BuildContext context,
    Employee emp,
    LedgerColors colors,
    LedgerTextStyles textStyles,
    LanguageCubit locale,
    NumberFormat oCcy,
  ) {
    Color statusBg = colors.brand.withValues(alpha: 0.08);
    Color statusText = colors.brand;
    String statusLabel = locale.translate('hr_status_active');

    if (emp.status == 'vacation') {
      statusBg = colors.accentAmber.withValues(alpha: 0.1);
      statusText = colors.accentAmber;
      statusLabel = locale.translate('hr_status_vacation');
    } else if (emp.status == 'inactive') {
      statusBg = colors.surfaceNested;
      statusText = colors.textSecondary;
      statusLabel = locale.translate('hr_status_inactive');
    } else if (emp.status == 'fired') {
      statusBg = colors.accentRed.withValues(alpha: 0.1);
      statusText = colors.accentRed;
      statusLabel = locale.translate('hr_status_fired');
    }

    final initial = emp.fullName.isNotEmpty
        ? emp.fullName[0].toUpperCase()
        : '?';

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
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
                    fontSize: 16,
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
                        fontSize: 15,
                        color: colors.textPrimary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      emp.position ?? locale.translate('hr_default_employee'),
                      style: textStyles.captionSans.copyWith(
                        color: colors.textSecondary,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
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
              if (widget.canManage)
                PopupMenuButton<String>(
                  icon: Icon(
                    TablerIcons.dots_vertical,
                    size: 18,
                    color: colors.textSecondary,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  onSelected: (val) {
                    final bloc = context.read<HrBloc>();
                    switch (val) {
                      case 'docs':
                        widget.onShowDocuments(context, emp);
                        break;
                      case 'block':
                        bloc.add(BlockEmployeeRequested(emp.id));
                        break;
                      case 'unblock':
                        bloc.add(UnblockEmployeeRequested(emp.id));
                        break;
                      case 'archive':
                        bloc.add(ArchiveEmployeeRequested(emp.id));
                        break;
                      case 'restore':
                        bloc.add(RestoreEmployeeRequested(emp.id));
                        break;
                    }
                  },
                  itemBuilder: (ctx) => [
                    PopupMenuItem(
                      value: 'docs',
                      child: Row(
                        children: [
                          const Icon(TablerIcons.files, size: 16),
                          const SizedBox(width: 8),
                          Text(locale.translate('hr_action_documents')),
                        ],
                      ),
                    ),
                    if (emp.status != 'inactive')
                      PopupMenuItem(
                        value: 'block',
                        child: Row(
                          children: [
                            Icon(
                              TablerIcons.user_off,
                              size: 16,
                              color: colors.accentAmber,
                            ),
                            const SizedBox(width: 8),
                            Text(locale.translate('hr_action_block')),
                          ],
                        ),
                      )
                    else
                      PopupMenuItem(
                        value: 'unblock',
                        child: Row(
                          children: [
                            Icon(
                              TablerIcons.user_check,
                              size: 16,
                              color: colors.accentGreen,
                            ),
                            const SizedBox(width: 8),
                            Text(locale.translate('hr_action_unblock')),
                          ],
                        ),
                      ),
                    if (!emp.isArchived)
                      PopupMenuItem(
                        value: 'archive',
                        child: Row(
                          children: [
                            const Icon(TablerIcons.archive, size: 16),
                            const SizedBox(width: 8),
                            Text(locale.translate('hr_action_archive')),
                          ],
                        ),
                      )
                    else
                      PopupMenuItem(
                        value: 'restore',
                        child: Row(
                          children: [
                            const Icon(TablerIcons.archive_off, size: 16),
                            const SizedBox(width: 8),
                            Text(locale.translate('hr_action_restore')),
                          ],
                        ),
                      ),
                  ],
                ),
            ],
          ),
          const SizedBox(height: 10),
          Container(height: 1, color: colors.border),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              if (emp.phone != null && emp.phone!.isNotEmpty)
                Row(
                  children: [
                    Icon(
                      TablerIcons.phone,
                      size: 13,
                      color: colors.textSecondary,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      emp.phone!,
                      style: textStyles.captionSans.copyWith(
                        color: colors.textSecondary,
                        fontSize: 12.5,
                      ),
                    ),
                  ],
                )
              else
                Text(
                  emp.departmentName ??
                      locale.translate('hr_default_main_office'),
                  style: textStyles.captionSans.copyWith(
                    color: colors.textSecondary,
                    fontSize: 12.5,
                  ),
                ),
              Text(
                '${oCcy.format(emp.baseSalary)} TJS',
                style: textStyles.bodyMono.copyWith(
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                  color: colors.textPrimary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _KpiTabWidget extends StatefulWidget {
  final HrLoaded state;
  final String? period;
  final bool canManage;
  final void Function(BuildContext, KpiRecord) onEditKpi;
  final void Function(BuildContext)? onAddKpi;

  const _KpiTabWidget({
    required this.state,
    this.period,
    required this.canManage,
    required this.onEditKpi,
    this.onAddKpi,
  });

  @override
  State<_KpiTabWidget> createState() => _KpiTabWidgetState();
}

class _KpiTabWidgetState extends State<_KpiTabWidget> {
  int _selectedTab = 0;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final textStyles = context.textStyles;
    final locale = context.watch<LanguageCubit>();
    final oCcy = localizedDecimalFormat(context);

    final alertsCount = widget.state.kpiAlerts.where((a) => a.triggered).length;

    return Column(
      children: [
        Container(
          color: colors.surface,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _selectedTab = 0),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      color: _selectedTab == 0
                          ? colors.brand
                          : colors.surfaceNested,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: _selectedTab == 0 ? colors.brand : colors.border,
                      ),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      '${locale.translate('hr_kpi_all_metrics')} (${widget.state.kpiRecords.length})',
                      style: textStyles.bodySans.copyWith(
                        color: _selectedTab == 0
                            ? colors.surface
                            : colors.textPrimary,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _selectedTab = 1),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      color: _selectedTab == 1
                          ? colors.brand
                          : colors.surfaceNested,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: _selectedTab == 1 ? colors.brand : colors.border,
                      ),
                    ),
                    alignment: Alignment.center,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          TablerIcons.sparkles,
                          size: 14,
                          color: _selectedTab == 1
                              ? colors.surface
                              : colors.accentAmber,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${locale.translate('hr_kpi_ai_alerts')} ($alertsCount)',
                          style: textStyles.bodySans.copyWith(
                            color: _selectedTab == 1
                                ? colors.surface
                                : colors.textPrimary,
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        Container(height: 1, color: colors.border),
        Expanded(
          child: RefreshIndicator(
            onRefresh: () async {
              final completion = Completer<void>();
              context.read<HrBloc>().add(
                LoadHrData(
                  widget.period ?? widget.state.period,
                  forceRefresh: true,
                  completion: completion,
                ),
              );
              await completion.future;
            },
            child: _selectedTab == 0
                ? _buildAllKpisList(context, colors, textStyles, locale, oCcy)
                : _buildAlertsList(context, colors, textStyles, locale, oCcy),
          ),
        ),
      ],
    );
  }

  Widget _buildAllKpisList(
    BuildContext context,
    LedgerColors colors,
    LedgerTextStyles textStyles,
    LanguageCubit locale,
    NumberFormat oCcy,
  ) {
    if (widget.state.kpiRecords.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          const SizedBox(height: 60),
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      color: colors.surfaceNested,
                      shape: BoxShape.circle,
                      border: Border.all(color: colors.border),
                    ),
                    alignment: Alignment.center,
                    child: Icon(
                      TablerIcons.target_arrow,
                      size: 28,
                      color: colors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    locale.translate('hr_kpi_no_records'),
                    style: textStyles.h2Sans.copyWith(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: colors.textPrimary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ],
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: widget.state.kpiRecords.length,
      separatorBuilder: (context, index) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final kpi = widget.state.kpiRecords[index];
        final completion =
            kpi.completion ??
            (kpi.planValue > 0 ? (kpi.factValue / kpi.planValue * 100) : 0.0);
        final ratio =
            (kpi.planValue > 0 ? (kpi.factValue / kpi.planValue) : 0.0).clamp(
              0.0,
              1.0,
            );

        Color badgeBg = colors.accentGreen.withValues(alpha: 0.1);
        Color badgeText = colors.accentGreen;
        if (completion < 80) {
          badgeBg = colors.accentRed.withValues(alpha: 0.1);
          badgeText = colors.accentRed;
        } else if (completion < 100) {
          badgeBg = colors.accentAmber.withValues(alpha: 0.1);
          badgeText = colors.accentAmber;
        }

        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: colors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          kpi.employeeName ?? 'Сотрудник',
                          style: textStyles.bodySans.copyWith(
                            fontWeight: FontWeight.w600,
                            fontSize: 14.5,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: colors.surfaceNested,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            kpi.metric,
                            style: textStyles.captionSans.copyWith(
                              color: colors.brand,
                              fontWeight: FontWeight.w600,
                              fontSize: 11.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: badgeBg,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      '${completion.toStringAsFixed(1)}%',
                      style: textStyles.captionSans.copyWith(
                        color: badgeText,
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  if (widget.canManage) ...[
                    IconButton(
                      icon: const Icon(TablerIcons.pencil, size: 17),
                      onPressed: () => widget.onEditKpi(context, kpi),
                      tooltip: locale.translate('common_edit'),
                    ),
                    IconButton(
                      icon: Icon(
                        TablerIcons.trash,
                        size: 17,
                        color: colors.accentRed,
                      ),
                      onPressed: () => context.read<HrBloc>().add(
                        DeleteKpiRequested(kpi.id),
                      ),
                      tooltip: locale.translate('common_delete'),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: ratio,
                  minHeight: 6,
                  backgroundColor: colors.surfaceNested,
                  valueColor: AlwaysStoppedAnimation<Color>(badgeText),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${locale.translate('hr_kpi_plan')}: ${oCcy.format(kpi.planValue)}',
                    style: textStyles.captionSans.copyWith(
                      color: colors.textSecondary,
                      fontSize: 12.5,
                    ),
                  ),
                  Text(
                    '${locale.translate('hr_kpi_fact')}: ${oCcy.format(kpi.factValue)}',
                    style: textStyles.bodyMono.copyWith(
                      fontWeight: FontWeight.w600,
                      color: colors.textPrimary,
                      fontSize: 12.5,
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildAlertsList(
    BuildContext context,
    LedgerColors colors,
    LedgerTextStyles textStyles,
    LanguageCubit locale,
    NumberFormat oCcy,
  ) {
    if (widget.state.kpiAlerts.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          const SizedBox(height: 60),
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      color: colors.surfaceNested,
                      shape: BoxShape.circle,
                      border: Border.all(color: colors.border),
                    ),
                    alignment: Alignment.center,
                    child: Icon(
                      TablerIcons.sparkles,
                      size: 28,
                      color: colors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    locale.translate('hr_kpi_empty'),
                    style: textStyles.h2Sans.copyWith(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: colors.textPrimary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ],
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: widget.state.kpiAlerts.length,
      separatorBuilder: (context, index) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final alert = widget.state.kpiAlerts[index];
        final percent = formatLocalizedNumber(
          context,
          alert.completion * 100,
          maximumFractionDigits: 0,
        );

        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: alert.triggered
                ? colors.accentAmber.withValues(alpha: 0.04)
                : colors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: alert.triggered ? colors.accentAmber : colors.border,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    alert.employeeName,
                    style: textStyles.bodySans.copyWith(
                      fontWeight: FontWeight.w600,
                      fontSize: 14.5,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: alert.triggered
                          ? colors.accentAmber.withValues(alpha: 0.1)
                          : colors.accentGreen.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      '$percent%',
                      style: textStyles.captionSans.copyWith(
                        color: alert.triggered
                            ? colors.accentAmber
                            : colors.accentGreen,
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                alert.metric,
                style: textStyles.captionSans.copyWith(fontSize: 13),
              ),
              const SizedBox(height: 4),
              Text(
                '${locale.translate('hr_kpi_plan')}: ${oCcy.format(alert.planValue)}  •  ${locale.translate('hr_kpi_fact')}: ${oCcy.format(alert.factValue)}',
                style: textStyles.captionSans.copyWith(
                  color: colors.textSecondary,
                  fontSize: 12.5,
                ),
              ),
              if (alert.comment != null && alert.comment!.isNotEmpty) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: colors.accentAmber.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        TablerIcons.sparkles,
                        size: 14,
                        color: colors.accentAmber,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          alert.comment!,
                          style: textStyles.captionSans.copyWith(
                            color: colors.accentAmber,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}
