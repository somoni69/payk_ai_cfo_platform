part of 'tasks_screen.dart';

extension _TasksListBuilders on _TasksViewState {
  Widget _buildCheckbox(
    BuildContext context,
    Task task,
    bool isDone,
    bool isPending,
  ) {
    return AnimatedCheckbox(
      value: isDone,
      isPending: isPending,
      isEnabled: _canManageTasks(context),
      semanticLabel: task.title,
      pendingSemanticLabel: context.translate('common_loading'),
      onChanged: (newValue) {
        if (isPending) return;
        final nextStatus = newValue ? TaskStatus.done : TaskStatus.todo;
        context.read<TasksBloc>().add(
          UpdateTaskStatusRequested(taskId: task.id, status: nextStatus),
        );
      },
    );
  }

  Widget _buildTaskListHeader(
    BuildContext context,
    List<Task> tasks,
    TaskStatus status,
  ) {
    final colors = context.colors;
    final textStyles = context.textStyles;
    final language = context.watch<LanguageCubit>();
    final count = tasks.length;
    final urgentCount = tasks
        .where((t) => t.priority == TaskPriority.urgent)
        .length;
    final highCount = tasks
        .where((t) => t.priority == TaskPriority.high)
        .length;

    String titleText = '';

    switch (status) {
      case TaskStatus.todo:
        titleText = language.translate('tasks_list_header_new');
        break;
      case TaskStatus.inProgress:
        titleText = language.translate('tasks_list_header_in_progress');
        break;
      case TaskStatus.review:
        titleText = language.translate('tasks_list_header_review');
        break;
      case TaskStatus.done:
        titleText = language.translate('tasks_list_header_done');
        break;
    }

    final List<String> priorityList = [];
    if (urgentCount > 0) {
      priorityList.add(
        language.translatePlural('tasks_priority_urgent_count', urgentCount),
      );
    }
    if (highCount > 0) {
      priorityList.add(
        language.translate(
          'tasks_priority_high_count',
          params: {'count': highCount},
        ),
      );
    }
    final priorityText = priorityList.join(' · ');

    return Container(
      decoration: BoxDecoration(
        color: colors.brand.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.brand.withValues(alpha: 0.05)),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                titleText,
                style: textStyles.bodySans.copyWith(
                  fontWeight: FontWeight.w500,
                  fontSize: 16,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: colors.brand.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  _taskCountLabel(language, count),
                  style: textStyles.captionSans.copyWith(
                    color: colors.brand,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          if (priorityText.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              priorityText,
              style: textStyles.captionSans.copyWith(
                color: colors.textSecondary,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTaskList(
    BuildContext context,
    List<Task> allTasks,
    TaskStatus status,
    List<TaskProject> projects,
    List<TaskAssignee> assignees,
    Set<String> pendingTaskIds,
  ) {
    final colors = context.colors;
    final textStyles = context.textStyles;
    final language = context.watch<LanguageCubit>();

    final tasks = allTasks.where((t) => t.status == status).toList();

    return RefreshIndicator(
      onRefresh: () => _refreshTasks(context),
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: tasks.length + 1,
        separatorBuilder: (context, index) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          if (index == 0) {
            return _buildTaskListHeader(context, tasks, status);
          }

          final task = tasks[index - 1];
          final isDone = status == TaskStatus.done;

          Color pColor = colors.surfaceNested;
          Color pTextColor = colors.textSecondary;
          if (task.priority == TaskPriority.urgent) {
            pColor = colors.accentRed.withValues(alpha: 0.1);
            pTextColor = colors.accentRed;
          } else if (task.priority == TaskPriority.high) {
            pColor = colors.accentAmber.withValues(alpha: 0.1);
            pTextColor = colors.accentAmber;
          } else if (task.priority == TaskPriority.medium) {
            pColor = colors.brand.withValues(alpha: 0.1);
            pTextColor = colors.brand;
          } else if (task.priority == TaskPriority.low) {
            pColor = colors.accentGreen.withValues(alpha: 0.1);
            pTextColor = colors.accentGreen;
          }

          return GestureDetector(
            onTap: _canManageTasks(context)
                ? () => _showEditTaskBottomSheet(
                    context,
                    task,
                    projects,
                    assignees,
                  )
                : null,
            child: Container(
              key: ValueKey(task.id),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: colors.surface,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: colors.border),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          task.title,
                          style: textStyles.bodySans.copyWith(
                            fontWeight: FontWeight.w500,
                            decoration: isDone
                                ? TextDecoration.lineThrough
                                : null,
                            color: isDone
                                ? colors.textTooltip
                                : colors.textPrimary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            if (task.projectName != null) ...[
                              Flexible(
                                child: Text(
                                  task.projectName!,
                                  style: textStyles.captionSans.copyWith(
                                    color: colors.brand,
                                    fontWeight: FontWeight.w500,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                width: 3,
                                height: 3,
                                decoration: BoxDecoration(
                                  color: colors.textSecondary.withValues(
                                    alpha: 0.4,
                                  ),
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 8),
                            ],
                            Icon(
                              TablerIcons.calendar,
                              size: 12,
                              color: colors.textTooltip,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              _formatLocalizedCompactDate(
                                language,
                                task.dueDate,
                              ),
                              style: textStyles.captionSans.copyWith(
                                color:
                                    task.dueDate.isBefore(DateTime.now()) &&
                                        !isDone
                                    ? colors.accentRed
                                    : colors.textTooltip,
                              ),
                            ),
                            if (task.assigneeName != null &&
                                task.assigneeName!.trim().isNotEmpty) ...[
                              const SizedBox(width: 8),
                              Container(
                                width: 3,
                                height: 3,
                                decoration: BoxDecoration(
                                  color: colors.textSecondary.withValues(
                                    alpha: 0.4,
                                  ),
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Icon(
                                TablerIcons.user,
                                size: 12,
                                color: colors.textTooltip,
                              ),
                              const SizedBox(width: 4),
                              Flexible(
                                child: Text(
                                  language.translateMessage(task.assigneeName!),
                                  style: textStyles.captionSans.copyWith(
                                    color: colors.textTooltip,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  LedgerPill(
                    text: language.translate(task.priority.localizationKey),
                    backgroundColor: pColor,
                    textColor: pTextColor,
                    fontSize: 13,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                  ),
                  const SizedBox(width: 12),
                  _buildCheckbox(
                    context,
                    task,
                    isDone,
                    pendingTaskIds.contains(task.id),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  /// Compact priority chips in a single row (no orphan wrap on the second line).
  Widget _buildPriorityChips(
    BuildContext context, {
    required TaskPriority selectedPriority,
    required ValueChanged<TaskPriority> onSelected,
  }) {
    final colors = context.colors;
    final textStyles = context.textStyles;
    final language = context.watch<LanguageCubit>();

    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: TaskPriority.values.map((priority) {
        final isSelected = selectedPriority == priority;

        final selectedTextColor = switch (priority) {
          TaskPriority.urgent => colors.accentRed,
          TaskPriority.high => colors.accentAmber,
          TaskPriority.low => colors.accentGreen,
          TaskPriority.medium => colors.brand,
        };

        final selectedBgColor = selectedTextColor.withValues(alpha: 0.15);
        final selectedBorderColor = selectedTextColor;

        return Semantics(
          button: true,
          selected: isSelected,
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(999),
              onTap: () => onSelected(priority),
              child: Container(
                constraints: const BoxConstraints(minHeight: 48),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: isSelected ? selectedBgColor : colors.surface,
                  border: Border.all(
                    color: isSelected ? selectedBorderColor : colors.border,
                  ),
                  borderRadius: BorderRadius.circular(999),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 8,
                ),
                child: Text(
                  language.translate(priority.localizationKey),
                  style: textStyles.captionSans.copyWith(
                    color: isSelected
                        ? selectedTextColor
                        : colors.textSecondary,
                    fontWeight: isSelected ? FontWeight.w500 : FontWeight.w400,
                  ),
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}
