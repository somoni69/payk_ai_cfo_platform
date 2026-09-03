part of 'tasks_screen.dart';

extension _TasksListBuilders on _TasksViewMixin {
  Widget _buildAllTasksTab(
    BuildContext context,
    List<Task> allTasks,
    List<TaskProject> projects,
    List<TaskAssignee> assignees,
    Set<String> pendingTaskIds,
  ) {
    final colors = context.colors;
    final textStyles = context.textStyles;
    final language = context.watch<LanguageCubit>();
    final canManage = _canManageTasks(context);

    final todoCount = allTasks.where((t) => t.status == TaskStatus.todo).length;
    final inProgressCount = allTasks
        .where((t) => t.status == TaskStatus.inProgress)
        .length;
    final reviewCount = allTasks
        .where((t) => t.status == TaskStatus.review)
        .length;
    final doneCount = allTasks.where((t) => t.status == TaskStatus.done).length;

    // Filter tasks by active status filter chip
    final tasks = allTasks.where((t) {
      if (_selectedStatusFilter != null && t.status != _selectedStatusFilter) {
        return false;
      }
      return true;
    }).toList();

    return RefreshIndicator(
      onRefresh: () => _refreshTasks(context),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 96),
        children: [
          // 1. Status Filter Chips Row
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildStatusFilterChip(
                  context,
                  label: language.translate('tasks_filter_all_status'),
                  count: allTasks.length,
                  isSelected: _selectedStatusFilter == null,
                  onTap: () => _rebuild(() => _selectedStatusFilter = null),
                ),
                const SizedBox(width: 8),
                _buildStatusFilterChip(
                  context,
                  label: language.translate('tasks_tab_new'),
                  count: todoCount,
                  isSelected: _selectedStatusFilter == TaskStatus.todo,
                  onTap: () =>
                      _rebuild(() => _selectedStatusFilter = TaskStatus.todo),
                ),
                const SizedBox(width: 8),
                _buildStatusFilterChip(
                  context,
                  label: language.translate('tasks_tab_in_progress'),
                  count: inProgressCount,
                  isSelected: _selectedStatusFilter == TaskStatus.inProgress,
                  onTap: () => _rebuild(
                    () => _selectedStatusFilter = TaskStatus.inProgress,
                  ),
                ),
                const SizedBox(width: 8),
                _buildStatusFilterChip(
                  context,
                  label: language.translate('tasks_tab_review'),
                  count: reviewCount,
                  isSelected: _selectedStatusFilter == TaskStatus.review,
                  onTap: () =>
                      _rebuild(() => _selectedStatusFilter = TaskStatus.review),
                ),
                const SizedBox(width: 8),
                _buildStatusFilterChip(
                  context,
                  label: language.translate('tasks_tab_done'),
                  count: doneCount,
                  isSelected: _selectedStatusFilter == TaskStatus.done,
                  onTap: () =>
                      _rebuild(() => _selectedStatusFilter = TaskStatus.done),
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // 2. Task Cards List or Empty State
          if (tasks.isEmpty)
            Container(
              margin: const EdgeInsets.only(top: 16),
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: colors.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: colors.border),
              ),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      TablerIcons.clipboard_list,
                      size: 32,
                      color: colors.textSecondary,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      language.translate('tasks_empty'),
                      style: textStyles.captionSans.copyWith(
                        color: colors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            ...tasks.map((task) {
              final isPending = pendingTaskIds.contains(task.id);
              return UnifiedTaskCard(
                key: ValueKey('all-${task.id}'),
                task: task,
                isPersonal: false,
                canManage: canManage,
                isPending: isPending,
                onTap: canManage
                    ? () => _showEditTaskBottomSheet(
                        context,
                        task,
                        projects,
                        assignees,
                      )
                    : null,
                onStatusChanged: canManage
                    ? (val) {
                        if (isPending) return;
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
              );
            }),
        ],
      ),
    );
  }

