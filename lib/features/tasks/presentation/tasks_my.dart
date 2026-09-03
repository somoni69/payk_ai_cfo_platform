part of 'tasks_screen.dart';

extension _TasksMyTab on _TasksViewMixin {
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
    final userId = _currentUserId;

    if (state.isMyTasksLoading && !state.myTasksLoaded) {
      return const TasksMyShimmer();
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
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
        children: [
          // Section 1: Личные задачи
          _buildMySectionHeader(
            context,
            title: language.translate('tasks_my_personal_section'),
            count: personal.length,
            icon: TablerIcons.checkbox,
          ),
          if (personal.isEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 20),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: colors.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: colors.border),
                ),
                child: Center(
                  child: Text(
                    language.translate('tasks_my_personal_empty'),
                    style: textStyles.captionSans.copyWith(
                      color: colors.textSecondary,
                    ),
                  ),
                ),
              ),
            )
          else ...[
            ...personal.map((task) {
              return UnifiedTaskCard(
                key: ValueKey('personal-${task.id}'),
                task: task,
                isPersonal: true,
                canManage: true,
                isPending: state.pendingStatusTaskIds.contains(task.id),
                onTap: () => _showPersonalTaskSheet(context, editing: task),
                onStatusChanged: (val) {
                  final nextStatus = val ? TaskStatus.done : TaskStatus.todo;
                  context.read<TasksBloc>().add(
                    UpdateTaskStatusRequested(
                      taskId: task.id,
                      status: nextStatus,
                    ),
                  );
                },
              );
            }),
            const SizedBox(height: 14),
          ],

          // Section 2: Назначенные мне
          _buildMySectionHeader(
            context,
            title: language.translate('tasks_my_assigned_section'),
            count: assigned.length + mineOther.length,
            icon: TablerIcons.user_check,
          ),
          if (assigned.isEmpty && mineOther.isEmpty)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: colors.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: colors.border),
              ),
              child: Center(
                child: Text(
                  language.translate('tasks_my_assigned_empty'),
                  style: textStyles.captionSans.copyWith(
                    color: colors.textSecondary,
                  ),
                ),
              ),
            )
          else ...[
            ...assigned.map((task) {
              final isAssignee =
                  userId != null && task.assigneeId == userId.toString();
              final isReviewer =
                  _isDirector ||
                  (userId != null &&
                      task.createdBy != null &&
                      task.createdBy == userId);

              return UnifiedTaskCard(
                key: ValueKey('assigned-${task.id}'),
                task: task,
                isPersonal: false,
                isAssignee: isAssignee,
                isReviewer: isReviewer,
                canManage: isAssignee || _canManageTasks(context),
                isPending: state.pendingStatusTaskIds.contains(task.id),
                onTap: _canManageTasks(context)
                    ? () => _showEditTaskBottomSheet(
                        context,
                        task,
                        state.projects,
                        state.assignees,
                      )
                    : null,
                onStatusChanged: (isAssignee || _canManageTasks(context))
                    ? (val) {
                        final nextStatus = val
                            ? TaskStatus.done
                            : TaskStatus.todo;
                        context.read<TasksBloc>().add(
                          UpdateTaskStatusRequested(
                            taskId: task.id,
                            status: nextStatus,
                          ),
                        );
                      }
                    : null,
                onAccept: (isAssignee && task.acknowledgedAt == null)
                    ? () => context.read<TasksBloc>().add(
                        AcknowledgeTaskRequested(task.id),
                      )
                    : null,
                onSubmit: (isAssignee && task.acknowledgedAt != null)
                    ? () => context.read<TasksBloc>().add(
                        SubmitTaskRequested(task.id),
                      )
                    : null,
                onApprove: (isReviewer && task.status == TaskStatus.review)
                    ? () => context.read<TasksBloc>().add(
                        AcceptTaskRequested(task.id),
                      )
                    : null,
                onReject: (isReviewer && task.status == TaskStatus.review)
                    ? () => _showRejectSheet(context, task)
                    : null,
              );
            }),
            ...mineOther.map((task) {
              final isReviewer =
                  _isDirector ||
                  (userId != null &&
                      task.createdBy != null &&
                      task.createdBy == userId);

              return UnifiedTaskCard(
                key: ValueKey('mine-other-${task.id}'),
                task: task,
                isPersonal: false,
                isAssignee: false,
                isReviewer: isReviewer,
                canManage: _canManageTasks(context),
                isPending: state.pendingStatusTaskIds.contains(task.id),
                onTap: _canManageTasks(context)
                    ? () => _showEditTaskBottomSheet(
                        context,
                        task,
                        state.projects,
                        state.assignees,
                      )
                    : null,
                onStatusChanged: _canManageTasks(context)
                    ? (val) {
                        final nextStatus = val
                            ? TaskStatus.done
                            : TaskStatus.todo;
                        context.read<TasksBloc>().add(
                          UpdateTaskStatusRequested(
                            taskId: task.id,
                            status: nextStatus,
                          ),
                        );
                      }
                    : null,
                onApprove: (isReviewer && task.status == TaskStatus.review)
                    ? () => context.read<TasksBloc>().add(
                        AcceptTaskRequested(task.id),
                      )
                    : null,
                onReject: (isReviewer && task.status == TaskStatus.review)
                    ? () => _showRejectSheet(context, task)
                    : null,
              );
            }),
          ],
        ],
      ),
    );
  }

  Widget _buildMySectionHeader(
    BuildContext context, {
    required String title,
    required int count,
    required IconData icon,
  }) {
    final colors = context.colors;
    final textStyles = context.textStyles;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Icon(icon, size: 18, color: colors.brand),
          const SizedBox(width: 8),
          Text(
            title,
            style: textStyles.bodySans.copyWith(
              fontWeight: FontWeight.w600,
              fontSize: 15,
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: colors.brand.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              '$count',
              style: textStyles.captionSans.copyWith(
                color: colors.brand,
                fontWeight: FontWeight.w600,
                fontSize: 12,
              ),
            ),
          ),
        ],
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
          return ElevatedButton(
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
                  height: kLedgerModalButtonHeight,
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
          return ElevatedButton(
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
                  UpdatePersonalTaskRequested(taskId: editing.id, input: input),
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
          );
        },
      );
    } finally {
      titleCtrl.dispose();
      descCtrl.dispose();
    }
  }
}
