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
            ? ListView(
                children: [
                  const SizedBox(height: 80),
                  Center(
                    child: Text(
                      locale.translate('hr_org_empty'),
                      style: textStyles.bodySans.copyWith(
                        color: colors.textSecondary,
                      ),
                    ),
                  ),
                ],
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
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 3,
                ),
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
      Scaffold(
        floatingActionButton: canWrite
            ? FloatingActionButton.extended(
                heroTag: null,
                onPressed: () => _showAttendanceSheet(context, state),
                backgroundColor: colors.brand,
                foregroundColor: colors.surface,
                elevation: 0,
                highlightElevation: 0,
                focusElevation: 0,
                hoverElevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: colors.brand),
                ),
                icon: const Icon(TablerIcons.plus),
                label: Text(
                  locale.translate('hr_attendance_add'),
                  style: textStyles.bodySans.copyWith(
                    color: colors.surface,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              )
            : null,
        body: RefreshIndicator(
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
              ? ListView(
                  children: [
                    const SizedBox(height: 80),
                    Center(
                      child: Text(
                        locale.translate('hr_attendance_empty'),
                        style: textStyles.bodySans.copyWith(
                          color: colors.textSecondary,
                        ),
                      ),
                    ),
                  ],
                )
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 88),
                  itemCount: state.attendance.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
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
      Scaffold(
        floatingActionButton: canWrite
            ? FloatingActionButton.extended(
                heroTag: null,
                onPressed: () => _showCandidateSheet(context),
                backgroundColor: colors.brand,
                foregroundColor: colors.surface,
                elevation: 0,
                highlightElevation: 0,
                focusElevation: 0,
                hoverElevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: colors.brand),
                ),
                icon: const Icon(TablerIcons.plus),
                label: Text(
                  locale.translate('hr_candidate_add'),
                  style: textStyles.bodySans.copyWith(
                    color: colors.surface,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              )
            : null,
        body: RefreshIndicator(
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
              ? ListView(
                  children: [
                    const SizedBox(height: 80),
                    Center(
                      child: Text(
                        locale.translate('hr_candidates_empty'),
                        style: textStyles.bodySans.copyWith(
                          color: colors.textSecondary,
                        ),
                      ),
                    ),
                  ],
                )
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 88),
                  itemCount: state.candidates.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
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
    final canWrite = _canManageHr(context);

    return _sectionLoader(
      state,
      state.evaluationsLoaded,
      Scaffold(
        floatingActionButton: canWrite && state.employees.isNotEmpty
            ? FloatingActionButton.extended(
                heroTag: null,
                onPressed: () => _showEvaluationSheet(context, state),
                backgroundColor: colors.brand,
                foregroundColor: colors.surface,
                elevation: 0,
                highlightElevation: 0,
                focusElevation: 0,
                hoverElevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: colors.brand),
                ),
                icon: const Icon(TablerIcons.plus),
                label: Text(
                  locale.translate('hr_evaluation_add'),
                  style: textStyles.bodySans.copyWith(
                    color: colors.surface,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              )
            : null,
        body: RefreshIndicator(
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
              ? ListView(
                  children: [
                    const SizedBox(height: 80),
                    Center(
                      child: Text(
                        locale.translate('hr_evaluations_empty'),
                        style: textStyles.bodySans.copyWith(
                          color: colors.textSecondary,
                        ),
                      ),
                    ),
                  ],
                )
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 88),
                  itemCount: state.evaluations.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
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
      Scaffold(
        floatingActionButton: canWrite && state.employees.isNotEmpty
            ? FloatingActionButton.extended(
                heroTag: null,
                onPressed: () => _showContractSheet(context, state),
                backgroundColor: colors.brand,
                foregroundColor: colors.surface,
                elevation: 0,
                highlightElevation: 0,
                focusElevation: 0,
                hoverElevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: colors.brand),
                ),
                icon: const Icon(TablerIcons.plus),
                label: Text(
                  locale.translate('hr_contract_add'),
                  style: textStyles.bodySans.copyWith(
                    color: colors.surface,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              )
            : null,
        body: RefreshIndicator(
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
              ? ListView(
                  children: [
                    const SizedBox(height: 80),
                    Center(
                      child: Text(
                        locale.translate('hr_contracts_empty'),
                        style: textStyles.bodySans.copyWith(
                          color: colors.textSecondary,
                        ),
                      ),
                    ),
                  ],
                )
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 88),
                  itemCount: state.contracts.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
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
    final colors = context.colors;
    final textStyles = context.textStyles;
    final localeCubit = context.watch<LanguageCubit>();
    final oCcy = localizedDecimalFormat(context);

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
        itemCount: state.employees.length,
        separatorBuilder: (context, index) => const SizedBox(height: 10),
        itemBuilder: (context, index) {
          final emp = state.employees[index];

          Color statusBg = colors.brand.withValues(alpha: 0.08);
          Color statusText = colors.brand;
          String statusLabel = localeCubit.translate('hr_status_active');

          if (emp.status == 'vacation') {
            statusBg = colors.accentAmber.withValues(alpha: 0.1);
            statusText = colors.accentAmber;
            statusLabel = localeCubit.translate('hr_status_vacation');
          } else if (emp.status == 'fired') {
            statusBg = colors.accentRed.withValues(alpha: 0.1);
            statusText = colors.accentRed;
            statusLabel = localeCubit.translate('hr_status_fired');
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
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
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
                      const SizedBox(height: 3),
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
                          fontSize: 13,
                        ),
                      ),
                      if (emp.phone != null) ...[
                        const SizedBox(height: 3),
                        Row(
                          children: [
                            Icon(
                              TablerIcons.phone,
                              size: 13,
                              color: colors.textTooltip,
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
                        ),
                      ],
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
                    const SizedBox(height: 6),
                    Text(
                      localeCubit.translate(
                        'hr_amount_tjs',
                        params: {'amount': oCcy.format(emp.baseSalary)},
                      ),
                      style: textStyles.bodySans.copyWith(
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
        },
      ),
    );
  }

  Widget _buildKpiTab(
    BuildContext context,
    HrLoaded state, {
    String? period,
  }) {
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
            style: textStyles.bodySans.copyWith(
              color: colors.textTooltip,
              fontSize: 14.5,
            ),
          ),
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
        itemCount: state.kpiAlerts.length,
        separatorBuilder: (context, index) => const SizedBox(height: 10),
        itemBuilder: (context, index) {
          final alert = state.kpiAlerts[index];
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
                      localeCubit.translateMessage(alert.employeeName),
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
                        localeCubit.translate(
                          'hr_percentage',
                          params: {'value': percent},
                        ),
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
                  localeCubit.translate(
                    'hr_kpi_metric_value',
                    params: {'metric': alert.metric},
                  ),
                  style: textStyles.captionSans.copyWith(fontSize: 13),
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
                      style: textStyles.captionSans.copyWith(
                        color: colors.textSecondary,
                        fontSize: 12.5,
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
                    style: textStyles.captionSans.copyWith(
                      color: colors.accentAmber,
                      fontStyle: FontStyle.italic,
                      fontSize: 12.5,
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
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Text(
            localeCubit.translate('hr_salary_empty'),
            style: textStyles.bodySans.copyWith(
              color: colors.textTooltip,
              fontSize: 14.5,
            ),
          ),
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
}