  Widget _buildStatusFilterChip(
    BuildContext context, {
    required String label,
    required int count,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    final colors = context.colors;
    final textStyles = context.textStyles;

    return Material(
      color: isSelected ? colors.brand : colors.surface,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isSelected ? colors.brand : colors.border,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: textStyles.captionSans.copyWith(
                  color: isSelected ? Colors.white : colors.textPrimary,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                  fontSize: 12,
                ),
              ),
              const SizedBox(width: 5),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                decoration: BoxDecoration(
                  color: isSelected
                      ? Colors.white.withValues(alpha: 0.25)
                      : colors.surfaceNested,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '$count',
                  style: textStyles.captionSans.copyWith(
                    color: isSelected ? Colors.white : colors.textSecondary,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPriorityChips(
    BuildContext context, {
    required TaskPriority selectedPriority,
    required ValueChanged<TaskPriority> onSelected,
  }) {
    final colors = context.colors;
    final textStyles = context.textStyles;
    final language = context.watch<LanguageCubit>();

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: TaskPriority.values.map((priority) {
        final isSelected = selectedPriority == priority;

        final priorityColor = switch (priority) {
          TaskPriority.urgent => colors.accentRed,
          TaskPriority.high => colors.accentAmber,
          TaskPriority.low => colors.accentGreen,
          TaskPriority.medium => colors.brand,
        };

        return ChoiceChip(
          label: Text(language.translate(priority.localizationKey)),
          selected: isSelected,
          onSelected: (val) {
            if (val) onSelected(priority);
          },
          selectedColor: priorityColor,
          backgroundColor: colors.surface,
          checkmarkColor: Colors.white,
          labelStyle: textStyles.captionSans.copyWith(
            color: isSelected ? Colors.white : colors.textPrimary,
            fontWeight: isSelected ? FontWeight.w500 : FontWeight.w400,
            fontSize: 12,
          ),
          side: BorderSide(color: isSelected ? priorityColor : colors.border),
        );
      }).toList(),
    );
  }

  Widget _buildBoardTab(
    BuildContext context,
    List<Task> allTasks,
    Set<String> pendingTaskIds,
  ) {
    final colors = context.colors;
    final textStyles = context.textStyles;
    final language = context.watch<LanguageCubit>();
    final canManage = _canManageTasks(context);
    final boardTasks = allTasks.where((t) => !t.isPersonal).toList();

    return RefreshIndicator(
      onRefresh: () => _refreshTasks(context),
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
        itemCount: TaskStatus.values.length,
        itemBuilder: (context, index) {
          final status = TaskStatus.values[index];
          final column = boardTasks.where((t) => t.status == status).toList();
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
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
                      Expanded(
                        child: Text(
                          language.translate(status.localizationKey),
                          style: textStyles.bodySans.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      Text(
                        '${column.length}',
                        style: textStyles.captionSans.copyWith(
                          color: colors.textSecondary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (column.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Text(
                        language.translate('tasks_board_empty_column'),
                        style: textStyles.captionSans.copyWith(
                          color: colors.textSecondary,
                        ),
                      ),
                    )
                  else
                    for (final task in column)
                      _BoardTaskCard(
                        task: task,
                        pending: pendingTaskIds.contains(task.id),
                        canMove: canManage,
                        onBack: index == 0
                            ? null
                            : () => context.read<TasksBloc>().add(
                                UpdateTaskStatusRequested(
                                  taskId: task.id,
                                  status: TaskStatus.values[index - 1],
                                ),
                              ),
                        onForward: index == TaskStatus.values.length - 1
                            ? null
                            : () => context.read<TasksBloc>().add(
                                UpdateTaskStatusRequested(
                                  taskId: task.id,
                                  status: TaskStatus.values[index + 1],
                                ),
                              ),
                      ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _BoardTaskCard extends StatelessWidget {
  const _BoardTaskCard({
    required this.task,
    required this.pending,
    required this.canMove,
    this.onBack,
    this.onForward,
  });

  final Task task;
  final bool pending;
  final bool canMove;
  final VoidCallback? onBack;
  final VoidCallback? onForward;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final textStyles = context.textStyles;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: colors.surfaceNested,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: colors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              task.title,
              style: textStyles.bodySans.copyWith(fontWeight: FontWeight.w600),
            ),
            if (task.assigneeName != null && task.assigneeName!.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                task.assigneeName!,
                style: textStyles.captionSans.copyWith(
                  color: colors.textSecondary,
                ),
              ),
            ],
            if (canMove) ...[
              const SizedBox(height: 6),
              Row(
                children: [
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    onPressed: pending ? null : onBack,
                    icon: Icon(
                      TablerIcons.arrow_left,
                      size: 18,
                      color: onBack == null ? colors.textTooltip : colors.brand,
                    ),
                  ),
                  const Spacer(),
                  if (pending)
                    const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    onPressed: pending ? null : onForward,
                    icon: Icon(
                      TablerIcons.arrow_right,
                      size: 18,
                      color: onForward == null
                          ? colors.textTooltip
                          : colors.brand,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
