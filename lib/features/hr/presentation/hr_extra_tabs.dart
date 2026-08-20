part of 'hr_screen.dart';

extension _HrExtraTabs on _HrViewState {
  Widget _sectionLoader(HrLoaded state, bool loaded, Widget child) {
    if (!loaded && state.sectionLoading) {
      return const Center(child: CircularProgressIndicator());
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
        child: LedgerCard(
          padding: const EdgeInsets.all(12),
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
                    fontWeight: FontWeight.w500,
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
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    if (node.position != null && node.position!.isNotEmpty)
                      Text(
                        node.position!,
                        style: textStyles.captionSans.copyWith(
                          color: colors.textSecondary,
                        ),
                      ),
                  ],
                ),
              ),
              LedgerPill(
                text: locale.translate('hr_status_${node.status}'),
                backgroundColor: node.status == 'active'
                    ? colors.accentGreen.withValues(alpha: 0.1)
                    : colors.surfaceNested,
                textColor: node.status == 'active'
                    ? colors.accentGreen
                    : colors.textSecondary,
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
                    return LedgerCard(
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  row.employeeName ?? '#${row.employeeId}',
                                  style: textStyles.bodySans.copyWith(
                                    fontWeight: FontWeight.w500,
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
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Text(
                            '${row.hours} h',
                            style: textStyles.bodyMono.copyWith(
                              fontWeight: FontWeight.w500,
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
                    return LedgerCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  c.fullName,
                                  style: textStyles.bodySans.copyWith(
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                              LedgerPill(
                                text: locale.translate(
                                  'hr_candidate_stage_${c.stage}',
                                ),
                                backgroundColor: colors.surfaceNested,
                                textColor: colors.textSecondary,
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
                    return LedgerCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            e.employeeName ?? '#${e.employeeId}',
                            style: textStyles.bodySans.copyWith(
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${locale.translate('hr_eval_performance')}: ${e.performance} · ${locale.translate('hr_eval_potential')}: ${e.potential}',
                            style: textStyles.captionSans.copyWith(
                              color: colors.textSecondary,
                            ),
                          ),
                          if (e.note != null && e.note!.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(e.note!, style: textStyles.captionSans),
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
                    return LedgerCard(
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  c.employeeName ?? '#${c.employeeId}',
                                  style: textStyles.bodySans.copyWith(
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '№ ${c.number}',
                                  style: textStyles.captionSans.copyWith(
                                    color: colors.textSecondary,
                                  ),
                                ),
                                Text(
                                  formatLocalizedDateTime(
                                    context,
                                    c.startDate,
                                    style: LocalizedDateTimeStyle.date,
                                  ),
                                  style: textStyles.smallSans.copyWith(
                                    color: colors.textTooltip,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          LedgerPill(
                            text: c.isExpiring
                                ? locale.translate('hr_contract_expiring')
                                : locale.translate(
                                    'hr_contract_status_${c.status}',
                                  ),
                            backgroundColor: c.isExpiring
                                ? colors.accentAmber.withValues(alpha: 0.12)
                                : colors.surfaceNested,
                            textColor: c.isExpiring
                                ? colors.accentAmber
                                : colors.textSecondary,
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
              style: textStyles.bodySans.copyWith(fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 8),
            if (report == null || report.hired.isEmpty)
              LedgerCard(
                child: Text(
                  locale.translate('hr_movement_empty'),
                  style: textStyles.captionSans.copyWith(
                    color: colors.textSecondary,
                  ),
                ),
              )
            else
              ...report.hired.map(
                (r) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: LedgerCard(
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
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              if (r.position != null)
                                Text(
                                  r.position!,
                                  style: textStyles.captionSans.copyWith(
                                    color: colors.textSecondary,
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
                            style: textStyles.smallMono,
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            const SizedBox(height: 16),
            Text(
              locale.translate('hr_movement_fired'),
              style: textStyles.bodySans.copyWith(fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 8),
            if (report == null || report.fired.isEmpty)
              LedgerCard(
                child: Text(
                  locale.translate('hr_movement_empty'),
                  style: textStyles.captionSans.copyWith(
                    color: colors.textSecondary,
                  ),
                ),
              )
            else
              ...report.fired.map(
                (r) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: LedgerCard(
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
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              if (r.position != null)
                                Text(
                                  r.position!,
                                  style: textStyles.captionSans.copyWith(
                                    color: colors.textSecondary,
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
                            style: textStyles.smallMono,
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
}
