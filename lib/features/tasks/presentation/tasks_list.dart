part of 'tasks_screen.dart';

extension _TasksListBuilders on _TasksViewState {
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
        color: colors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.border),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                titleText,
                style: textStyles.bodySans.copyWith(
                  fontWeight: FontWeight.w600,
                  fontSize: 15,
                ),
              ),
              if (priorityText.isNotEmpty) ...[
                const SizedBox(height: 3),
                Text(
                  priorityText,
                  style: textStyles.captionSans.copyWith(
                    color: colors.textSecondary,
                    fontSize: 12,
                  ),
                ),
              ],
            ],
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: colors.brand.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              _taskCountLabel(language, count),
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

  Widget _buildTaskList(
    BuildContext context,
    List<Task> allTasks,
    TaskStatus status,
    List<TaskProject> projects,
    List<TaskAssignee> assignees,
    Set<String> pendingTaskIds,
  ) {
    final canManage = _canManageTasks(context);

    // Apply active project filter or search query if any
    final tasks = allTasks.where((t) {
      if (t.status != status) return false;
      if (_selectedProjectId != null &&
          _selectedProjectId!.isNotEmpty &&
          t.projectId != _selectedProjectId) {
        return false;
      }
      if (_searchQuery.isNotEmpty &&
          !t.title.toLowerCase().contains(_searchQuery.toLowerCase()) &&
          !t.description.toLowerCase().contains(_searchQuery.toLowerCase())) {
        return false;
      }
      if (_onlyOverdue &&
          (!t.dueDate.isBefore(DateTime.now()) ||
              t.status == TaskStatus.done)) {
        return false;
      }
      return true;
    }).toList();

    return RefreshIndicator(
      onRefresh: () => _refreshTasks(context),
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
        itemCount: tasks.length + 1,
        itemBuilder: (context, index) {
          if (index == 0) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _buildTaskListHeader(context, tasks, status),
            );
          }

          final task = tasks[index - 1];
          final isPending = pendingTaskIds.contains(task.id);

          return UnifiedTaskCard(
            key: ValueKey(task.id),
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
                    final nextStatus = val ? TaskStatus.done : TaskStatus.todo;
                    context.read<TasksBloc>().add(
                      UpdateTaskStatusRequested(
                        taskId: task.id,
                        status: nextStatus,
                      ),
                    );
                  }
                : null,
          );
        },
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
          ),
          side: BorderSide(color: isSelected ? priorityColor : colors.border),
        );
      }).toList(),
    );
  }
}
