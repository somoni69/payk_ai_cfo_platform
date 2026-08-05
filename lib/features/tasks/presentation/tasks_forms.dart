part of 'tasks_screen.dart';

extension _TasksFormBuilders on _TasksViewState {
  Future<void> _showAddTaskBottomSheet(
    BuildContext context,
    List<TaskProject> projects,
    List<TaskAssignee> assignees,
  ) async {
    final tasksBloc = context.read<TasksBloc>();
    final colors = context.colors;
    final textStyles = context.textStyles;

    final titleController = TextEditingController();
    final descController = TextEditingController();

    TaskPriority selectedPriority = TaskPriority.medium;
    TaskProject? selectedProject;
    TaskAssignee? selectedAssignee;
    DateTime? selectedStartDate;
    DateTime selectedDueDate = DateTime.now().add(const Duration(days: 3));

    bool isDirty() {
      return titleController.text.trim().isNotEmpty ||
          descController.text.trim().isNotEmpty ||
          selectedProject != null ||
          selectedAssignee != null ||
          selectedStartDate != null ||
          selectedPriority != TaskPriority.medium;
    }

    try {
      await LedgerBottomSheet.show(
        context: context,
        title: context.read<LanguageCubit>().translate('tasks_add_title'),
        isDirty: isDirty,
        builder: (context, setSheetState) {
          final language = context.read<LanguageCubit>();

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: titleController,
                style: textStyles.bodySans,
                onChanged: (_) => setSheetState(() {}),
                decoration: InputDecoration(
                  labelText: language.translate('tasks_field_title'),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: descController,
                maxLines: 3,
                style: textStyles.bodySans,
                keyboardType: TextInputType.text,
                textInputAction: TextInputAction.done,
                onChanged: (_) => setSheetState(() {}),
                decoration: InputDecoration(
                  labelText: language.translate('tasks_field_description'),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                language.translate('tasks_field_project'),
                style: textStyles.bodySans.copyWith(
                  fontWeight: FontWeight.w500,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 6),
              ExpansibleWidget<TaskProject?>.selection(
                cardPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 4,
                ),
                title: Text(
                  selectedProject?.name ??
                      language.translate('tasks_select_project_optional'),
                  style: textStyles.bodySans.copyWith(
                    color: selectedProject == null
                        ? colors.textTooltip
                        : colors.textPrimary,
                  ),
                ),
                items: [null, ...projects],
                selectedValue: selectedProject,
                itemLabelBuilder: (p) =>
                    p?.name ?? language.translate('tasks_no_project'),
                onSelected: (p) {
                  setSheetState(() {
                    selectedProject = p;
                  });
                },
              ),
              const SizedBox(height: 16),
              Text(
                language.translate('tasks_field_priority'),
                style: textStyles.bodySans.copyWith(
                  fontWeight: FontWeight.w500,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 8),
              _buildPriorityChips(
                context,
                selectedPriority: selectedPriority,
                onSelected: (p) {
                  setSheetState(() {
                    selectedPriority = p;
                  });
                },
              ),
              const SizedBox(height: 16),
              Text(
                language.translate('tasks_field_assignee'),
                style: textStyles.bodySans.copyWith(
                  fontWeight: FontWeight.w500,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 6),
              ExpansibleWidget<TaskAssignee?>.selection(
                cardPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 4,
                ),
                title: Text(
                  language.translateMessage(
                    selectedAssignee?.fullName ??
                        language.translate('tasks_no_assignee'),
                  ),
                  style: textStyles.bodySans.copyWith(
                    color: selectedAssignee == null
                        ? colors.textTooltip
                        : colors.textPrimary,
                  ),
                ),
                items: [null, ...assignees],
                selectedValue: selectedAssignee,
                itemLabelBuilder: (a) => language.translateMessage(
                  a?.fullName ?? language.translate('tasks_no_assignee'),
                ),
                onSelected: (a) {
                  setSheetState(() {
                    selectedAssignee = a;
                  });
                },
              ),
              const SizedBox(height: 16),
              Text(
                language.translate('tasks_field_start_date'),
                style: textStyles.bodySans.copyWith(
                  fontWeight: FontWeight.w500,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 6),
              InkWell(
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: selectedStartDate ?? DateTime.now(),
                    firstDate: DateTime.now().subtract(
                      const Duration(days: 365),
                    ),
                    lastDate: DateTime.now().add(const Duration(days: 365)),
                  );
                  if (picked != null) {
                    setSheetState(() {
                      selectedStartDate = picked;
                    });
                  }
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    border: Border.all(color: colors.border),
                    borderRadius: BorderRadius.circular(8),
                    color: colors.surface,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        selectedStartDate != null
                            ? formatLocalizedDateTime(
                                context,
                                selectedStartDate!,
                                style: LocalizedDateTimeStyle.date,
                              )
                            : language.translate('tasks_not_set'),
                        style: textStyles.captionSans,
                      ),
                      Icon(
                        TablerIcons.calendar,
                        size: 16,
                        color: colors.textSecondary,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                language.translate('tasks_field_due_date'),
                style: textStyles.bodySans.copyWith(
                  fontWeight: FontWeight.w500,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 6),
              InkWell(
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: selectedDueDate,
                    firstDate: DateTime.now().subtract(
                      const Duration(days: 365),
                    ),
                    lastDate: DateTime.now().add(const Duration(days: 365)),
                  );
                  if (picked != null) {
                    setSheetState(() {
                      selectedDueDate = picked;
                    });
                  }
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    border: Border.all(color: colors.border),
                    borderRadius: BorderRadius.circular(8),
                    color: colors.surface,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        formatLocalizedDateTime(
                          context,
                          selectedDueDate,
                          style: LocalizedDateTimeStyle.date,
                        ),
                        style: textStyles.captionSans,
                      ),
                      Icon(
                        TablerIcons.calendar,
                        size: 16,
                        color: colors.textSecondary,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
        footerBuilder: (context, setSheetState) {
          final language = context.read<LanguageCubit>();

          return ElevatedButton(
            onPressed: () {
              if (titleController.text.trim().isNotEmpty) {
                final newTask = Task(
                  id: '',
                  title: titleController.text.trim(),
                  description: descController.text.trim(),
                  status: TaskStatus.todo,
                  dueDate: selectedDueDate,
                  priority: selectedPriority,
                  projectId: selectedProject?.id,
                  projectName: selectedProject?.name,
                  assigneeId: selectedAssignee?.id,
                  assigneeName: selectedAssignee?.fullName,
                  startDate: selectedStartDate,
                );
                tasksBloc.add(CreateTaskRequested(newTask));
                Navigator.pop(context);
              }
            },
            child: Text(language.translate('tasks_create')),
          );
        },
      );
    } finally {
      // Defer dispose until TextFields unmount after the sheet route is gone.
      final title = titleController;
      final desc = descController;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        title.dispose();
        desc.dispose();
      });
    }
  }

  Future<void> _showEditTaskBottomSheet(
    BuildContext context,
    Task task,
    List<TaskProject> projects,
    List<TaskAssignee> assignees,
  ) async {
    final tasksBloc = context.read<TasksBloc>();
    final colors = context.colors;
    final textStyles = context.textStyles;

    final titleController = TextEditingController(text: task.title);
    final descController = TextEditingController(text: task.description);

    TaskStatus selectedStatus = task.status;
    TaskPriority selectedPriority = task.priority;
    TaskProject? selectedProject;
    if (task.projectId != null) {
      try {
        selectedProject = projects.firstWhere((p) => p.id == task.projectId);
      } catch (_) {}
    }
    TaskAssignee? selectedAssignee;
    if (task.assigneeId != null) {
      try {
        selectedAssignee = assignees.firstWhere((a) => a.id == task.assigneeId);
      } catch (_) {
        if (task.assigneeName != null && task.assigneeName!.trim().isNotEmpty) {
          selectedAssignee = TaskAssignee(
            id: task.assigneeId!,
            fullName: task.assigneeName!,
          );
        }
      }
    }
    DateTime? selectedStartDate = task.startDate;
    DateTime selectedDueDate = task.dueDate;

    bool isDateChanged(DateTime? a, DateTime? b) {
      if (a == null && b == null) return false;
      if (a == null || b == null) return true;
      return a.year != b.year || a.month != b.month || a.day != b.day;
    }

    bool isDirty() {
      final currentTitle = titleController.text.trim();
      final currentDesc = descController.text.trim();
      final origProjectId = task.projectId;
      final currentProjectId = selectedProject?.id;

      return currentTitle != task.title ||
          currentDesc != task.description ||
          selectedStatus != task.status ||
          currentProjectId != origProjectId ||
          selectedAssignee?.id != task.assigneeId ||
          selectedPriority != task.priority ||
          isDateChanged(selectedStartDate, task.startDate) ||
          isDateChanged(selectedDueDate, task.dueDate);
    }

    try {
      await LedgerBottomSheet.show(
        context: context,
        title: context.read<LanguageCubit>().translate('tasks_edit_title'),
        isDirty: isDirty,
        builder: (context, setSheetState) {
          final language = context.read<LanguageCubit>();

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: titleController,
                style: textStyles.bodySans,
                onChanged: (_) => setSheetState(() {}),
                decoration: InputDecoration(
                  labelText: language.translate('tasks_field_title'),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: descController,
                maxLines: 3,
                style: textStyles.bodySans,
                keyboardType: TextInputType.text,
                textInputAction: TextInputAction.done,
                onChanged: (_) => setSheetState(() {}),
                decoration: InputDecoration(
                  labelText: language.translate('tasks_field_description'),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                language.translate('tasks_field_stage_status'),
                style: textStyles.bodySans.copyWith(
                  fontWeight: FontWeight.w500,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 6),
              ExpansibleWidget<TaskStatus>.selection(
                cardPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 4,
                ),
                title: Text(
                  language.translate(selectedStatus.localizationKey),
                  style: textStyles.bodySans,
                ),
                items: TaskStatus.values,
                selectedValue: selectedStatus,
                itemLabelBuilder: (s) => language.translate(s.localizationKey),
                onSelected: (s) {
                  setSheetState(() {
                    selectedStatus = s;
                  });
                },
              ),
              const SizedBox(height: 16),
              Text(
                language.translate('tasks_field_project'),
                style: textStyles.bodySans.copyWith(
                  fontWeight: FontWeight.w500,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 6),
              ExpansibleWidget<TaskProject?>.selection(
                cardPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 4,
                ),
                title: Text(
                  selectedProject?.name ??
                      language.translate('tasks_select_project_optional'),
                  style: textStyles.bodySans.copyWith(
                    color: selectedProject == null
                        ? colors.textTooltip
                        : colors.textPrimary,
                  ),
                ),
                items: [null, ...projects],
                selectedValue: selectedProject,
                itemLabelBuilder: (p) =>
                    p?.name ?? language.translate('tasks_no_project'),
                onSelected: (p) {
                  setSheetState(() {
                    selectedProject = p;
                  });
                },
              ),
              const SizedBox(height: 16),
              Text(
                language.translate('tasks_field_priority'),
                style: textStyles.bodySans.copyWith(
                  fontWeight: FontWeight.w500,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 8),
              _buildPriorityChips(
                context,
                selectedPriority: selectedPriority,
                onSelected: (p) {
                  setSheetState(() {
                    selectedPriority = p;
                  });
                },
              ),
              const SizedBox(height: 16),
              Text(
                language.translate('tasks_field_assignee'),
                style: textStyles.bodySans.copyWith(
                  fontWeight: FontWeight.w500,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 6),
              ExpansibleWidget<TaskAssignee?>.selection(
                cardPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 4,
                ),
                title: Text(
                  language.translateMessage(
                    selectedAssignee?.fullName ??
                        language.translate('tasks_no_assignee'),
                  ),
                  style: textStyles.bodySans.copyWith(
                    color: selectedAssignee == null
                        ? colors.textTooltip
                        : colors.textPrimary,
                  ),
                ),
                items: [null, ...assignees],
                selectedValue: selectedAssignee,
                itemLabelBuilder: (a) => language.translateMessage(
                  a?.fullName ?? language.translate('tasks_no_assignee'),
                ),
                onSelected: (a) {
                  setSheetState(() {
                    selectedAssignee = a;
                  });
                },
              ),
              const SizedBox(height: 16),
              Text(
                language.translate('tasks_field_start_date'),
                style: textStyles.bodySans.copyWith(
                  fontWeight: FontWeight.w500,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 6),
              InkWell(
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: selectedStartDate ?? DateTime.now(),
                    firstDate: DateTime.now().subtract(
                      const Duration(days: 365),
                    ),
                    lastDate: DateTime.now().add(const Duration(days: 365)),
                  );
                  if (picked != null) {
                    setSheetState(() {
                      selectedStartDate = picked;
                    });
                  }
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    border: Border.all(color: colors.border),
                    borderRadius: BorderRadius.circular(8),
                    color: colors.surface,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        selectedStartDate != null
                            ? formatLocalizedDateTime(
                                context,
                                selectedStartDate!,
                                style: LocalizedDateTimeStyle.date,
                              )
                            : language.translate('tasks_not_set'),
                        style: textStyles.captionSans,
                      ),
                      Icon(
                        TablerIcons.calendar,
                        size: 16,
                        color: colors.textSecondary,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                language.translate('tasks_field_due_date'),
                style: textStyles.bodySans.copyWith(
                  fontWeight: FontWeight.w500,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 6),
              InkWell(
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: selectedDueDate,
                    firstDate: DateTime.now().subtract(
                      const Duration(days: 365),
                    ),
                    lastDate: DateTime.now().add(const Duration(days: 365)),
                  );
                  if (picked != null) {
                    setSheetState(() {
                      selectedDueDate = picked;
                    });
                  }
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    border: Border.all(color: colors.border),
                    borderRadius: BorderRadius.circular(8),
                    color: colors.surface,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        formatLocalizedDateTime(
                          context,
                          selectedDueDate,
                          style: LocalizedDateTimeStyle.date,
                        ),
                        style: textStyles.captionSans,
                      ),
                      Icon(
                        TablerIcons.calendar,
                        size: 16,
                        color: colors.textSecondary,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: OutlinedButton.icon(
                  onPressed: () {
                    tasksBloc.add(DeletePersonalTaskRequested(task.id));
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
                  label: Text(
                    context.read<LanguageCubit>().translate('common_delete'),
                  ),
                ),
              ),
            ],
          );
        },
        footerBuilder: (context, setSheetState) {
          final language = context.read<LanguageCubit>();

          return ElevatedButton(
            onPressed: () {
              if (titleController.text.trim().isNotEmpty) {
                // Explicit Task so clearing project/assignee can set nulls (copyWith can't).
                final updatedTask = Task(
                  id: task.id,
                  title: titleController.text.trim(),
                  description: descController.text.trim(),
                  status: selectedStatus,
                  dueDate: selectedDueDate,
                  priority: selectedPriority,
                  projectId: selectedProject?.id,
                  projectName: selectedProject?.name,
                  assigneeId: selectedAssignee?.id,
                  assigneeName: selectedAssignee?.fullName,
                  startDate: selectedStartDate,
                  dependsOnId: task.dependsOnId,
                  position: task.position,
                );
                tasksBloc.add(UpdateTaskRequested(updatedTask));
                Navigator.pop(context);
              }
            },
            child: Text(language.translate('tasks_save_changes')),
          );
        },
      );
    } finally {
      final title = titleController;
      final desc = descController;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        title.dispose();
        desc.dispose();
      });
    }
  }
}
