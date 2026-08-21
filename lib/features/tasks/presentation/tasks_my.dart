part of 'tasks_screen.dart';

extension _TasksMyTab on _TasksViewState {
  int? get _currentUserId {
    final auth = context.read<AuthBloc>().state;
    return auth is AuthAuthenticated ? auth.id : null;
  }

  bool get _isDirector {
    final auth = context.read<AuthBloc>().state;
    return auth is AuthAuthenticated && auth.role == UserRole.director;
  }

  Widget _buildMyTasksTab(BuildContext context, TasksLoaded state) {
    final colors = context.colors;
    final textStyles = context.textStyles;
    final language = context.watch<LanguageCubit>();

    if (state.isMyTasksLoading && !state.myTasksLoaded) {
      return const TasksOverviewShimmer();
    }

    final personal = state.myTasks.where((t) => t.isPersonal).toList();
    // Assigned team queue — acceptance cycle.
    final assigned = state.assignedToMe;
    // Non-personal items from /tasks/my that are not in assigned list (authored by me).
    final assignedIds = assigned.map((t) => t.id).toSet();
    final mineOther = state.myTasks
        .where((t) => !t.isPersonal && !assignedIds.contains(t.id))
        .toList();

    return RefreshIndicator(
      onRefresh: () => _refreshTasks(context),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
        children: [
          Text(
            language.translate('tasks_my_personal_section'),
            style: textStyles.bodySans.copyWith(fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 8),
          if (personal.isEmpty)
            LedgerCard(
              child: Text(
                language.translate('tasks_my_personal_empty'),
                style: textStyles.captionSans.copyWith(
                  color: colors.textSecondary,
                ),
              ),
            )
          else
            ...personal.map((t) => _personalTaskCard(context, t)),
          const SizedBox(height: 20),
          Text(
            language.translate('tasks_my_assigned_section'),
            style: textStyles.bodySans.copyWith(fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 8),
          if (assigned.isEmpty && mineOther.isEmpty)
            LedgerCard(
              child: Text(
                language.translate('tasks_my_assigned_empty'),
                style: textStyles.captionSans.copyWith(
                  color: colors.textSecondary,
                ),
              ),
            )
          else ...[
            ...assigned.map((t) => _assignedTaskCard(context, t)),
            ...mineOther.map((t) => _assignedTaskCard(context, t)),
          ],
        ],
      ),
    );
  }

  Widget _personalTaskCard(BuildContext context, Task task) {
    final colors = context.colors;
    final textStyles = context.textStyles;
    final language = context.read<LanguageCubit>();
    final isDone = task.status == TaskStatus.done;
    final isOverdue = !isDone && task.dueDate.isBefore(DateTime.now());

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: LedgerCard(
        onTap: () => _showPersonalTaskSheet(context, editing: task),
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Checkbox icon
            Padding(
              padding: const EdgeInsets.only(top: 2, right: 10),
              child: Icon(
                isDone
                    ? TablerIcons.circle_check_filled
                    : TablerIcons.circle,
                size: 20,
                color: isDone ? colors.accentGreen : colors.textTooltip,
              ),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          task.title,
                          style: textStyles.bodySans.copyWith(
                            fontWeight: FontWeight.w600,
                            fontSize: 15,
                            decoration:
                                isDone ? TextDecoration.lineThrough : null,
                            color: isDone
                                ? colors.textSecondary
                                : colors.textPrimary,
                          ),
                        ),
                      ),
                      LedgerPill(
                        text: language.translate(task.status.localizationKey),
                        backgroundColor: isDone
                            ? colors.accentGreen.withValues(alpha: 0.12)
                            : colors.surfaceNested,
                        textColor: isDone
                            ? colors.accentGreen
                            : colors.textSecondary,
                      ),
                    ],
                  ),
                  if (task.description.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      task.description,
                      style: textStyles.captionSans.copyWith(
                        color: colors.textSecondary,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Icon(
                        TablerIcons.calendar,
                        size: 13,
                        color:
                            isOverdue ? colors.accentRed : colors.textTooltip,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        formatLocalizedDateTime(
                          context,
                          task.dueDate,
                          style: LocalizedDateTimeStyle.date,
                        ),
                        style: textStyles.captionSans.copyWith(
                          color:
                              isOverdue ? colors.accentRed : colors.textTooltip,
                          fontWeight: isOverdue
                              ? FontWeight.w600
                              : FontWeight.normal,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _assignedTaskCard(BuildContext context, Task task) {
    final colors = context.colors;
    final textStyles = context.textStyles;
    final language = context.read<LanguageCubit>();
    final userId = _currentUserId;
    final isAssignee = userId != null && task.assigneeId == userId.toString();
    final isReviewer =
        _isDirector ||
        (userId != null && task.createdBy != null && task.createdBy == userId);
    final isDone = task.status == TaskStatus.done;
    final isSubmitted = task.status == TaskStatus.review;
    final isOverdue = !isDone && task.dueDate.isBefore(DateTime.now());

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: LedgerCard(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 2, right: 10),
                  child: Icon(
                    isDone
                        ? TablerIcons.circle_check_filled
                        : (isSubmitted
                            ? TablerIcons.clock_hour_4
                            : TablerIcons.circle),
                    size: 20,
                    color: isDone
                        ? colors.accentGreen
                        : (isSubmitted
                            ? colors.accentAmber
                            : colors.textTooltip),
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              task.title,
                              style: textStyles.bodySans.copyWith(
                                fontWeight: FontWeight.w600,
                                fontSize: 15,
                                decoration:
                                    isDone ? TextDecoration.lineThrough : null,
                                color: isDone
                                    ? colors.textSecondary
                                    : colors.textPrimary,
                              ),
                            ),
                          ),
                          LedgerPill(
                            text: language.translate(
                              task.status.localizationKey,
                            ),
                            backgroundColor: isDone
                                ? colors.accentGreen.withValues(alpha: 0.12)
                                : (isSubmitted
                                    ? colors.accentAmber.withValues(alpha: 0.12)
                                    : colors.surfaceNested),
                            textColor: isDone
                                ? colors.accentGreen
                                : (isSubmitted
                                    ? colors.accentAmber
                                    : colors.textSecondary),
                          ),
                        ],
                      ),
                      if (task.description.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          task.description,
                          style: textStyles.captionSans.copyWith(
                            color: colors.textSecondary,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: colors.surfaceNested,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        TablerIcons.calendar,
                        size: 13,
                        color:
                            isOverdue ? colors.accentRed : colors.textTooltip,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        formatLocalizedDateTime(
                          context,
                          task.dueDate,
                          style: LocalizedDateTimeStyle.date,
                        ),
                        style: textStyles.captionSans.copyWith(
                          color:
                              isOverdue ? colors.accentRed : colors.textTooltip,
                          fontWeight: isOverdue
                              ? FontWeight.w600
                              : FontWeight.normal,
                        ),
                      ),
                    ],
                  ),
                ),
                if (task.assigneeName != null &&
                    task.assigneeName!.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: colors.surfaceNested,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          TablerIcons.user,
                          size: 13,
                          color: colors.textTooltip,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          task.assigneeName!,
                          style: textStyles.captionSans.copyWith(
                            color: colors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
                if (task.acknowledgedAt != null)
                  LedgerPill(
                    text: language.translate('tasks_review_acknowledged'),
                    backgroundColor: colors.accentGreen.withValues(alpha: 0.1),
                    textColor: colors.accentGreen,
                  )
                else if (!isDone)
                  LedgerPill(
                    text: language.translate('tasks_review_waiting_ack'),
                    backgroundColor: colors.surfaceNested,
                    textColor: colors.textSecondary,
                  ),
                if (task.acceptedAt != null)
                  LedgerPill(
                    text: language.translate('tasks_review_accepted'),
                    backgroundColor: colors.accentGreen.withValues(alpha: 0.1),
                    textColor: colors.accentGreen,
                  ),
              ],
            ),
            if (task.rejectReason != null &&
                task.rejectReason!.isNotEmpty &&
                !isDone) ...[
              const SizedBox(height: 6),
              Text(
                '${language.translate('tasks_review_rejected_reason')}: ${task.rejectReason}',
                style: textStyles.captionSans.copyWith(color: colors.accentRed),
              ),
            ],
            if (!task.isPersonal) ...[
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (isAssignee && task.acknowledgedAt == null && !isDone)
                    _actionChip(
                      context,
                      label: language.translate('tasks_review_acknowledge'),
                      icon: TablerIcons.check,
                      onTap: () => context.read<TasksBloc>().add(
                        AcknowledgeTaskRequested(task.id),
                      ),
                    ),
                  if (isAssignee && !isSubmitted && !isDone)
                    _actionChip(
                      context,
                      label: language.translate('tasks_review_submit'),
                      icon: TablerIcons.send,
                      filled: true,
                      onTap: () => context.read<TasksBloc>().add(
                        SubmitTaskRequested(task.id),
                      ),
                    ),
                  if (isReviewer && !isDone) ...[
                    _actionChip(
                      context,
                      label: language.translate('tasks_review_accept'),
                      icon: TablerIcons.checks,
                      filled: true,
                      onTap: () => context.read<TasksBloc>().add(
                        AcceptTaskRequested(task.id),
                      ),
                    ),
                    _actionChip(
                      context,
                      label: language.translate('tasks_review_reject'),
                      icon: TablerIcons.arrow_back_up,
                      onTap: () => _showRejectSheet(context, task),
                    ),
                  ],
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _actionChip(
    BuildContext context, {
    required String label,
    required IconData icon,
    required VoidCallback onTap,
    bool filled = false,
  }) {
    final colors = context.colors;
    final textStyles = context.textStyles;
    return Material(
      color: filled ? colors.brand : colors.surface,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: filled ? null : Border.all(color: colors.border),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 16,
                color: filled ? colors.surface : colors.textPrimary,
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: textStyles.smallSans.copyWith(
                  color: filled ? colors.surface : colors.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showRejectSheet(BuildContext context, Task task) async {
    final textStyles = context.textStyles;
    final language = context.read<LanguageCubit>();
    final reasonCtrl = TextEditingController();
    try {
      await LedgerBottomSheet.show(
        context: context,
        title: language.translate('tasks_review_reject_title'),
        builder: (context, setSheetState) {
          return TextField(
            controller: reasonCtrl,
            maxLines: 3,
            style: textStyles.bodySans,
            decoration: InputDecoration(
              labelText: language.translate('tasks_review_reject_reason_hint'),
            ),
          );
        },
        footerBuilder: (context, setSheetState) {
          return SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                context.read<TasksBloc>().add(
                  RejectTaskRequested(
                    taskId: task.id,
                    reason: reasonCtrl.text.trim().isEmpty
                        ? null
                        : reasonCtrl.text.trim(),
                  ),
                );
                Navigator.pop(context);
              },
              child: Text(language.translate('tasks_review_reject')),
            ),
          );
        },
      );
    } finally {
      reasonCtrl.dispose();
    }
  }

  Future<void> _showPersonalTaskSheet(
    BuildContext context, {
    Task? editing,
  }) async {
    final tasksBloc = context.read<TasksBloc>();
    final colors = context.colors;
    final textStyles = context.textStyles;
    final language = context.read<LanguageCubit>();

    final titleCtrl = TextEditingController(text: editing?.title ?? '');
    final descCtrl = TextEditingController(text: editing?.description ?? '');
    DateTime dueDate =
        editing?.dueDate ?? DateTime.now().add(const Duration(days: 1));
    TaskPriority priority = editing?.priority ?? TaskPriority.medium;
    TaskStatus status = editing?.status ?? TaskStatus.todo;

    try {
      await LedgerBottomSheet.show(
        context: context,
        title: language.translate(
          editing == null ? 'tasks_my_new' : 'tasks_my_edit',
        ),
        builder: (context, setSheetState) {
          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: titleCtrl,
                style: textStyles.bodySans,
                decoration: InputDecoration(
                  labelText: language.translate('tasks_field_title'),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: descCtrl,
                style: textStyles.bodySans,
                maxLines: 3,
                decoration: InputDecoration(
                  labelText: language.translate('tasks_field_description'),
                ),
              ),
              const SizedBox(height: 12),
              InkWell(
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: dueDate,
                    firstDate: DateTime(2020),
                    lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
                  );
                  if (picked != null) {
                    setSheetState(() => dueDate = picked);
                  }
                },
                child: InputDecorator(
                  decoration: InputDecoration(
                    labelText: language.translate('tasks_field_due_date'),
                    suffixIcon: const Icon(TablerIcons.calendar, size: 18),
                  ),
                  child: Text(
                    formatLocalizedDateTime(
                      context,
                      dueDate,
                      style: LocalizedDateTimeStyle.date,
                    ),
                    style: textStyles.bodySans,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              ExpansibleWidget<TaskPriority>.selection(
                cardPadding: EdgeInsets.zero,
                tilePadding: const EdgeInsets.symmetric(horizontal: 8),
                title: Text(
                  language.translate(priority.localizationKey),
                  style: textStyles.bodySans.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                ),
                items: TaskPriority.values,
                selectedValue: priority,
                itemLabelBuilder: (p) => language.translate(p.localizationKey),
                onSelected: (v) => setSheetState(() => priority = v),
              ),
              if (editing != null) ...[
                const SizedBox(height: 12),
                ExpansibleWidget<TaskStatus>.selection(
                  cardPadding: EdgeInsets.zero,
                  tilePadding: const EdgeInsets.symmetric(horizontal: 8),
                  title: Text(
                    language.translate(status.localizationKey),
                    style: textStyles.bodySans.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  items: TaskStatus.values,
                  selectedValue: status,
                  itemLabelBuilder: (s) =>
                      language.translate(s.localizationKey),
                  onSelected: (v) => setSheetState(() => status = v),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: OutlinedButton.icon(
                    onPressed: () {
                      tasksBloc.add(DeletePersonalTaskRequested(editing.id));
                      Navigator.pop(context);
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: colors.accentRed,
                      side: BorderSide(
                        color: colors.accentRed.withValues(alpha: 0.5),
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    icon: const Icon(TablerIcons.trash, size: 18),
                    label: Text(language.translate('common_delete')),
                  ),
                ),
              ],
            ],
          );
        },
        footerBuilder: (context, setSheetState) {
          return SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: () {
                final title = titleCtrl.text.trim();
                if (title.isEmpty) return;
                final input = PersonalTaskInput(
                  title: title,
                  description: descCtrl.text.trim().isEmpty
                      ? null
                      : descCtrl.text.trim(),
                  dueDate: dueDate,
                  priority: priority,
                  status: editing == null ? null : status,
                );
                if (editing != null) {
                  tasksBloc.add(
                    UpdatePersonalTaskRequested(
                      taskId: editing.id,
                      input: input,
                    ),
                  );
                } else {
                  tasksBloc.add(CreatePersonalTaskRequested(input));
                }
                Navigator.pop(context);
              },
              child: Text(
                language.translate(
                  editing == null ? 'common_create' : 'common_save',
                ),
              ),
            ),
          );
        },
      );
    } finally {
      titleCtrl.dispose();
      descCtrl.dispose();
    }
  }
}
