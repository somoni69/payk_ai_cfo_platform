part of 'tasks_screen.dart';

extension _TasksCalendarBuilders on _TasksViewState {
  Widget _buildCalendarTab(
    BuildContext context,
    List<Task> tasks,
    List<TaskProject> projects,
    List<TaskAssignee> assignees,
  ) {
    final colors = context.colors;
    final textStyles = context.textStyles;
    final language = context.watch<LanguageCubit>();

    final year = _calendarMonth.year;
    final month = _calendarMonth.month;

    final firstDay = DateTime(year, month, 1);
    final weekdayOffset = (firstDay.weekday - 1) % 7;
    final startGridDate = firstDay.subtract(Duration(days: weekdayOffset));

    final gridDates = List<DateTime>.generate(
      42,
      (index) => startGridDate.add(Duration(days: index)),
    );

    final tasksByDay = <DateTime, List<Task>>{};
    for (final task in tasks) {
      final day = DateUtils.dateOnly(task.dueDate);
      (tasksByDay[day] ??= <Task>[]).add(task);
    }
    final monthNames = [
      language.translate('tasks_month_january'),
      language.translate('tasks_month_february'),
      language.translate('tasks_month_march'),
      language.translate('tasks_month_april'),
      language.translate('tasks_month_may'),
      language.translate('tasks_month_june'),
      language.translate('tasks_month_july'),
      language.translate('tasks_month_august'),
      language.translate('tasks_month_september'),
      language.translate('tasks_month_october'),
      language.translate('tasks_month_november'),
      language.translate('tasks_month_december'),
    ];
    final weekdayLabels = List.generate(
      7,
      (index) => language.translate(_weekdayLocalizationKey(index + 1)),
    );

    return RefreshIndicator(
      onRefresh: () => _refreshTasks(context),
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                language.translate(
                  'tasks_calendar_month_year',
                  params: {'month': monthNames[month - 1], 'year': year},
                ),
                style: textStyles.h2Sans,
              ),
              Row(
                children: [
                  IconButton(
                    icon: const Icon(TablerIcons.chevron_left),
                    tooltip: language.translate('common_previous'),
                    onPressed: () {
                      _rebuild(() {
                        _calendarMonth = DateTime(year, month - 1, 1);
                        _selectedCalendarDay = null;
                      });
                    },
                  ),
                  TextButton(
                    onPressed: () {
                      _rebuild(() {
                        _calendarMonth = DateTime.now();
                        _selectedCalendarDay = DateTime.now();
                      });
                    },
                    child: Text(
                      language.translate('tasks_calendar_today'),
                      style: textStyles.captionSans.copyWith(
                        color: colors.brand,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(TablerIcons.chevron_right),
                    tooltip: language.translate('common_next'),
                    onPressed: () {
                      _rebuild(() {
                        _calendarMonth = DateTime(year, month + 1, 1);
                        _selectedCalendarDay = null;
                      });
                    },
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            language.translate('tasks_calendar_workload_hint'),
            style: textStyles.captionSans.copyWith(color: colors.textSecondary),
          ),
          const SizedBox(height: 8),
          GridView.builder(
            padding: EdgeInsets.zero,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              mainAxisSpacing: 4,
              crossAxisSpacing: 4,
              childAspectRatio: 1.5,
            ),
            itemCount: 7,
            itemBuilder: (context, index) {
              return Center(
                child: Text(
                  weekdayLabels[index],
                  style: textStyles.smallSans.copyWith(
                    color: colors.textSecondary,
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 2),
          GridView.builder(
            padding: EdgeInsets.zero,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              mainAxisSpacing: 6,
              crossAxisSpacing: 6,
              childAspectRatio: 1.1,
            ),
            itemCount: 42,
            itemBuilder: (context, index) {
              final day = gridDates[index];
              final isCurrentMonth = day.month == month;
              final isToday = DateUtils.isSameDay(day, DateTime.now());
              final isSelected =
                  _selectedCalendarDay != null &&
                  DateUtils.isSameDay(day, _selectedCalendarDay!);
              final dayTasks =
                  tasksByDay[DateUtils.dateOnly(day)] ?? const <Task>[];

              return GestureDetector(
                onTap: () {
                  _rebuild(() {
                    _selectedCalendarDay = day;
                  });
                },
                child: Container(
                  decoration: BoxDecoration(
                    color: isSelected
                        ? colors.brand.withValues(alpha: 0.15)
                        : isCurrentMonth
                        ? colors.surface
                        : colors.background,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isSelected
                          ? colors.brand
                          : isToday
                          ? colors.brand.withValues(alpha: 0.5)
                          : colors.border,
                      width: isSelected ? 1.5 : 1.0,
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        '${day.day}',
                        style: textStyles.smallMono.copyWith(
                          fontWeight: isToday || isSelected
                              ? FontWeight.w500
                              : FontWeight.w400,
                          color: isCurrentMonth
                              ? (isToday ? colors.brand : colors.textPrimary)
                              : colors.textTooltip,
                        ),
                      ),
                      if (dayTasks.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: dayTasks.take(3).map((t) {
                            Color dotColor = colors.brand;
                            if (t.priority == TaskPriority.urgent) {
                              dotColor = colors.accentRed;
                            } else if (t.priority == TaskPriority.high) {
                              dotColor = colors.accentAmber;
                            } else if (t.priority == TaskPriority.low) {
                              dotColor = colors.accentGreen;
                            }
                            return Container(
                              width: 5,
                              height: 5,
                              margin: const EdgeInsets.symmetric(horizontal: 1),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: dotColor,
                              ),
                            );
                          }).toList(),
                        ),
                      ],
                    ],
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 20),
          if (_selectedCalendarDay != null) ...[
            Text(
              language.translate(
                'tasks_calendar_due_on',
                params: {
                  'date': _formatLocalizedLongDate(
                    language,
                    _selectedCalendarDay!,
                  ),
                },
              ),
              style: textStyles.bodySans.copyWith(fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 8),
            _buildDayTasksList(
              context,
              tasksByDay[DateUtils.dateOnly(_selectedCalendarDay!)] ??
                  const <Task>[],
              projects,
              assignees,
            ),
          ] else ...[
            Center(
              child: Text(
                language.translate('tasks_calendar_select_day'),
                style: textStyles.captionSans.copyWith(
                  color: colors.textTooltip,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDayTasksList(
    BuildContext context,
    List<Task> dayTasks,
    List<TaskProject> projects,
    List<TaskAssignee> assignees,
  ) {
    final colors = context.colors;
    final textStyles = context.textStyles;
    final language = context.watch<LanguageCubit>();

    if (dayTasks.isEmpty) {
      return LedgerCard(
        padding: const EdgeInsets.all(16),
        child: Center(
          child: Text(
            language.translate('tasks_calendar_empty_day'),
            style: textStyles.captionSans.copyWith(color: colors.textTooltip),
          ),
        ),
      );
    }

    return Column(
      children: dayTasks.map((task) {
        return GestureDetector(
          onTap: () {
            if (task.isPersonal) {
              _showPersonalTaskSheet(context, editing: task);
              return;
            }
            if (_canManageTasks(context)) {
              _showEditTaskBottomSheet(context, task, projects, assignees);
            }
          },
          child: Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: colors.surface,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: colors.border),
            ),
            child: Row(
              children: [
                Container(
                  width: 4,
                  height: 32,
                  decoration: BoxDecoration(
                    color: task.priority == TaskPriority.urgent
                        ? colors.accentRed
                        : task.priority == TaskPriority.high
                        ? colors.accentAmber
                        : task.priority == TaskPriority.low
                        ? colors.accentGreen
                        : colors.brand,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        task.title,
                        style: textStyles.bodySans.copyWith(
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: [
                          LedgerPill(
                            text: language.translate(
                              task.isPersonal
                                  ? 'tasks_source_personal'
                                  : 'tasks_source_corporate',
                            ),
                            backgroundColor: task.isPersonal
                                ? colors.accentAmber.withValues(alpha: 0.12)
                                : colors.surfaceNested,
                            textColor: task.isPersonal
                                ? colors.accentAmber
                                : colors.textSecondary,
                          ),
                          if (task.projectName != null)
                            Text(
                              language.translate(
                                'tasks_project_value',
                                params: {'project': task.projectName!},
                              ),
                              style: textStyles.captionSans.copyWith(
                                color: colors.textSecondary,
                              ),
                            ),
                          if (task.assigneeName != null &&
                              task.assigneeName!.trim().isNotEmpty)
                            Text(
                              language.translateMessage(task.assigneeName!),
                              style: textStyles.captionSans.copyWith(
                                color: colors.textSecondary,
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                LedgerPill(
                  text: language.translate(task.status.localizationKey),
                  backgroundColor: colors.brand.withValues(alpha: 0.08),
                  textColor: colors.brand,
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}
